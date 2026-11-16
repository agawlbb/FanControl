import XCTest
@testable import FanControlCore

final class VehicleOperationTests: XCTestCase {
    func testNormalDelaysRemainPendingUntilFinalCheck() {
        XCTAssertEqual(VehicleOperation.deliverySeconds, 180)
        XCTAssertEqual(VehicleOperation.alertSeconds, 195)
        for status in ["pending", "waking", "waiting", "delivering", "confirming"] {
            XCTAssertFalse(VehicleOperation.terminal(status))
        }
        for status in ["complete", "accepted", "failed", "unconfirmed", "cancelled"] {
            XCTAssertTrue(VehicleOperation.terminal(status))
        }
    }
}
