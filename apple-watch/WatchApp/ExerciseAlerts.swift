import Foundation
import UserNotifications
import FanControlCore

// Independent of view lifetime and network delivery. Cancel only with matching
// confirmation; an HTTP completion or accepted/pending operation is insufficient.
@MainActor final class ExerciseAlerts: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ExerciseAlerts()
    private var requests: [String: String] = [:]
    private var monitors: [String: Task<Void, Never>] = [:]
    func begin(target: String, action: String, operationID: String? = nil, connection: Connection? = nil) -> String {
        let id = "exercise-" + UUID().uuidString
        let deadline = Date().addingTimeInterval(VehicleOperation.alertSeconds)
        let center = UNUserNotificationCenter.current()
        if let old = requests[target] { confirm(old) }
        requests[target] = id
        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) == true
            guard granted, requests[target] == id else { return }
            let content = UNMutableNotificationContent()
            content.title = "Exercise not confirmed"
            content.body = action == "stop_exercise" ? "Stop Exercise is not confirmed. Check that your car is unlocked and climate is on." : "Start Exercise is not confirmed. Check that your car is locked."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            if requests[target] != id { center.removePendingNotificationRequests(withIdentifiers: [id]) }
        }
        if let operationID, let connection {
            monitors[id] = Task {
                let client = Integration(connection)
                // User-started bounded observation only; no physical command or wake.
                while Date() < deadline.addingTimeInterval(30), requests[target] == id, !Task.isCancelled {
                    do { try await Task.sleep(nanoseconds: 3_000_000_000) } catch { return }
                    if let state = try? await client.request(["action": "vehicle_status", "operation_id": operationID]),
                       state["operation_id"] as? String == operationID { outcome(id, state: state) }
                }
                monitors.removeValue(forKey: id)
            }
        }
        return id
    }
    func outcome(_ id: String, state: [String: Any]) {
        switch state["operation_status"] as? String {
        case "complete", "cancelled": confirm(id)
        case "failed": rejected(id)
        default: break // Pending, acceptance, unknown and timeouts cannot cancel the fallback.
        }
    }
    func rejected(_ id: String) {
        guard requests.values.contains(id) else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = "Exercise request failed"
        content.body = "The request was rejected. Check the watch connection and approved panel configuration."
        content.sound = .default
        Task { try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) }
        monitors.removeValue(forKey: id)?.cancel()
    }
    func confirm(_ id: String) {
        if let key = requests.first(where: { $0.value == id })?.key { requests.removeValue(forKey: key) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
        monitors.removeValue(forKey: id)?.cancel()
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
