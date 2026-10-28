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

// MARK: - ArtworkCacheSizeBenchTest

class ArtworkCacheSizeBenchTest: XCTestCase {
  func testBenchGetArtworkCacheSize() throws {
    let fm = CacheFileManager.shared
    let info = AccountInfo(
      serverHash: "bench-\(UUID().uuidString)",
      userHash: "bench",
      apiType: .notDetected
    )
    let dir = try XCTUnwrap(fm.getOrCreateAbsoluteArtworksDirectory(for: info))
    defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }

    // ~60 KB each, roughly a cached cover
    let payload = Data(repeating: 0xAB, count: 60_000)
    var created = 0
    var report = "BENCH device-results (ms; median of 7 runs, 1 cold run first)\n"
    for target in [100, 1000, 10_000] {
      while created < target {
        try payload.write(to: dir.appendingPathComponent("\(created).png"))
        created += 1
      }
      var times = [Double]()
      var size: Int64 = 0
      for _ in 0 ..< 8 {
        let start = DispatchTime.now().uptimeNanoseconds
        size = fm.getArtworkCacheSize(for: info)
        times.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)
      }
      let cold = times[0]
      let warm = times.dropFirst().sorted()[3]
      XCTAssertEqual(size, Int64(target * 60_000))
      report +=
        "BENCH n=\(target) cold=\(String(format: "%.2f", cold)) median=\(String(format: "%.2f", warm)) min=\(String(format: "%.2f", times.dropFirst().min()!)) max=\(String(format: "%.2f", times.dropFirst().max()!))\n"
    }
    print(report)
  }
}
