import Foundation
import CryptoKit

// Stores observations only. Requested projections and receipts never enter here.
public final class ObservationCache: @unchecked Sendable {
    public static let shared = ObservationCache()
    private let defaults: UserDefaults
    private let lock = NSLock()
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    private func key(_ connection: Connection, _ device: Device) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let role = (try? encoder.encode(device)) ?? Data()
        let scope = Data((connection.watch_id + "|" + connection.url + "|" + connection.token).utf8) + role
        return "observation." + SHA256.hash(data: scope).map { String(format: "%02x", $0) }.joined()
    }
    public func load(_ connection: Connection, _ device: Device) -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        guard let data = defaults.data(forKey: key(connection, device)) else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
    public func save(_ state: [String: Any], connection: Connection, device: Device) {
        var valid: [String: Any] = [:]
        if device.panel?.type == "on_duty", state["available"] as? Bool == true,
           let cityPair = state["city_pair"] as? String, !cityPair.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let departure = state["departure"] as? String, FlightPresentation.departure(departure) != nil {
            // Retain one complete flight observation. Availability is live evidence,
            // never a persisted permission to recolor saved data on opening.
            valid["city_pair"] = cityPair
            valid["departure"] = departure
        }
        if ["on", "off"].contains(state["state"] as? String ?? "") {
            valid["state"] = state["state"]
            if let attrs = state["attributes"] as? [String: Any], let percentage = attrs["percentage"] as? Int, (0...100).contains(percentage) {
                valid["attributes"] = ["percentage": percentage]
            }
        }
        if state["climate_available"] as? Bool == true, let on = state["climate_on"] as? Bool {
            valid["climate_on"] = on
        }
        if let battery = state["battery"] as? Double, battery.isFinite, (0...100).contains(battery) { valid["battery"] = battery }
        for role in ["garage", "trunk"] {
            if ["open", "closed"].contains(state[role + "_state"] as? String ?? "") { valid[role + "_state"] = state[role + "_state"] }
        }
        guard !valid.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        let k = key(connection, device)
        var merged = defaults.data(forKey: k).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        merged.merge(valid) { _, new in new }
        if let data = try? JSONSerialization.data(withJSONObject: merged) { defaults.set(data, forKey: k) }
    }
    public func clear() {
        lock.lock(); defer { lock.unlock() }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("observation.") { defaults.removeObject(forKey: key) }
    }
}
