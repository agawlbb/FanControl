import XCTest
@testable import FanControlCore

final class CacheAndToggleTests: XCTestCase {
    func testSwipedDefaultSurvivesRecreationUntilHAChanges() throws {
        let suite = "tile-test-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var c = try connection()
        let other = try JSONDecoder().decode(Device.self, from: Data("{\"entity\":\"fan.other\",\"title\":\"Other\"}".utf8))
        c.devices.append(other)
        let tile = DefaultWatchTile(defaults: defaults)
        tile.save(other.entity, connection: c)
        XCTAssertEqual(DefaultWatchTile(defaults: defaults).load(c), other.entity)
        c.companion_settings = CompanionSettings(order: [other.entity])
        XCTAssertEqual(tile.load(c), other.entity)
        tile.save(c.entity, connection: c)
        XCTAssertEqual(tile.load(c), c.entity)
        tile.save(other.entity, connection: c)
        var changed = c; changed.revision = 2
        XCTAssertNil(tile.load(changed))
        XCTAssertNil(tile.load(c)) // An old preference cannot return after HA changes back.
        tile.save(other.entity, connection: c)
        changed = c; changed.entity = other.entity
        XCTAssertNil(tile.load(changed))
        tile.save(other.entity, connection: c)
        changed = c; changed.devices.removeLast()
        XCTAssertNil(tile.load(changed))
        tile.save(other.entity, connection: c)
        changed = c; changed.watch_id = String(repeating: "c", count: 32)
        XCTAssertNil(tile.load(changed))
        tile.save(other.entity, connection: c)
        tile.clear()
        XCTAssertNil(tile.load(c))
    }
    private func connection() throws -> Connection {
        let json = """
        {"url":"https://ha.example","token":"\(String(repeating: "a", count: 64))","watch_id":"\(String(repeating: "b", count: 32))","entity":"panel.fan","devices":[{"entity":"panel.fan","title":"Fan","panel":{"id":"fan","name":"Fan","type":"fan","fan_entity":"fan.bedroom"}}]}
        """
        return try JSONDecoder().decode(Connection.self, from: Data(json.utf8)).validated()
    }
    func testCacheSurvivesRecreationAndRejectsUnavailableProjectionAndOtherRoles() throws {
        let suite = "cache-test-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let c = try connection(), d = c.active!
        let cache = ObservationCache(defaults: defaults)
        cache.save(["state":"on", "attributes":["percentage":66]], connection:c, device:d)
        cache.save(["state":"unavailable", "attributes":["percentage":0], "requested":"off"], connection:c, device:d)
        let restored = ObservationCache(defaults: defaults).load(c, d)
        XCTAssertEqual(restored["state"] as? String, "on")
        XCTAssertEqual((restored["attributes"] as? [String:Any])?["percentage"] as? Int, 66)
        XCTAssertNil(restored["requested"])
        var other = c; other.watch_id = String(repeating:"c", count:32)
        XCTAssertTrue(cache.load(other,d).isEmpty)
        let encoded = try JSONEncoder().encode(d)
        let changed = try JSONDecoder().decode(Device.self, from: Data(String(decoding:encoded,as:UTF8.self).replacingOccurrences(of:"fan.bedroom",with:"fan.other").utf8))
        XCTAssertTrue(cache.load(c,changed).isEmpty)
        cache.clear(); XCTAssertTrue(cache.load(c,d).isEmpty)
    }
    func testGrayToggleReversesDisplayedRequestAndNeverUsesToggleCommand() {
        for command in ["turn_on","turn_off","climate_on","climate_off","garage_open","garage_close","trunk_open","trunk_close"] {
            let next = ToggleIntent.opposite(command)!
            XCTAssertNotEqual(next,command)
            XCTAssertEqual(ToggleIntent.opposite(next),command)
            XCTAssertTrue(ToggleIntent.replaces(next,command))
            XCTAssertFalse(next.contains("toggle"))
        }
        XCTAssertFalse(ToggleIntent.replaces("turn_off","climate_on"))
        XCTAssertFalse(ToggleIntent.replaces("turn_off","speed4"))
        XCTAssertNil(ToggleIntent.opposite("honk"))
    }
    func testInitialAndMovingCoversChooseOppositeOfDisplayedStateWithoutClaimingConfirmation() {
        for observed in [nil, "unknown", "unavailable", "closed", "closing"] as [String?] {
            XCTAssertEqual(ToggleIntent.coverPresentation(observed), "CLOSED")
            XCTAssertEqual(Evidence.coverIntent(observed), "open")
        }
        for observed in ["open", "opening"] {
            XCTAssertEqual(ToggleIntent.coverPresentation(observed), "OPEN")
            XCTAssertEqual(Evidence.coverIntent(observed), "close")
        }
        // Once the first tap projects OPEN, a second tap chooses CLOSE even
        // if a delayed CLOSED observation arrives in between.
        XCTAssertEqual(ToggleIntent.opposite("trunk_open"), "trunk_close")
    }
}
