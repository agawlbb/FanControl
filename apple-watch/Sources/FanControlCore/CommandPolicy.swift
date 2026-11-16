import Foundation

public enum CommandPolicy {
    public static let active = ["pending", "waking", "waiting", "delivering", "confirming"]
    public static let terminal = ["complete", "accepted", "failed", "unconfirmed", "cancelled"]
    public static func owns(_ state: [String: Any]) -> Bool {
        (active + ["complete", "accepted"]).contains(state["operation_status"] as? String ?? "")
    }
    public static func accept(_ state: [String: Any], id: String, previous: Data?) -> Bool {
        guard state["operation_id"] as? String == id,
              (active + terminal).contains(state["operation_status"] as? String ?? "") else { return false }
        guard let previous, let old = try? JSONSerialization.jsonObject(with: previous) as? [String: Any] else { return true }
        if let before = old["observed_at_ms"] as? Int, let after = state["observed_at_ms"] as? Int, after < before { return false }
        if old["local_error"] as? Bool == true { return true }
        let oldStatus = old["operation_status"] as? String ?? ""
        if ["complete", "accepted", "cancelled"].contains(oldStatus) { return false }
        if terminal.contains(oldStatus), active.contains(state["operation_status"] as? String ?? "") { return false }
        return true
    }
    public static func climateIntent(observedOn: Bool, fresh: Bool, previous: String?) -> String {
        if let previous, previous.hasPrefix("climate_") { return ToggleIntent.opposite(previous) ?? "climate_on" }
        return fresh && observedOn ? "climate_off" : "climate_on"
    }
}
extension Device {
    public func sameCommandTarget(as other: Device) -> Bool {
        guard entity == other.entity else { return false }
        func roles(_ panel: Panel?) -> Data? {
            guard let panel, let raw = try? JSONEncoder().encode(panel),
                  let body = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else { return nil }
            return try? JSONSerialization.data(withJSONObject: body.filter { $0.key == "id" || $0.key == "type" || $0.key.hasSuffix("_entity") }, options: [.sortedKeys])
        }
        return roles(panel) == roles(other.panel)
    }
}
