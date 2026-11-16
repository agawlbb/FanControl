import XCTest
@testable import FanControlCore

final class OnDutyTests: XCTestCase {
    @MainActor func testFlightSelectionComesFromConfiguredSensors() async throws {
        let raw = Data(#"{"entity":"panel.on_duty","title":"On Duty","panel":{"id":"on_duty","name":"On Duty","type":"on_duty","city_pair_entity":"sensor.airports","departure_entity":"sensor.departure"}}"#.utf8)
        let device = try JSONDecoder().decode(Device.self, from: raw)
        try device.panel!.validateRoles()
        XCTAssertFalse(device.panel!.vehicle)
        XCTAssertEqual(VisibleStateRefresh.available(["available": true], for: device), true)
        XCTAssertFalse(VisibleStateRefresh.available(["available": false], for: device))
    }
    private func connection() throws -> Connection {
        let json = """
        {"url":"https://ha.example","token":"\(String(repeating: "a", count: 64))","watch_id":"\(String(repeating: "b", count: 32))","entity":"panel.on_duty","devices":[{"entity":"panel.on_duty","title":"On Duty","panel":{"id":"on_duty","name":"On Duty","type":"on_duty","city_pair_entity":"sensor.airports","departure_entity":"sensor.departure"}}]}
        """
        return try JSONDecoder().decode(Connection.self, from: Data(json.utf8)).validated()
    }
    @MainActor func testLastFlightSurvivesReopeningWithoutBecomingFresh() async throws {
        let suite = "flight-cache-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let c = try connection(), d = try XCTUnwrap(c.active)
        let state: [String: Any] = ["city_pair": "TPA → CLT", "departure": "2026-11-05T18:52:00+00:00", "available": true]
        ObservationCache(defaults: defaults).save(state, connection: c, device: d)
        let restored = ObservationCache(defaults: defaults).load(c, d)
        XCTAssertEqual(restored["city_pair"] as? String, "TPA → CLT")
        XCTAssertEqual(restored["departure"] as? String, state["departure"] as? String)
        XCTAssertNil(restored["available"])
        XCTAssertFalse(VisibleStateRefresh.available(restored, for: d))
        XCTAssertTrue(VisibleStateRefresh.available(state, for: d))
    }
    func testUnavailableAndPartialUpdatesPreserveOneCompleteFlight() throws {
        let suite = "flight-cache-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let c = try connection(), d = try XCTUnwrap(c.active)
        let cache = ObservationCache(defaults: defaults)
        cache.save(["city_pair": "TPA → CLT", "departure": "2026-11-05T18:52:00Z", "available": true], connection: c, device: d)
        let invalidStates: [[String: Any]] = [
            ["city_pair": NSNull(), "departure": NSNull(), "available": false],
            ["city_pair": "CLT → SFO", "departure": "unknown", "available": true],
            ["city_pair": "CLT → SFO", "available": true],
            ["city_pair": "", "departure": "2026-11-06T12:00:00Z", "available": true]
        ]
        for state in invalidStates { cache.save(state, connection: c, device: d) }
        XCTAssertEqual(cache.load(c, d)["city_pair"] as? String, "TPA → CLT")
        XCTAssertEqual(cache.load(c, d)["departure"] as? String, "2026-11-05T18:52:00Z")
        cache.save(["city_pair": "CLT → SFO", "departure": "2026-11-06T12:00:00Z", "available": true], connection: c, device: d)
        XCTAssertEqual(cache.load(c, d)["city_pair"] as? String, "CLT → SFO")
        XCTAssertEqual(cache.load(c, d)["departure"] as? String, "2026-11-06T12:00:00Z")
        var other = c; other.watch_id = String(repeating: "c", count: 32)
        XCTAssertTrue(cache.load(other, d).isEmpty)
        let changedData = Data(String(decoding: try JSONEncoder().encode(d), as: UTF8.self)
            .replacingOccurrences(of: "sensor.airports", with: "sensor.other_airports").utf8)
        let changed = try JSONDecoder().decode(Device.self, from: changedData)
        XCTAssertTrue(cache.load(c, changed).isEmpty)
    }
    func testDepartureAndCountdown() throws {
        let departure = try XCTUnwrap(FlightPresentation.departure("2026-11-05T18:52:00+00:00"))
        XCTAssertEqual(FlightPresentation.timeToGo(departure: departure, now: departure.addingTimeInterval(-3661)), "1h 2m")
        XCTAssertEqual(FlightPresentation.timeToGo(departure: departure, now: departure.addingTimeInterval(-1)), "1m")
        XCTAssertEqual(FlightPresentation.timeToGo(departure: departure, now: departure.addingTimeInterval(100)), "0m")
        XCTAssertNotNil(FlightPresentation.departure("2026-11-05T18:52:00.123+00:00"))
        XCTAssertNil(FlightPresentation.departure("unknown"))
    }
    func testFullMessageRoundTrip() throws {
        let message = AppMessage(id: "alert", title: "Route changed", message: "Full route\nSecond line", atMS: 123)
        XCTAssertEqual(try JSONDecoder().decode(AppMessage.self, from: JSONEncoder().encode(message)), message)
    }
}
