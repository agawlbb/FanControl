import XCTest
@testable import FanControlCore

final class MusicSyncHandshakeTests: XCTestCase {
    func testLateActivationAndReachabilitySubmitOnce() {
        let now = Date(timeIntervalSince1970: 1000)
        var attempt = MusicSyncAttempt(watchID: "watch", now: now)
        XCTAssertFalse(attempt.claim(activated: false, reachable: false, watchID: "watch", now: now))
        XCTAssertFalse(attempt.claim(activated: true, reachable: false, watchID: "watch", now: now))
        XCTAssertTrue(attempt.claim(activated: true, reachable: true, watchID: "watch", now: now.addingTimeInterval(1)))
        XCTAssertFalse(attempt.claim(activated: true, reachable: true, watchID: "watch", now: now.addingTimeInterval(2)))
    }
    func testExpiredAndOtherWatchAttemptsCannotSubmit() {
        let now = Date(timeIntervalSince1970: 1000)
        var attempt = MusicSyncAttempt(watchID: "watch", now: now)
        XCTAssertFalse(attempt.claim(activated: true, reachable: true, watchID: "other", now: now))
        XCTAssertFalse(attempt.claim(activated: true, reachable: true, watchID: "watch", now: now.addingTimeInterval(15)))
        let retry = MusicSyncAttempt(watchID: "watch", now: now.addingTimeInterval(20))
        XCTAssertNotEqual(retry.id, attempt.id)
    }
    func testReplyCarriesOneSongWithoutApplicationContextDelivery() throws {
        let id = UUID()
        let track = ExerciseTrack(name: "one.mp3", sha256: String(repeating: "a", count: 64), size: 20)
        let manifest = try OfflinePlaylist(watchID: "watch", tracks: [track])
        let reply = MusicSyncReply(requestID: id, watchID: "watch", playlist: manifest)
        let decoded = try JSONDecoder().decode(MusicSyncReply.self, from: JSONEncoder().encode(reply))
        XCTAssertEqual(try decoded.resolved(requestID: id, watchID: "watch"), manifest)
        XCTAssertEqual(try decoded.resolved(requestID: id, watchID: "watch").tracks.count, 1)
    }
    func testStaleWrongTargetMissingAndInvalidPlaylistsCannotConfirm() throws {
        let id = UUID(), other = try OfflinePlaylist(watchID: "other", tracks: [])
        XCTAssertThrowsError(try MusicSyncReply(requestID: id, watchID: "watch", playlist: other).resolved(requestID: id, watchID: "watch"))
        let valid = try OfflinePlaylist(watchID: "watch", tracks: [])
        XCTAssertThrowsError(try MusicSyncReply(requestID: UUID(), watchID: "watch", playlist: valid).resolved(requestID: id, watchID: "watch"))
        XCTAssertThrowsError(try MusicSyncReply(requestID: id, watchID: "other", playlist: valid).resolved(requestID: id, watchID: "watch"))
        XCTAssertThrowsError(try MusicSyncReply(requestID: id, watchID: "watch").resolved(requestID: id, watchID: "watch"))
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as! [String: Any]
        json["generation"] = 0
        let invalid = try JSONDecoder().decode(OfflinePlaylist.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertThrowsError(try MusicSyncReply(requestID: id, watchID: "watch", playlist: invalid).resolved(requestID: id, watchID: "watch"))
    }
    func testPhoneFailuresAreDistinctFromTransportFailure() {
        let id = UUID()
        for failure in [MusicSyncFailure.notLinked, .differentWatch, .transferUnavailable] {
            XCTAssertThrowsError(try MusicSyncReply(requestID: id, watchID: nil, failure: failure).resolved(requestID: id, watchID: "watch")) { error in
                XCTAssertEqual(error as? MusicSyncFailure, failure)
            }
        }
        XCTAssertNotEqual(MusicSyncFailure.notLinked.message, MusicSyncFailure.differentWatch.message)
    }
}
