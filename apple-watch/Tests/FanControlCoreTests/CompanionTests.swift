import XCTest
@testable import FanControlCore
final class CompanionTests: XCTestCase {
    func testPlaylistValidationAndOrderRoundTrip() throws {
        let a = ExerciseTrack(name: "a.mp3", sha256: String(repeating: "a", count: 64), size: 20)
        let b = ExerciseTrack(name: "b.m4a", sha256: String(repeating: "b", count: 64), size: 30)
        let list = try OfflinePlaylist(watchID: "watch", tracks: [b, a])
        XCTAssertEqual(try JSONDecoder().decode(OfflinePlaylist.self, from: JSONEncoder().encode(list)), list)
        XCTAssertThrowsError(try OfflinePlaylist(watchID: "watch", tracks: [a, a]))
        XCTAssertThrowsError(try OfflinePlaylist(watchID: "watch", tracks: Array(repeating: a, count: 26)))
        XCTAssertNoThrow(try OfflinePlaylist(watchID: "watch", tracks: []))
        let oversized = ExerciseTrack(name: "huge.mp3", sha256: String(repeating: "d", count: 64), size: Int.max)
        XCTAssertThrowsError(try OfflinePlaylist(watchID: "watch", tracks: [oversized]))
    }
    func testSnapshotKeepsReceiverCredentialAndRejectsOtherWatchOrServer() throws {
        let config: [String: Any] = ["url": "https://example.invalid", "entity": "fan.test",
            "devices": [["entity": "fan.test", "title": "Fan"]], "revision": 3]
        var complete = config
        complete["watch_id"] = String(repeating: "b", count: 32)
        complete["token"] = String(repeating: "a", count: 64)
        let c = try JSONDecoder().decode(Connection.self, from: JSONSerialization.data(withJSONObject: complete)).validated()
        var phone = c; phone.token = String(repeating: "c", count: 64); phone.companion = true
        let snapshot = try CompanionSnapshot(response: ["configuration": config,
            "states": ["fan.test": ["state": "on"]], "sequence": 2, "at_ms": Int64(1000)], connection: phone)
        let withMessages = try CompanionSnapshot(response: ["configuration": config,
            "states": ["fan.test": ["state": "on"]], "sequence": 3, "at_ms": Int64(2000),
            "messages": [["id": "alert", "title": "Delay", "message": "Read the complete message", "at_ms": 1000]]], connection: phone)
        XCTAssertFalse(String(data: try JSONEncoder().encode(withMessages), encoding: .utf8)!.contains("Read the complete message"))
        let cleared = try CompanionSnapshot(response: ["configuration": config,
            "states": ["fan.test": ["state": "on"]], "sequence": 4, "at_ms": Int64(3000),
            "messages": []], connection: phone)
        XCTAssertEqual(cleared.sequence, 4) // Old HA message fields never become phone state.
        XCTAssertEqual(try snapshot.resolved(for: c).token, c.token)
        XCTAssertNil(try snapshot.resolved(for: c).companion)
        var other = c; other.watch_id = String(repeating: "d", count: 32)
        XCTAssertThrowsError(try snapshot.resolved(for: other))
        other = c; other.url = "https://other.invalid"
        XCTAssertThrowsError(try snapshot.resolved(for: other))
        let raw = String(data: try JSONEncoder().encode(snapshot), encoding: .utf8)!
        XCTAssertFalse(raw.contains(c.token)); XCTAssertFalse(raw.contains(phone.token))
    }
}
