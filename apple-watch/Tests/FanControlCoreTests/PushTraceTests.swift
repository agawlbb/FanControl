import XCTest
@testable import FanControlCore

final class PushTraceTests: XCTestCase {
    private func connection() throws -> Connection {
        let json = """
        {"url":"https://ha.example","token":"\(String(repeating: "a", count: 64))","watch_id":"\(String(repeating: "b", count: 32))","entity":"switch.example","revision":7,"devices":[{"entity":"switch.example","title":"Example"}]}
        """
        return try JSONDecoder().decode(Connection.self, from: Data(json.utf8)).validated()
    }
    func testPersistentOutboxRetainsOriginalReceiptTimeAndDeduplicatesAcknowledgment() throws {
        let suite = "trace-" + UUID().uuidString, c = try connection()
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let update = UUID().uuidString.lowercased()
        let trace = PushTrace(defaults: defaults)
        trace.record("received", connection: c, updateID: update, now: Date(timeIntervalSince1970: 1800000000))
        trace.record("selection_saved", connection: c, updateID: update, now: Date(timeIntervalSince1970: 1800000001))
        let restored = PushTrace(defaults: defaults), events = restored.pending(c)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.first?.at_ms, 1800000000000)
        XCTAssertEqual(events.first?.update_id, update)
        XCTAssertEqual(events.last?.revision, 7)
        restored.acknowledge(Set(events.map(\.id)), connection: c)
        restored.acknowledge(Set(events.map(\.id)), connection: c)
        XCTAssertTrue(restored.pending(c).isEmpty)
        XCTAssertEqual(restored.history(c).count, 2)
    }
    func testSelectionChangesShareOutboxButDifferentCredentialOrWatchDoesNot() throws {
        let suite = "trace-" + UUID().uuidString, c = try connection()
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let trace = PushTrace(defaults: defaults)
        trace.record("received", connection: c, updateID: UUID().uuidString.lowercased())
        var next = c; next.revision = 8; next.entity = ""
        XCTAssertEqual(trace.pending(next).count, 1)
        next.token = String(repeating: "c", count: 64)
        XCTAssertTrue(trace.pending(next).isEmpty)
        next = c; next.watch_id = String(repeating: "d", count: 32)
        XCTAssertTrue(trace.pending(next).isEmpty)
        trace.record("received", connection: nil, updateID: UUID().uuidString.lowercased(), watchID: c.watch_id)
        XCTAssertEqual(trace.pending(c).count, 2)
        XCTAssertTrue(trace.pending(next).isEmpty)
    }
    func testBoundedHistoryAndUncorrelatedOpeningDoNotInventReceipt() throws {
        let suite = "trace-" + UUID().uuidString, c = try connection()
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let trace = PushTrace(defaults: defaults)
        trace.record("opened", connection: c)
        XCTAssertNil(trace.pending(c).first?.update_id)
        for _ in 0..<140 { trace.record("refresh_failed", connection: c) }
        XCTAssertEqual(trace.history(c).count, 120)
        XCTAssertEqual(trace.pending(c).count, 12)
        XCTAssertFalse(trace.history(c).contains { $0.phase == "received" || $0.phase == "selection_saved" })
        trace.clear()
        XCTAssertTrue(trace.history(c).isEmpty)
    }
    func testRevisionMetadataDoesNotInvalidateSameTargetButRolesAndCredentialsDo() throws {
        let original = try connection()
        var saved = original; saved.revision = nil
        XCTAssertTrue(saved.sameTarget(as: original))
        XCTAssertNotEqual(saved, original) // Persistence still rejects an older saved snapshot.
        saved.revision = 8
        XCTAssertTrue(saved.sameTarget(as: original))
        XCTAssertNotEqual(saved, original)
        saved.entity = ""
        XCTAssertFalse(saved.sameTarget(as: original))
        saved = original; saved.token = String(repeating: "c", count: 64)
        XCTAssertFalse(saved.sameTarget(as: original))
        saved = original; saved.devices = []
        XCTAssertFalse(saved.sameTarget(as: original))
    }
}
