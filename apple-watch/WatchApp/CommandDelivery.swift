import Foundation
import WatchKit
import FanControlCore
import OSLog

extension Notification.Name { static let commandOutcomeSaved = Notification.Name("commandOutcomeSaved") }

// The keychain outbox owns intent until HA acknowledges durable acceptance.
// Foreground HTTPS submits immediately; background continuation preserves the same intent.
@MainActor final class CommandDelivery: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    static let shared = CommandDelivery()
    static let sessionID = "dev.fancontrol.watch.command-delivery"
    typealias Entry = CommandRecord
    private let logger = Logger(subsystem: "dev.fancontrol.watch", category: "command-delivery")
    private var entries: [String: Entry] = [:]
    private let foregroundHTTP = HTTP()
    private var foregroundTasks: [String: Task<Void, Never>] = [:]
    private var buffers: [Int: Data] = [:]
    private var backgroundTasks: [WKURLSessionRefreshBackgroundTask] = []
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionID)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.timeoutIntervalForRequest = Connection.handoffSeconds
        config.timeoutIntervalForResource = Connection.handoffSeconds
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()
    override init() {
        super.init()
        if let data = SecureCommandStorage.load(), let saved = try? JSONDecoder().decode([String: Entry].self, from: data) { entries = saved }
    }
    func trace(_ id: String, _ phase: String, at: Date = Date()) {
        entries[id]?.mark(phase, at: at)
        try? save()
        var events = UserDefaults.standard.array(forKey: "commandTimingEvents") as? [[String: String]] ?? []
        events.append(["id": id, "phase": phase, "at": String(at.timeIntervalSince1970 * 1000)])
        UserDefaults.standard.set(Array(events.suffix(100)), forKey: "commandTimingEvents")
        logger.info("operation=\(id, privacy: .public) phase=\(phase, privacy: .public)")
    }
    func foregroundEntry() {
        for entry in entries.values where entry.matchesCurrentTarget(Vault.load()) {
            trace(entry.id, "app_foreground")
        }
    }
    func diagnostics() -> [String] {
        let events = UserDefaults.standard.array(forKey: "commandTimingEvents") as? [[String: String]] ?? []
        func stamp(_ ms: Double) -> String { Date(timeIntervalSince1970: ms / 1000).formatted(date: .abbreviated, time: .standard) }
        var result = events.reversed().map {
            ($0["id"] ?? "") + " " + ($0["phase"] ?? "") + " " + (Double($0["at"] ?? "").map(stamp) ?? "")
        }
        for entry in entries.values.sorted(by: { $0.issued > $1.issued }) {
            guard entry.matchesCurrentTarget(Vault.load()) else { continue }
            let body = (try? JSONSerialization.jsonObject(with: entry.body)) as? [String: Any]
            result.append(entry.id + " " + (body?["command"] as? String ?? "Command"))
            for (phase, at) in (entry.timings ?? [:]).sorted(by: { $0.value < $1.value }) {
                result.append(phase + " " + stamp(at))
            }
            if let data = entry.result, let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                result.append("Saved result: " + (state["operation_status"] as? String ?? "unknown"))
                if let timing = state["timing"] as? [String: Any] {
                    // Only known numeric timing fields; never display arbitrary server text.
                    for (phase, at) in timing.sorted(by: { $0.key < $1.key }) where phase.hasSuffix("_ms") {
                        if let ms = at as? Double { result.append("HA " + phase + " " + stamp(ms)) }
                    }
                }
            }
        }
        return result
    }
    private func save() throws { try SecureCommandStorage.save(JSONEncoder().encode(entries)) }
    func enqueue(_ body: [String: Any], connection: Connection, device: Device) throws {
        guard let id = body["operation_id"] as? String, let issued = body["issued_at_ms"] as? Int else { throw ControlError.invalidConfiguration }
        let previous = entries
        let replaced = entries.values.filter { $0.entity == device.entity && $0.connection.watch_id == connection.watch_id }.map(\.id)
        entries = entries.filter { Date().timeIntervalSince($0.value.issued) < 600 }
        entries = entries.filter { $0.value.entity != device.entity || $0.value.connection.watch_id != connection.watch_id }
        // Retain only the latest intent for each target; never recover superseded work.
        entries[id] = Entry(id: id, connection: connection, entity: device.entity, body: try JSONSerialization.data(withJSONObject: body), issued: Date(timeIntervalSince1970: Double(issued) / 1000))
        entries[id]?.timings = ["tap": Double(issued)]
        entries[id]?.mark("saved")
        do { try save() } catch { entries = previous; throw error }
        for id in replaced {
            foregroundTasks.removeValue(forKey: id)?.cancel()
            CommandAlerts.shared.clear(id)
        }
        if WKExtension.shared().applicationState == .active { submitForeground(id) }
        else { continueInBackground(id) }
        expireAfterHandoff(id)
    }
    private func submitForeground(_ id: String) {
        guard let entry = entries[id], entry.awaitingHandoff(),
              entry.matchesCurrentTarget(Vault.load()),
              let body = (try? JSONSerialization.jsonObject(with: entry.body)) as? [String: Any] else { return }
        trace(id, "foreground_submit")
        foregroundTasks[id] = Task { [weak self] in
            guard let self else { return }
            defer { self.foregroundTasks.removeValue(forKey: id) }
            do {
                let state = try await Integration(entry.connection, http: self.foregroundHTTP).request(body)
                guard !Task.isCancelled else { return }
                self.outcome(id, state: state)
                if self.entries[id]?.awaitingHandoff() == true { self.continueInBackground(id) }
            } catch {
                guard !Task.isCancelled, self.entries[id]?.awaitingHandoff() == true else { return }
                let code = (error as NSError).code
                self.trace(id, "foreground_error_" + String(code))
                self.continueInBackground(id)
            }
        }
    }
    // Called on wrist-down/app inactivity, independently of page navigation.
    func appInactive() {
        for id in Array(foregroundTasks.keys) { continueInBackground(id) }
    }
    private func continueInBackground(_ id: String) {
        guard var entry = entries[id], entry.matchesCurrentTarget(Vault.load()),
              entry.beginBackgroundContinuation() else { return }
        entries[id] = entry
        do { try save() } catch { rejected(id); return }
        trace(id, "background_continuation")
        do { try upload(id) }
        catch {
            trace(id, "background_setup_error_" + String((error as NSError).code))
            if foregroundTasks[id] == nil { rejected(id) }
        }
    }
    private func upload(_ id: String) throws {
        guard let entry = entries[id], entry.awaitingHandoff(),
              let current = Vault.load(), current.watch_id == entry.connection.watch_id, current.token == entry.connection.token,
              let body = try JSONSerialization.jsonObject(with: entry.body) as? [String: Any] else { return }
        entries[id]?.mark("remote_upload")
        try? save()
        logger.info("operation=\(id, privacy: .public) upload=remote")
        let packet = try CommandEnvelope.prepare(body, connection: entry.connection)
        var request = URLRequest(url: try entry.connection.remoteAddress().appendingPathComponent("api/fan_control/watch/request"))
        request.timeoutInterval = max(0.1, Connection.handoffSeconds - Date().timeIntervalSince(entry.issued))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("command-" + UUID().uuidString)
        try JSONSerialization.data(withJSONObject: packet.packet).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        let task = session.uploadTask(with: request, fromFile: file)
        task.taskDescription = [id, packet.aad, "remote", file.path].joined(separator: "|")
        task.resume()
    }
    private func expireAfterHandoff(_ id: String) {
        guard let entry = entries[id], !entry.accepted, entry.result == nil else { return }
        let remaining = max(0, Connection.handoffSeconds - Date().timeIntervalSince(entry.issued))
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            self?.rejected(id)
        }
    }
    func clear() {
        for id in entries.keys { CommandAlerts.shared.clear(id) }
        UserDefaults.standard.removeObject(forKey: "commandTimingEvents")
        for task in foregroundTasks.values { task.cancel() }
        foregroundTasks.removeAll()
        entries.removeAll(); SecureCommandStorage.clear()
        session.getAllTasks { tasks in for task in tasks { task.cancel() } }
    }
    func recover() {
        _ = session
        Task { await CommandAlerts.shared.recover() }
        session.getAllTasks { tasks in
            let active = Set(tasks.compactMap { $0.taskDescription?.components(separatedBy: "|").first })
            Task { @MainActor in
                for task in tasks {
                    let parts = (task.taskDescription ?? "").components(separatedBy: "|")
                    guard let id = parts.first, let entry = self.entries[id],
                          entry.awaitingHandoff(), parts.count == 4, parts[2] == "remote",
                          task.originalRequest?.url == (try? entry.connection.remoteAddress().appendingPathComponent("api/fan_control/watch/request")) else {
                        task.cancel(); continue
                    }
                }
                for entry in self.entries.values where !entry.accepted && entry.result == nil {
                    if Date().timeIntervalSince(entry.issued) >= Connection.handoffSeconds {
                        self.rejected(entry.id)
                    } else {
                        // Never resubmit an ambiguously delivered command on reopening.
                        if !active.contains(entry.id) && self.foregroundTasks[entry.id] == nil { self.rejected(entry.id) }
                        else { self.expireAfterHandoff(entry.id) }
                    }
                }
            }
        }
    }
    func outcome(_ id: String, state: [String: Any]) {
        guard var entry = entries[id], entry.matchesCurrentTarget(Vault.load()), state["operation_id"] as? String == id else { return }
        guard CommandPolicy.accept(state, id: id, previous: entry.result) else { return }
        entry.accepted = CommandPolicy.owns(state)
        entry.mark(entry.accepted ? "ack_received" : "handoff_failed")
        entry.result = try? JSONSerialization.data(withJSONObject: state)
        entries[id] = entry
        if entry.accepted { foregroundTasks[id]?.cancel() }
        trace(id, entry.accepted ? (entry.acknowledgedDuringHandoff ? "receipt_saved" : "late_receipt_saved") : "failure_saved")
        CommandAlerts.shared.outcome(id, state: state)
        logger.info("operation=\(id, privacy: .public) status=\(state["operation_status"] as? String ?? "unknown", privacy: .public)")
        NotificationCenter.default.post(name: .commandOutcomeSaved, object: id)
    }
    func record(_ id: String) -> Entry? { entries[id] }
    func alertRecords() -> [Entry] { Array(entries.values) }
    func reconcile(_ id: String) async {
        guard let entry = entries[id], let current = Vault.load(), current.watch_id == entry.connection.watch_id,
              current.token == entry.connection.token else { return }
        if let state = try? await Integration(entry.connection).request(["action": "operation_status", "operation_id": id]) {
            outcome(id, state: state)
        }
    }
    func rejected(_ id: String) {
        guard entries[id]?.accepted == false, entries[id]?.result == nil else { return }
        foregroundTasks.removeValue(forKey: id)?.cancel()
        outcome(id, state: ["operation_id": id, "operation_status": "failed", "reason": "Request rejected", "local_error": true])
        session.getAllTasks { tasks in
            for task in tasks where task.taskDescription?.components(separatedBy: "|").first == id { task.cancel() }
        }
    }
    func pending(connection: Connection, device: Device) -> Entry? {
        entries.values.filter { $0.connection.watch_id == connection.watch_id && $0.connection.token == connection.token && $0.entity == device.entity && Date().timeIntervalSince($0.issued) < 600 }.max { $0.issued < $1.issued }
    }
    func reconnect(_ task: WKURLSessionRefreshBackgroundTask) {
        backgroundTasks.append(task)
        _ = session
    }
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        MainActor.assumeIsolated {
            if (self.buffers[dataTask.taskIdentifier]?.count ?? 0) + data.count <= 262144 { self.buffers[dataTask.taskIdentifier, default: Data()].append(data) }
        }
    }
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        MainActor.assumeIsolated {
            let parts = (task.taskDescription ?? "").components(separatedBy: "|")
            guard parts.count == 4 else { return }
            let data = self.buffers.removeValue(forKey: task.taskIdentifier) ?? Data()
            try? FileManager.default.removeItem(atPath: parts[3])
            guard let entry = self.entries[parts[0]] else { return }
            let code = (task.response as? HTTPURLResponse)?.statusCode ?? 0
            if error == nil, (200..<300).contains(code), let result = try? CommandEnvelope.response(data, connection: entry.connection, aad: parts[1]) {
                // The UI deadline never invalidates authenticated receipt evidence.
                // Outcome policy still rejects wrong targets and stale terminal regressions.
                self.outcome(entry.id, state: result)
                if !CommandPolicy.owns(result), self.entries[entry.id]?.result == nil { self.rejected(entry.id) }
            } else {
                self.trace(entry.id, "background_error_http_" + String(code) + "_code_" + String((error as NSError?)?.code ?? 0))
                // A failed continuation cannot override a foreground receipt still in flight.
                if self.foregroundTasks[entry.id] == nil { self.rejected(entry.id) }
            }
        }
    }
    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        MainActor.assumeIsolated {
            let tasks = self.backgroundTasks; self.backgroundTasks.removeAll()
            for task in tasks { task.setTaskCompletedWithSnapshot(false) }
        }
    }
}
