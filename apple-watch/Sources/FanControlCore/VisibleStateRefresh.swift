import Foundation

/// One authenticated observation on visible entry, independent of command delivery.
@MainActor public enum VisibleStateRefresh {
    public static func request(for device: Device) -> [String: Any]? {
        // Vehicle entry has its own bounded wake/readiness coordinator.
        guard device.panel?.vehicle != true else { return nil }
        if let panel = device.panel {
            var body: [String: Any] = ["action": "panel_state", "panel_id": panel.id]
            if panel.type == "exercise" { body["music_mode"] = "local" }
            return body
        }
        return ["action": "state", "entity": device.entity]
    }

    public static func read(_ device: Device, using request: ([String: Any]) async throws -> [String: Any]) async throws -> [String: Any]? {
        guard let body = Self.request(for: device) else { return nil }
        try Task.checkCancellation()
        let state = try await request(body)
        try Task.checkCancellation()
        return state
    }

    public static func available(_ state: [String: Any], for device: Device) -> Bool {
        if ["fan", "light", "switch", "input_boolean"].contains(device.domain) {
            return ["on", "off"].contains(state["state"] as? String ?? "")
        }
        if device.panel?.type == "on_duty" { return state["available"] as? Bool == true }
        if device.panel != nil { return state["climate_available"] as? Bool == true }
        guard let value = state["state"] as? String else { return false }
        return !["", "unknown", "unavailable"].contains(value)
    }
}
