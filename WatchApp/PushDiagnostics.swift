import SwiftUI
import FanControlCore

@MainActor enum PushDiagnostics {
    static let shared = PushTrace()
    private static var sending = false
    static func flush(_ connection: Connection, client supplied: Integration? = nil) async {
        guard !sending, Vault.load() == connection else { return }
        sending = true; defer { sending = false }
        let client = supplied ?? Integration(connection)
        // Bounded; a later opening/refresh resumes remaining receipts.
        for _ in 0..<10 {
            let events = shared.pending(connection)
            guard !events.isEmpty, Vault.load() == connection, !Task.isCancelled,
                  let data = try? JSONEncoder().encode(events),
                  let body = try? JSONSerialization.jsonObject(with: data) else { return }
            do {
                let response = try await client.request(["action": "push_receipts", "events": body])
                guard Vault.load() == connection, let ids = response["recorded"] as? [String] else { return }
                let discarded = response["discarded"] as? [String] ?? []
                shared.acknowledge(Set(ids + discarded), connection: connection)
                if ids.isEmpty && discarded.isEmpty { return }
            } catch { return } // Keep the original event IDs/times for the next attempt.
        }
    }
}

struct PushDiagnosticsView: View {
    @ObservedObject private var player = ExercisePlayer.shared
    let connection: Connection?
    @State private var events: [PushTraceEvent] = []
    @State private var commands: [String] = []
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Diagnostics").font(.headline)
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"))").font(.caption2)
                if !player.syncFeedback.history.isEmpty {
                    Text("Music sync").font(.headline)
                    Text(player.syncFeedback.message).font(.caption2)
                    ForEach(Array(player.syncFeedback.history.enumerated()), id: \.offset) { _, message in Text(message).font(.caption2) }
                }
                Text("Command receipt and notification times are separate from vehicle completion.").font(.caption)
                Button("Refresh diagnostics") {
                    Task {
                        await CommandAlerts.shared.recover()
                        events = PushDiagnostics.shared.history(connection)
                        commands = CommandDelivery.shared.diagnostics()
                    }
                }
                Button("Report pending receipts") {
                    Task {
                        if let connection { await PushDiagnostics.flush(connection) }
                        events = PushDiagnostics.shared.history(connection)
                    }
                }
                if !commands.isEmpty {
                    Text("Command timings").font(.headline)
                    ForEach(Array(commands.enumerated()), id: \.offset) { item in Text(item.element).font(.caption2) }
                }
                if commands.isEmpty { Text("No saved command timings.").font(.caption2) }
                ForEach(events.reversed()) { event in
                    VStack(alignment: .leading) {
                        Text(event.phase.replacingOccurrences(of: "_", with: " "))
                        Text(Date(timeIntervalSince1970: Double(event.at_ms) / 1000), style: .time)
                        Text(event.update_id ?? "No correlated push")
                        if !event.panel.isEmpty { Text(event.panel) }
                        if let revision = event.revision { Text("Revision \(revision)") }
                        Text(event.reported ? "Reported to HA" : "Stored on watch")
                    }.font(.caption2)
                    Divider()
                }
            }
        }.onAppear { events = PushDiagnostics.shared.history(connection); commands = CommandDelivery.shared.diagnostics() }
    }
}
