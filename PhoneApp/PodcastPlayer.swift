import Foundation
import SwiftUI
import AVFoundation
import MediaPlayer
import CryptoKit
import FanControlCore

// One phone-owned coordinator also serves lock-screen and watch commands.
@MainActor final class PodcastPlayer: ObservableObject {
    static let shared = PodcastPlayer()
    @Published private(set) var queue = PodcastQueue()
    @Published private(set) var status = "Choose your next episode"
    @Published private(set) var playing = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var refreshing = false
    @Published private(set) var busy = false
    @Published private(set) var downloaded = Set<String>()
    private let player = AVPlayer()
    private let delegate = PodcastDownloadDelegate()
    private var session: URLSession!
    private var tasks: [String: URLSessionDownloadTask] = [:]
    private var validating = Set<String>()
    private var receipts: [PodcastReply] = []
    private var sequence: Int64 = 0
    private var playbackGeneration = UUID()
    private var loadedID: String?
    private var cellularID: String?
    private var observer: Any?
    private var notifications: [NSObjectProtocol] = []
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var ticks = 0
    private var recovering = true
    private var backgroundCompletion: (() -> Void)?
    private var eventsFinished = false
    func backgroundEvents(completion: @escaping () -> Void) {
        backgroundCompletion = completion; completeBackgroundEvents()
    }
    func downloadsFinishedEvents() { eventsFinished = true; completeBackgroundEvents() }
    private func completeBackgroundEvents() {
        guard eventsFinished, validating.isEmpty, let completion = backgroundCompletion else { return }
        backgroundCompletion = nil; eventsFinished = false; completion()
    }
    static let sessionID = "dev.fancontrol.watch.podcast.downloads"
    private let defaults = UserDefaults.standard
    private let directory: URL
    private init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Podcasts", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var resource = directory; var values = URLResourceValues(); values.isExcludedFromBackup = true; try? resource.setResourceValues(values)
        if let data = defaults.data(forKey: "podcastQueue"), let saved = try? JSONDecoder().decode(PodcastQueue.self, from: data) { queue = saved }
        if let data = defaults.data(forKey: "podcastReceipts"), let saved = try? JSONDecoder().decode([PodcastReply].self, from: data) { receipts = saved }
        sequence = Int64(defaults.integer(forKey: "podcastSequence"))
        cellularID = defaults.string(forKey: "podcastCellularID")
        position = queue.currentID.flatMap { queue.history[$0]?.position } ?? 0
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionID)
        config.sessionSendsLaunchEvents = true; config.isDiscretionary = false
        session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        downloaded = Set(queue.episodes.filter { FileManager.default.fileExists(atPath: file($0.id).path) }.map(\.id))
        status = queue.current == nil ? "Choose your next episode" : downloaded.contains(queue.currentID ?? "") ? "Ready" : "Waiting for Wi-Fi"
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        notifications.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                guard let self, let item = note.object as? AVPlayerItem, item === self.player.currentItem else { return }
                self.finish()
            }
        })
        notifications.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            Task { @MainActor in self?.pause() }
        })
        notifications.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            Task { @MainActor in self?.pause() }
        })
        configureRemote()
        session.getAllTasks { tasks in
            Task { @MainActor in
                for task in tasks {
                    guard let task = task as? URLSessionDownloadTask, let id = task.taskDescription, self.queue.window.contains(where: { $0.id == id }) else { task.cancel(); continue }
                    self.tasks[id] = task
                }
                self.recovering = false; self.replenish()
            }
        }
    }
    private func file(_ id: String) -> URL {
        let name = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name + ".mp3")
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(queue) { defaults.set(data, forKey: "podcastQueue") }
        defaults.set(cellularID, forKey: "podcastCellularID")
    }
    func snapshot() -> PodcastSnapshot {
        savePosition()
        playing = player.timeControlStatus == .playing
        sequence += 1; defaults.set(sequence, forKey: "podcastSequence")
        return PodcastSnapshot(episode: queue.current, revision: queue.revision, sequence: sequence, position: position, duration: duration,
                               playing: playing, downloaded: downloaded.contains(queue.currentID ?? ""), status: status)
    }
    private func changed() { persist(); nowPlaying(); PhoneModel.shared.publish() }
    func refresh() async {
        guard !refreshing else { return }
        refreshing = true; defer { refreshing = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: PodcastFeed.url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw PodcastError.invalidFeed }
            let episodes = try PodcastFeed.parse(data)
            try Task.checkCancellation()
            // Keep a current episode even if a publisher temporarily truncates the feed.
            queue.merge(episodes)
            if loadedID == nil { position = queue.currentID.flatMap { queue.history[$0]?.position } ?? 0 }
            replenish(); changed()
        } catch {
            if !Task.isCancelled { status = "Could not refresh episodes. Retry when connected."; changed() }
        }
    }
    func select(_ episode: PodcastEpisode) {
        guard !busy else { return }
        pause(); queue.select(episode.id); loadedID = nil; player.replaceCurrentItem(with: nil)
        position = queue.history[episode.id]?.position ?? 0; duration = 0; cellularID = nil
        status = downloaded.contains(episode.id) ? "Ready" : "Waiting for Wi-Fi"
        replenish(); changed()
    }
    func perform(_ action: PodcastAction, position: Double? = nil) {
        let command = PodcastCommand(action: action, episodeID: queue.currentID, revision: queue.revision, position: position)
        Task { _ = await handle(command) }
    }
    func handle(_ command: PodcastCommand) async -> PodcastReply {
        if let prior = receipts.first(where: { $0.commandID == command.id }) { return prior }
        guard command.valid(for: queue), !busy || command.action == .state else {
            return PodcastReply(commandID: command.id, accepted: false, snapshot: snapshot(), error: "Not confirmed. Refresh and retry.")
        }
        if command.action == .state { return PodcastReply(commandID: command.id, accepted: true, snapshot: snapshot()) }
        busy = true; defer { busy = false }
        let revision = queue.revision
        var accepted = false
        switch command.action {
        case .play, .playCurrent: accepted = await play()
        case .pause: pause(); accepted = player.rate == 0
        case .complete: finish(); accepted = true
        case .seek:
            if let target = command.position { accepted = await seek(target) }
        case .backward15, .forward15:
            savePosition()
            accepted = await seek(max(0, position + (command.action == .forward15 ? 15 : -15)))
        case .state: break
        }
        // Selection cannot change while busy, except intentional completion/end-of-file.
        if command.action != .complete && queue.revision != revision { accepted = false }
        changed()
        let reply = PodcastReply(commandID: command.id, accepted: accepted, snapshot: snapshot(), error: accepted ? nil : "Not confirmed. Check the iPhone and retry.")
        receipts.append(reply); receipts = Array(receipts.suffix(80))
        if let data = try? JSONEncoder().encode(receipts) { defaults.set(data, forKey: "podcastReceipts") }
        return reply
    }
    private func prepare() async -> Bool {
        guard let episode = queue.current, downloaded.contains(episode.id) else {
            status = queue.current == nil ? "Choose your next episode on iPhone" : "Episode not downloaded. Waiting for Wi-Fi."
            changed(); return false
        }
        if loadedID == episode.id && player.currentItem?.status == .readyToPlay { return true }
        player.replaceCurrentItem(with: AVPlayerItem(url: file(episode.id))); loadedID = episode.id
        let target = queue.history[episode.id]?.position ?? 0
        // A local file can still take time to become ready. Never leave a delayed Play queued.
        for _ in 0..<30 {
            if player.currentItem?.status == .readyToPlay { break }
            if player.currentItem?.status == .failed { status = "Audio unavailable. Retry download."; return false }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return false }
        }
        guard player.currentItem?.status == .readyToPlay else { status = "Audio not ready. Retry."; return false }
        let seconds = player.currentItem?.duration.seconds ?? 0
        duration = seconds.isFinite ? max(0, seconds) : 0
        return await seek(target)
    }
    private func play() async -> Bool {
        let generation = playbackGeneration
        guard await prepare(), playbackGeneration == generation else { return false }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, mode: .spokenAudio, options: [])
            try audio.setActive(true)
        } catch { status = "Audio output unavailable"; changed(); return false }
        player.play()
        for _ in 0..<20 {
            guard playbackGeneration == generation else { return false }
            if player.timeControlStatus == .playing {
                playing = true; status = "Playing"
                if let next = queue.cellularSuccessor(downloaded: downloaded) { cellularID = next.id }
                replenish(); changed(); return true
            }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { break }
        }
        pause(); status = "Playback not confirmed. Retry."; changed(); return false
    }
    func pause() {
        playbackGeneration = UUID()
        player.pause(); playing = false; savePosition(); status = "Paused"; changed()
    }
    private func seek(_ seconds: Double) async -> Bool {
        if loadedID != queue.currentID { guard await prepare() else { return false } }
        let target = min(max(0, seconds), max(0, duration - 0.05))
        let success = await player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        guard success else { return false }
        savePosition(); changed(); return abs(position - target) < 1
    }
    private func finish() {
        playbackGeneration = UUID()
        player.pause(); playing = false; savePosition(); player.replaceCurrentItem(with: nil); loadedID = nil
        queue.complete(); position = 0; duration = 0; cellularID = nil
        status = queue.current == nil ? "No upcoming episode. Choose on iPhone." : downloaded.contains(queue.currentID ?? "") ? "Ready" : "Waiting for Wi-Fi"
        replenish(); changed()
    }
    private func savePosition() {
        guard loadedID == queue.currentID, loadedID != nil else { return }
        let value = player.currentTime().seconds
        if value.isFinite { position = max(0, value); queue.save(position: position) }
    }
    private func tick() {
        guard loadedID != nil else { return }
        savePosition()
        playing = player.timeControlStatus == .playing
        if player.currentItem?.status == .failed { status = "Playback failed. Retry."; playing = false }
        ticks += 1
        if ticks % 3 == 0 { changed() } else { nowPlaying() }
    }
    func suspend() { savePosition(); persist() }
    func pairingChanged() {
        pause(); receipts = []; defaults.removeObject(forKey: "podcastReceipts")
    }
    func replenish(retry: Bool = false) {
        guard !recovering else { return }
        let wanted = Set(queue.window.map(\.id))
        for (id, task) in tasks where !wanted.contains(id) { task.cancel(); tasks.removeValue(forKey: id) }
        for id in downloaded.subtracting(wanted) {
            try? FileManager.default.removeItem(at: file(id)); downloaded.remove(id)
        }
        for episode in queue.window where !downloaded.contains(episode.id) && !validating.contains(episode.id) {
            let cellular = episode.id == cellularID
            if let existing = tasks[episode.id] {
                if cellular && existing.originalRequest?.allowsCellularAccess == false { existing.cancel(); tasks.removeValue(forKey: episode.id) }
                else { continue }
            }
            var request = URLRequest(url: episode.audioURL)
            request.allowsCellularAccess = cellular
            request.allowsExpensiveNetworkAccess = cellular
            request.allowsConstrainedNetworkAccess = cellular
            let task = session.downloadTask(with: request); task.taskDescription = episode.id
            tasks[episode.id] = task; task.resume()
        }
        if retry { status = "Downloads scheduled"; changed() }
    }
    func receivedFile(_ location: URL, id: String, taskID: Int, response: URLResponse?) async {
        guard tasks[id]?.taskIdentifier == taskID else { try? FileManager.default.removeItem(at: location); return }
        tasks.removeValue(forKey: id); validating.insert(id)
        defer {
            validating.remove(id); try? FileManager.default.removeItem(at: location)
            completeBackgroundEvents()
        }
        do {
            guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                  (response.mimeType?.lowercased().hasPrefix("audio/") == true || response.mimeType == "application/octet-stream") else { throw PodcastError.unavailable }
            let asset = AVURLAsset(url: location)
            let length = try await asset.load(.duration).seconds
            guard length.isFinite, length > 0, queue.window.contains(where: { $0.id == id }) else { throw PodcastError.unavailable }
            let destination = file(id)
            if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
            try FileManager.default.moveItem(at: location, to: destination)
            downloaded.insert(id)
            if id == queue.currentID && !playing { status = "Ready" }
            changed()
        } catch { status = "Download not completed. Retry on iPhone."; changed() }
    }
    func downloadFailed(id: String, taskID: Int) {
        guard tasks[id]?.taskIdentifier == taskID else { return }
        tasks.removeValue(forKey: id); status = "Download not completed. Retry on iPhone."; changed()
    }
    private func configureRemote() {
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [15]; center.skipBackwardCommand.preferredIntervals = [15]
        func add(_ command: MPRemoteCommand, action: PodcastAction, offset: Double? = nil) {
            let token = command.addTarget { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.perform(action, position: offset.map { max(0, self.position + $0) })
                }
                return .success
            }
            remoteTargets.append((command, token))
        }
        add(center.playCommand, action: .play); add(center.pauseCommand, action: .pause)
        add(center.skipForwardCommand, action: .forward15); add(center.skipBackwardCommand, action: .backward15)
        let toggle = center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.perform(self.playing ? .pause : .play)
            }
            return .success
        }
        remoteTargets.append((center.togglePlayPauseCommand, toggle))
    }
    private func nowPlaying() {
        guard let episode = queue.current else { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil; return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyArtist: "Mission Log", MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position, MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0]
    }
}

private final class PodcastDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription else { return }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
        do {
            try FileManager.default.moveItem(at: location, to: temporary)
            Task { @MainActor in await PodcastPlayer.shared.receivedFile(temporary, id: id, taskID: downloadTask.taskIdentifier, response: downloadTask.response) }
        } catch { Task { @MainActor in PodcastPlayer.shared.downloadFailed(id: id, taskID: downloadTask.taskIdentifier) } }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error != nil, let id = task.taskDescription else { return }
        Task { @MainActor in PodcastPlayer.shared.downloadFailed(id: id, taskID: task.taskIdentifier) }
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            PodcastPlayer.shared.downloadsFinishedEvents()
        }
    }
}
