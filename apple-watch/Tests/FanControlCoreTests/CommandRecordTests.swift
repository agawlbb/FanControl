import XCTest
@testable import FanControlCore
final class CommandRecordTests: XCTestCase {
    func testSavedIntentSurvivesRestartWithoutRecomputingTargetOrDeadline() throws {
        let raw = """
        {"url":"https://ha.example","token":"\(String(repeating:"a",count:64))","watch_id":"\(String(repeating:"b",count:32))","entity":"fan.test","devices":[{"entity":"fan.test","title":"Test"}]}
        """
        let c = try JSONDecoder().decode(Connection.self, from: Data(raw.utf8)).validated()
        let original: [String: Any] = ["operation_id":"stable", "command":"turn_off", "entity":"fan.test", "issued_at_ms":123456, "not_before_ms":124456]
        var entry = CommandRecord(id:"stable", connection:c, entity:"fan.test", body:try JSONSerialization.data(withJSONObject:original), issued:Date(timeIntervalSince1970:123.456))
        entry.accepted = true
        entry.result = try JSONSerialization.data(withJSONObject:["operation_id":"stable", "operation_status":"pending"])
        let restored = try JSONDecoder().decode(CommandRecord.self, from: JSONEncoder().encode(entry))
        let body = try JSONSerialization.jsonObject(with:restored.body) as! [String:Any]
        XCTAssertEqual(body["command"] as? String,"turn_off")
        XCTAssertEqual(body["operation_id"] as? String,"stable")
        XCTAssertEqual(body["issued_at_ms"] as? Int,123456)
        XCTAssertEqual(body["not_before_ms"] as? Int,124456)
        XCTAssertEqual(restored.connection,c)
        XCTAssertEqual(restored.issued,entry.issued)
        XCTAssertTrue(restored.accepted)
        XCTAssertEqual(restored.result,entry.result)
    }
    func testBackgroundContinuationIsBoundedAndSurvivesSerialization() throws {
        let raw = """
        {"url":"https://ha.example","token":"\(String(repeating:"a",count:64))","watch_id":"\(String(repeating:"b",count:32))","entity":"fan.test","devices":[{"entity":"fan.test","title":"Test"}]}
        """
        let c = try JSONDecoder().decode(Connection.self, from: Data(raw.utf8)).validated()
        let issued = Date(timeIntervalSince1970: 1000)
        let body = Data("captured absolute intent".utf8)
        let original = CommandRecord(id: "stable", connection: c, entity: "fan.test", body: body, issued: issued)
        var entry = original
        XCTAssertTrue(entry.beginBackgroundContinuation(now: issued.addingTimeInterval(2)))
        XCTAssertFalse(entry.beginBackgroundContinuation(now: issued.addingTimeInterval(3)))
        var restored = try JSONDecoder().decode(CommandRecord.self, from: JSONEncoder().encode(entry))
        XCTAssertFalse(restored.beginBackgroundContinuation(now: issued.addingTimeInterval(4)))
        XCTAssertEqual(restored.body, body)
        XCTAssertEqual(restored.id, "stable")
        XCTAssertEqual(restored.issued, issued)
        var expired = original
        XCTAssertFalse(expired.beginBackgroundContinuation(now: issued.addingTimeInterval(Connection.handoffSeconds)))
        var accepted = original; accepted.accepted = true
        XCTAssertFalse(accepted.beginBackgroundContinuation(now: issued.addingTimeInterval(1)))
        var failed = original; failed.result = Data()
        XCTAssertFalse(failed.beginBackgroundContinuation(now: issued.addingTimeInterval(1)))
    }
}
