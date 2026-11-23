import XCTest
@testable import FanControlCore

final class FlightTripTests: XCTestCase {
    private func trip(flights: String = #"[{"number":"AA123","city_pair":"CLT → BOS","departure":"2026-11-24T12:00:00Z","arrival":"2026-11-24T14:00:00Z"},{"number":"AA456","city_pair":"BOS → CLT","departure":"2026-11-25T12:00:00Z","arrival":"2026-11-25T14:00:00Z"}]"#) throws -> FlightTrip {
        try JSONDecoder().decode(FlightTrip.self, from: Data("{\"version\":1,\"available\":true,\"source_last_success\":\"2026-11-24T11:00:00Z\",\"flights\":\(flights)}".utf8)).validated()
    }
    func testFullTripRetainsOrderAndFlightNumber() throws {
        let value = try trip()
        XCTAssertEqual(value.flights.map(\.number), ["AA123", "AA456"])
        let restored = try JSONDecoder().decode(FlightTrip.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(restored, value)
        let at = try XCTUnwrap(FlightPresentation.departure("2026-11-24T11:00:10Z"))
        XCTAssertEqual(value.state(now: at)["available"] as? Bool, true)
        XCTAssertEqual(value.state(now: at.addingTimeInterval(181))["available"] as? Bool, false)
    }
    @MainActor func testFlightTileNeverReadsHomeAssistant() throws {
        let raw = Data(#"{"entity":"panel.on_duty","title":"On Duty","panel":{"id":"on_duty","name":"On Duty","type":"on_duty","city_pair_entity":"sensor.airports","departure_entity":"sensor.departure"}}"#.utf8)
        let device = try JSONDecoder().decode(Device.self, from: raw)
        XCTAssertNil(VisibleStateRefresh.request(for: device))
    }
    func testEmptyTripExplicitlyClearsFlights() throws {
        XCTAssertTrue(try trip(flights: "[]").flights.isEmpty)
    }
    func testIncompleteTripCannotMixWithPriorFlight() {
        XCTAssertThrowsError(try trip(flights: #"[{"number":"AA1","city_pair":"CLT → BOS","departure":"unknown","arrival":"2026-11-24T14:00:00Z"}]"#))
    }
    func testWatchEnvelopeContainsNoServerSecret() throws {
        let value = PhoneFlightSnapshot(watchID: "synthetic-watch", trip: try trip(), generation: 100)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(PhoneFlightSnapshot.self, from: data)
        XCTAssertEqual(decoded.trip?.flights.count, 2)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("secret"))
    }
}
