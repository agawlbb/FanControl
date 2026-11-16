import XCTest
@testable import FanControlCore

final class SetupTests: XCTestCase {
    private func connection(entity: String, devices: String) throws -> Connection {
        let json = """
        {"url":"https://ha.example","token":"\(String(repeating:"a", count:64))","watch_id":"\(String(repeating:"b",count:32))","entity":"\(entity)","devices":\(devices)}
        """
        return try JSONDecoder().decode(Connection.self, from: Data(json.utf8)).validated()
    }
    func testPairedWatchCanWaitForItsFirstPanel() throws {
        let value = try connection(entity: "", devices: "[]")
        XCTAssertNil(value.active)
        XCTAssertThrowsError(try connection(entity: "fan.missing", devices: "[]"))
    }
    func testFanPanelUsesNormalFanEvidenceAndRejectsWrongRole() throws {
        let devices = """
        [{"entity":"panel.bedroom","title":"Bedroom","panel":{"id":"bedroom","name":"Bedroom","type":"fan","fan_entity":"fan.bedroom"}}]
        """
        let value = try connection(entity:"panel.bedroom", devices:devices)
        XCTAssertEqual(value.active?.domain,"fan")
        XCTAssertTrue(Evidence.matches("speed4", ["state":"on","attributes":["percentage":66]], panel:value.active!.panel))
        XCTAssertFalse(Evidence.matches("speed4", ["state":"off","attributes":["percentage":66]], panel:value.active!.panel))
        XCTAssertFalse(Evidence.matches("turn_on", ["state":"unavailable"], panel:value.active!.panel))
        XCTAssertThrowsError(try connection(entity:"panel.bedroom", devices:devices.replacingOccurrences(of:"fan.bedroom",with:"switch.bedroom")))
    }
    func testDispatchAcknowledgmentDoesNotClaimScriptCompletion() {
        var feedback = Feedback(target:"same watch/panel",command:"leave",label:"Leave for work")
        feedback.phase = .accepted
        XCTAssertFalse(feedback.gray)
        XCTAssertFalse(Evidence.matches("activate", ["accepted":true], panel:nil))
    }
}
