import Foundation

/// Local notifications describe recent user commands, never entry reads/wakes.
public enum CommandAlertPolicy {
    public static let fallbackSeconds: TimeInterval = 225
    public static let maximumAge: TimeInterval = 300

    public static func relevant(_ record: CommandRecord, current: Connection?, now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(record.issued)
        guard age >= -5, age < maximumAge, record.matchesCurrentTarget(current),
              let body = try? JSONSerialization.jsonObject(with: record.body) as? [String: Any],
              body["action"] as? String == "operation_submit",
              let command = body["command"] as? String, !command.isEmpty, command != "wake" else { return false }
        return true
    }

    public static func fallback(_ record: CommandRecord, current: Connection?, now: Date = Date()) -> Bool {
        guard relevant(record, current: current, now: now), !record.accepted else { return false }
        guard let data = record.result,
              let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return true }
        return !CommandPolicy.owns(state) && !CommandPolicy.terminal.contains(state["operation_status"] as? String ?? "")
    }

    public static func localOutcome(_ record: CommandRecord, state: [String: Any], current: Connection?, now: Date = Date()) -> Bool {
        if let data = record.result,
           let latest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           CommandPolicy.owns(latest) || latest["operation_status"] as? String == "cancelled" { return false }
        return relevant(record, current: current, now: now) && state["operation_id"] as? String == record.id &&
            ["failed", "unconfirmed"].contains(state["operation_status"] as? String ?? "") && state["outcome_alerts"] as? Bool != true
    }
}
