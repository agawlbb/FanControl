import Foundation
import CryptoKit

// Small live messages supplement the OS-scheduled file transfer. A completed
// chunk exchange is not proof of installation; only the watch's saved receipt is.
public enum OfflineMusicTransfer {
    public static let chunkSize = 32 * 1024
    public static func byteCount(track: ExerciseTrack, offset: Int) throws -> Int {
        try track.validate()
        guard offset >= 0, offset < track.size else { throw ControlError.invalidResponse }
        return min(chunkSize, track.size - offset)
    }
    public static func append(_ data: Data, to file: URL, track: ExerciseTrack, offset: Int) throws -> Bool {
        guard data.count == (try byteCount(track: track, offset: offset)) else { throw ControlError.invalidResponse }
        if offset == 0 { try Data().write(to: file, options: .atomic) }
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        guard try handle.seekToEnd() == UInt64(offset) else { throw ControlError.invalidResponse }
        try handle.write(contentsOf: data)
        guard offset + data.count == track.size else { return false }
        try handle.synchronize()
        let complete = try Data(contentsOf: file, options: .mappedIfSafe)
        let hash = SHA256.hash(data: complete).map { String(format: "%02x", $0) }.joined()
        guard complete.count == track.size, hash == track.sha256 else { throw ControlError.invalidResponse }
        return true
    }
}
