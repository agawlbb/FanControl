import XCTest
@testable import FanControlCore

final class FlightTripTests: XCTestCase {
    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(FlightPresentation.departure(value))
    }
    private func trip(flights: String = #"[{"number":"AA123","city_pair":"CLT → BOS","departure":"2026-11-24T12:00:00Z","arrival":"2026-11-24T14:00:00Z"},{"number":"AA456","city_pair":"BOS → CLT","departure":"2026-11-25T12:00:00Z","arrival":"2026-11-25T14:00:00Z"}]"#) throws -> FlightTrip {
        try JSONDecoder().decode(FlightTrip.self, from: Data("{\"version\":1,\"available\":true,\"source_last_success\":\"2026-11-24T11:00:00Z\",\"flights\":\(flights)}".utf8)).validated()
    }
    func testServerFocusRetainsPreviousFlightsAndDoesNotRewindWithDelayedEstimates() throws {
        let original = try trip()
        let encoded = try JSONEncoder().encode(original)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        payload["focused_flight_index"] = 1
        let value = try JSONDecoder().decode(FlightTrip.self, from: JSONSerialization.data(withJSONObject: payload)).validated()
        let now = try date("2026-11-24T11:00:00Z")
        XCTAssertEqual(value.openingFlightIndex(now: now), 1)
        let rows = try XCTUnwrap(value.state(now: now)["flights"] as? [[String: Any]])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["completed"] as? Bool, true)
        XCTAssertEqual(rows[1]["completed"] as? Bool, false)
        XCTAssertEqual(rows[0]["arrival"] as? String, "2026-11-24T14:00:00Z")
        let restored = try JSONDecoder().decode(PhoneFlightSnapshot.self,
            from: JSONEncoder().encode(PhoneFlightSnapshot(watchID: "test", trip: value, generation: 1)))
        XCTAssertEqual(restored.trip?.focused_flight_index, 1)
        payload["focused_flight_index"] = 2
        XCTAssertThrowsError(try JSONDecoder().decode(FlightTrip.self,
            from: JSONSerialization.data(withJSONObject: payload)).validated())
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
    func testOpeningAdvancesAtFortyMinutesAndRetainsSkippedFlightAbove() throws {
        let value = try trip()
        let before = try date("2026-11-24T12:39:59Z")
        let cutoff = try date("2026-11-24T12:40:00Z")
        XCTAssertEqual(value.openingFlightIndex(now: before), 0)
        XCTAssertEqual(value.openingFlightIndex(now: cutoff), 1)
        let state = value.state(now: cutoff)
        XCTAssertEqual(state["opening_flight_index"] as? Int, 1)
        let rows = try XCTUnwrap(state["flights"] as? [[String: Any]])
        XCTAssertEqual(rows.compactMap { $0["number"] as? String }, ["AA123", "AA456"])
        XCTAssertEqual(rows.first?["departure"] as? String, "2026-11-24T12:00:00Z")
        XCTAssertNil(rows.first?["actual_departure"])
        XCTAssertNil(rows.first?["status"])
        XCTAssertEqual(rows.first?["completed"] as? Bool, true)
        XCTAssertEqual(rows.last?["completed"] as? Bool, false)
    }
    func testLaterEstimateReplacesOldCutoffWithoutChangingTheServerSnapshot() throws {
        let original = try trip()
        let updatedFlights = try JSONEncoder().encode(original.flights)
        let delayedJSON = String(decoding: updatedFlights, as: UTF8.self)
            .replacingOccurrences(of: "2026-11-24T12:00:00Z", with: "2026-11-24T13:00:00Z")
        let delayed = try trip(flights: delayedJSON)
        let now = try date("2026-11-24T12:45:00Z")
        XCTAssertEqual(original.openingFlightIndex(now: now), 1)
        XCTAssertEqual(delayed.openingFlightIndex(now: now), 0)
        XCTAssertEqual(delayed.openingFlightIndex(now: try date("2026-11-24T13:40:00Z")), 1)
        XCTAssertEqual(original.flights[0].departure, "2026-11-24T12:00:00Z")
    }
    func testOpeningSkipsElapsedPrefixAndKeepsFinalFlightWhenNoNextExists() throws {
        let flights = #"[{"number":"AA1","city_pair":"CLT → BOS","departure":"2026-11-24T12:00:00Z","arrival":"2026-11-24T14:00:00Z"},{"number":"AA2","city_pair":"BOS → JFK","departure":"2026-11-24T15:00:00Z","arrival":"2026-11-24T16:00:00Z"},{"number":"AA3","city_pair":"JFK → CLT","departure":"2026-11-24T17:00:00Z","arrival":"2026-11-24T19:00:00Z"}]"#
        let value = try trip(flights: flights)
        XCTAssertEqual(value.openingFlightIndex(now: try date("2026-11-24T11:00:00Z")), 0)
        XCTAssertEqual(value.openingFlightIndex(now: try date("2026-11-24T15:40:00Z")), 2)
        XCTAssertEqual(value.openingFlightIndex(now: try date("2026-11-25T00:00:00Z")), 2)
        XCTAssertEqual(value.flights.count, 3)
        let single = try trip(flights: #"[{"number":"AA1","city_pair":"CLT → BOS","departure":"2026-11-24T12:00:00Z","arrival":"2026-11-24T14:00:00Z"}]"#)
        XCTAssertEqual(single.openingFlightIndex(now: try date("2026-11-25T00:00:00Z")), 0)
        XCTAssertNil(try trip(flights: "[]").openingFlightIndex())
    }
    func testLatestDepartureEstimateDrivesOpeningAcrossTimezonesAndOffline() throws {
        let flights = #"[{"number":"AA1","city_pair":"CLT → BOS","departure":"2026-11-24T08:00:00.500-05:00","scheduled_departure":"2026-11-24T12:00:00Z","arrival":"2026-11-24T15:00:00Z"},{"number":"AA2","city_pair":"BOS → CLT","departure":"2026-11-25T12:00:00Z","arrival":"2026-11-25T14:00:00Z"}]"#
        let value = try trip(flights: flights)
        XCTAssertEqual(value.openingFlightIndex(now: try date("2026-11-24T13:40:00.499Z")), 0)
        let now = try date("2026-11-24T13:40:00.500Z")
        XCTAssertEqual(value.openingFlightIndex(now: now), 1)
        XCTAssertEqual(value.state(now: now)["available"] as? Bool, false)
        XCTAssertEqual(value.state(now: now)["opening_flight_index"] as? Int, 1)
        XCTAssertEqual(try JSONDecoder().decode(FlightTrip.self, from: JSONEncoder().encode(value)), value)
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
    func testDepartureUsesEachAirportZoneAndRespectsDaylightSaving() throws {
        let locale = Locale(identifier: "en_GB")
        let raw = "2026-07-15T18:00:00Z"
        XCTAssertEqual(FlightPresentation.departureTime(raw, timeZoneIdentifier: "America/Los_Angeles", locale: locale), "11:00")
        XCTAssertEqual(FlightPresentation.departureTime(raw, timeZoneIdentifier: "America/New_York", locale: locale), "14:00")
        XCTAssertEqual(FlightPresentation.departureTime(raw, timeZoneIdentifier: "America/Phoenix", locale: locale), "11:00")
        let winter = "2026-12-15T18:00:00Z"
        XCTAssertEqual(FlightPresentation.departureTime(winter, timeZoneIdentifier: "America/Los_Angeles", locale: locale), "10:00")
        XCTAssertEqual(FlightPresentation.departureTime(winter, timeZoneIdentifier: "America/Phoenix", locale: locale), "11:00")
    }
    func testDepartureZoneHandlesMidnightAndMissingMetadataWithoutDeviceZoneFallback() {
        let locale = Locale(identifier: "en_GB")
        XCTAssertEqual(FlightPresentation.departureTime("2026-07-16T02:30:00Z", timeZoneIdentifier: "America/Los_Angeles", locale: locale), "19:30")
        XCTAssertEqual(FlightPresentation.departureTime("2026-07-16T02:30:00Z", timeZoneIdentifier: nil, locale: locale), "—")
        XCTAssertEqual(FlightPresentation.departureTime("2026-07-16T02:30:00Z", timeZoneIdentifier: "invalid", locale: locale), "—")
    }
    func testDepartureZoneSurvivesPhoneWatchAndOfflineRoundTrip() throws {
        let flights = #"[{"number":"AA1","city_pair":"LAX → CLT","departure":"2026-07-15T18:00:00Z","departure_timezone":"America/Los_Angeles","arrival":"2026-07-15T23:00:00Z"},{"number":"AA2","city_pair":"CLT → LAX","departure":"2026-07-16T14:00:00Z","departure_timezone":"America/New_York","arrival":"2026-07-16T19:00:00Z"}]"#
        let value = PhoneFlightSnapshot(watchID: "synthetic-watch", trip: try trip(flights: flights), generation: 100)
        let restored = try JSONDecoder().decode(PhoneFlightSnapshot.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(restored.trip?.flights.map(\.departure_timezone), ["America/Los_Angeles", "America/New_York"])
        let rows = try XCTUnwrap(restored.trip?.state()["flights"] as? [[String: Any]])
        XCTAssertEqual(rows[0]["departure_timezone"] as? String, "America/Los_Angeles")
        XCTAssertEqual(rows[1]["departure_timezone"] as? String, "America/New_York")
    }
}
