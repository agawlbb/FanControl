import XCTest
@testable import FanControlCore

final class MusicSyncFeedbackTests: XCTestCase {
    func testFailureSurvivesRepeatedProgressPauseAndRestart() throws {
        let id = UUID(); var feedback = MusicSyncFeedback()
        feedback.begin(id, message: "Preparing")
        feedback.progress(id, message: "Receiving 0%")
        feedback.fail(id, message: "Saving chunk failed (NSCocoaErrorDomain 513).")
        for _ in 0..<5 {
            feedback.progress(id, message: "Received 0/1")
            feedback.pause(id, message: "Waiting")
            feedback.fail(id, message: "Different late error")
        }
        let restored = try JSONDecoder().decode(MusicSyncFeedback.self, from: JSONEncoder().encode(feedback))
        XCTAssertEqual(restored.phase, .failed)
        XCTAssertEqual(restored.message, "Saving chunk failed (NSCocoaErrorDomain 513).")
        XCTAssertEqual(restored.history.count, 2)
    }
    func testOldCallbacksCannotChangeNewSyncAndExplicitRetryClearsFailure() {
        let old = UUID(), new = UUID(); var feedback = MusicSyncFeedback()
        feedback.begin(old, message: "Old")
        feedback.fail(old, message: "Failed")
        feedback.begin(new, message: "Retry")
        feedback.progress(old, message: "Stale progress")
        feedback.fail(old, message: "Stale failure")
        feedback.verified(old, tracks: 1)
        XCTAssertEqual(feedback.message, "Retry")
        feedback.progress(new, message: "Receiving 1/1")
        XCTAssertEqual(feedback.phase, .receiving)
    }
    func testOnlyVerifiedInstallationReplacesFailureAndHistoryKeepsIt() {
        let id = UUID(); var feedback = MusicSyncFeedback()
        feedback.begin(id, message: "Started")
        feedback.fail(id, message: "Live chunk failed")
        feedback.verified(id, tracks: 1)
        feedback.progress(id, message: "Old progress")
        feedback.fail(id, message: "Old failure")
        XCTAssertEqual(feedback.phase, .ready)
        XCTAssertEqual(feedback.message, "1 track ready offline")
        XCTAssertTrue(feedback.history.contains("Live chunk failed"))
    }
    func testScreenSleepIsAPauseNotAFailureAndCanResume() {
        let id = UUID(); var feedback = MusicSyncFeedback()
        feedback.begin(id, message: "Started")
        feedback.pause(id, message: "Screen asleep")
        XCTAssertEqual(feedback.phase, .paused)
        feedback.progress(id, message: "Receiving 1/1")
        XCTAssertEqual(feedback.phase, .receiving)
    }
    func testFailureIncludesStageAndNumericCodeWithoutUnderlyingPayload() {
        let error = NSError(domain: "WCErrorDomain", code: 7007, userInfo: [NSLocalizedDescriptionKey: "private payload"])
        let message = MusicSyncFeedback.failure(stage: "Requesting chunk at byte 0", error: error)
        XCTAssertEqual(message, "Requesting chunk at byte 0 failed (WCErrorDomain 7007).")
        XCTAssertFalse(message.contains("private payload"))
        XCTAssertTrue(MusicSyncFeedback.failure(stage: "Verifying audio", error: MusicFileFailure.checksumMismatch).contains("SHA-256"))
        XCTAssertTrue(MusicSyncFeedback.failure(stage: "Receiving audio", error: MusicFileFailure.mismatchedReply).contains("matching audio chunk"))
    }
    func testHistoryRemainsBoundedAcrossRetries() {
        var feedback = MusicSyncFeedback()
        for _ in 0..<20 { feedback.begin(UUID(), message: UUID().uuidString) }
        XCTAssertEqual(feedback.history.count, 8)
    }
}
