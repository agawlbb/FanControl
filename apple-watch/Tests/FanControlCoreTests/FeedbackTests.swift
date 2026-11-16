import XCTest
import CryptoKit
@testable import FanControlCore
final class FeedbackTests: XCTestCase {
    func testRequestedAndFailedRemainGray() {
        var f = Feedback(target: "watch A/config A", command: "turn_on", label: "ON")
        XCTAssertTrue(f.gray); f.phase = .unconfirmed; XCTAssertTrue(f.gray)
        f.phase = .confirmed; XCTAssertFalse(f.gray)
    }
    func testUnavailableMismatchAndDelayedEvidence() {
        XCTAssertFalse(Evidence.matches("turn_on", ["state": "unavailable"], panel: nil))
        XCTAssertFalse(Evidence.matches("turn_on", ["state": "off"], panel: nil))
        XCTAssertTrue(Evidence.matches("turn_on", ["state": "on"], panel: nil))
        XCTAssertFalse(Evidence.matches("activate", ["state": "on"], panel: nil))
    }
    func testExactFanMapping() {
        for (i, p) in Evidence.percentages.enumerated() {
            XCTAssertTrue(Evidence.matches("speed\(i+1)", ["state":"on", "attributes":["percentage":p]], panel:nil))
            XCTAssertFalse(Evidence.matches("speed\(i+1)", ["state":"off", "attributes":["percentage":p]], panel:nil))
        }
    }
    func testCoverAssumptionFixesAbsoluteOpen() {
        let intent = Evidence.coverIntent(nil)
        XCTAssertEqual(intent, "open")
        XCTAssertEqual(Evidence.coverIntent("opening"), "close")
        XCTAssertEqual(Evidence.coverIntent("open"), "close")
        XCTAssertEqual(intent, "open")
    }
    func testDistinctRequestsAndTargets() {
        let a = Feedback(target:"A", command:"turn_on", label:"ON")
        let b = Feedback(target:"B", command:"turn_on", label:"ON")
        XCTAssertNotEqual(a.id, b.id); XCTAssertNotEqual(a.target, b.target)
    }
    func testAuthenticatedResponseRejectsWrongCommandNonce() throws {
        let key = SymmetricKey(size: .bits256)
        let sealed = try AES.GCM.seal(Data("{}".utf8), using:key, authenticating:Data("request-A:response".utf8))
        let envelope: [String:Any] = ["iv":Data(sealed.nonce).base64EncodedString(), "ciphertext":(sealed.ciphertext+sealed.tag).base64EncodedString()]
        XCTAssertEqual(try open(envelope,key:key,aad:"request-A:response"),Data("{}".utf8))
        XCTAssertThrowsError(try open(envelope,key:key,aad:"request-B:response"))
    }
    func testAddressPolicy() throws {
        _ = try Connection.address("http://192.168.1.2:8123")
        XCTAssertThrowsError(try Connection.address("http://example.com"))
        XCTAssertThrowsError(try Connection.address("http://192.168.1.2",external:true))
        XCTAssertThrowsError(try Connection.address("https://user:password@example.com"))
    }
}
