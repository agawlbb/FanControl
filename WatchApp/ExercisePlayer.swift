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
    @Published private(set) var status = ""
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
        guard !syncing else { status = "Finish music sync first"; return }
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
        syncing = false; stop()
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
        guard WCSession.default.activationState == .activated,
              WCSession.default.isCompanionAppInstalled else {
            status = "Open the iPhone app to sync music"
            return
        }
        // The iPhone library is authoritative. HA's legacy playlist can contain
        // different tracks and must never replace the phone's imported music.
        WCSession.default.transferUserInfo(["music_sync_requested": true, "watch_id": c.watch_id])
        status = "Music sync requested from iPhone"
    }
    func receive(_ manifest: OfflinePlaylist) {
        guard let c = Vault.load(), manifest.watchID == c.watch_id,
              (try? manifest.validate()) != nil else { return }
        let destination = root(c)
        let pending = destination.appendingPathComponent("incoming.json")
        if let data = try? Data(contentsOf: pending), let old = try? JSONDecoder().decode(OfflinePlaylist.self, from: data),
           old.generation > manifest.generation || (old.generation == manifest.generation && old.id != manifest.id) { return }
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
        } catch { status = "Music transfer failed" }
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
        } catch { status = "Music transfer failed" }
    }
    private func commitIncoming(_ manifest: OfflinePlaylist, connection c: Connection) throws {
        let destination = root(c)
        let staging = destination.appendingPathComponent(manifest.id.uuidString)
        let received = manifest.tracks.filter { FileManager.default.fileExists(atPath: staging.appendingPathComponent($0.fileName).path) }.count
        guard received == manifest.tracks.count else {
            status = "Received \(received)/\(manifest.tracks.count) tracks from iPhone"
            return
        }
        let library = Library(directory: manifest.id.uuidString, tracks: manifest.tracks)
        try JSONEncoder().encode(library).write(to: destination.appendingPathComponent("playlist.json"), options: .atomic)
        if !active { scope = nil; load(c) } else { reloadLibrary = true }
        // Preserve the active player's folder until playback ends.
        for item in (try? FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)) ?? [] {
            if UUID(uuidString: item.lastPathComponent) != nil, item != staging, item != folder { try? FileManager.default.removeItem(at: item) }
        }
        status = "\(manifest.tracks.count) tracks ready offline"
        WCSession.default.transferUserInfo(["playlist_saved": manifest.id.uuidString, "watch_id": c.watch_id])
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
