import SwiftUI
import AVFoundation
import CryptoKit
import WatchKit
import WatchConnectivity
import FanControlCore

// The player belongs to the process, not the visible panel. Wrist-down and panel
// navigation must not destroy ongoing audio. No HA/vehicle result confirms music.
@MainActor final class ExercisePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = ExercisePlayer()
    @Published private(set) var playing = false
    @Published private(set) var beganPlayback = false
    @Published private(set) var waiting = false
    @Published private(set) var syncing = false
    private var musicTask: Task<Void, Never>?
    private var syncRequestID: UUID?
    private var syncAttempt: MusicSyncAttempt?
    private var syncConnection: Connection?
    private var syncRequestTimeout: Task<Void, Never>?
    private var musicPlaylist: UUID?
    @Published private(set) var status = ""
    @Published private(set) var syncFeedback = MusicSyncFeedback() {
        didSet {
            guard syncFeedback != oldValue, syncFeedback.phase != .receiving, let feedbackLocation,
                  let data = try? JSONEncoder().encode(syncFeedback) else { return }
            try? FileManager.default.createDirectory(at: feedbackLocation.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: feedbackLocation, options: .atomic)
        }
    }
    private var feedbackLocation: URL?
    private func syncScope(_ c: Connection) {
        let file = root(c).appendingPathComponent("sync-feedback.json")
        guard feedbackLocation != file else { return }
        feedbackLocation = nil
        syncFeedback = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(MusicSyncFeedback.self, from: $0) } ?? MusicSyncFeedback()
        feedbackLocation = file
    }
    private func failTransfer(_ id: UUID, connection c: Connection, stage: String, error: Error) {
        syncFeedback.fail(id, message: MusicSyncFeedback.failure(stage: stage, error: error))
        guard syncFeedback.id == id, syncFeedback.phase == .failed else { return }
        let report: [String: Any] = ["music_sync_failure": id.uuidString, "reason": syncFeedback.message, "watch_id": c.watch_id]
        WCSession.default.transferUserInfo(report)
        if WCSession.default.isReachable { WCSession.default.sendMessage(report, replyHandler: { _ in }, errorHandler: { _ in }) }
    }
    private var player: AVAudioPlayer?
    private var tracks: [ExerciseTrack] = []
    private var index = 0
    private var folder: URL?
    private var scope: String?
    private var reloadLibrary = false
    private var sessionTarget: Device?
    private var active = false
    private var wantsPlayback = false
    private var speakerChosen = false
    private var activation = UUID()
    private var routeObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private let session = AVAudioSession.sharedInstance()

    private struct Library: Codable { let directory: String; let tracks: [ExerciseTrack] }
    private var musicDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ExerciseMusic")
    }
    private func root(_ c: Connection) -> URL {
        let key = c.url + "|" + (c.remote_url ?? "") + "|" + c.watch_id + "|" + c.token
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return musicDirectory.appendingPathComponent(digest)
    }
    override private init() {
        super.init()
        if let c = Vault.load() { syncScope(c) }
        routeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.routeChanged() }
        }
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let began = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            if began { Task { @MainActor in self?.pause() } }
        }
    }
    func load(_ c: Connection) {
        let location = root(c)
        guard scope != location.path || reloadLibrary else { return }
        stop(); tracks = []; folder = nil; scope = location.path; reloadLibrary = false
        guard let data = try? Data(contentsOf: location.appendingPathComponent("playlist.json")),
              let library = try? JSONDecoder().decode(Library.self, from: data),
              UUID(uuidString: library.directory) != nil, (0...25).contains(library.tracks.count),
              library.tracks.allSatisfy({ (try? $0.validate()) != nil }) else { return }
        let saved = location.appendingPathComponent(library.directory)
        guard library.tracks.allSatisfy({ FileManager.default.fileExists(atPath: saved.appendingPathComponent($0.fileName).path) }) else { return }
        tracks = library.tracks; folder = saved
    }
    func start(_ c: Connection, target: Device) {
        load(c); stop(); sessionTarget = target; active = true; wantsPlayback = true
        guard !tracks.isEmpty else { status = "Add music on iPhone"; return }
        waiting = true; status = "Waiting for headset"
        activate()
    }
    func stopIfTargetChanged(_ c: Connection) {
        guard active, let sessionTarget else { return }
        // Compare typed configuration, not JSON text whose key order can vary.
        if scope != root(c).path || !c.devices.contains(sessionTarget) { stop() }
    }
    func stop() {
        activation = UUID(); active = false; wantsPlayback = false; speakerChosen = false; sessionTarget = nil
        player?.stop(); player = nil; index = 0; playing = false; beganPlayback = false; waiting = false; status = ""
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
    func forget() {
        feedbackLocation = nil; syncFeedback = MusicSyncFeedback()
        syncRequestTimeout?.cancel(); syncRequestTimeout = nil; syncAttempt = nil; syncConnection = nil
        musicTask?.cancel(); musicTask = nil; musicPlaylist = nil; syncRequestID = nil; syncing = false; stop()
        // Delete persisted copies even if no library was loaded this launch.
        try? FileManager.default.removeItem(at: musicDirectory)
        UserDefaults.standard.removeObject(forKey: "exerciseHeadsetUID")
        scope = nil; tracks = []; folder = nil
    }
    func useSpeaker() {
        guard active, !tracks.isEmpty else { return }
        speakerChosen = true; wantsPlayback = true
        // Apple controls destination selection. Never force speaker output or
        // assume that accepting a picker actually selected the requested route.
        activate()
    }
    private func activate() {
        let ticket = UUID(); activation = ticket
        do {
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            session.activate(options: []) { [weak self] success, _ in
                Task { @MainActor in
                    guard let self, self.active, self.activation == ticket else { return }
                    if success { self.routeChanged() }
                    else { self.playing = false; self.waiting = true; self.status = "Waiting for headset" }
                }
            }
        } catch { status = "Audio not available"; waiting = true }
    }
    private func allowedRoute() -> Bool {
        let outputs = session.currentRoute.outputs
        guard !outputs.isEmpty else { return false }
        return outputs.allSatisfy { port in
            let bluetooth = [AVAudioSession.Port.bluetoothA2DP, .bluetoothLE, .bluetoothHFP].contains(port.portType)
            let name = Vault.load()?.companion_settings?.headset ?? ExerciseAudioRoute.preferredName
            let preferred = bluetooth && (port.portName == name || (name == ExerciseAudioRoute.preferredName && ExerciseAudioRoute.isPreferred(name: port.portName, uid: port.uid, rememberedUID: UserDefaults.standard.string(forKey: "exerciseHeadsetUID"))))
            if preferred { UserDefaults.standard.set(port.uid, forKey: "exerciseHeadsetUID") }
            return ExerciseAudioRoute.mayPlay(preferredHeadset: preferred, builtInSpeaker: port.portType == .builtInSpeaker, speakerChosen: speakerChosen)
        }
    }
    private func routeChanged() {
        guard active else { return }
        guard allowedRoute() else {
            let lost = playing
            player?.pause(); playing = false; beganPlayback = false; waiting = true
            if lost { speakerChosen = false; wantsPlayback = true }
            status = speakerChosen ? "Choose Watch speaker in Control Center" : "Waiting for headset"; return
        }
        waiting = false
        if wantsPlayback { playCurrent() }
    }
    private func playCurrent() {
        guard active, allowedRoute(), !tracks.isEmpty, let folder else { return }
        do {
            if player == nil {
                player = try AVAudioPlayer(contentsOf: folder.appendingPathComponent(tracks[index].fileName))
                player?.delegate = self
            }
            playing = player?.play() == true
            beganPlayback = beganPlayback || playing
            status = playing ? "" : "Playback not confirmed"
        } catch { playing = false; status = "Track could not play" }
    }
    func pause() { wantsPlayback = false; player?.pause(); playing = false }
    func toggle() {
        if playing { pause() }
        else { wantsPlayback = true; activate() }
    }
    func skip(_ delta: Int) {
        guard active, !tracks.isEmpty else { return }
        let resume = wantsPlayback
        player?.stop(); player = nil; index = (index + delta + tracks.count) % tracks.count
        playing = false
        if resume { routeChanged() }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.player === player, self.active else { return }
            if flag { self.skip(1) }
            else { self.pause(); self.status = "Track could not play" }
        }
    }
    func sync(_ c: Connection) {
        syncRequestTimeout?.cancel()
        let attempt = MusicSyncAttempt(watchID: c.watch_id)
        syncAttempt = attempt; syncRequestID = attempt.id; syncConnection = c
        syncScope(c)
        syncFeedback.begin(attempt.id, message: "Connecting to iPhone…")
        syncRequestTimeout = Task {
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            guard syncRequestID == attempt.id, Vault.load()?.token == c.token else { return }
            syncAttempt = nil; syncRequestID = nil; syncConnection = nil
            syncFeedback.fail(attempt.id, message: "Connection timed out. Phone link: \(WCSession.default.isReachable ? "reachable" : "unreachable").")
        }
        continueSyncRequest()
    }
    private func continueSyncRequest() {
        guard let c = syncConnection, Vault.load()?.token == c.token,
              syncAttempt?.claim(activated: WCSession.default.activationState == .activated,
                                 reachable: WCSession.default.isReachable, watchID: c.watch_id) == true,
              let requestID = syncRequestID else { return }
        // Use the same live channel as Podcast. An installation hint must not
        // veto a working channel. The reply itself supplies the matching list.
        WCSession.default.sendMessage(["music_sync_requested": true, "music_sync_id": requestID.uuidString,
                                       "watch_id": c.watch_id], replyHandler: { value in
            Task { @MainActor in
                guard self.syncRequestID == requestID, Vault.load()?.token == c.token else { return }
                do {
                    guard let raw = value["music_sync_reply"] as? Data else { throw MusicSyncFailure.invalidReply }
                    let reply = try JSONDecoder().decode(MusicSyncReply.self, from: raw)
                    let manifest = try reply.resolved(requestID: requestID, watchID: c.watch_id)
                    self.syncRequestID = nil; self.syncAttempt = nil; self.syncConnection = nil
                    self.syncRequestTimeout?.cancel(); self.syncRequestTimeout = nil
                    self.receive(manifest)
                } catch { self.failSyncRequest(requestID, connection: c, error: error) }
            }
        }, errorHandler: { error in
            Task { @MainActor in self.failSyncRequest(requestID, connection: c, error: error) }
        })
    }
    private func failSyncRequest(_ id: UUID, connection c: Connection, error: Error) {
        guard syncRequestID == id, Vault.load()?.token == c.token else { return }
        syncRequestTimeout?.cancel(); syncRequestTimeout = nil
        syncAttempt = nil; syncRequestID = nil; syncConnection = nil
        failTransfer(id, connection: c, stage: "Connecting to iPhone", error: error)
    }
    func connectivityReady() {
        continueSyncRequest()
        guard syncRequestID == nil, let c = Vault.load(),
              WKExtension.shared().applicationState == .active,
              let data = try? Data(contentsOf: root(c).appendingPathComponent("incoming.json")),
              let manifest = try? JSONDecoder().decode(OfflinePlaylist.self, from: data) else { return }
        receive(manifest)
    }
    func receive(_ manifest: OfflinePlaylist) {
        guard let c = Vault.load(), manifest.watchID == c.watch_id,
              (try? manifest.validate()) != nil else { return }
        syncScope(c)
        let destination = root(c)
        let pending = destination.appendingPathComponent("incoming.json")
        let previous = (try? Data(contentsOf: pending)).flatMap { try? JSONDecoder().decode(OfflinePlaylist.self, from: $0) }
        if let previous, previous.generation > manifest.generation || (previous.generation == manifest.generation && previous.id != manifest.id) { return }
        if syncRequestID == nil, syncFeedback.id != manifest.id,
           syncFeedback.phase != .failed || previous?.id != manifest.id {
            syncFeedback.begin(manifest.id, message: "Preparing \(manifest.tracks.count) tracks from iPhone")
        }
        if musicPlaylist != manifest.id {
            musicTask?.cancel(); musicTask = nil; musicPlaylist = nil; syncing = false
        }
        let staging = destination.appendingPathComponent(manifest.id.uuidString)
        do {
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            try JSONEncoder().encode(manifest).write(to: pending, options: .atomic)
            // Reorders reuse verified files from the installed library.
            if let data = try? Data(contentsOf: destination.appendingPathComponent("playlist.json")),
               let library = try? JSONDecoder().decode(Library.self, from: data) {
                for track in manifest.tracks where library.tracks.contains(track) {
                    let source = destination.appendingPathComponent(library.directory).appendingPathComponent(track.fileName)
                    let target = staging.appendingPathComponent(track.fileName)
                    if !FileManager.default.fileExists(atPath: target.path) { try? FileManager.default.copyItem(at: source, to: target) }
                }
            }
            let installed = (try? Data(contentsOf: destination.appendingPathComponent("playlist.json")))
                .flatMap { try? JSONDecoder().decode(Library.self, from: $0) }?.directory
            for item in (try? FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)) ?? [] {
                if UUID(uuidString: item.lastPathComponent) != nil, item != staging,
                   item.lastPathComponent != installed, item != folder { try? FileManager.default.removeItem(at: item) }
            }
            try commitIncoming(manifest, connection: c)
            beginMusicTransfer(manifest, connection: c)
        } catch { failTransfer(manifest.id, connection: c, stage: "Preparing watch storage", error: error) }
    }
    private func beginMusicTransfer(_ manifest: OfflinePlaylist, connection c: Connection) {
        guard syncFeedback.phase != .failed,
              musicPlaylist != manifest.id, WCSession.default.activationState == .activated,
              WCSession.default.isReachable, WKExtension.shared().applicationState == .active else { return }
        let staging = root(c).appendingPathComponent(manifest.id.uuidString)
        guard manifest.tracks.contains(where: { !FileManager.default.fileExists(atPath: staging.appendingPathComponent($0.fileName).path) }) else { return }
        musicTask?.cancel(); musicPlaylist = manifest.id; syncing = true
        musicTask = Task {
            var stage = "Receiving audio"
            defer {
                if musicPlaylist == manifest.id { musicPlaylist = nil; musicTask = nil; syncing = false }
            }
            do {
                for (number, track) in manifest.tracks.enumerated() {
                    let target = staging.appendingPathComponent(track.fileName)
                    if FileManager.default.fileExists(atPath: target.path) { continue }
                    let partial = staging.appendingPathComponent(track.fileName + ".part")
                    defer { try? FileManager.default.removeItem(at: partial) }
                    var offset = 0
                    while offset < track.size {
                        try Task.checkCancellation()
                        guard musicPlaylist == manifest.id, Vault.load()?.token == c.token,
                              Vault.load()?.watch_id == c.watch_id else { throw CancellationError() }
                        guard WKExtension.shared().applicationState == .active else {
                            syncFeedback.pause(manifest.id, message: "Screen asleep; waiting for background transfer")
                            return
                        }
                        guard WCSession.default.isReachable else {
                            syncFeedback.pause(manifest.id, message: "Phone link lost; waiting for background transfer")
                            return
                        }
                        syncFeedback.progress(manifest.id, message: "Receiving \(number + 1)/\(manifest.tracks.count) (\(offset * 100 / track.size)%)")
                        stage = "Requesting audio chunk at byte \(offset)"
                        let reply = try await musicReply(["music_chunk": manifest.id.uuidString,
                            "watch_id": c.watch_id, "file": track.fileName, "offset": offset])
                        try Task.checkCancellation()
                        guard musicPlaylist == manifest.id, Vault.load()?.token == c.token,
                              reply["music_chunk"] as? String == manifest.id.uuidString,
                              reply["file"] as? String == track.fileName,
                              reply["offset"] as? Int == offset, let data = reply["data"] as? Data else { throw MusicFileFailure.mismatchedReply }
                        stage = "Saving audio chunk at byte \(offset)"
                        let complete = try OfflineMusicTransfer.append(data, to: partial, track: track, offset: offset)
                        offset += data.count
                        if complete {
                            // A background file can win the race; both paths verify
                            // the same manifest and only install complete files.
                            if !FileManager.default.fileExists(atPath: target.path) {
                                try FileManager.default.moveItem(at: partial, to: target)
                            }
                            stage = "Installing verified playlist"
                            try commitIncoming(manifest, connection: c)
                        }
                    }
                }
            } catch {
                guard musicPlaylist == manifest.id, Vault.load()?.token == c.token else { return }
                if error is CancellationError {
                    syncFeedback.pause(manifest.id, message: "Live transfer paused; waiting for background transfer")
                } else { failTransfer(manifest.id, connection: c, stage: stage, error: error) }
            }
        }
    }
    private func musicReply(_ message: [String: Any]) async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { continuation in
            // WatchConnectivity delivers either a reply or an error, including
            // its reply timeout. Never interpret dispatch alone as receipt.
            WCSession.default.sendMessage(message, replyHandler: { continuation.resume(returning: $0) },
                errorHandler: { continuation.resume(throwing: $0) })
        }
    }
    func receiveFile(_ file: URL, metadata: [String: Any]) {
        defer { try? FileManager.default.removeItem(at: file) }
        guard let raw = metadata["playlist"] as? Data,
              let manifest = try? JSONDecoder().decode(OfflinePlaylist.self, from: raw),
              let name = metadata["file"] as? String,
              let track = manifest.tracks.first(where: { $0.fileName == name }),
              let c = Vault.load(), manifest.watchID == c.watch_id else { return }
        receive(manifest)
        let destination = root(c)
        guard let pending = try? Data(contentsOf: destination.appendingPathComponent("incoming.json")),
              let current = try? JSONDecoder().decode(OfflinePlaylist.self, from: pending), current.id == manifest.id else { return }
        do {
            let data = try Data(contentsOf: file, options: .mappedIfSafe)
            guard data.count == track.size, SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == track.sha256 else { throw ControlError.invalidResponse }
            let target = destination.appendingPathComponent(manifest.id.uuidString).appendingPathComponent(track.fileName)
            try data.write(to: target, options: .atomic)
            try commitIncoming(manifest, connection: c)
        } catch { failTransfer(manifest.id, connection: c, stage: "Verifying background audio", error: error) }
    }
    private func commitIncoming(_ manifest: OfflinePlaylist, connection c: Connection) throws {
        let destination = root(c)
        let staging = destination.appendingPathComponent(manifest.id.uuidString)
        let received = manifest.tracks.filter { FileManager.default.fileExists(atPath: staging.appendingPathComponent($0.fileName).path) }.count
        guard received == manifest.tracks.count else {
            syncFeedback.progress(manifest.id, message: "Received \(received)/\(manifest.tracks.count) tracks from iPhone")
            return
        }
        let library = Library(directory: manifest.id.uuidString, tracks: manifest.tracks)
        try JSONEncoder().encode(library).write(to: destination.appendingPathComponent("playlist.json"), options: .atomic)
        if !active { scope = nil; load(c) } else { reloadLibrary = true }
        // Preserve the active player's folder until playback ends.
        for item in (try? FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)) ?? [] {
            if UUID(uuidString: item.lastPathComponent) != nil, item != staging, item != folder { try? FileManager.default.removeItem(at: item) }
        }
        musicTask?.cancel(); musicTask = nil; musicPlaylist = nil; syncing = false
        syncFeedback.verified(manifest.id, tracks: manifest.tracks.count)
        let receipt: [String: Any] = ["playlist_saved": manifest.id.uuidString, "watch_id": c.watch_id]
        WCSession.default.transferUserInfo(receipt)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(receipt, replyHandler: { _ in }, errorHandler: { _ in })
        }
    }
    #if DEBUG && targetEnvironment(simulator)
    func preview(playing: Bool) {
        // Rendering fixtures contain no audio and never activate an audio session.
        self.playing = playing; beganPlayback = playing; waiting = !playing
        status = playing ? "" : "Waiting for headset"
    }
    #endif
}

struct ExercisePlaybackView: View {
    @ObservedObject private var player = ExercisePlayer.shared
    var body: some View {
        VStack(spacing: 4) {
            if player.beganPlayback && !player.waiting {
                HStack(spacing: 2) {
                    Button { player.skip(-1) } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel("Previous track")
                    Button { player.toggle() } label: { Image(systemName: player.playing ? "pause.fill" : "play.fill") }.accessibilityLabel(player.playing ? "Pause" : "Play")
                    Button { player.skip(1) } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("Next track")
                }.buttonStyle(PlaybackButtonStyle())
                WatchVolume().frame(height: 44)
            } else if player.waiting {
                Text(player.status).font(.caption2).foregroundStyle(.gray)
                Button("Use watch speaker") { player.useSpeaker() }
                    .font(.caption2).buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(Color.gray.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
            } else if !player.status.isEmpty {
                Text(player.status).font(.caption2).foregroundStyle(.gray)
            }
        }
    }
}

// Native system volume, including Crown interaction; never simulate system
// volume by changing the player's per-track gain.
private struct WatchVolume: WKInterfaceObjectRepresentable {
    @Environment(\.scenePhase) private var phase
    final class Coordinator { var active = false }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
        WKInterfaceVolumeControl(origin: .local)
    }
    func updateWKInterfaceObject(_ object: WKInterfaceVolumeControl, context: Context) {
        let active = phase == .active
        guard context.coordinator.active != active else { return }
        context.coordinator.active = active
        if active {
            let coordinator = context.coordinator
            DispatchQueue.main.async { if coordinator.active { object.focus() } }
        } else { object.resignFocus() }
    }
    static func dismantleWKInterfaceObject(_ object: WKInterfaceVolumeControl, coordinator: Coordinator) {
        coordinator.active = false; object.resignFocus()
    }
}

private struct PlaybackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(maxWidth: .infinity, minHeight: 28)
            .foregroundStyle(.mint)
            .background(Color.mint.opacity(configuration.isPressed ? 0.3 : 0.18), in: RoundedRectangle(cornerRadius: 15))
    }
}
