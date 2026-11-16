import XCTest
@testable import FanControlCore

final class CommandAlertPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2000)
    private func connection(token: String = "a", entity: String = "fan.bedroom") throws -> Connection {
        let body: [String: Any] = ["url": "https://ha.example", "token": String(repeating: token, count: 64),
            "watch_id": String(repeating: "b", count: 32), "entity": entity,
            "devices": [["entity": entity, "title": "Bedroom"]]]
        return try JSONDecoder().decode(Connection.self, from: JSONSerialization.data(withJSONObject: body))
    }
    private func record(command: String = "turn_on", age: TimeInterval = 10, action: String = "operation_submit") throws -> CommandRecord {
        let c = try connection()
        let body = try JSONSerialization.data(withJSONObject: ["action": action, "command": command])
        return CommandRecord(id: "one", connection: c, entity: c.entity, body: body, issued: now.addingTimeInterval(-age))
    }
    func testRecentUserCommandGetsFallbackButOpeningReadsAndWakesNeverDo() throws {
        let c = try connection()
        XCTAssertTrue(CommandAlertPolicy.fallback(try record(), current: c, now: now))
        for action in ["state", "panel_state", "operation_status", "config"] {
            XCTAssertFalse(CommandAlertPolicy.fallback(try record(action: action), current: c, now: now))
        }
        XCTAssertFalse(CommandAlertPolicy.fallback(try record(command: "wake"), current: c, now: now))
        XCTAssertFalse(CommandAlertPolicy.fallback(try record(command: ""), current: c, now: now))
    }
    func testRecoveryRemovesAcknowledgedAndTerminalFallbacks() throws {
        let c = try connection()
        var entry = try record()
        entry.accepted = true
        XCTAssertFalse(CommandAlertPolicy.fallback(entry, current: c, now: now))
        entry.accepted = false
        for status in CommandPolicy.active + CommandPolicy.terminal {
            entry.result = try JSONSerialization.data(withJSONObject: ["operation_status": status])
            XCTAssertFalse(CommandAlertPolicy.fallback(entry, current: c, now: now))
        }
    }
    func testOldAndFutureCommandsCannotGenerateNewLocalAlerts() throws {
        let ages: [TimeInterval] = [300, 600, 86400, -60]
        for age in ages {
            XCTAssertFalse(CommandAlertPolicy.relevant(try record(age: age), current: try connection(), now: now))
        }
        XCTAssertTrue(CommandAlertPolicy.relevant(try record(age: 224), current: try connection(), now: now))
    }
    func testNotificationSubmissionResumingAfterTwentyFiveMinutesIsObsolete() throws {
        let entry = try record(command: "start_exercise")
        let failure: [String: Any] = ["operation_id": "one", "operation_status": "failed", "local_error": true]
        let current = try connection()
        XCTAssertTrue(CommandAlertPolicy.localOutcome(entry, state: failure, current: current, now: now))
        // Both the pre-submission and post-submission checks use the original tap.
        let reopened = now.addingTimeInterval(25 * 60)
        XCTAssertFalse(CommandAlertPolicy.localOutcome(entry, state: failure, current: current, now: reopened))
        XCTAssertFalse(CommandAlertPolicy.relevant(entry, current: current, now: reopened))
    }
    func testRevocationChangedTargetAndMissingPairingSuppressAlerts() throws {
        let entry = try record()
        XCTAssertFalse(CommandAlertPolicy.relevant(entry, current: nil, now: now))
        XCTAssertFalse(CommandAlertPolicy.relevant(entry, current: try connection(token: "c"), now: now))
        XCTAssertFalse(CommandAlertPolicy.relevant(entry, current: try connection(entity: "fan.other"), now: now))
    }
    func testOnlyMatchingRecentTerminalFailureCanUseLocalOutcome() throws {
        let entry = try record(), c = try connection()
        for status in ["failed", "unconfirmed"] {
            let state: [String: Any] = ["operation_id": "one", "operation_status": status]
            XCTAssertTrue(CommandAlertPolicy.localOutcome(entry, state: state, current: c, now: now))
            XCTAssertFalse(CommandAlertPolicy.localOutcome(try record(age: 600), state: state, current: c, now: now))
            var remote = state; remote["outcome_alerts"] = true
            XCTAssertFalse(CommandAlertPolicy.localOutcome(entry, state: remote, current: c, now: now))
            var wrong = state; wrong["operation_id"] = "other"
            XCTAssertFalse(CommandAlertPolicy.localOutcome(entry, state: wrong, current: c, now: now))
        }
        for status in CommandPolicy.active + ["accepted", "complete", "cancelled", "unknown"] {
            XCTAssertFalse(CommandAlertPolicy.localOutcome(entry, state: ["operation_id": "one", "operation_status": status], current: c, now: now))
        }
    }
    func testAcknowledgmentArrivingDuringAlertPermissionWaitSuppressesOldFailure() throws {
        var entry = try record()
        let failure: [String: Any] = ["operation_id": "one", "operation_status": "unconfirmed"]
        XCTAssertTrue(CommandAlertPolicy.localOutcome(entry, state: failure, current: try connection(), now: now))
        for status in ["pending", "confirming", "complete", "accepted", "cancelled"] {
            entry.result = try JSONSerialization.data(withJSONObject: ["operation_id": "one", "operation_status": status])
            XCTAssertFalse(CommandAlertPolicy.localOutcome(entry, state: failure, current: try connection(), now: now))
        }
    }
}
