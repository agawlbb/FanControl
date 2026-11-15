import Foundation
import WatchKit
import FanControlCore

// Pushes are passive invalidations. Never call WatchModel.enter or send commands.
@MainActor final class PushNotifications: NSObject, WKApplicationDelegate {
    private static var token: String?
    private static var delivery: Task<Void, Never>?

    static func register() {
        guard Vault.load() != nil else { return }
        WKApplication.shared().registerForRemoteNotifications()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let transfer = task as? WKURLSessionRefreshBackgroundTask, transfer.sessionIdentifier == CommandDelivery.sessionID {
                CommandDelivery.shared.reconnect(transfer)
            } else if let connectivity = task as? WKWatchConnectivityRefreshBackgroundTask {
                WatchCompanion.shared.reconnect(connectivity)
            } else { task.setTaskCompletedWithSnapshot(false) }
        }
    }

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        Self.token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Self.syncRegistration()
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        PushDiagnostics.shared.record("registration_failed", connection: Vault.load())
    }

    static func syncRegistration() {
        guard let token, let original = Vault.load(),
              let environment = Bundle.main.object(forInfoDictionaryKey: "FanControlAPNSEnvironment") as? String,
              ["development", "production"].contains(environment) else { return }
        delivery?.cancel()
        delivery = Task {
            // Existing encrypted pairing carries the APNs token to HA; relay
            // credentials and Apple's signing key never enter the watch app.
            guard !Task.isCancelled, Vault.load() == original else { return }
            _ = try? await Integration(original).request([
                "action": "push_register", "purpose": "command_outcomes", "device_token": token,
                "environment": environment == "development" ? "sandbox" : "production"
            ])
            _ = try? await Integration(original).request([
                "action": "push_register", "device_token": token,
                "environment": environment == "development" ? "sandbox" : "production"
            ])
        }
    }

    func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any],
                                      fetchCompletionHandler completionHandler: @escaping (WKBackgroundFetchResult) -> Void) {
        if let hint = userInfo["fancontrol"] as? [String: Any], let id = hint["operation_id"] as? String, UUID(uuidString: id) != nil {
            // Push data is a hint. Only the authenticated operation result changes receipt state.
            Task {
                await CommandDelivery.shared.reconcile(id)
                completionHandler(.newData)
            }
            return
        }
        guard let hint = userInfo["fancontrol"] as? [String: Any], hint["refresh"] as? Bool == true else {
            completionHandler(.noData); return
        }
        // IDs are correlation hints only. Panel selection always comes from authenticated HA.
        let updateID = (hint["update_id"] as? String).flatMap { UUID(uuidString: $0)?.uuidString.lowercased() }
        let connection = Vault.load()
        PushDiagnostics.shared.record("received", connection: connection, updateID: updateID, watchID: hint["watch_id"] as? String)
        Task {
            // An active UI already polls; this never navigates, confirms a
            // command, or launches the foreground entry/wake path.
            let refreshed = await BackgroundRefresh.refresh(updateID: updateID)
            if WKApplication.shared().applicationState == .active, let current = Vault.load() {
                await PushDiagnostics.flush(current)
            }
            completionHandler(refreshed ? .newData : .noData)
        }
    }
}
