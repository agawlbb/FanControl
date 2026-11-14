import Foundation
import WatchConnectivity
import WatchKit
import FanControlCore

extension Notification.Name { static let companionSnapshotSaved = Notification.Name("companionSnapshotSaved") }

@MainActor final class WatchCompanion: NSObject, WCSessionDelegate {
    static let shared = WatchCompanion()
    private var granting = false
    private var protectedEntities = Set<String>()
    func protectIntent(_ entity: String) { protectedEntities.insert(entity) }
    func beginEntry() { protectedEntities.removeAll() }
    private let session = WCSession.default
    func start() { session.delegate = self; session.activate() }
    func requestLatest() {
        provision()
        if let c = Vault.load(), session.activationState == .activated {
            session.transferUserInfo(["watch_opened": true, "watch_id": c.watch_id, "panel": c.entity,
                                      "revision": c.revision ?? 0, "at_ms": Int(Date().timeIntervalSince1970 * 1000)])
        }
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(["action": "latest"], replyHandler: { message in
            Task { @MainActor in self.receive(message, live: true) }
        }, errorHandler: { _ in })
    }
    func provision() {
        guard !granting, session.activationState == .activated, let c = Vault.load() else { return }
        // A credential is transferred only once per pairing. A relink request
        // explicitly resets this marker; routine wrist raises do no HA reads.
        let marker = "companionGranted." + c.watch_id
        guard !UserDefaults.standard.bool(forKey: marker) else { return }
        granting = true
        Task {
            defer { granting = false }
            do {
                var grant = try await Integration(c).request(["action": "companion_grant"])
                guard Vault.load()?.token == c.token else { return }
                grant["watch_id"] = c.watch_id
                let data = try JSONSerialization.data(withJSONObject: grant)
                _ = try JSONDecoder().decode(Connection.self, from: data).validated()
                session.transferUserInfo(["grant": data])
                UserDefaults.standard.set(true, forKey: marker)
            } catch { /* Companion can retry Link; direct watch commands remain independent. */ }
        }
    }
    private func receive(_ message: [String: Any], live: Bool = false) {
        WatchPodcast.shared.receive(message, live: live)
        if message["action"] as? String == "link", let c = Vault.load() {
            UserDefaults.standard.removeObject(forKey: "companionGranted." + c.watch_id); provision()
        }
        if let data = message["snapshot"] as? Data { applySnapshot(data) }
        if let raw = message["playlist"] as? Data,
           let manifest = try? JSONDecoder().decode(OfflinePlaylist.self, from: raw) {
            ExercisePlayer.shared.receive(manifest)
        }
    }
    private func applySnapshot(_ data: Data) {
        guard let snapshot = try? JSONDecoder().decode(CompanionSnapshot.self, from: data), let c = Vault.load() else { return }
            let key = "companionSequence." + c.watch_id
            guard snapshot.sequence > UserDefaults.standard.integer(forKey: key),
                  let next = try? snapshot.resolved(for: c),
                  (next.revision ?? 0) >= (c.revision ?? 0) else { return }
            do {
                ExercisePlayer.shared.stopIfTargetChanged(next)
                try Vault.save(next)
                for d in next.devices where !protectedEntities.contains(d.entity) {
                    if let raw = snapshot.states[d.entity], let state = try JSONSerialization.jsonObject(with: raw) as? [String: Any] {
                        ObservationCache.shared.save(state, connection: next, device: d)
                    }
                }
                UserDefaults.standard.set(snapshot.sequence, forKey: key)
                PushDiagnostics.shared.record("watch_saved", connection: next, updateID: snapshot.updateID)
                NotificationCenter.default.post(name: .companionSnapshotSaved, object: snapshot)
                session.transferUserInfo(["watch_saved": snapshot.sequence, "update_id": snapshot.updateID ?? "", "watch_id": c.watch_id])
            } catch { }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.receive(session.receivedApplicationContext); self.provision(); if WKExtension.shared().applicationState == .active { self.requestLatest() } }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { Task { @MainActor in self.receive(applicationContext) } }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) { Task { @MainActor in self.receive(userInfo) } }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { Task { @MainActor in self.receive(message, live: true) } }
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // The URL is temporary and must be copied before this delegate returns.
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.copyItem(at: file.fileURL, to: temporary)
            let metadata = file.metadata ?? [:]
            Task { @MainActor in ExercisePlayer.shared.receiveFile(temporary, metadata: metadata) }
        } catch { }
    }
}
