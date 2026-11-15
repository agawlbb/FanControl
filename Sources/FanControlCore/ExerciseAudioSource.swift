import Foundation
import CryptoKit
import AVFoundation

public struct ExerciseAudioSource {
    public let url: URL
    public let fileTypeHint: String?

    public static func prepare(_ track: ExerciseTrack, in directory: URL) throws -> ExerciseAudioSource {
        try track.validate()
        let url = directory.appendingPathComponent(track.fileName)
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard data.count == track.size, hash == track.sha256 else { throw MusicFileFailure.checksumMismatch }
        let hint: String?
        switch url.pathExtension.lowercased() {
        case "mp3": hint = AVFileType.mp3.rawValue
        case "m4a": hint = AVFileType.m4a.rawValue
        default: hint = nil
        }
        return ExerciseAudioSource(url: url, fileTypeHint: hint)
    }
}
