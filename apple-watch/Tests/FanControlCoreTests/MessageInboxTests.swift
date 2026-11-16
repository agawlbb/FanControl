import XCTest
@testable import FanControlCore

final class MessageInboxTests: XCTestCase {
    let now: Int64 = 100_000_000
    func item(_ id: String, at: Int64) -> AppMessage { AppMessage(id: id, title: "Delay", message: "Full notification text", atMS: at) }

    func testReceivedMessagesSurviveLocalStorageAndDuplicates() throws {
        var inbox = MessageInbox()
        XCTAssertTrue(inbox.receive(item("one", at: now - 1000), now: now))
        XCTAssertTrue(inbox.receive(item("two", at: now), now: now))
        XCTAssertTrue(inbox.receive(item("one", at: now), now: now))
        XCTAssertEqual(inbox.messages.map(\.id), ["two", "one"])
        XCTAssertEqual(inbox.messages.last?.at_ms, now - 1000)
        let saved = try JSONDecoder().decode([AppMessage].self, from: JSONEncoder().encode(inbox.messages))
        XCTAssertEqual(MessageInbox(messages: saved).messages, inbox.messages)
    }
    func testDismissalRemovesContentAndRejectsLateBannerImportAfterReopening() {
        var inbox = MessageInbox()
        inbox.receive(item("one", at: now), now: now)
        inbox.dismiss("one", now: now)
        XCTAssertTrue(inbox.messages.isEmpty)
        var reopened = MessageInbox(messages: inbox.messages, dismissed: inbox.dismissed)
        XCTAssertFalse(reopened.receive(item("one", at: now), now: now + 1000))
        XCTAssertTrue(reopened.receive(item("two", at: now + 1000), now: now + 1000))
    }
    func testTwelveHourBoundaryExpiresMessagesAndCannotImportThemAgain() {
        var inbox = MessageInbox()
        let original = item("one", at: now)
        inbox.receive(original, now: now)
        XCTAssertTrue(inbox.expire(now: now + MessageInbox.lifetimeMS - 1).isEmpty)
        XCTAssertEqual(inbox.expire(now: now + MessageInbox.lifetimeMS), ["one"])
        XCTAssertFalse(inbox.receive(original, now: now + MessageInbox.lifetimeMS + 1))
        XCTAssertTrue(inbox.messages.isEmpty)
    }
    func testDismissalMarkersExpireAndFutureClockDoesNotExtendRetention() {
        var inbox = MessageInbox()
        inbox.receive(item("one", at: now + 100_000), now: now)
        XCTAssertEqual(inbox.messages.first?.at_ms, now)
        inbox.dismiss("one", now: now)
        inbox.expire(now: now + MessageInbox.lifetimeMS)
        XCTAssertTrue(inbox.dismissed.isEmpty)
    }
    func testNotificationCenterImportPreservesOriginalAge() {
        var inbox = MessageInbox()
        let old = item("old", at: now - MessageInbox.lifetimeMS - 1)
        XCTAssertFalse(inbox.receive(old, now: now))
        XCTAssertTrue(inbox.receive(item("recent", at: now - 6000), now: now))
        XCTAssertEqual(inbox.messages.first?.at_ms, now - 6000)
    }
}
