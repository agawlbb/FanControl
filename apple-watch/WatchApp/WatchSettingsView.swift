import SwiftUI
import FanControlCore

// The long-press sheet and settings preview share one native watch layout.
struct WatchSettingsView: View {
    @ObservedObject var model: WatchModel
    @ObservedObject private var player = ExercisePlayer.shared
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var pairingStatus = ""
    @State private var pairing: Task<Void, Never>?
    @State private var pairingID: UUID?
    @State private var connectionCheck: Task<Void, Never>?
    @State private var connectionResult = ""
    @State private var confirmForget = false

    var body: some View {
        NavigationStack {
            List {
                if let connection = model.connection {
                    Section("Connection") {
                        Button(action: testConnection) {
                            HStack {
                                Label("Test connection", systemImage: "network")
                                if connectionCheck != nil { Spacer(); ProgressView().frame(width: 16, height: 16) }
                            }
                        }.disabled(connectionCheck != nil)
                        if !connectionResult.isEmpty {
                            Text(connectionResult).font(.footnote).foregroundStyle(.secondary)
                        }
                        NavigationLink("Connection details") {
                            List {
                                Section("Server") {
                                    Text(connection.remote_url.flatMap { $0.isEmpty ? nil : $0 } ?? "Not configured")
                                        .font(.caption2).fixedSize(horizontal: false, vertical: true)
                                }
                                Section("Watch ID") {
                                    Text(connection.watch_id).font(.caption2.monospaced())
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }.navigationTitle("Connection")
                        }
                    }
                    Section("Exercise music") {
                        Button {
                            player.sync(connection)
                        } label: {
                            HStack {
                                Label("Sync music", systemImage: "arrow.triangle.2.circlepath")
                                if player.syncing { Spacer(); ProgressView().frame(width: 16, height: 16) }
                            }
                        }.disabled(player.syncing)
                        if !player.syncFeedback.message.isEmpty {
                            Text(player.syncFeedback.message).font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Section {
                        NavigationLink {
                            PushDiagnosticsView(connection: connection)
                        } label: {
                            Label("Diagnostics", systemImage: "waveform.path.ecg")
                        }
                    }
                    Section {
                        Button("Forget connection", role: .destructive) { confirmForget = true }
                    }
                } else {
                    Section("Home Assistant") {
                        TextField("https://home.example", text: $address)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .disabled(pairing != nil)
                        Button(pairing == nil ? "Pair watch" : "Cancel pairing", action: pair)
                            .disabled(pairing == nil && address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if !pairingStatus.isEmpty {
                            Text(pairingStatus).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Link("Source & license", destination: URL(string: "https://github.com/agawlbb/FanControlWatch")!)
                        .font(.footnote)
                } footer: {
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"))")
                        .font(.caption2)
                }
            }
            .navigationTitle(model.connection == nil ? "Connect" : "Settings")
            .tint(.mint)
            .alert("Forget connection?", isPresented: $confirmForget) {
                Button("Forget connection", role: .destructive) { model.forget(); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Pairing and downloaded music will be removed.")
            }
        }
        .onDisappear { pairingID = nil; pairing?.cancel(); pairing = nil; connectionCheck?.cancel(); connectionCheck = nil }
    }

    private func testConnection() {
        guard connectionCheck == nil, let original = model.connection else { return }
        connectionResult = ""
        connectionCheck = Task {
            let result: String
            do {
                _ = try original.remoteAddress()
                let response = try await Integration(original).request(["action": "config"])
                guard response["devices"] is [[String: Any]], response["entity"] is String else {
                    throw ControlError.invalidResponse
                }
                result = "Connected to Home Assistant."
            } catch { result = ConnectionCheck.failureMessage(error) }
            guard !Task.isCancelled else { return }
            connectionCheck = nil
            guard model.connection?.sameTarget(as: original) == true else { return }
            connectionResult = result
        }
    }

    private func pair() {
        if let pairing {
            pairingID = nil; pairing.cancel(); self.pairing = nil; pairingStatus = "Pairing cancelled"
            return
        }
        let enteredAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let ticket = UUID(); pairingID = ticket
        pairingStatus = ""
        pairing = Task {
            defer { if pairingID == ticket { pairing = nil; pairingID = nil } }
            do {
                let connection = try await Pairing().run(address: enteredAddress) {
                    if pairingID == ticket, !Task.isCancelled { pairingStatus = $0 }
                }
                guard !Task.isCancelled, pairingID == ticket else { return }
                model.paired(connection); dismiss()
            } catch {
                if !Task.isCancelled, pairingID == ticket { pairingStatus = "Pairing failed." }
            }
        }
    }
}
