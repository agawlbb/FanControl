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
    public static func resumeOffset(at file: URL, track: ExerciseTrack) throws -> Int {
        try track.validate()
        guard FileManager.default.fileExists(atPath: file.path) else { return 0 }
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.uint64Value <= UInt64(track.size) else { throw MusicFileFailure.wrongOffset }
        let offset = Int(size.uint64Value)
        guard offset == track.size || offset % chunkSize == 0 else { throw MusicFileFailure.wrongOffset }
        if offset == track.size { try verify(Data(contentsOf: file, options: .mappedIfSafe), track: track) }
        return offset
    }
    public static func saveVerified(_ data: Data, to file: URL, track: ExerciseTrack) throws {
        try verify(data, track: track)
        // Background delivery needs the same write-boundary preparation as live
        // chunks; a prior manifest callback is not a storage guarantee.
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
    }
    private static func verify(_ data: Data, track: ExerciseTrack) throws {
        try track.validate()
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard data.count == track.size, hash == track.sha256 else { throw MusicFileFailure.checksumMismatch }
    }
    public static func append(_ data: Data, to file: URL, track: ExerciseTrack, offset: Int) throws -> Bool {
        guard data.count == (try byteCount(track: track, offset: offset)) else { throw MusicFileFailure.invalidSize }
        if offset == 0 {
            // The directory prepared before the async phone request may no
            // longer exist. Establish it at the actual first write, then save
            // real bytes rather than creating/reopening an empty placeholder.
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
        } else {
            // Never manufacture a missing prefix for a later chunk.
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            guard try handle.seekToEnd() == UInt64(offset) else { throw MusicFileFailure.wrongOffset }
            try handle.write(contentsOf: data)
            if offset + data.count == track.size { try handle.synchronize() }
        }
        guard offset + data.count == track.size else { return false }
        let complete = try Data(contentsOf: file, options: .mappedIfSafe)
        try verify(complete, track: track)
        return true
    }
}
