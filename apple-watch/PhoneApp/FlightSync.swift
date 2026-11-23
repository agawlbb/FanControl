import Foundation
import Security
import FanControlCore

@MainActor final class PhoneFlightSync {
    static let shared = PhoneFlightSync()
    private struct Pairing: Codable {
        let secret: String
        let installation: String
    }
    private let endpoint = URL(string: "https://flights.coffeybean.com/api/fancontrol/")!
    private var operation = 0
    private var generation = Int64(UserDefaults.standard.double(forKey: "flightGeneration"))
    private var activeRequests = 0
    private var pairing: Pairing? {
        guard let raw = Self.readSecret() else { return nil }
        return try? JSONDecoder().decode(Pairing.self, from: raw)
    }
    var paired: Bool { pairing != nil }
    private var trip: FlightTrip? {
        guard let raw = UserDefaults.standard.data(forKey: "flightTrip") else { return nil }
        return try? JSONDecoder().decode(FlightTrip.self, from: raw).validated()
    }
    func snapshot(watchID: String) -> Data? {
        try? JSONEncoder().encode(PhoneFlightSnapshot(watchID: watchID, trip: paired ? trip : nil, generation: generation))
    }
    private func request(_ path: String, pairing: Pairing, body: [String: String]? = nil) async throws -> Data {
        var request = URLRequest(url: endpoint.appendingPathComponent(path))
        request.timeoutInterval = 8
        request.setValue("Bearer " + pairing.secret, forHTTPHeaderField: "Authorization")
        if let body {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        // Fixed HTTPS endpoint; refuse redirects before exposing authorization headers.
        let session = URLSession(configuration: .ephemeral, delegate: NoFlightRedirect(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw ControlError.invalidResponse }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 262144 else { throw ControlError.invalidResponse }
            data.append(byte)
        }
        return data
    }
    func pair(secret: String) async throws {
        let secret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (32...256).contains(secret.utf8.count), !secret.contains(where: \.isWhitespace) else { throw ControlError.invalidConfiguration }
        operation += 1; let ticket = operation
        let next = Pairing(secret: secret, installation: pairing?.installation ?? UUID().uuidString.lowercased())
        let data = try await request("snapshot", pairing: next)
        let trip = try JSONDecoder().decode(FlightTrip.self, from: data).validated()
        guard ticket == operation else { throw CancellationError() }
        try Self.saveSecret(JSONEncoder().encode(next))
        save(trip)
    }
    @discardableResult func refresh() async -> Bool {
        guard let original = pairing, activeRequests == 0 else { return false }
        activeRequests += 1; defer { activeRequests -= 1 }
        let ticket = operation
        do {
            let data = try await request("snapshot", pairing: original)
            let next = try JSONDecoder().decode(FlightTrip.self, from: data).validated()
            guard ticket == operation, pairing?.secret == original.secret else { return false }
            save(next); return true
        } catch { return false }
    }
    func register(token: String, environment: String) async {
        guard let original = pairing else { return }
        _ = try? await request("register", pairing: original, body: ["installation_id": original.installation,
            "device_token": token, "environment": environment])
    }
    private func save(_ trip: FlightTrip) {
        if let raw = try? JSONEncoder().encode(trip) { UserDefaults.standard.set(raw, forKey: "flightTrip") }
        generation = max(generation + 1, Int64(Date().timeIntervalSince1970 * 1000))
        UserDefaults.standard.set(Double(generation), forKey: "flightGeneration")
    }
    func forget() {
        let old = pairing
        operation += 1
        SecItemDelete(Self.query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: "flightTrip")
        generation = max(generation + 1, Int64(Date().timeIntervalSince1970 * 1000))
        UserDefaults.standard.set(Double(generation), forKey: "flightGeneration")
        if let old { Task { _ = try? await request("unregister", pairing: old, body: ["installation_id": old.installation]) } }
    }
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "dev.fancontrol.phone.flightsync", kSecAttrAccount as String: "server"]
    }
    private static func readSecret() -> Data? {
        var result: CFTypeRef?
        let lookup = Self.query.merging([kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]) { _, new in new }
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
    private static func saveSecret(_ data: Data) throws {
        let attrs: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            guard SecItemAdd(query.merging(attrs) { _, new in new } as CFDictionary, nil) == errSecSuccess else { throw ControlError.invalidConfiguration }
        } else if status != errSecSuccess { throw ControlError.invalidConfiguration }
    }
}

private final class NoFlightRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
