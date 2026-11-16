import Foundation

public struct OfflineMusicLibrary: Codable {
    public let directory: String
    public let tracks: [ExerciseTrack]
    public init(directory: String, tracks: [ExerciseTrack]) {
        self.directory = directory; self.tracks = tracks
    }
    // Identical install boundary for background files and live chunks. The
    // previous playlist remains authoritative until every replacement verifies.
    @discardableResult public static func installIfComplete(_ manifest: OfflinePlaylist, at root: URL) throws -> Bool {
        try manifest.validate()
        let directory = root.appendingPathComponent(manifest.id.uuidString)
        guard manifest.tracks.allSatisfy({ FileManager.default.fileExists(atPath: directory.appendingPathComponent($0.fileName).path) }) else { return false }
        for track in manifest.tracks {
            try OfflineMusicTransfer.verifyFile(at: directory.appendingPathComponent(track.fileName), track: track)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let library = OfflineMusicLibrary(directory: manifest.id.uuidString, tracks: manifest.tracks)
        try JSONEncoder().encode(library).write(to: root.appendingPathComponent("playlist.json"), options: .atomic)
        return true
    }
}
