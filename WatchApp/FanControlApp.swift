import SwiftUI
import WatchKit
import UserNotifications
import FanControlCore

@main struct FanControlApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @WKApplicationDelegateAdaptor(PushNotifications.self) private var pushDelegate
    init() { UNUserNotificationCenter.current().delegate = CommandAlerts.shared; WatchCompanion.shared.start(); CommandDelivery.shared.recover() }
    var body: some Scene {
        WindowGroup {
            ControlsView().onChange(of: scenePhase) { _, phase in
                if phase != .active { CommandDelivery.shared.appInactive() }
            }
        }
            .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) { await BackgroundRefresh.run() }
    }
}
@MainActor final class WatchModel: ObservableObject {
    @Published var connection = Vault.load()
    @Published var observed: [String: Any] = [:]
    @Published var stateFresh = false
    @Published var feedback: Feedback?
    @Published private(set) var commandPending = false
    @Published var speedDraft: Int?
    @Published private var actionReceipts = ActionReceipts()
    private var work: Task<Void, Never>?
    private var command: Task<Void, Never>?
    private var vehicleIntent: (client: Integration, id: String, alert: String?)?
    private var activeIntent: (id: String, connection: Connection, device: Device, feedback: Feedback)?
    private var generation = UUID()
    private var visible = false
    private let defaultTile = DefaultWatchTile()
    private var wakeAfter: ContinuousClock.Instant?
    @Published private var sessionTarget: String?
    @Published private(set) var showingSettings = false
    var showingPodcast: Bool { sessionTarget == PodcastTile.id && !showingSettings }
    var device: Device? {
        guard !showingSettings, !showingPodcast else { return nil }
        return connection?.devices.first { $0.entity == (sessionTarget ?? connection?.entity) }
    }
    var busy: Bool { commandPending }
    var canAdjustSpeed: Bool { visible && device?.domain == "fan" && (!busy || feedback?.command == "turn_on" || feedback?.command.hasPrefix("speed") == true) }
    var displayedSpeed: Int {
        if let speedDraft { return speedDraft }
        if let command = feedback?.command, command.hasPrefix("speed"), let value = Int(command.dropFirst(5)) { return value }
        let percentage = (observed["attributes"] as? [String: Any])?["percentage"] as? Int ?? 16
        return Evidence.percentages.firstIndex(where: { $0 >= percentage }).map { $0 + 1 } ?? 6
    }
    func leave(resetReceipts: Bool = true) {
        if resetReceipts { actionReceipts.clear() }
        if showingPodcast { WatchPodcast.shared.leave() }
        visible = false; generation = UUID(); work?.cancel(); command?.cancel(); speedDraft = nil
        commandPending = false; activeIntent = nil
        if feedback?.phase == .pending { feedback?.phase = .unconfirmed }
        stateFresh = false
    }
    func enter(resetSelection: Bool = true, allowEntryWake: Bool = true) {
        // A refresh launch can instantiate the view without user-visible entry.
        guard WKExtension.shared().applicationState == .active else { return }
        leave(resetReceipts: resetSelection); visible = true
        if resetSelection { WatchCompanion.shared.beginEntry(); connection = Vault.load(); sessionTarget = connection.flatMap { defaultTile.load($0) }; showingSettings = false; feedback = nil; wakeAfter = nil }
        // Migrate older unlocked-only keychain entries before the next wrist-down push.
        if let connection { try? Vault.save(connection) }
        if let connection, resetSelection {
            PushDiagnostics.shared.record("opened", connection: connection)
            CommandDelivery.shared.foregroundEntry()
            Task {
                await CommandAlerts.shared.recover()
                await CommandAlerts.shared.prepareNotifications()
            }
        }
        observed = connection.flatMap { c in device.map { ObservationCache.shared.load(c, $0) } } ?? [:]
        if showingPodcast { WatchPodcast.shared.enter(); return }
        WatchCompanion.shared.requestLatest()
        // Settings is local navigation, with no device reads, entry wake or controls.
        if showingSettings { observed = [:]; return }
        #if DEBUG
        if let preview = ControlPreview.snapshot() {
            connection = preview.0; observed = preview.1; stateFresh = true
            #if targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("--preview-exercise") {
                ExercisePlayer.shared.preview(playing: ProcessInfo.processInfo.arguments.contains("--preview-playing"))
            }
            #endif
            if ProcessInfo.processInfo.arguments.contains("--preview-pending") {
                feedback = Feedback(target: preview.0.identity, command: "climate_off", label: "Climate OFF")
            }
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--preview-settings") { showingSettings = true; observed = [:]; return }
            if args.contains("--preview-action-pending") || args.contains("--preview-action-accepted") {
                let action = args.contains("--preview-exercise") ? "start_exercise" : "honk"
                let f = Feedback(target: preview.0.watch_id + "|panel.preview", command: action, label: "Activated")
                actionReceipts.begin(f)
                if args.contains("--preview-action-accepted") { actionReceipts.finish(f, accepted: true) }
                else { feedback = f }
            }
            return
        }
        #endif
        guard let connection else { return }
        if let d = device { resumeCommand(connection, d) }
        let ticket = generation
        let entryID = UUID().uuidString.lowercased()
        let vehicleEntry = allowEntryWake && device?.panel?.vehicle == true
        if vehicleEntry { CommandDelivery.shared.trace(entryID, "entry_displayed") }
        work = Task {
            defer { if vehicleEntry { CommandDelivery.shared.trace(entryID, Task.isCancelled ? "entry_cancelled" : "entry_finished") } }
            if let deadline = wakeAfter {
                do { try await Task.sleep(until: deadline, clock: .continuous) } catch { return }
            }
            guard !Task.isCancelled, ticket == generation, visible, let d = device else { return }
            let client = Integration(connection)
            if d.panel?.vehicle != true {
                // Refresh the displayed nonvehicle target once, even without a phone
                // or a command tap. A passive cache alone is never fresh evidence.
                guard feedback == nil, speedDraft == nil else { return }
                do {
                    guard let state = try await VisibleStateRefresh.read(d, using: { try await client.request($0) }),
                          !Task.isCancelled, ticket == generation, visible,
                          let current = self.connection, current.watch_id == connection.watch_id, current.token == connection.token,
                          device?.sameCommandTarget(as: d) == true, feedback == nil, speedDraft == nil else { return }
                    stateFresh = VisibleStateRefresh.available(state, for: d)
                    if stateFresh {
                        observed = state
                        ObservationCache.shared.save(state, connection: current, device: d)
                    }
                } catch {
                    // Keep the saved observation gray. Never affect a later command
                    // or another screen, and never turn this read into a retry loop.
                }
                return
            }
            guard allowEntryWake, let p = d.panel, p.vehicle else { return }
            let id = entryID
            let issued = Int(Date().timeIntervalSince1970 * 1000)
            CommandDelivery.shared.trace(id, "entry_displayed_settled")
            var body = panelBody(p, command: "wake")
            body["action"] = "operation_submit"; body["operation_id"] = id; body["issued_at_ms"] = issued
            do {
                let state = try await client.request(body)
                guard state["operation_id"] as? String == id else { return }
                CommandDelivery.shared.trace(id, "entry_ack_received")
                guard visible, ticket == generation, !Task.isCancelled,
                      device?.sameCommandTarget(as: d) == true else { return }
                if state["observation_fresh"] as? Bool == true {
                    observed = state; stateFresh = true
                    ObservationCache.shared.save(state, connection: connection, device: d)
                }
            } catch { /* Entry wake is best effort; HA owns accepted execution. */ }
        }
    }

    func swipe(_ direction: Int) {
        guard let c = connection else { return }
        let current: WatchPage = showingSettings ? .settings : showingPodcast ? .podcast : .device(sessionTarget ?? c.entity)
        let index = UserDefaults.standard.object(forKey: "podcastIndex") as? Int
        let order = PodcastTile.order(devices: (c.companion_settings ?? CompanionSettings()).ordered(c.devices.map(\.entity)), index: index)
        let next = WatchPage.next(current, entities: order, direction: direction)
        leave(resetReceipts: false); observed = [:]; feedback = nil
        switch next {
        case .settings: showingSettings = true
        case .podcast:
            showingSettings = false; sessionTarget = PodcastTile.id
            defaultTile.save(PodcastTile.id, connection: c)
        case .device(let entity):
            showingSettings = false; sessionTarget = entity
            defaultTile.save(entity, connection: c)
        }
        wakeAfter = .now.advanced(by: .milliseconds(1500))
        enter(resetSelection: false)
    }
    func openPodcast() {
        guard visible, !busy else { return }
        leave(resetReceipts: false); observed = [:]; feedback = nil
        showingSettings = false; sessionTarget = PodcastTile.id; visible = true
        WatchPodcast.shared.enter(play: true)
    }
    private func panelBody(_ p: Panel, command: String? = nil) -> [String: Any] {
        var body: [String: Any] = ["action": command == nil ? "panel_state" : "panel_command", "panel_id": p.id]
        if p.type == "exercise" { body["music_mode"] = "local" }
        if let command { body["command"] = command; body["panel_config"] = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) }
        return body
    }
    func actionFeedback(_ action: String) -> Feedback? {
        guard let c = connection, let d = device else { return nil }
        return actionReceipts.feedback(target: c.watch_id + "|" + d.entity, command: action)
    }
    func adjust(_ delta: Int) {
        guard canAdjustSpeed else { return }
        let speed = min(6, max(1, displayedSpeed + delta))
        speedDraft = speed
        // HA owns the quiet window too: a saved request cannot vanish on wrist-down.
        send("speed\(speed)", label: "Speed \(speed)", quietWindow: true)
    }
    func send(_ action: String, label: String, quietWindow: Bool = false) {
        let replacing = busy && (ToggleIntent.replaces(action, feedback?.command) || quietWindow)
        guard (!busy || replacing), visible, let c = connection, let d = device else { return }
        WatchCompanion.shared.protectIntent(d.entity)
        command?.cancel()
        if !quietWindow { speedDraft = nil }
        let f = Feedback(target: ActionReceipts.applies(action) ? c.watch_id + "|" + d.entity : c.identity,
                         command: action, label: RequestedPresentation.label(command: action, original: label))
        feedback = f; commandPending = true
        if ActionReceipts.applies(action) { actionReceipts.begin(f) }
        if action == "start_exercise" { ExercisePlayer.shared.start(c, target: d) }
        if action == "stop_exercise" { ExercisePlayer.shared.stop() }
        var body = d.panel.map { panelBody($0, command: action) } ?? ["entity": d.entity, "command": action]
        let identity = UUID().uuidString.lowercased()
        let issued = Int(Date().timeIntervalSince1970 * 1000)
        body["action"] = "operation_submit"; body["operation_id"] = identity; body["issued_at_ms"] = issued
        if quietWindow { body["not_before_ms"] = issued + 1000 }
        do { try CommandDelivery.shared.enqueue(body, connection: c, device: d) }
        catch {
            feedback?.phase = .unconfirmed; commandPending = false
            if ActionReceipts.applies(f.command) { actionReceipts.finish(f, accepted: false) }
            CommandAlerts.shared.outcome(identity, state: ["operation_id": identity, "operation_status": "failed", "local_error": true])
            return
        }
        monitor(identity, body: body, connection: c, device: d, feedback: f)
    }
    private func monitor(_ identity: String, body: [String: Any], connection c: Connection, device d: Device, feedback f: Feedback) {
        activeIntent = (identity, c, d, f)
        commandPending = true
        // Only listen for the upload receipt. No second submission or status polling.
        refreshCommandOutcome(identity)
    }
    func refreshCommandOutcome(_ id: String) {
        guard visible, let intent = activeIntent, intent.id == id,
              let c = connection, c.watch_id == intent.connection.watch_id, c.token == intent.connection.token,
              let current = device, current.sameCommandTarget(as: intent.device), feedback?.id == intent.feedback.id,
              let entry = CommandDelivery.shared.record(id), let data = entry.result,
              let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              state["operation_id"] as? String == id else { return }
        let status = state["operation_status"] as? String ?? "unknown"
        let acknowledgedAt = CommandDelivery.shared.record(id)?.timings?["ack_received"]
            .map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
        if CommandPolicy.owns(state), !entry.acknowledgedDuringHandoff {
            // Save late evidence and clear alerts without replaying expired UI feedback.
            actionReceipts.remove(intent.feedback)
            commandPending = false; feedback = nil; activeIntent = nil
            return
        }
        if CommandPolicy.owns(state) {
            if feedback?.phase != .accepted { CommandDelivery.shared.trace(id, "ack_displayed") }
            feedback?.phase = .accepted; speedDraft = nil
            if ActionReceipts.applies(intent.feedback.command) { actionReceipts.finish(intent.feedback, accepted: true, now: acknowledgedAt) }
        } else if ["failed", "unconfirmed", "cancelled"].contains(status) {
            feedback?.phase = .unconfirmed
            if ActionReceipts.applies(intent.feedback.command) { actionReceipts.finish(intent.feedback, accepted: false) }
        }
        // Acknowledgment ends watch responsibility, even while HA is still waking.
        commandPending = false
        let f = intent.feedback
        if ActionReceipts.applies(f.command) {
            if CommandPolicy.owns(state) {
                Task { [weak self] in
                    let remaining = max(0, acknowledgedAt.addingTimeInterval(ActionReceipts.acceptedSeconds).timeIntervalSinceNow)
                    try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                    guard let self else { return }
                    self.actionReceipts.remove(f)
                    if self.feedback?.id == f.id { self.feedback = nil; self.activeIntent = nil }
                }
            } else {
                feedback = nil; activeIntent = nil
            }
        } else {
            activeIntent = nil
        }
        // Subsequent HA execution/failure events must not restart receipt UI.
        activeIntent = nil
        if state["observation_fresh"] as? Bool == true {
            observed = state; stateFresh = true
            ObservationCache.shared.save(state, connection: c, device: current)
        }
    }
    private func resumeCommand(_ c: Connection, _ d: Device) {
        guard let entry = CommandDelivery.shared.pending(connection: c, device: d),
              let body = try? JSONSerialization.jsonObject(with: entry.body) as? [String: Any],
              let action = body["command"] as? String else { return }
        let recentActionReceipt = ActionReceipts.applies(action) && entry.showsActionReceipt()
        guard entry.awaitingHandoff() || recentActionReceipt else { return }
        let label = action.hasPrefix("garage_") ? "Garage"
            : action.hasPrefix("trunk_") ? "Trunk"
            : action.hasPrefix("speed") ? "Speed " + String(action.dropFirst(5)) : "Run"
        let f = Feedback(target: ActionReceipts.applies(action) ? c.watch_id + "|" + d.entity : c.identity,
                         command: action, label: RequestedPresentation.label(command: action, original: label))
        feedback = f
        if ActionReceipts.applies(action) { actionReceipts.begin(f) }
        monitor(entry.id, body: body, connection: c, device: d, feedback: f)
    }
    func cancel() {
        if let intent = vehicleIntent {
            Task { _ = try? await intent.client.request(["action": "operation_cancel", "operation_id": intent.id]) }
        }
        command?.cancel(); speedDraft = nil
        if let intent = activeIntent { CommandAlerts.shared.clear(intent.id) }
        if busy { feedback?.phase = .unconfirmed }; commandPending = false
    }
    func receiveCompanion(_ snapshot: CompanionSnapshot?) {
        guard let saved = Vault.load() else { return }
        // Invalidate older navigation even when a command defers visible selection.
        _ = defaultTile.load(saved)
        // Persisted snapshots can arrive during a command. Never clear or
        // recolor that intent; apply selection on its next safe entry.
        guard feedback == nil, speedDraft == nil else { return }
        if showingPodcast, connection?.sameTarget(as: saved) == true, connection?.revision == saved.revision {
            connection = saved
            return
        }
        let prior = device
        let nextEntity = sessionTarget ?? saved.entity
        let next = saved.devices.first { $0.entity == nextEntity }
        let same = prior.flatMap { old in next.map { old.sameCommandTarget(as: $0) } } ?? false
        let selectedChanged = connection?.entity != saved.entity
        connection = saved
        if !same || selectedChanged {
            enter(resetSelection: true, allowEntryWake: visible)
        } else if visible, let d = device, d.panel?.type == "on_duty" {
            observed = ObservationCache.shared.load(saved, d)
            stateFresh = false
            if let snapshot, let source = try? snapshot.resolved(for: saved), source.sameTarget(as: saved),
               let raw = snapshot.states[d.entity],
               let state = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
               VisibleStateRefresh.available(state, for: d) {
                observed = state
                stateFresh = true
            }
        } else if !stateFresh, let d = device {
            observed = ObservationCache.shared.load(saved, d)
            // A passive snapshot cannot cancel the active entry coordinator or confirm a command.
        }
    }

    func paired(_ value: Connection) { if connection?.watch_id != value.watch_id || connection?.token != value.token { CommandDelivery.shared.clear(); WatchPodcast.shared.clear() }; connection = value; WatchCompanion.shared.provision(); enter() }
    func forget() { WatchPodcast.shared.clear(); CommandDelivery.shared.clear(); defaultTile.clear(); leave(); showingSettings = false; sessionTarget = nil; ExercisePlayer.shared.forget(); ObservationCache.shared.clear(); PushDiagnostics.shared.clear(); Vault.clear(); connection = nil; observed = [:]; feedback = nil }
}





