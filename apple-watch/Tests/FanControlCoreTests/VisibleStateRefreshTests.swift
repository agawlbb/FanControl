import XCTest
@testable import FanControlCore

@MainActor final class VisibleStateRefreshTests: XCTestCase {
    private func device(_ entity: String = "fan.bedroom", panel: [String: Any]? = nil) throws -> Device {
        var body: [String: Any] = ["entity": entity, "title": "Bedroom"]
        if let panel { body["panel"] = panel }
        return try JSONDecoder().decode(Device.self, from: JSONSerialization.data(withJSONObject: body))
    }

    func testOpeningEachNonvehicleDeviceReadsOnceWithoutACommandOrPhone() async throws {
        for domain in ["fan", "light", "switch", "input_boolean", "script", "scene"] {
            let target = try device(domain + ".bedroom")
            var reads = 0
            let state = try await VisibleStateRefresh.read(target) { body in
                reads += 1
                XCTAssertEqual(body["action"] as? String, "state")
                XCTAssertEqual(body["entity"] as? String, target.entity)
                XCTAssertNil(body["command"])
                XCTAssertNil(body["operation_id"])
                // An unchanged fan does not inherit the vehicle report-age policy.
                return ["state": "off", "last_updated": "2020-01-01", "observation_fresh": false]
            }
            XCTAssertEqual(reads, 1)
            XCTAssertTrue(VisibleStateRefresh.available(try XCTUnwrap(state), for: target))
        }
    }

    func testFanPanelReadsItsConfiguredPanelInsteadOfTheSyntheticEntity() async throws {
        let target = try device("panel.bedroom", panel: ["id": "bedroom", "type": "fan", "name": "Bedroom", "fan_entity": "fan.bedroom"])
        let state = try await VisibleStateRefresh.read(target) { body in
            XCTAssertEqual(body["action"] as? String, "panel_state")
            XCTAssertEqual(body["panel_id"] as? String, "bedroom")
            XCTAssertNil(body["entity"])
            return ["state": "on", "attributes": ["percentage": 50]]
        }
        XCTAssertTrue(VisibleStateRefresh.available(try XCTUnwrap(state), for: target))
    }

    func testVehicleEntryStillBelongsToItsWakeCoordinator() async throws {
        for type in ["work_morning", "driving", "exercise"] {
            let target = try device("panel.car", panel: ["id": "car", "type": type, "name": "Car", "wake_entity": "button.wake"])
            let state = try await VisibleStateRefresh.read(target) { _ in
                XCTFail("A vehicle must not take the nonvehicle read path")
                return [:]
            }
            XCTAssertNil(state)
        }
    }

    func testNonvehiclePanelReadPreservesLocalExerciseMode() async throws {
        let target = try device("panel.exercise", panel: ["id": "exercise", "type": "exercise", "name": "Exercise"])
        let body = try XCTUnwrap(VisibleStateRefresh.request(for: target))
        XCTAssertEqual(body["action"] as? String, "panel_state")
        XCTAssertEqual(body["music_mode"] as? String, "local")
        XCTAssertTrue(VisibleStateRefresh.available(["climate_available": true], for: target))
        XCTAssertFalse(VisibleStateRefresh.available(["climate_available": false], for: target))
    }

    func testUnknownUnavailableAndMalformedPowerStatesRemainGray() async throws {
        let invalid: [[String: Any]] = [[:], ["state": "unknown"], ["state": "unavailable"], ["state": "opening"], ["state": true]]
        for domain in ["fan", "light", "switch", "input_boolean"] {
            let target = try device(domain + ".bedroom")
            for state in invalid {
                XCTAssertFalse(VisibleStateRefresh.available(state, for: target))
            }
            XCTAssertTrue(VisibleStateRefresh.available(["state": "on"], for: target))
            XCTAssertTrue(VisibleStateRefresh.available(["state": "off"], for: target))
        }
    }

    func testFailedReadDoesNotRetry() async throws {
        let target = try device()
        var reads = 0
        do {
            _ = try await VisibleStateRefresh.read(target) { _ in
                reads += 1
                throw ControlError.rejected(503)
            }
            XCTFail("Transport failure must remain a failure")
        } catch ControlError.rejected(503) {
            XCTAssertEqual(reads, 1)
        }
    }

    func testLeavingDuringAReadDiscardsItsResponse() async throws {
        let target = try device()
        let task = Task { @MainActor in
            try await VisibleStateRefresh.read(target) { _ in
                withUnsafeCurrentTask { $0?.cancel() }
                return ["state": "on"]
            }
        }
        do {
            _ = try await task.value
            XCTFail("A cancelled entry must not return fresh state")
        } catch is CancellationError { }
    }
}
