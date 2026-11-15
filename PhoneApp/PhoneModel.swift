import Foundation
import SwiftUI
import WatchConnectivity
import BackgroundTasks
import UserNotifications
import FanControlCore

@MainActor final class PhoneModel: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneModel()
    @Published private(set) var connection = Vault.load()
    @Published var settings = CompanionSettings()
    @Published private var inbox = MessageInbox()
    var messages: [AppMessage] { inbox.messages }
    @Published var selectedMessage: AppMessage?
    @Published var error = ""
    @Published private(set) var reachable = false
    @Published private(set) var refreshedAt: Date?
    @Published private(set) var watchSequence = 0
    @Published private(set) var events: [String] = []
    @Published private(set) var refreshing = false
    var pushToken: String?
    private let session = WCSession.default
    private var snapshot: CompanionSnapshot?
    private var foregroundWork: Task<Void, Never>?
    private var outbox: [[String: Any]] = []
    @Published private(set) var saving = false
    private var defaults: UserDefaults { .standard }
    override private init() {
        super.init()
        if let c = connection { settings = c.companion_settings ?? CompanionSettings() }
        if let raw = defaults.data(forKey: "phoneSnapshot"), let saved = try? JSONDecoder().decode(CompanionSnapshot.self, from: raw),
           let c = connection, (try? saved.resolved(for: c)) != nil { snapshot = saved; refreshedAt = Date(timeIntervalSince1970: Double(saved.atMS) / 1000) }
        if let raw = defaults.data(forKey: "phoneMessages"), let saved = try? JSONDecoder().decode([AppMessage].self, from: raw), connection != nil { inbox = MessageInbox(messages: saved, dismissed: defaults.dictionary(forKey: "phoneMessageDismissals") as? [String: Int64] ?? [:]) }
        expireMessages()
        events = defaults.stringArray(forKey: "phoneEvents") ?? []
        outbox = defaults.array(forKey: "phoneReceipts") as? [[String: Any]] ?? []
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--preview-companion") {
            let json = """
            {"url":"https://example.invalid","token":"\(String(repeating: "a", count: 64))","watch_id":"\(String(repeating: "b", count: 32))","entity":"panel.driving","companion":true,"devices":[{"entity":"panel.driving","title":"Driving"},{"entity":"panel.exercise","title":"Exercise"},{"entity":"fan.office","title":"Office fan"}]}
            """
            connection = try? JSONDecoder().decode(Connection.self, from: Data(json.utf8)).validated()
            settings = CompanionSettings(order: ["fan.office", "panel.driving", "panel.exercise"])
            return
        }
        #endif
        session.delegate = self; session.activate()
    }
    func foreground() {
        Task { await PodcastPlayer.shared.refresh() }
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--preview-companion") { return }
        #endif
        foregroundWork?.cancel()
        foregroundWork = Task {
            await loadDeliveredMessages()
            await registerPush()
            while !Task.isCancelled {
                expireMessages()
                _ = await refresh()
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
            }
        }
    }
    private var messageTime: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    private func saveMessages() {
        if let raw = try? JSONEncoder().encode(messages) { defaults.set(raw, forKey: "phoneMessages") }
        defaults.set(inbox.dismissed, forKey: "phoneMessageDismissals")
    }
    private func clearMessages() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        inbox = MessageInbox(); selectedMessage = nil
        defaults.removeObject(forKey: "phoneMessageDismissals")
    }
    func dismissMessage(_ id: String) {
        guard let original = connection else { return }
        inbox.dismiss(id, now: messageTime)
        if selectedMessage?.id == id { selectedMessage = nil }
        saveMessages()
        Task { await removeDeliveredMessages([id], original: original) }
    }
    func expireMessages() {
        var updated = inbox
        let ids = Set(updated.expire(now: messageTime))
        guard updated != inbox else { return }
        inbox = updated
        if let selectedMessage, !messages.contains(where: { $0.id == selectedMessage.id }) { self.selectedMessage = nil }
        saveMessages()
        if !ids.isEmpty, let original = connection { Task { await removeDeliveredMessages(ids, original: original) } }
    }
    @discardableResult func receiveNotification(_ content: UNNotificationContent, deliveredAt: Date = Date(), open: Bool = false) -> Bool {
        guard let hint = content.userInfo["fancontrol"] as? [String: Any],
              hint["notification"] as? Bool == true,
              hint["watch_id"] as? String == connection?.watch_id,
              let id = hint["update_id"] as? String else { return false }
        expireMessages()
        let received = Int64(deliveredAt.timeIntervalSince1970 * 1000)
        let at = min(hint["sent_at_ms"] as? Int64 ?? received, received)
        let accepted = inbox.receive(AppMessage(id: id, title: content.title, message: content.body, atMS: at), now: messageTime)
        saveMessages()
        if open, accepted { selectedMessage = messages.first { $0.id == id } }
        return accepted
    }
    private func removeDeliveredMessages(_ ids: Set<String>, original: Connection) async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
        guard connection?.watch_id == original.watch_id, connection?.token == original.token else { return }
        let identifiers = delivered.compactMap { notification -> String? in
            guard let hint = notification.request.content.userInfo["fancontrol"] as? [String: Any],
                  hint["watch_id"] as? String == original.watch_id,
                  let id = hint["update_id"] as? String, ids.contains(id) else { return nil }
            return notification.request.identifier
        }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    private func loadDeliveredMessages() async {
        expireMessages()
        guard let original = connection else { return }
        let center = UNUserNotificationCenter.current()
        let notifications = await center.deliveredNotifications()
        guard connection?.watch_id == original.watch_id, connection?.token == original.token else { return }
        var removed: [String] = []
        for notification in notifications {
            guard let hint = notification.request.content.userInfo["fancontrol"] as? [String: Any],
                  hint["notification"] as? Bool == true, hint["watch_id"] as? String == original.watch_id else { continue }
            if !receiveNotification(notification.request.content, deliveredAt: notification.date) { removed.append(notification.request.identifier) }
        }
        center.removeDeliveredNotifications(withIdentifiers: removed)
    }
    func background() {
        PodcastPlayer.shared.suspend()
        foregroundWork?.cancel(); foregroundWork = nil
        let request = BGAppRefreshTaskRequest(identifier: PhoneDelegate.refreshID)
        request.earliestBeginDate = Date().addingTimeInterval(15 * 60)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: PhoneDelegate.refreshID)
        try? BGTaskScheduler.shared.submit(request)
    }
    func link() {
        guard session.activationState == .activated, session.isReachable else { error = "Open Fan Control on your watch."; return }
        session.sendMessage(["action": "link"], replyHandler: nil, errorHandler: { _ in Task { @MainActor in self.error = "Watch unavailable" } })
    }
    func unlink() {
        guard let c = connection else { return }
        Task {
            do {
                _ = try await Integration(c).request(["action": "companion_unlink"])
                guard connection?.token == c.token else { return }
                foregroundWork?.cancel(); connection = nil; snapshot = nil; outbox = []; events = []; watchSequence = 0; refreshedAt = nil
                clearMessages(); PhoneLibrary.shared.targetChanged(); PodcastPlayer.shared.pairingChanged()
                Vault.clear()
                for key in ["phoneSnapshot", "phoneReceipts", "phoneEvents", "phoneMessages", "phoneMessageDismissals"] { defaults.removeObject(forKey: key) }
                for transfer in session.outstandingFileTransfers { transfer.cancel() }
                for transfer in session.outstandingUserInfoTransfers { transfer.cancel() }
                try? session.updateApplicationContext([:])
            } catch { if connection?.token == c.token { self.error = "Unlink not confirmed. Try again." } }
        }
    }
    func registerPush() async {
        guard let c = connection, let pushToken,
              let environment = Bundle.main.object(forInfoDictionaryKey: "FanControlAPNSEnvironment") as? String else { return }
        do { _ = try await Integration(c).request(["action": "companion_push_register", "device_token": pushToken, "environment": environment == "development" ? "sandbox" : "production"]) }
        catch { if connection?.token == c.token, !Task.isCancelled { record("phone_failed"); self.error = "Push registration not confirmed" } }
    }
    @discardableResult func refresh(updateID: String? = nil) async -> Bool {
        guard let original = connection, !refreshing, !saving else { return false }
        refreshing = true; defer { refreshing = false }
        do {
            let response = try await Integration(original).request(["action": "companion_snapshot"])
            try Task.checkCancellation()
            guard connection?.token == original.token else { return false }
            let next = try CompanionSnapshot(response: response, connection: original, updateID: updateID)
            try install(next, original: original)
            record("phone_saved", updateID: updateID)
            await flushReceipts()
            return true
        } catch {
            guard connection?.token == original.token, !Task.isCancelled else { return false }
            record("phone_failed", updateID: updateID)
            self.error = "Home Assistant unavailable"
            await flushReceipts()
            return false
        }
    }
    private func install(_ next: CompanionSnapshot, original: Connection) throws {
        if let old = snapshot, old.watchID == next.watchID, old.sequence >= next.sequence { return }
        let c = try next.resolved(for: original)
        guard (c.revision ?? 0) >= (connection?.revision ?? 0) else { return }
        try Vault.save(c)
        defaults.set(try JSONEncoder().encode(next), forKey: "phoneSnapshot")
        connection = c; snapshot = next; settings = c.companion_settings ?? CompanionSettings()
        refreshedAt = Date(timeIntervalSince1970: Double(next.atMS) / 1000); error = ""
        publish()
    }
    func saveSettings() {
        guard let original = connection, !saving else { return }
        var value = settings
        value.order = value.ordered(original.devices.map(\.entity))
        saving = true
        Task {
            defer { saving = false }
            do {
                let raw = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
                let response = try await Integration(original).request(["action": "companion_settings", "revision": original.revision ?? 0, "settings": raw])
                guard connection?.token == original.token else { return }
                let next = try CompanionSnapshot(response: response, connection: original)
                try install(next, original: original)
            } catch {
                guard connection?.token == original.token else { return }
                settings = connection?.companion_settings ?? CompanionSettings()
                self.error = "Settings not confirmed. Refresh to check."
            }
        }
    }
    @Published var podcastIndex: Int? = UserDefaults.standard.object(forKey: "podcastIndex") as? Int
    var orderedTiles: [String] { PodcastTile.order(devices: orderedDevices.map(\.entity), index: podcastIndex) }
    func moveTiles(_ indices: IndexSet, to destination: Int) {
        var tiles = orderedTiles; tiles.move(fromOffsets: indices, toOffset: destination)
        podcastIndex = tiles.firstIndex(of: PodcastTile.id)
        defaults.set(podcastIndex, forKey: "podcastIndex")
        let devices = tiles.filter { $0 != PodcastTile.id }
        if devices != orderedDevices.map(\.entity) { settings.order = devices; saveSettings() }
        publish()
    }
    var orderedDevices: [Device] {
        guard let c = connection else { return [] }
        return settings.ordered(c.devices.map(\.entity)).compactMap { id in c.devices.first { $0.entity == id } }
    }
    func move(_ indices: IndexSet, to destination: Int) {
        var order = orderedDevices.map(\.entity); order.move(fromOffsets: indices, toOffset: destination)
        settings.order = order; saveSettings()
    }
    private func payload() -> [String: Any] {
        var value: [String: Any] = [:]
        if let snapshot, let raw = try? JSONEncoder().encode(snapshot) { value["snapshot"] = raw }
        if let manifest = PhoneLibrary.shared.manifest, manifest.watchID == connection?.watch_id,
           let raw = try? JSONEncoder().encode(manifest) { value["playlist"] = raw }
        if let c = connection {
            value["podcast"] = try? JSONEncoder().encode(PodcastPlayer.shared.snapshot())
            value["podcast_watch_id"] = c.watch_id
            value["podcast_index"] = podcastIndex ?? orderedDevices.count
        }
        return value
    }
    func publish() {
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled, connection != nil else { return }
        do {
            let value = payload()
            try session.updateApplicationContext(value)
            if session.isReachable { session.sendMessage(value, replyHandler: nil, errorHandler: { _ in }) }
        }
        catch { self.error = "Watch update pending" }
    }
    func record(_ phase: String, updateID: String? = nil) {
        guard let c = connection else { return }
        let at = Int(Date().timeIntervalSince1970 * 1000)
        var event: [String: Any] = ["id": UUID().uuidString.lowercased(), "phase": phase, "at_ms": at, "panel": c.entity, "revision": c.revision ?? 0, "watch_id": c.watch_id]
        if let updateID { event["update_id"] = updateID }
        outbox.append(event); outbox = Array(outbox.suffix(120)); defaults.set(outbox, forKey: "phoneReceipts")
        events.append("\(Date().formatted(date: .omitted, time: .standard)) · \(phase)")
        events = Array(events.suffix(120)); defaults.set(events, forKey: "phoneEvents")
    }
    private func flushReceipts() async {
        guard let c = connection, !outbox.isEmpty else { return }
        let batch = Array(outbox.prefix(12))
        guard let result = try? await Integration(c).request(["action": "push_receipts", "events": batch]) else { return }
        let acknowledged = Set((result["recorded"] as? [String] ?? []) + (result["discarded"] as? [String] ?? []))
        outbox.removeAll { acknowledged.contains($0["id"] as? String ?? "") }; defaults.set(outbox, forKey: "phoneReceipts")
    }
    private func receive(_ value: [String: Any]) {
        if let grant = value["grant"] as? Data, let c = try? JSONDecoder().decode(Connection.self, from: grant).validated(), c.companion == true {
            do {
                if connection?.token != c.token {
                    snapshot = nil; outbox = []; events = []; watchSequence = 0; refreshedAt = nil
                    clearMessages(); PhoneLibrary.shared.targetChanged(); PodcastPlayer.shared.pairingChanged()
                    for key in ["phoneSnapshot", "phoneReceipts", "phoneEvents", "phoneMessages", "phoneMessageDismissals"] { defaults.removeObject(forKey: key) }
                }
                try Vault.save(c); connection = c; settings = c.companion_settings ?? CompanionSettings(); error = ""
                Task { await registerPush(); _ = await refresh() }
            } catch { self.error = "Link failed" }
        }
        guard value["watch_id"] as? String == connection?.watch_id else { return }
        if value["watch_opened"] as? Bool == true {
            record("watch_opened")
            // Preserve the watch's actual first-display panel and time separately
            // from the phone's newer cached selection.
            if let last = outbox.indices.last {
                outbox[last]["panel"] = value["panel"] as? String ?? ""
                outbox[last]["revision"] = value["revision"] as? Int ?? 0
                outbox[last]["at_ms"] = value["at_ms"] as? Int ?? outbox[last]["at_ms"]
                defaults.set(outbox, forKey: "phoneReceipts")
            }
        }
        if let seq = value["watch_saved"] as? Int {
            watchSequence = max(watchSequence, seq)
            let update = (value["update_id"] as? String).flatMap { UUID(uuidString: $0)?.uuidString.lowercased() }
            record("watch_saved", updateID: update)
            Task { await flushReceipts() }
        }
        if value["music_sync_requested"] as? Bool == true { PhoneLibrary.shared.sync() }
        if let id = value["playlist_saved"] as? String { PhoneLibrary.shared.acknowledge(id) }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { Task { @MainActor in self.reachable = session.isReachable; self.publish() } }
    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        Task { @MainActor in PhoneLibrary.shared.transferFinished(fileTransfer, error: error) }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) { Task { @MainActor in self.reachable = session.isReachable } }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { }
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            Vault.clear(); self.connection = nil; self.snapshot = nil; self.outbox = []; self.settings = CompanionSettings()
            self.events = []; self.watchSequence = 0; self.refreshedAt = nil; PhoneLibrary.shared.targetChanged(); PodcastPlayer.shared.pairingChanged()
            self.clearMessages(); self.defaults.removeObject(forKey: "phoneMessages"); self.defaults.removeObject(forKey: "phoneMessageDismissals"); self.defaults.removeObject(forKey: "phoneSnapshot"); self.defaults.removeObject(forKey: "phoneReceipts"); self.defaults.removeObject(forKey: "phoneEvents")
            session.activate()
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) { Task { @MainActor in self.receive(userInfo) } }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            if let raw = message["podcast_command"] as? Data {
                guard message["watch_id"] as? String == self.connection?.watch_id,
                      let command = try? JSONDecoder().decode(PodcastCommand.self, from: raw) else { replyHandler([:]); return }
                let original = self.connection
                let reply = await PodcastPlayer.shared.handle(command)
                guard self.connection?.watch_id == original?.watch_id, self.connection?.token == original?.token else { replyHandler([:]); return }
                replyHandler(["podcast_reply": (try? JSONEncoder().encode(reply)) ?? Data()])
                return
            }
            replyHandler(self.payload()) // Return cache promptly; fetch HA separately.
            if message["action"] as? String == "latest" { _ = await self.refresh() }
        }
    }
}
