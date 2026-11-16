import XCTest
@testable import FanControlCore
final class CommandPolicyTests: XCTestCase {
    private func saved(_ status: String, at: Int) throws -> Data {
        try JSONSerialization.data(withJSONObject:["operation_id":"one", "operation_status":status,"observed_at_ms":at])
    }
    func testEveryControlTurnsTealOnHandoffWhileExecutionRemainsActive() {
        for action in ["climate_on", "turn_on", "speed3", "trunk_open", "podcast", "activate"] {
            var feedback = Feedback(target:"watch/target",command:action,label:"ON")
            XCTAssertTrue(feedback.gray)
            feedback.phase = .accepted
            XCTAssertFalse(feedback.gray)
            XCTAssertTrue(CommandPolicy.active.contains("waking"))
            feedback.phase = .unconfirmed
            XCTAssertTrue(feedback.gray)
        }
    }
    func testBackgroundReceiptCanArriveBeforeForegroundResponse() throws {
        let background:[String:Any] = ["operation_id":"one","operation_status":"waking","observed_at_ms":200]
        XCTAssertTrue(CommandPolicy.accept(background,id:"one",previous:nil))
        XCTAssertTrue(CommandPolicy.owns(background))
        XCTAssertFalse(CommandPolicy.accept(["operation_id":"other","operation_status":"complete"],id:"one",previous:nil))
        XCTAssertFalse(CommandPolicy.accept(["operation_id":"one","operation_status":"pending","observed_at_ms":100],id:"one",previous:try saved("waking",at:200)))
    }
    func testCompletionFailureAndCancellationCannotRegressToPending() throws {
        for status in ["complete","accepted","cancelled","failed","unconfirmed"] {
            XCTAssertFalse(CommandPolicy.accept(["operation_id":"one","operation_status":"pending","observed_at_ms":300],id:"one",previous:try saved(status,at:200)))
        }
        XCTAssertTrue(CommandPolicy.accept(["operation_id":"one","operation_status":"complete","observed_at_ms":300],id:"one",previous:try saved("unconfirmed",at:200)))
    }
    func testAuthenticatedOwnershipCanCorrectAnEarlierLocalTransportError() throws {
        let local = try JSONSerialization.data(withJSONObject:["operation_status":"failed","local_error":true])
        XCTAssertTrue(CommandPolicy.accept(["operation_id":"one","operation_status":"waiting"],id:"one",previous:local))
    }
    func testColdClimateTapIsAbsoluteOnRegardlessOfCachedOn() {
        XCTAssertEqual(CommandPolicy.climateIntent(observedOn:true,fresh:false,previous:nil),"climate_on")
        XCTAssertEqual(CommandPolicy.climateIntent(observedOn:true,fresh:true,previous:nil),"climate_off")
        let first = CommandPolicy.climateIntent(observedOn:true,fresh:false,previous:nil)
        XCTAssertEqual(first,"climate_on")
        XCTAssertEqual(CommandPolicy.climateIntent(observedOn:false,fresh:false,previous:first),"climate_off")
    }
    func testRoleMatchingIgnoresCosmeticsButRejectsAnotherCar() throws {
        func device(_ name:String, _ climate:String) throws -> Device {
            let data=try JSONSerialization.data(withJSONObject:["entity":"panel.work","title":name,"panel":["id":"work","type":"work_morning","name":name,"climate_entity":climate,"wake_entity":"button.wake","awake_entity":"binary_sensor.online"]])
            return try JSONDecoder().decode(Device.self,from:data)
        }
        let original=try device("Work","climate.blue")
        XCTAssertTrue(original.sameCommandTarget(as:try device("Renamed","climate.blue")))
        XCTAssertFalse(original.sameCommandTarget(as:try device("Work","climate.white")))
    }
    func testTimingsAreBoundedAndPreserveOriginalTap() throws {
        let raw="""
        {"url":"https://ha.example","token":"\(String(repeating:"a",count:64))","watch_id":"\(String(repeating:"b",count:32))","entity":"fan.test","devices":[{"entity":"fan.test","title":"Fan"}]}
        """
        let connection=try JSONDecoder().decode(Connection.self,from:Data(raw.utf8))
        var record=CommandRecord(id:"one",connection:connection,entity:"fan.test",body:Data(),issued:Date())
        record.mark("tap");let tap=record.timings?["tap"]
        for i in 0..<100 { record.mark(i%2 == 0 ? "local_upload":"remote_upload") }
        record.mark("tap")
        XCTAssertEqual(record.timings?["tap"],tap)
        XCTAssertEqual(record.events?.count,40)
        let restored=try JSONDecoder().decode(CommandRecord.self,from:JSONEncoder().encode(record))
        XCTAssertEqual(restored.timings,record.timings)
    }
}
