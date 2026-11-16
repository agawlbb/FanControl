import XCTest
@testable import FanControlCore

final class ActionReceiptTests: XCTestCase {
    func testUntouchedActionsAreTealAndOnlyUnacknowledgedRequestsAreGray() {
        XCTAssertFalse(ActionReceipts.isGray(nil))
        var receipts = ActionReceipts()
        let request = Feedback(target: "watch/panel", command: "honk", label: "Activated")
        receipts.begin(request)
        XCTAssertTrue(ActionReceipts.isGray(receipts.feedback(target: request.target, command: request.command)))
        receipts.finish(request, accepted: false)
        XCTAssertNil(receipts.feedback(target: request.target, command: request.command))
        receipts.begin(request)
        receipts.finish(request, accepted: true)
        XCTAssertFalse(ActionReceipts.isGray(receipts.feedback(target: request.target, command: request.command)))
        receipts.clear()
        XCTAssertFalse(ActionReceipts.isGray(receipts.feedback(target: request.target, command: request.command)))
    }
    func testHandoffAcknowledgesOwnershipBeforeDispatchOrCompletion() {
        for status in ["pending", "waking", "waiting", "delivering", "confirming", "complete", "accepted"] {
            XCTAssertTrue(ActionReceipts.acknowledgesHandoff(["operation_status": status]))
        }
        for status in ["unknown", "failed", "cancelled", "unconfirmed", "expired", ""] {
            XCTAssertFalse(ActionReceipts.acknowledgesHandoff(["operation_status": status]))
        }
        XCTAssertFalse(ActionReceipts.acknowledgesHandoff([:]))
        XCTAssertFalse(ActionReceipts.acknowledgesHandoff(["stage": "accepted"]))
    }
    func testActionsExcludeFanSpeedAndToggles() {
        for command in ["activate", "leave", "honk", "podcast", "start_exercise", "stop_exercise"] {
            XCTAssertTrue(ActionReceipts.applies(command))
        }
        for command in ["turn_on", "turn_off", "speed1", "speed6", "climate_on", "climate_off", "garage_open", "trunk_close"] {
            XCTAssertFalse(ActionReceipts.applies(command))
            XCTAssertFalse(ActionReceipts.acknowledges(command, response: [:]))
        }
        XCTAssertFalse(Evidence.matches("honk", ["accepted":true], panel:nil))
        XCTAssertFalse(Evidence.matches("podcast", ["accepted":true], panel:nil))
    }
    func testStopRequiresCompletionAndRejectsPendingOrTerminalRejections() {
        for status in ["complete"] {
            XCTAssertTrue(ActionReceipts.acknowledges("stop_exercise", response:["operation_status":status]))
        }
        for status in ["pending", "cancelled", "expired", "unsupported", "unknown", ""] {
            XCTAssertFalse(ActionReceipts.acknowledges("stop_exercise", response:["operation_status":status]))
        }
        XCTAssertFalse(ActionReceipts.acknowledges("stop_exercise", response:[:]))
    }
    func testStartRequiresAnExplicitSuccessfulLockDispatch() {
        XCTAssertTrue(ActionReceipts.acknowledges("start_exercise", response:["steps":[["step":"lock", "status":"requested"]]]))
        for status in ["pending", "unconfirmed", "skipped", ""] {
            XCTAssertFalse(ActionReceipts.acknowledges("start_exercise", response:["steps":[["step":"lock", "status":status]]]))
        }
        XCTAssertFalse(ActionReceipts.acknowledges("start_exercise", response:["locked":true]))
        XCTAssertFalse(ActionReceipts.acknowledges("start_exercise", response:[:]))
    }
    func testReceiptsRemainIndependentUntilSessionEnds() {
        var receipts = ActionReceipts()
        let start = Feedback(target:"watch/panel", command:"start_exercise", label:"Activated")
        receipts.begin(start)
        XCTAssertEqual(receipts.feedback(target:start.target,command:start.command)?.phase,.pending)
        receipts.finish(start,accepted:true)
        let stop = Feedback(target:start.target, command:"stop_exercise",label:"Activated")
        receipts.begin(stop); receipts.finish(stop,accepted:false)
        XCTAssertEqual(receipts.feedback(target:start.target,command:start.command)?.phase,.accepted)
        XCTAssertNil(receipts.feedback(target:stop.target,command:stop.command))
        receipts.clear()
        XCTAssertNil(receipts.feedback(target:start.target,command:start.command))
    }
    func testStaleCallbacksAndOtherTargetsCannotRecolorNewRequest() {
        var receipts = ActionReceipts()
        let old = Feedback(target:"watchA/panelA", command:"honk", label:"Activated")
        let next = Feedback(target:old.target, command:old.command,label:"Activated")
        receipts.begin(old); receipts.begin(next); receipts.finish(old,accepted:true)
        XCTAssertEqual(receipts.feedback(target:next.target,command:next.command)?.phase,.pending)
        let other = Feedback(target:"watchB/panelB",command:"honk",label:"Activated")
        receipts.finish(other,accepted:true)
        XCTAssertNil(receipts.feedback(target:other.target,command:other.command))
        receipts.clear(); receipts.finish(next,accepted:true)
        XCTAssertNil(receipts.feedback(target:next.target,command:next.command))
    }
}
