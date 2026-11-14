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

// MARK: - MimeFileConverterTest

class MimeFileConverterTest: XCTestCase {
  func testM4bGetsMp4Extension() {
    XCTAssertEqual(MimeFileConverter.getFilenameExtension(mimeType: "audio/m4b"), "mp4")
    XCTAssertEqual(MimeFileConverter.getFilenameExtension(mimeType: "audio/x-m4b"), "mp4")
  }
}

// MARK: - PlayContextAlbumTest

@MainActor
class PlayContextAlbumTest: XCTestCase {
  var cdHelper: CoreDataHelper!
  var library: LibraryStorage!
  var companion: CoreDataCompanion!
  var account: Account!
  var album: Album!

  override func setUp() async throws {
    cdHelper = CoreDataHelper()
    library = cdHelper.createSeededStorage()
    companion = CoreDataCompanion(context: cdHelper.persistentContainer.viewContext)
    account = library.getAccount(info: TestAccountInfo.create1())
    album = library.createAlbum(account: account)
    album.remoteStatus = .available
  }

  private func addSong(track: Int, disc: String? = nil, cached: Bool = false) -> Song {
    let song = library.createSong(account: account)
    song.track = track
    song.disk = disc
    song.size = 1000
    song.album = album
    if cached {
      song.relFilePath = URL(string: "song\(disc ?? "")\(track).mp3")
    }
    library.saveContext()
    return song
  }

  private func context(
    for song: Song,
    onlyCached: Bool = false
  )
    -> PlayContext? {
    PlayContext(songInAlbumContext: song, onlyCached: onlyCached, coreDataCompanion: companion)
  }

  func testAlbumQueuedStartingAtSong() {
    let songs = [addSong(track: 1), addSong(track: 2), addSong(track: 3)]
    let context = context(for: songs[1])
    XCTAssertEqual(context?.playables.compactMap { $0.asSong }, songs)
    XCTAssertEqual(context?.index, 1)
    XCTAssertEqual(context?.getActivePlayable(), songs[1])
  }

  func testTwoDiscAlbumIsQueuedDiscByDisc() {
    let disc2Track1 = addSong(track: 1, disc: "2")
    let disc1Track2 = addSong(track: 2, disc: "1")
    let disc2Track2 = addSong(track: 2, disc: "2")
    let disc1Track1 = addSong(track: 1, disc: "1")
    let context = context(for: disc2Track1)
    XCTAssertEqual(
      context?.playables.compactMap { $0.asSong },
      [disc1Track1, disc1Track2, disc2Track1, disc2Track2]
    )
    XCTAssertEqual(context?.index, 2)
  }

  func testSongWithoutAlbumIsQueuedAlone() {
    let song = library.createSong(account: account)
    let context = context(for: song)
    XCTAssertEqual(context?.playables.count, 1)
    XCTAssertEqual(context?.getActivePlayable(), song)
  }

  func testUnsyncedAlbumQueuesOnlyKnownSongsUntilFetched() {
    let first = addSong(track: 1)
    XCTAssertFalse(album.isSongsMetaDataSynced)
    XCTAssertEqual(context(for: first)?.playables.count, 1)
    // what the album fetch does: store the album's other songs
    let second = addSong(track: 2)
    let context = context(for: first)
    XCTAssertEqual(context?.playables.compactMap { $0.asSong }, [first, second])
    XCTAssertEqual(context?.index, 0)
  }

  func testOfflineQueuesOnlyCachedSongs() {
    _ = addSong(track: 1)
    let cached2 = addSong(track: 2, cached: true)
    let cached3 = addSong(track: 3, cached: true)
    let context = context(for: cached3, onlyCached: true)
    XCTAssertEqual(context?.playables.compactMap { $0.asSong }, [cached2, cached3])
    XCTAssertEqual(context?.index, 1)
  }

  func testOfflineUncachedSongWithCachedSiblingsPlaysNothing() {
    let uncached = addSong(track: 1)
    _ = addSong(track: 2, cached: true)
    XCTAssertNil(context(for: uncached, onlyCached: true))
  }
}
