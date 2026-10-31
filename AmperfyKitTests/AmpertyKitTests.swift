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

// MARK: - CacheDownloadQueryTests

class CacheDownloadQueryTests: XCTestCase {
  private func dict(_ items: [URLQueryItem]) -> [String: String] {
    Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
  }

  // Ampache: only `stream` honours `bitrate` (bits per second), `download` ignores it.

  func testAmpacheMp3WithCapUsesStreamWithBitsPerSecond() {
    let items = dict(AmpacheXmlServerApi.downloadQueryItems(format: .mp3, maxBitrate: .limit128))
    XCTAssertEqual(items, [
      "action": "stream", "format": "mp3", "bitrate": "128000",
    ])
  }

  func testAmpacheMp3WithoutCapUsesDownload() {
    let items = dict(AmpacheXmlServerApi.downloadQueryItems(format: .mp3, maxBitrate: .noLimit))
    XCTAssertEqual(items, ["action": "download", "format": "mp3"])
  }

  func testAmpacheRawAndServerConfigIgnoreCap() {
    for format in [CacheTranscodingFormatPreference.raw, .serverConfig] {
      let items = dict(AmpacheXmlServerApi.downloadQueryItems(
        format: format,
        maxBitrate: .limit128
      ))
      XCTAssertEqual(items, ["action": "download", "format": "raw"], "\(format)")
    }
  }

  func testAmpacheEveryCapIsSentInBitsPerSecond() {
    for cap in CacheMaxBitratePreference.allCases where cap != .noLimit {
      let items = dict(AmpacheXmlServerApi.downloadQueryItems(format: .mp3, maxBitrate: cap))
      XCTAssertEqual(items["bitrate"], String(cap.rawValue * 1000))
    }
  }

  // Subsonic: `download` is the original file; a cap needs `stream`.

  func testSubsonicRawUsesDownloadWithoutParameters() {
    let (action, items) = SubsonicServerApi.downloadAction(format: .raw, maxBitrate: .limit128)
    XCTAssertEqual(action, "download")
    XCTAssertTrue(items.isEmpty)
  }

  func testSubsonicMp3WithCap() {
    let (action, items) = SubsonicServerApi.downloadAction(format: .mp3, maxBitrate: .limit128)
    XCTAssertEqual(action, "stream")
    XCTAssertEqual(dict(items), ["format": "mp3", "maxBitRate": "128"])
  }

  func testSubsonicMp3WithoutCap() {
    let (action, items) = SubsonicServerApi.downloadAction(format: .mp3, maxBitrate: .noLimit)
    XCTAssertEqual(action, "stream")
    XCTAssertEqual(dict(items), ["format": "mp3"])
  }

  func testSubsonicServerConfigWithCapHasNoFormat() {
    let (action, items) = SubsonicServerApi.downloadAction(
      format: .serverConfig,
      maxBitrate: .limit128
    )
    XCTAssertEqual(action, "stream")
    XCTAssertEqual(dict(items), ["maxBitRate": "128"])
  }
}
