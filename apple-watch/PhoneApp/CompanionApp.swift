import SwiftUI
import UIKit
import BackgroundTasks
import UserNotifications
import FanControlCore

@main struct CompanionApp: App {
    @UIApplicationDelegateAdaptor(PhoneDelegate.self) private var delegate
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup { CompanionView() }
            .onChange(of: phase) { _, value in
                if value == .active { PhoneModel.shared.foreground() }
                else { PhoneModel.shared.background() }
            }
    }
}

final class PhoneDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let refreshID = "dev.fancontrol.watch.phone.refresh"
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        _ = PhoneModel.shared
        _ = PodcastPlayer.shared
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshID, using: .main) { task in
            Task { @MainActor in
                let work = Task {
                    await PodcastPlayer.shared.refresh()
                    let flights = await PhoneModel.shared.refreshFlights()
                    let home = await PhoneModel.shared.refresh()
                    return flights || home
                }
                task.expirationHandler = { work.cancel() }
                let success = await work.value
                PhoneModel.shared.background()
                task.setTaskCompleted(success: success)
            }
        }
        application.registerForRemoteNotifications()
        return true
    }
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == PodcastPlayer.sessionID else { completionHandler(); return }
        PodcastPlayer.shared.backgroundEvents(completion: completionHandler)
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let hint = notification.request.content.userInfo["fancontrol"] as? [String: Any]
        Task { @MainActor in
            guard hint?["notification"] as? Bool == true,
                  let connection = PhoneModel.shared.connection,
                  hint?["watch_id"] as? String == connection.watch_id else {
                completionHandler([]); return
            }
            let accepted = PhoneModel.shared.receiveNotification(notification.request.content, deliveredAt: notification.date)
            completionHandler(accepted ? [.banner, .list, .sound] : [])
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            PhoneModel.shared.receiveNotification(response.notification.request.content, deliveredAt: response.notification.date, open: true)
            completionHandler()
        }
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PhoneModel.shared.pushToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await PhoneModel.shared.registerPush(); await PhoneModel.shared.registerFlightPush() }
    }
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if userInfo["flightsync"] as? Bool == true {
            Task { @MainActor in
                let success = await PhoneModel.shared.refreshFlights()
                completionHandler(success ? .newData : .failed)
            }
            return
        }
        if let hint = userInfo["fancontrol"] as? [String: Any], hint["notification"] as? Bool == true,
           let aps = userInfo["aps"] as? [String: Any], let alert = aps["alert"] as? [String: Any],
           let title = alert["title"] as? String, let body = alert["body"] as? String {
            Task { @MainActor in
                let content = UNMutableNotificationContent()
                content.title = title; content.body = body; content.userInfo = userInfo
                let saved = PhoneModel.shared.receiveNotification(content)
                completionHandler(saved ? .newData : .noData)
            }
            return
        }
        guard let hint = userInfo["fancontrol"] as? [String: Any], hint["refresh"] as? Bool == true,
              hint["watch_id"] as? String == PhoneModel.shared.connection?.watch_id else { completionHandler(.noData); return }
        let update = (hint["update_id"] as? String).flatMap { UUID(uuidString: $0)?.uuidString.lowercased() }
        Task {
            PhoneModel.shared.record("phone_received", updateID: update)
            let success = await PhoneModel.shared.refresh(updateID: update)
            completionHandler(success ? .newData : .failed)
        }
    }
}
