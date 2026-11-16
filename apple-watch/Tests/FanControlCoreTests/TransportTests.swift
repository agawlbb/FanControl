import XCTest
import CryptoKit
@testable import FanControlCore

final class MockProtocol: URLProtocol {
    static var handle: ((URLRequest) throws -> (Int, Data))?
    static func body(_ request: URLRequest) throws -> Data {
        if let data = request.httpBody { return data }
        // URLSession may move the POST body into a stream before URLProtocol.
        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open(); defer { stream.close() }
        var data = Data(); var bytes = [UInt8](repeating:0,count:4096)
        while true {
            let count = stream.read(&bytes,maxLength:bytes.count)
            if count < 0 { throw stream.streamError ?? URLError(.cannotDecodeRawData) }
            if count == 0 { return data }
            data.append(contentsOf:bytes.prefix(count))
        }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handle!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
final class TransportTests: XCTestCase {
    private func client() throws -> Integration {
        let raw = """
        {"url":"https://local.example","remote_url":"https://remote.example","token":"\(String(repeating:"a",count:64))","watch_id":"\(String(repeating:"b",count:32))","entity":"fan.test","devices":[{"entity":"fan.test","title":"Test"}]}
        """
        let c = try JSONDecoder().decode(Connection.self, from:Data(raw.utf8)).validated()
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [MockProtocol.self]
        return Integration(c,http:HTTP(configuration:config))
    }
    override func tearDown() { MockProtocol.handle = nil; super.tearDown() }
    func testPrivateMusicChunkUsesLargerBudgetWithoutRelaxingOrdinaryReads() async throws {
        let c = try client()
        MockProtocol.handle = { request in
            let packet = try JSONSerialization.jsonObject(with: MockProtocol.body(request)) as! [String: Any]
            let aad = "fan-control-v1:\(packet["watch_id"]!):\(packet["timestamp"]!):\(packet["nonce"]!):response"
            let plain = try JSONSerialization.data(withJSONObject: ["data":Data(repeating:42,count:196608).base64EncodedString(), "offset":0])
            let key = SymmetricKey(data:try Data(hex:String(repeating:"a",count:64)))
            let box = try AES.GCM.seal(plain,using:key,authenticating:Data(aad.utf8))
            let envelope = ["iv":Data(box.nonce).base64EncodedString(),"ciphertext":(box.ciphertext + box.tag).base64EncodedString()]
            return (200,try JSONSerialization.data(withJSONObject:envelope))
        }
        let chunk = try await c.request(["action":"exercise_music_chunk","name":"01 song.mp3","offset":0])
        XCTAssertEqual(Data(base64Encoded:chunk["data"] as! String)?.count,196608)
        do { _ = try await c.request(["action":"state","entity":"fan.test"]); XCTFail("Ordinary reads must retain the small limit") } catch {}
    }
    func testAmbiguousCommandNeverFallsBackToAnotherEndpoint() async throws {
        let c = try client(); var hosts = [String]()
        MockProtocol.handle = { request in hosts.append(request.url!.host!); throw URLError(.timedOut) }
        do { _ = try await c.request(["action":"command","entity":"fan.test","command":"turn_on"]); XCTFail("Expected timeout") } catch {}
        XCTAssertEqual(hosts,["remote.example"])
    }
    func testReadFailureAndRejectionNeverTryLocal() async throws {
        let c = try client(); var hosts = [String]()
        MockProtocol.handle = { request in hosts.append(request.url!.host!); throw URLError(.notConnectedToInternet) }
        do { _ = try await c.request(["action":"state","entity":"fan.test"]); XCTFail("Expected failure") } catch {}
        XCTAssertEqual(hosts,["remote.example"])
        hosts = []
        MockProtocol.handle = { request in hosts.append(request.url!.host!); return (403,Data()) }
        do { _ = try await c.request(["action":"state","entity":"fan.test"]); XCTFail("Expected rejection") } catch {}
        XCTAssertEqual(hosts,["remote.example"])
    }
    func testPanelCommandAlsoNeverReplaysOnRemote() async throws {
        let c = try client(); var count = 0
        MockProtocol.handle = { _ in count += 1; throw URLError(.networkConnectionLost) }
        do { _ = try await c.request(["action":"panel_command","panel_id":"driving","command":"trunk_open"]); XCTFail("Expected failure") } catch {}
        XCTAssertEqual(count,1)
    }
    func testDurableSubmissionUsesRemoteOnceWithCapturedOperationID() async throws {
        let c = try client(); var hosts = [String](); var nonces = [String]()
        MockProtocol.handle = { request in
            hosts.append(request.url!.host!)
            let packet = try JSONSerialization.jsonObject(with: MockProtocol.body(request)) as! [String: Any]
            nonces.append(packet["nonce"] as! String)
            let aad = "fan-control-v1:\(packet["watch_id"]!):\(packet["timestamp"]!):\(packet["nonce"]!)"
            let key = SymmetricKey(data: try Data(hex: String(repeating:"a",count:64)))
            let plain = try open(packet, key:key, aad:aad)
            let body = try JSONSerialization.jsonObject(with:plain) as! [String:Any]
            XCTAssertEqual(body["operation_id"] as? String, "stable-id")

            let box = try AES.GCM.seal(JSONSerialization.data(withJSONObject:["operation_id":"stable-id", "operation_status":"pending"]),using:key,authenticating:Data((aad + ":response").utf8))
            return (200,try JSONSerialization.data(withJSONObject:["iv":Data(box.nonce).base64EncodedString(),"ciphertext":(box.ciphertext + box.tag).base64EncodedString()]))
        }
        let result = try await c.request(["action":"operation_submit", "operation_id":"stable-id", "entity":"fan.test", "command":"turn_on"])
        XCTAssertEqual(result["operation_status"] as? String,"pending")
        XCTAssertEqual(hosts,["remote.example"])
        XCTAssertEqual(Set(nonces).count,1)
    }
    func testContinuationUsesSameAbsoluteIntentWithFreshAuthentication() async throws {
        let c = try client()
        var nonces = Set<String>()
        var intents = [Data]()
        MockProtocol.handle = { request in
            let packet = try JSONSerialization.jsonObject(with: MockProtocol.body(request)) as! [String: Any]
            XCTAssertEqual(request.url?.host, "remote.example")
            nonces.insert(packet["nonce"] as! String)
            let aad = "fan-control-v1:\(packet["watch_id"]!):\(packet["timestamp"]!):\(packet["nonce"]!)"
            let key = SymmetricKey(data: try Data(hex: String(repeating: "a", count: 64)))
            let encrypted = Data(base64Encoded: packet["ciphertext"] as! String)!
            let sealed = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: Data(base64Encoded: packet["iv"] as! String)!), ciphertext: encrypted.dropLast(16), tag: encrypted.suffix(16))
            let plain = try AES.GCM.open(sealed, using: key, authenticating: Data(aad.utf8))
            let body = try JSONSerialization.jsonObject(with: plain)
            intents.append(try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]))
            if intents.count == 1 { throw URLError(.networkConnectionLost) }
            let box = try AES.GCM.seal(JSONSerialization.data(withJSONObject: ["operation_id": "handoff", "operation_status": "pending"]), using: key, authenticating: Data((aad + ":response").utf8))
            return (200, try JSONSerialization.data(withJSONObject: ["iv": Data(box.nonce).base64EncodedString(), "ciphertext": (box.ciphertext + box.tag).base64EncodedString()]))
        }
        let intent: [String: Any] = ["action": "operation_submit", "operation_id": "handoff", "entity": "fan.test", "command": "turn_off", "issued_at_ms": 123456]
        do { _ = try await c.request(intent); XCTFail("Expected lost connection") } catch {}
        let receipt = try await c.request(intent)
        XCTAssertEqual(intents.count, 2)
        XCTAssertEqual(intents.first, intents.last)
        XCTAssertEqual(nonces.count, 2)
        XCTAssertTrue(CommandPolicy.owns(receipt))
    }
    func testRateLimitedDurableSubmissionDoesNotRetry() async throws {
        let c = try client(); var hosts = [String]()
        MockProtocol.handle = { request in hosts.append(request.url!.host!); return (429,Data()) }
        do { _ = try await c.request(["action":"operation_submit", "operation_id":"stable-id"]); XCTFail("Expected retryable error") } catch {}
        XCTAssertEqual(hosts,["remote.example"])
    }
}
