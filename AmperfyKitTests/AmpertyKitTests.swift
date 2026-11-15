//
//  AmpertyKitTests.swift
//  AmperfyKitTests
//
//  Created by Maximilian Bauer on 06.06.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

@testable import AmperfyKit
import CoreData
import XCTest

// MARK: - AmperfyKitTests

class AmperfyKitTests: XCTestCase {
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testExample() throws {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    // Any test you write for XCTest can be annotated as throws and async.
    // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
    // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
  }

  func testPerformanceExample() throws {
    // This is an example of a performance test case.
    measure {
      // Put the code you want to measure the time of here.
    }
  }
}

// MARK: - MimeFileConverterTest

class MimeFileConverterTest: XCTestCase {
  func testM4bGetsMp4Extension() {
    XCTAssertEqual(MimeFileConverter.getFilenameExtension(mimeType: "audio/m4b"), "mp4")
    XCTAssertEqual(MimeFileConverter.getFilenameExtension(mimeType: "audio/x-m4b"), "mp4")
  }
}

// MARK: - LogPruneBench

@MainActor
class LogPruneBench: XCTestCase {
  private func peakResidentBytes() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
      MemoryLayout<mach_task_basic_info>
        .size / MemoryLayout<natural_t>.size
    )
    let kr = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    return kr == KERN_SUCCESS ? UInt64(info.resident_size_max) : 0
  }

  /// Real SQLite file store in a temp dir, filled with `entries` log entries.
  private func makeStore(entries: Int) throws -> (PersistentStorage, NSPersistentContainer, URL) {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("LogPruneBench-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("Amperfy.sqlite")
    let container = NSPersistentContainer(
      name: "Amperfy",
      managedObjectModel: CoreDataPersistentManager.managedObjectModel
    )
    let description = NSPersistentStoreDescription(url: url)
    description.type = NSSQLiteStoreType
    description.shouldAddStoreAsynchronously = false
    container.persistentStoreDescriptions = [description]
    container.loadPersistentStores { _, error in
      if let error { fatalError("\(error)") }
    }
    let ctx = container.newBackgroundContext()
    let base = Date().addingTimeInterval(-86400)
    var i = 0
    while i < entries {
      let end = min(i + 5000, entries)
      let from = i
      ctx.performAndWait {
        for n in from ..< end {
          let mo = LogEntryMO(context: ctx)
          mo.creationDate = base.addingTimeInterval(Double(n) * 0.01)
          mo.message = "Seed entry \(n): some connection error message of typical length ........"
          mo.statusCode = 0
          mo.type = 0
        }
        try! ctx.save()
        ctx.reset()
      }
      i = end
    }
    let storage =
      PersistentStorage(coreDataManager: MOCK_CoreDataManager(persistentContainer: container))
    return (storage, container, dir)
  }

  private func count(_ container: NSPersistentContainer) -> Int {
    let ctx = container.newBackgroundContext()
    return ctx.performAndWait { (try? ctx.count(for: LogEntryMO.fetchRequest())) ?? -1 }
  }

  /// Same body as EventLogger.saveAndDisplay, with the prune call switchable.
  private func writeOne(_ storage: PersistentStorage, prune: Bool, cap: Int = 5000) async throws {
    try await storage.async.perform { companion in
      let logEntry = companion.library.createLogEntry()
      logEntry.type = .debug
      logEntry.statusCode = 0
      logEntry.message = "Bench: a typical logged message of moderate length ........"
      if prune { companion.library.deleteLogEntries(keepingNewest: cap) }
      companion.saveContext()
    }
  }

  private func ms(_ a: UInt64, _ b: UInt64) -> Double { Double(b - a) / 1_000_000 }

  private func timed(
    _ storage: PersistentStorage,
    prune: Bool,
    warmup: Int,
    reps: Int
  ) async throws
    -> (mean: Double, max: Double) {
    for _ in 0 ..< warmup { try await writeOne(storage, prune: prune) }
    var times = [Double]()
    for _ in 0 ..< reps {
      let t0 = DispatchTime.now().uptimeNanoseconds
      try await writeOne(storage, prune: prune)
      times.append(ms(t0, DispatchTime.now().uptimeNanoseconds))
    }
    return (times.reduce(0, +) / Double(times.count), times.max()!)
  }

  private func report(_ name: String, _ r: (mean: Double, max: Double), _ extra: String = "") {
    print(String(format: "BENCH %@ mean=%.2f ms max=%.2f ms %@", name, r.mean, r.max, extra))
  }

  func testCases1to3() async throws {
    print("BENCH store=SQLite on-disk (temp dir), simulator")
    let (s1, c1, d1) = try makeStore(entries: 5000)
    report(
      "case1 baseline 5000 entries, no prune",
      try await timed(s1, prune: false, warmup: 20, reps: 300),
      "final count=\(count(c1))"
    )
    try? FileManager.default.removeItem(at: d1)

    let (s2, c2, d2) = try makeStore(entries: 5000)
    report(
      "case2 prune 5000 entries",
      try await timed(s2, prune: true, warmup: 20, reps: 300),
      "final count=\(count(c2))"
    )
    try? FileManager.default.removeItem(at: d2)

    let (s3, c3, d3) = try makeStore(entries: 500)
    report(
      "case3 prune 500 entries (below cap)",
      try await timed(s3, prune: true, warmup: 20, reps: 300),
      "final count=\(count(c3))"
    )
    try? FileManager.default.removeItem(at: d3)
  }

  func testCase4Burst() async throws {
    for prune in [false, true] {
      let (s, c, d) = try makeStore(entries: 5000)
      for _ in 0 ..< 10 { try await writeOne(s, prune: prune) }
      let t0 = DispatchTime.now().uptimeNanoseconds
      for _ in 0 ..< 200 { try await writeOne(s, prune: prune) }
      let total = ms(t0, DispatchTime.now().uptimeNanoseconds)
      print(String(
        format: "BENCH case4 burst 200 sequential writes prune=%@ total=%.1f ms (%.2f ms/entry) final count=%d",
        "\(prune)",
        total,
        total / 200,
        count(c)
      ))
      try? FileManager.default.removeItem(at: d)
    }
  }

  func testCase5FirstRunAfterUpdate() async throws {
    for prune in [false, true] {
      let (s, c, d) = try makeStore(entries: 50000)
      try await writeOne(s, prune: false) // warm up connection / model
      let peak0 = peakResidentBytes()
      let t0 = DispatchTime.now().uptimeNanoseconds
      try await writeOne(s, prune: prune)
      let t = ms(t0, DispatchTime.now().uptimeNanoseconds)
      let peak1 = peakResidentBytes()
      print(String(
        format: "BENCH case5 50000 entries one write prune=%@ time=%.1f ms peakResident before=%.0f MB after=%.0f MB final count=%d",
        "\(prune)",
        t,
        Double(peak0) / 1_048_576,
        Double(peak1) / 1_048_576,
        count(c)
      ))
      try? FileManager.default.removeItem(at: d)
    }
  }
}
