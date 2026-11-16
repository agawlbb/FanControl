import XCTest
import CryptoKit
@testable import FanControlCore

final class OfflineMusicTransferTests: XCTestCase {
    private func track(_ data: Data) -> ExerciseTrack {
        ExerciseTrack(name: "one.mp3", sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), size: data.count)
    }
    private func temporaryFile() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    func testCleanupPreservesSleepingTransferAndInstalledPlaybackAcrossDirectoryURLForms() throws {
        let root = temporaryFile()
        defer { try? FileManager.default.removeItem(at: root) }
        let incoming = UUID().uuidString, installed = UUID().uuidString, playing = UUID().uuidString, obsolete = UUID().uuidString
        let bytes = Data(repeating: 3, count: chunkSizeForTest)
        let song = track(bytes)
        for name in [incoming, installed, playing, obsolete] {
            try OfflineMusicTransfer.saveVerified(bytes, to: root.appendingPathComponent(name).appendingPathComponent(song.fileName), track: song)
        }
        let partial = root.appendingPathComponent(incoming).appendingPathComponent("prefix.part")
        try bytes.write(to: partial)
        // Enumerated URLs and appended URLs have different directory forms.
        // Repeated manifest delivery after wrist-down must keep both generations.
        for _ in 0..<3 {
            try OfflineMusicTransfer.pruneGenerations(in: root, keeping: [incoming, installed, playing])
        }
        XCTAssertEqual(try Data(contentsOf: partial), bytes)
        for name in [incoming, installed, playing] {
            try OfflineMusicTransfer.verifyFile(at: root.appendingPathComponent(name).appendingPathComponent(song.fileName), track: song)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(obsolete).path))
        try OfflineMusicTransfer.pruneGenerations(in: root, keeping: [incoming, playing])
        try OfflineMusicTransfer.verifyFile(at: root.appendingPathComponent(incoming).appendingPathComponent(song.fileName), track: song)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(installed).path))
    }
    private var chunkSizeForTest: Int { OfflineMusicTransfer.chunkSize }
    func testTransportCompletionCannotDisplayInstalledProgress() {
        XCTAssertEqual(OfflineMusicTransfer.sendingProgress(1), 0.99)
        XCTAssertEqual(OfflineMusicTransfer.sendingProgress(0.11), 0.11)
    }
    func testSingleSongRequiresAllChunksAndMatchingHash() throws {
        let data = Data((0..<(OfflineMusicTransfer.chunkSize * 2 + 17)).map { UInt8($0 % 251) })
        let song = track(data), file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        var offset = 0
        while offset < data.count {
            let count = try OfflineMusicTransfer.byteCount(track: song, offset: offset)
            let complete = try OfflineMusicTransfer.append(data.subdata(in: offset..<(offset + count)), to: file, track: song, offset: offset)
            offset += count
            XCTAssertEqual(complete, offset == data.count)
        }
        XCTAssertEqual(try Data(contentsOf: file), data)
    }
    func testFirstChunkCreatesMissingNestedStagingAndVerifies() throws {
        let root = temporaryFile()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("Music/pairing/playlist/song.mp3.part")
        let data = Data(repeating: 5, count: 41)
        XCTAssertTrue(try OfflineMusicTransfer.append(data, to: file, track: track(data), offset: 0))
        XCTAssertEqual(try Data(contentsOf: file), data)
    }
    func testStagingRemovedWhileWaitingForFirstReplyIsRecreated() throws {
        let root = temporaryFile()
        defer { try? FileManager.default.removeItem(at: root) }
        let staging = root.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let file = staging.appendingPathComponent("song.mp3.part")
        let data = Data(repeating: 6, count: OfflineMusicTransfer.chunkSize + 9)
        // The first response arrives after its staging directory has disappeared.
        try FileManager.default.removeItem(at: staging)
        XCTAssertFalse(try OfflineMusicTransfer.append(data.prefix(OfflineMusicTransfer.chunkSize), to: file, track: track(data), offset: 0))
        XCTAssertTrue(try OfflineMusicTransfer.append(data.suffix(9), to: file, track: track(data), offset: OfflineMusicTransfer.chunkSize))
        XCTAssertEqual(try Data(contentsOf: file), data)
    }
    func testLaterChunkCannotRecreateMissingPrefix() throws {
        let root = temporaryFile()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("missing/song.mp3.part")
        let data = Data(repeating: 7, count: OfflineMusicTransfer.chunkSize + 3)
        XCTAssertThrowsError(try OfflineMusicTransfer.append(data.suffix(3), to: file, track: track(data), offset: OfflineMusicTransfer.chunkSize))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }
    func testResumesAtPhotographedOffsetAfterReopeningPartialFile() throws {
        let root = temporaryFile()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("playlist/song.mp3.part")
        let data = Data((0..<(OfflineMusicTransfer.chunkSize * 23 + 11)).map { UInt8($0 % 251) })
        let song = track(data)
        var offset = 0
        for _ in 0..<21 {
            let end = offset + OfflineMusicTransfer.chunkSize
            XCTAssertFalse(try OfflineMusicTransfer.append(data.subdata(in: offset..<end), to: file, track: song, offset: offset))
            offset = end
        }
        XCTAssertEqual(offset, 688128)
        // Reopening the persisted prefix after a lost live request must not
        // truncate it or request byte zero again.
        offset = try OfflineMusicTransfer.resumeOffset(at: file, track: song)
        XCTAssertEqual(offset, 688128)
        while offset < data.count {
            let count = try OfflineMusicTransfer.byteCount(track: song, offset: offset)
            let complete = try OfflineMusicTransfer.append(data.subdata(in: offset..<(offset + count)), to: file, track: song, offset: offset)
            offset += count
            XCTAssertEqual(complete, offset == data.count)
        }
        XCTAssertEqual(try Data(contentsOf: file), data)
        XCTAssertEqual(try OfflineMusicTransfer.resumeOffset(at: file, track: song), data.count)
    }
    func testIncompleteOrOversizedPrefixCannotResume() throws {
        let root = temporaryFile()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("partial")
        let song = track(Data(repeating: 1, count: OfflineMusicTransfer.chunkSize + 9))
        XCTAssertEqual(try OfflineMusicTransfer.resumeOffset(at: file, track: song), 0)
        try Data(repeating: 1, count: 13).write(to: file)
        XCTAssertThrowsError(try OfflineMusicTransfer.resumeOffset(at: file, track: song))
        try Data(repeating: 1, count: song.size + 1).write(to: file)
        XCTAssertThrowsError(try OfflineMusicTransfer.resumeOffset(at: file, track: song))
    }
    func testCorruptFullPartialCannotBeInstalledOnResume() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let data = Data(repeating: 1, count: 20)
        try Data(repeating: 2, count: 20).write(to: file)
        XCTAssertThrowsError(try OfflineMusicTransfer.resumeOffset(at: file, track: track(data)))
    }
    func testCorruptAlignedPrefixStillFailsWholeFileVerification() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let data = Data(repeating: 1, count: OfflineMusicTransfer.chunkSize + 9), song = track(data)
        try Data(repeating: 2, count: OfflineMusicTransfer.chunkSize).write(to: file)
        let offset = try OfflineMusicTransfer.resumeOffset(at: file, track: song)
        XCTAssertThrowsError(try OfflineMusicTransfer.append(data.suffix(9), to: file, track: song, offset: offset))
    }
    func testBackgroundAudioCreatesMissingDestinationAndVerifies() throws {
        let root = temporaryFile()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("Music/pairing/playlist/song.mp3")
        let data = Data(repeating: 9, count: 117)
        try OfflineMusicTransfer.saveVerified(data, to: file, track: track(data))
        XCTAssertEqual(try Data(contentsOf: file), data)
    }
    func testInvalidBackgroundFileCannotReplaceInstalledAudio() throws {
        let root = temporaryFile()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("song.mp3"), old = Data([1, 2, 3])
        try old.write(to: file)
        let requested = Data([4, 5, 6])
        XCTAssertThrowsError(try OfflineMusicTransfer.saveVerified(Data([7, 8, 9]), to: file, track: track(requested)))
        XCTAssertEqual(try Data(contentsOf: file), old)
    }
    func testCorruptionNeverConfirmsTrack() throws {
        let data = Data(repeating: 1, count: 20), file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertThrowsError(try OfflineMusicTransfer.append(Data(repeating: 2, count: 20), to: file, track: track(data), offset: 0))
    }
    func testMissingDuplicateAndOversizedChunksRejected() throws {
        let data = Data(repeating: 3, count: OfflineMusicTransfer.chunkSize + 1), song = track(data), file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let first = data.prefix(OfflineMusicTransfer.chunkSize)
        XCTAssertFalse(try OfflineMusicTransfer.append(first, to: file, track: song, offset: 0))
        XCTAssertThrowsError(try OfflineMusicTransfer.append(Data([3]), to: file, track: song, offset: 1))
        XCTAssertThrowsError(try OfflineMusicTransfer.append(data, to: file, track: song, offset: 0))
        XCTAssertThrowsError(try OfflineMusicTransfer.byteCount(track: song, offset: -1))
        XCTAssertThrowsError(try OfflineMusicTransfer.byteCount(track: song, offset: data.count))
    }
    func testInterruptedPartialFileCanRestartAndVerify() throws {
        let data = Data(repeating: 4, count: OfflineMusicTransfer.chunkSize + 7), song = track(data), file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertFalse(try OfflineMusicTransfer.append(data.prefix(OfflineMusicTransfer.chunkSize), to: file, track: song, offset: 0))
        XCTAssertFalse(try OfflineMusicTransfer.append(data.prefix(OfflineMusicTransfer.chunkSize), to: file, track: song, offset: 0))
        XCTAssertTrue(try OfflineMusicTransfer.append(data.suffix(7), to: file, track: song, offset: OfflineMusicTransfer.chunkSize))
    }
    func testScreenOffWakeWaitsForActivationAndPendingContent() {
        let drain = ConnectivityDrain()
        XCTAssertFalse(drain.canComplete(activated: false, hasContentPending: false))
        XCTAssertFalse(drain.canComplete(activated: true, hasContentPending: true))
        XCTAssertTrue(drain.canComplete(activated: true, hasContentPending: false))
    }
    func testDeliveredFilesMustFinishPersistenceBeforeWakeCompletes() {
        let drain = ConnectivityDrain()
        drain.begin(); drain.begin()
        // WCSession can report no pending content while actor work is queued.
        XCTAssertFalse(drain.canComplete(activated: true, hasContentPending: false))
        drain.end()
        XCTAssertFalse(drain.canComplete(activated: true, hasContentPending: false))
        drain.end()
        XCTAssertTrue(drain.canComplete(activated: true, hasContentPending: false))
        drain.begin()
        XCTAssertFalse(drain.canComplete(activated: true, hasContentPending: false))
    }
}
