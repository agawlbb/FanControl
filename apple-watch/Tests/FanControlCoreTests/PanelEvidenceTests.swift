import XCTest
@testable import FanControlCore
final class PanelEvidenceTests: XCTestCase {
    private func panel(_ type: String) throws -> Panel {
        let json = """
        {"id":"test","name":"Test","type":"\(type)","climate_entity":"climate.test","wake_entity":"button.wake","awake_entity":"binary_sensor.online"}
        """
        return try JSONDecoder().decode(Panel.self,from:Data(json.utf8))
    }
    func testDrivingRequiresMatchingAvailableCoverEvidence() throws {
        let p = try panel("driving")
        XCTAssertFalse(Evidence.matches("trunk_open",["trunk_state":"opening","trunk_open_available":true,"vehicle_ready":true],panel:p))
        XCTAssertFalse(Evidence.matches("trunk_open",["trunk_state":"open","trunk_open_available":false,"vehicle_ready":true],panel:p))
        XCTAssertFalse(Evidence.matches("trunk_open",["trunk_state":"open","trunk_open_available":true,"vehicle_ready":false],panel:p))
        XCTAssertTrue(Evidence.matches("trunk_open",["trunk_state":"open","trunk_open_available":true,"vehicle_ready":true],panel:p))
        XCTAssertTrue(Evidence.matches("garage_open",["garage_state":"open","garage_open_available":true,"vehicle_ready":false],panel:p))
    }
    func testClimateUnknownAndOfflineNeverConfirm() throws {
        let p = try panel("work_morning")
        XCTAssertFalse(Evidence.matches("climate_on",["climate_on":true,"climate_available":false,"vehicle_ready":true],panel:p))
        XCTAssertFalse(Evidence.matches("climate_on",["climate_on":true,"climate_available":true,"vehicle_ready":false],panel:p))
        XCTAssertTrue(Evidence.matches("climate_on",["climate_on":true,"climate_available":true,"vehicle_ready":true],panel:p))
    }
    func testStopNeedsWholeOperationCompletionNotLockOrDispatch() throws {
        let p = try panel("exercise")
        XCTAssertFalse(Evidence.matches("stop_exercise",["locked":true,"vehicle_ready":true,"operation_status":"pending"],panel:p))
        XCTAssertFalse(Evidence.matches("stop_exercise",["vehicle_ready":true,"operation_status":"cancelled"],panel:p))
        XCTAssertTrue(Evidence.matches("stop_exercise",["operation_status":"complete"],panel:p))
        XCTAssertFalse(Evidence.matches("start_exercise",["vehicle_ready":true,"steps":[["status":"requested"]]],panel:p))
        XCTAssertTrue(Evidence.matches("start_exercise",["vehicle_ready":true,"locked":true],panel:p))
    }
    func testDrivingOffRequiresMatchingObservationAndHornNeverConfirmsFromDispatch() throws {
        let p = try panel("driving")
        XCTAssertFalse(Evidence.matches("climate_off", ["vehicle_ready":true,"climate_available":true,"climate_on":true], panel:p))
        XCTAssertTrue(Evidence.matches("climate_off", ["vehicle_ready":true,"climate_available":false,"climate_off_available":true,"climate_on":false], panel:p))
        XCTAssertFalse(Evidence.matches("climate_off", ["vehicle_ready":true,"climate_available":false,"climate_on":false], panel:p))
        XCTAssertFalse(Evidence.matches("honk", ["vehicle_ready":true,"honk_available":true,"accepted":true], panel:p))
    }
}

