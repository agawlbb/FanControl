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
    let connection: Connection?
    @State private var events: [PushTraceEvent] = []
    @State private var commands: [String] = []
    @State private var reporting = false

    var body: some View {
        List {
            Section {
                Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                if let connection, !PushDiagnostics.shared.pending(connection).isEmpty {
                    Button {
                        guard !reporting else { return }
                        reporting = true
                        Task {
                            defer { reporting = false }
                            await PushDiagnostics.flush(connection)
                            refresh()
                        }
                    } label: {
                        HStack {
                            Label("Send reports", systemImage: "arrow.up.circle")
                            if reporting { Spacer(); ProgressView().frame(width: 16, height: 16) }
                        }
                    }.disabled(reporting)
                }
            }
            if commands.isEmpty && events.isEmpty {
                Text("No recent activity").foregroundStyle(.secondary)
            }
            if !commands.isEmpty {
                Section("Command activity") {
                    ForEach(Array(commands.enumerated()), id: \.offset) { _, command in
                        Text(command).font(.caption2.monospaced())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if !events.isEmpty {
                Section("Updates") {
                    ForEach(events.reversed()) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.phase.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.footnote)
                            Text(Date(timeIntervalSince1970: Double(event.at_ms) / 1000), format: .dateTime.month().day().hour().minute().second())
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Diagnostics")
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: .commandOutcomeSaved)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .companionSnapshotSaved)) { _ in refresh() }
    }

    private func refresh() {
        events = PushDiagnostics.shared.history(connection)
        commands = CommandDelivery.shared.diagnostics()
    }
}
