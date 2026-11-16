import XCTest
import Foundation
import CryptoKit
import AVFoundation
@testable import FanControlCore

final class ExerciseAudioSourceTests: XCTestCase {
    private func fixture() throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "generated-tone", withExtension: "mp3"))
        return try Data(contentsOf: url)
    }
    private func track(_ data: Data) -> ExerciseTrack {
        ExerciseTrack(name: "generated-tone.mp3", sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), size: data.count)
    }
    private func directory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("playlist")
    }
    func testTransferredMP3OpensWithAppleDecoderFromHashedLibraryPath() throws {
        let data = try fixture(), song = track(data), folder = directory()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        try OfflineMusicTransfer.saveVerified(data, to: folder.appendingPathComponent(song.fileName), track: song)
        let source = try ExerciseAudioSource.prepare(song, in: folder)
        let player = try AVAudioPlayer(contentsOf: source.url, fileTypeHint: source.fileTypeHint)
        XCTAssertGreaterThan(player.duration, 0.1)
        XCTAssertEqual(player.numberOfChannels, 2)
        let file = try AVAudioFile(forReading: source.url)
        XCTAssertEqual(file.processingFormat.sampleRate, 44100)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096))
        try file.read(into: buffer)
        XCTAssertGreaterThan(buffer.frameLength, 0)
        // No play(), route selection or audible output in this regression.
    }
    func testMissingSavedTrackKeepsNativeReadErrorWithoutLeakingPath() throws {
        let data = try fixture(), folder = directory()
        XCTAssertThrowsError(try ExerciseAudioSource.prepare(track(data), in: folder)) { error in
            let native = error as NSError
            XCTAssertEqual(native.domain, NSCocoaErrorDomain)
            let message = MusicSyncFeedback.failure(stage: "Reading saved track", error: error)
            XCTAssertTrue(message.contains("NSCocoaErrorDomain"))
            XCTAssertFalse(message.contains(folder.path))
        }
    }
    func testTruncatedStoredAudioRejectedBeforeDecoder() throws {
        let data = try fixture(), song = track(data), folder = directory()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.prefix(data.count / 2).write(to: folder.appendingPathComponent(song.fileName))
        XCTAssertThrowsError(try ExerciseAudioSource.prepare(song, in: folder))
    }
    func testChangedStoredAudioRejectedBeforeDecoder() throws {
        let data = try fixture(), song = track(data), folder = directory()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var modified = data; modified[modified.count / 2] ^= 1
        try modified.write(to: folder.appendingPathComponent(song.fileName))
        XCTAssertThrowsError(try ExerciseAudioSource.prepare(song, in: folder))
    }
}
