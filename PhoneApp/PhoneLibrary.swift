import Foundation
import SwiftUI
import CryptoKit
import WatchConnectivity
import FanControlCore

@MainActor final class PhoneLibrary: ObservableObject {
    static let shared = PhoneLibrary()
    @Published private(set) var tracks: [ExerciseTrack] = []
    @Published private(set) var status = ""
    @Published private(set) var progress: Double = 0
    @Published private(set) var manifest: OfflinePlaylist?
    @Published var error = ""
    private var liveUpdatedAt: Date?
    private var livePlaylist: UUID?
    private var savedPlaylist: UUID?
    private var root: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Music") }
    private init() {
        if let data = try? Data(contentsOf: root.appendingPathComponent("library.json")),
           let saved = try? JSONDecoder().decode([ExerciseTrack].self, from: data),
           (try? OfflinePlaylist(watchID: "local", tracks: saved)) != nil { tracks = saved }
        if let data = try? Data(contentsOf: root.appendingPathComponent("transfer.json")),
           let saved = try? JSONDecoder().decode(OfflinePlaylist.self, from: data), (try? saved.validate()) != nil { manifest = saved }
    }
    private func save() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(tracks).write(to: root.appendingPathComponent("library.json"), options: .atomic)
    }
    func importFiles(_ urls: [URL]) {
        do {
            var next = tracks
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size > 0, size <= 30 * 1024 * 1024 else { throw ControlError.invalidResponse }
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                let track = ExerciseTrack(name: url.lastPathComponent, sha256: hash, size: data.count)
                try track.validate()
                guard !next.contains(where: { $0.fileName == track.fileName }) else { continue }
                _ = try OfflinePlaylist(watchID: "local", tracks: next + [track])
                try data.write(to: root.appendingPathComponent(track.fileName), options: .atomic)
                next.append(track)
            }
            let old = tracks; tracks = next
            do { try save() } catch { tracks = old; throw error }
            self.error = ""; status = ""
        } catch { self.error = "Import failed. Use MP3, M4A or AAC; up to 25 tracks, 30 MB each and 200 MB total." }
    }
    func move(_ offsets: IndexSet, to destination: Int) {
        let old = tracks; tracks.move(fromOffsets: offsets, toOffset: destination)
        do { try save(); status = "" } catch { tracks = old; self.error = "Changes not saved" }
    }
    func remove(_ offsets: IndexSet) {
        let old = tracks; tracks.remove(atOffsets: offsets)
        do { try save(); status = "" } catch { tracks = old; self.error = "Changes not saved" }
        // Keep queued source files until WatchConnectivity completes them.
    }
    func sync() {
        guard let c = PhoneModel.shared.connection, WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { error = "Watch app unavailable"; return }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let previous = manifest?.generation ?? 0
            let next = try OfflinePlaylist(watchID: c.watch_id, tracks: tracks, generation: max(previous + 1, Int64(Date().timeIntervalSince1970 * 1000)))
            let raw = try JSONEncoder().encode(next)
            for track in tracks {
                guard FileManager.default.fileExists(atPath: root.appendingPathComponent(track.fileName).path) else { throw ControlError.invalidResponse }
            }
            try raw.write(to: root.appendingPathComponent("transfer.json"), options: .atomic)
            for transfer in WCSession.default.outstandingFileTransfers where transfer.file.metadata?["playlist"] != nil { transfer.cancel() }
            manifest = next; livePlaylist = nil; savedPlaylist = nil; PhoneModel.shared.publish()
            for track in tracks {
                WCSession.default.transferFile(root.appendingPathComponent(track.fileName), metadata: ["playlist": raw, "file": track.fileName])
            }
            progress = 0; status = "Waiting for watch"; error = ""
        } catch { self.error = "Transfer could not start" }
    }
    func musicChunk(_ request: [String: Any]) -> [String: Any] {
        guard let c = PhoneModel.shared.connection,
              request["watch_id"] as? String == c.watch_id,
              let manifest, manifest.watchID == c.watch_id,
              request["music_chunk"] as? String == manifest.id.uuidString,
              let name = request["file"] as? String,
              let number = manifest.tracks.firstIndex(where: { $0.fileName == name }),
              let offset = request["offset"] as? Int else { return [:] }
        do {
            let track = manifest.tracks[number]
            let count = try OfflineMusicTransfer.byteCount(track: track, offset: offset)
            let handle = try FileHandle(forReadingFrom: root.appendingPathComponent(track.fileName))
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(offset))
            guard let data = try handle.read(upToCount: count), data.count == count else { throw ControlError.invalidResponse }
            if savedPlaylist != manifest.id {
                livePlaylist = manifest.id; liveUpdatedAt = Date()
                let previous = manifest.tracks.prefix(number).reduce(0) { $0 + $1.size }
                let total = manifest.tracks.reduce(0) { $0 + $1.size }
                progress = Double(previous + offset + count) / Double(total)
                status = "Sending \(number + 1)/\(manifest.tracks.count) to watch (\(Int(progress * 100))%)"
                error = ""
            }
            return ["music_chunk": manifest.id.uuidString, "file": name, "offset": offset, "data": data]
        } catch {
            error = "Music file unavailable. Import it again and tap Sync."
            return [:]
        }
    }
    func acknowledge(_ id: String) {
        guard manifest?.id.uuidString == id else { return }
        savedPlaylist = manifest?.id; livePlaylist = nil; progress = 1
        status = tracks == manifest?.tracks ? "On watch" : ""
        error = ""
        for transfer in WCSession.default.outstandingFileTransfers {
            guard let raw = transfer.file.metadata?["playlist"] as? Data,
                  let queued = try? JSONDecoder().decode(OfflinePlaylist.self, from: raw), queued.id == manifest?.id else { continue }
            transfer.cancel()
        }
        let keep = Set(tracks.map(\.fileName))
        for file in (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] {
            if ["mp3", "m4a", "aac"].contains(file.pathExtension), !keep.contains(file.lastPathComponent) { try? FileManager.default.removeItem(at: file) }
        }
    }
    func targetChanged() {
        for transfer in WCSession.default.outstandingFileTransfers where transfer.file.metadata?["playlist"] != nil { transfer.cancel() }
        livePlaylist = nil; savedPlaylist = nil; manifest = nil; status = ""; progress = 0; error = ""
        try? FileManager.default.removeItem(at: root.appendingPathComponent("transfer.json"))
    }
    func updateProgress() {
        if livePlaylist != nil, let at = liveUpdatedAt, Date().timeIntervalSince(at) > 20 {
            livePlaylist = nil
            status = "Queued for background transfer; open the watch app to resume now"
        }
        guard livePlaylist != manifest?.id, savedPlaylist != manifest?.id else { return }
        guard let manifest, !manifest.tracks.isEmpty else { progress = 1; return }
        let pending = WCSession.default.outstandingFileTransfers.filter {
            guard let raw = $0.file.metadata?["playlist"] as? Data,
                  let list = try? JSONDecoder().decode(OfflinePlaylist.self, from: raw) else { return false }
            return list.id == manifest.id
        }
        progress = min(1, max(0, (Double(manifest.tracks.count - pending.count) + pending.reduce(0) { $0 + $1.progress.fractionCompleted }) / Double(manifest.tracks.count)))
    }
    func transferFinished(_ transfer: WCSessionFileTransfer, error: Error?) {
        guard let raw = transfer.file.metadata?["playlist"] as? Data,
              let list = try? JSONDecoder().decode(OfflinePlaylist.self, from: raw), list.id == manifest?.id else { return }
        updateProgress()
        if error != nil, savedPlaylist != list.id, livePlaylist != list.id { status = ""; self.error = "Transfer interrupted. Tap Sync to retry." }
    }
}
