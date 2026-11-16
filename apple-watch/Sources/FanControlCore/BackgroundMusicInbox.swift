import Foundation

// WCSession owns its temporary URL only until didReceive returns. Persist both
// bytes and the delivery identity before returning, independently of UI lifetime.
public final class BackgroundMusicInbox: @unchecked Sendable {
    public struct Delivery: Codable, Sendable {
        public let id: UUID
        public let playlist: OfflinePlaylist
        public let fileName: String
    }
    public let root: URL
    private let lock = NSLock()
    public init(root: URL) { self.root = root }
    public static var applicationRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BackgroundMusicInbox", isDirectory: true)
    }
    @discardableResult public func enqueue(file: URL, playlist: OfflinePlaylist, fileName: String) throws -> Delivery {
        lock.lock(); defer { lock.unlock() }
        try playlist.validate()
        guard let track = playlist.tracks.first(where: { $0.fileName == fileName }) else { throw ControlError.invalidResponse }
        let delivery = Delivery(id: UUID(), playlist: playlist, fileName: fileName)
        let directory = root.appendingPathComponent(delivery.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            let audio = directory.appendingPathComponent("audio")
            try FileManager.default.copyItem(at: file, to: audio)
            try OfflineMusicTransfer.verifyFile(at: audio, track: track)
            // The manifest is the commit marker. An interrupted copy is never
            // exposed as a complete delivery after a background relaunch.
            try JSONEncoder().encode(delivery).write(to: directory.appendingPathComponent("delivery.json"), options: .atomic)
            return delivery
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }
    public func pending() -> [Delivery] {
        lock.lock(); defer { lock.unlock() }
        return ((try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [])
            .compactMap { directory in
                guard let data = try? Data(contentsOf: directory.appendingPathComponent("delivery.json")),
                      let value = try? JSONDecoder().decode(Delivery.self, from: data),
                      value.id.uuidString == directory.lastPathComponent,
                      (try? value.playlist.validate()) != nil,
                      value.playlist.tracks.contains(where: { $0.fileName == value.fileName }) else { return nil }
                return value
            }.sorted { $0.playlist.generation < $1.playlist.generation }
    }
    // Installation is synchronous within the OS background wake. A failed
    // install stays queued; successful entries alone release their durable copy.
    public func installPending(_ install: (Delivery, URL) -> Bool) {
        for delivery in pending() {
            if install(delivery, file(for: delivery)) { try? remove(delivery) }
        }
    }
    public func file(for delivery: Delivery) -> URL {
        root.appendingPathComponent(delivery.id.uuidString).appendingPathComponent("audio")
    }
    public func remove(_ delivery: Delivery) throws {
        lock.lock(); defer { lock.unlock() }
        try FileManager.default.removeItem(at: root.appendingPathComponent(delivery.id.uuidString))
    }
    public func removeAll() throws {
        lock.lock(); defer { lock.unlock() }
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }
}
