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
import AudioStreaming
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

// MARK: - BenchDelegate

// Needs `serve.py <dir> 8765` on the host serving moov-end.m4b and moov-front.m4b.
final class BenchDelegate: AudioPlayerDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var _errors = [String]()
  private var _started = false
  var errors: [String] { lock.withLock { _errors } }
  var started: Bool { lock.withLock { _started } }

  func audioPlayerDidStartPlaying(player: AudioStreaming.AudioPlayer, with entryId: AudioEntryId) {
    lock.withLock { _started = true }
  }

  func audioPlayerUnexpectedError(player: AudioStreaming.AudioPlayer, error: AudioPlayerError) {
    lock.withLock { _errors.append("\(error)") }
  }

  func audioPlayerDidFinishBuffering(
    player: AudioStreaming.AudioPlayer,
    with entryId: AudioEntryId
  ) {}
  func audioPlayerStateChanged(
    player: AudioStreaming.AudioPlayer,
    with newState: AudioPlayerState,
    previous: AudioPlayerState
  ) {}
  func audioPlayerDidFinishPlaying(
    player: AudioStreaming.AudioPlayer,
    entryId: AudioEntryId,
    stopReason: AudioPlayerStopReason,
    progress: Double,
    duration: Double
  ) {}
  func audioPlayerDidCancel(player: AudioStreaming.AudioPlayer, queuedItems: [AudioEntryId]) {}
  func audioPlayerDidReadMetadata(player: AudioStreaming.AudioPlayer, metadata: [String: String]) {}
}

// MARK: - M4bPlaybackBench

@MainActor
class M4bPlaybackBench: XCTestCase {
  let server = "http://127.0.0.1:8765"

  func wait(_ seconds: Double) {
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
  }

  func run(_ label: String, url: URL) -> String {
    let delegate = BenchDelegate()
    let player = AudioStreaming.AudioPlayer()
    player.delegate = delegate
    player.volume = 0
    player.play(url: url)
    wait(4)
    let progressBeforeSeek = player.progress
    let duration = player.duration
    player.seek(to: 30)
    wait(3)
    let progressAfterSeek = player.progress
    let state = player.state
    player.stop()
    wait(0.5)
    let started = delegate.started
    let errors = delegate.errors
    let ok = started && errors.isEmpty && progressBeforeSeek > 1 && progressAfterSeek > 30
    let line = String(
      format: "BENCH %@ %@ | started=%d progress=%.1f duration=%.1f afterSeek(30)=%.1f state=%@ errors=%@",
      ok ? "OK  " : "FAIL",
      label,
      started ? 1 : 0,
      progressBeforeSeek,
      duration,
      progressAfterSeek,
      "\(state)",
      errors.joined(separator: "; ")
    )
    print(line)
    return line
  }

  func localCopy(of file: String, ext: String) throws -> URL {
    let data = try Data(contentsOf: URL(string: "\(server)/\(file)")!)
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("bench-\(file)").deletingPathExtension().appendingPathExtension(ext)
    try data.write(to: url)
    return url
  }

  func testMatrix() throws {
    for file in ["moov-end.m4b", "moov-front.m4b"] {
      for ext in ["unknown", "m4b", "mp4", "m4a"] {
        _ = try run("local  \(file) as .\(ext)", url: localCopy(of: file, ext: ext))
      }
      for mime in ["audio/m4b", "audio/x-m4b", "audio/mp4", "audio/x-m4a"] {
        _ = run("stream \(file) ct=\(mime)", url: URL(string: "\(server)/\(file)?ct=\(mime)")!)
      }
    }
  }
}

// MARK: - MimeFileConverterTest

class MimeFileConverterTest: XCTestCase {
  func testM4bGetsMp4Extension() {
    XCTAssertEqual(MimeFileConverter.getFilenameExtension(mimeType: "audio/m4b"), "mp4")
    XCTAssertEqual(MimeFileConverter.getFilenameExtension(mimeType: "audio/x-m4b"), "mp4")
    XCTAssertEqual(MimeFileConverter.getFilenameExtension(mimeType: "Audio/M4B"), "mp4")
  }

  func testM4aExtensions() {
    XCTAssertEqual(MimeFileConverter.getFilenameExtension(mimeType: "audio/m4a"), "mp4")
    XCTAssertEqual(MimeFileConverter.getFilenameExtension(mimeType: "audio/x-m4a"), "m4a")
    XCTAssertEqual(MimeFileConverter.getFilenameExtension(mimeType: "audio/mp4"), "mp4")
  }

  func testOtherExtensionsUnchanged() {
    XCTAssertEqual(MimeFileConverter.getFilenameExtension(mimeType: "audio/mpeg"), "mp3")
    XCTAssertEqual(MimeFileConverter.getFilenameExtension(mimeType: "audio/x-flac"), "flac")
    XCTAssertEqual(MimeFileConverter.getFilenameExtension(mimeType: "audio/ogg"), "ogg")
    XCTAssertEqual(MimeFileConverter.getFilenameExtension(mimeType: nil), "unknown")
  }

  func testM4bIsConvertedForPlayer() {
    XCTAssertEqual(
      MimeFileConverter.convertToValidMimeTypeWhenNeccessary(mimeType: "audio/m4b"),
      "audio/mp4"
    )
  }
}
