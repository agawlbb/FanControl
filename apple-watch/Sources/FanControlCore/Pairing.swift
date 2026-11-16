import Foundation
import CryptoKit
import Security

public final class Pairing {
    private let http = HTTP()
    public init() {}
    private func der(_ tag: UInt8, _ bytes: Data) -> Data {
        var length = [UInt8](); var n = bytes.count
        repeat { length.insert(UInt8(n & 255), at: 0); n >>= 8 } while n > 0
        return Data([tag]) + (bytes.count < 128 ? Data([UInt8(bytes.count)]) : Data([0x80 | UInt8(length.count)]) + Data(length)) + bytes
    }
    public func run(address: String, progress: @escaping @MainActor (String) -> Void) async throws -> Connection {
        _ = try Connection.remoteAddress(address)
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048] as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey), let pkcs1 = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else { throw ControlError.invalidResponse }
        // Android sends SubjectPublicKeyInfo, not Security's PKCS#1 representation.
        let algorithm = Data([0x30,0x0d,0x06,0x09,0x2a,0x86,0x48,0x86,0xf7,0x0d,0x01,0x01,0x01,0x05,0x00])
        let spki = der(0x30, algorithm + der(0x03, Data([0]) + pkcs1))
        let fingerprint = Data(SHA256.hash(data: spki)).hex.prefix(12).uppercased()
        let created = try await http.post(address, path: "api/fan_control/pair/create", body: ["public_key": spki.base64EncodedString(), "platform": "watch_os"])
        guard let code = created["code"] as? String, code.range(of: "^[0-9]{8}$", options: .regularExpression) != nil,
              let token = created["device_token"] as? String, token.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
              created["fingerprint"] as? String == fingerprint, let expiry = created["expires_at"] as? Double,
              expiry > Date().timeIntervalSince1970, expiry <= Date().timeIntervalSince1970 + 610 else { throw ControlError.invalidResponse }
        await progress("Code: \(code)\nFingerprint: \(fingerprint)\nIn Home Assistant choose Fan Control → Configure → Pair a watch. Compare every fingerprint character.")
        while Date().timeIntervalSince1970 < expiry {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            let response = try await http.post(address, path: "api/fan_control/pair/poll", body: [:], token: token)
            if response["status"] as? String == "pending" { continue }
            guard response["status"] as? String == "ready", let envelope = response["envelope"] as? [String: Any], envelope["version"] as? Int == 1,
                  let wrappedText = envelope["wrapped_key"] as? String, let wrapped = Data(base64Encoded: wrappedText), wrapped.count == 256,
                  let key = SecKeyCreateDecryptedData(privateKey, .rsaEncryptionOAEPSHA256, wrapped as CFData, &error) as Data?, key.count == 32 else { throw ControlError.invalidResponse }
            let plain = try open(envelope, key: SymmetricKey(data: key), aad: code)
            guard let settings = try JSONSerialization.jsonObject(with: plain) as? [String: Any], settings["version"] as? Int == 1, settings["integration"] as? Bool == true else { throw ControlError.invalidConfiguration }
            let connection = try JSONDecoder().decode(Connection.self, from: plain).validated()
            try Task.checkCancellation()
            try Vault.save(connection)
            guard Vault.load() == connection else { throw ControlError.invalidConfiguration }
            _ = try await http.post(address, path: "api/fan_control/pair/acknowledge", body: [:], token: token)
            return connection
        }
        throw ControlError.notConfirmed
    }
}

