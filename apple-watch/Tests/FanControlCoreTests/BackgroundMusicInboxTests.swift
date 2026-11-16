import XCTest
import CryptoKit
@testable import FanControlCore

final class BackgroundMusicInboxTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    private func fixture(_ value: UInt8 = 7, generation: Int64 = 1) throws -> (URL, OfflinePlaylist, Data) {
        let data = Data(repeating: value, count: OfflineMusicTransfer.chunkSize + 19)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let track = ExerciseTrack(name: "test.mp3", sha256: hash, size: data.count)
        let playlist = try OfflinePlaylist(watchID: "watch", tracks: [track], generation: generation)
        let source = root.appendingPathComponent(UUID().uuidString)
        try data.write(to: source)
        return (source, playlist, data)
    }
    func testBackgroundDeliveryInstallsAfterOriginalTempFileAndProcessAreGone() throws {
        let (source, playlist, bytes) = try fixture()
        let inboxRoot = root.appendingPathComponent("inbox")
        try BackgroundMusicInbox(root: inboxRoot).enqueue(file: source, playlist: playlist, fileName: playlist.tracks[0].fileName)
        try FileManager.default.removeItem(at: source) // WCSession delegate returned.
        // Reconstruct the process, with no foreground UI or reachable phone.
        let restarted = BackgroundMusicInbox(root: inboxRoot)
        var installed = 0
        restarted.installPending { delivery, file in
            do {
                XCTAssertEqual(delivery.playlist, playlist)
                let target = root.appendingPathComponent("installed").appendingPathComponent(delivery.fileName)
                try OfflineMusicTransfer.saveVerified(Data(contentsOf: file), to: target, track: delivery.playlist.tracks[0])
                XCTAssertEqual(try Data(contentsOf: target), bytes)
                installed += 1
                return true
            } catch { XCTFail("\(error)"); return false }
        }
        XCTAssertEqual(installed, 1)
        XCTAssertTrue(restarted.pending().isEmpty)
        restarted.installPending { _, _ in XCTFail("Already installed delivery replayed"); return false }
    }
    func testFailedInstallIsRetainedUntilLaterBackgroundWakeSucceeds() throws {
        let (source, playlist, bytes) = try fixture()
        let inboxRoot = root.appendingPathComponent("inbox")
        let inbox = BackgroundMusicInbox(root: inboxRoot)
        try inbox.enqueue(file: source, playlist: playlist, fileName: playlist.tracks[0].fileName)
        inbox.installPending { _, _ in false }
        let restarted = BackgroundMusicInbox(root: inboxRoot)
        XCTAssertEqual(restarted.pending().count, 1)
        restarted.installPending { _, file in
            XCTAssertEqual(try? Data(contentsOf: file), bytes)
            return true
        }
        XCTAssertTrue(restarted.pending().isEmpty)
    }
    func testMultipleBackgroundFilesInstallOnlyWholeVerifiedReplacementWithoutForeground() throws {
        let (source1, one, bytes1) = try fixture(4)
        let (source2, two, bytes2) = try fixture(5)
        let manifest = try OfflinePlaylist(watchID: "watch", tracks: one.tracks + two.tracks, generation: 2)
        let libraryRoot = root.appendingPathComponent("library")
        let oldDirectory = libraryRoot.appendingPathComponent(one.id.uuidString)
        try OfflineMusicTransfer.saveVerified(bytes1, to: oldDirectory.appendingPathComponent(one.tracks[0].fileName), track: one.tracks[0])
        XCTAssertTrue(try OfflineMusicLibrary.installIfComplete(one, at: libraryRoot))
        let inboxRoot = root.appendingPathComponent("inbox")
        let inbox = BackgroundMusicInbox(root: inboxRoot)
        try inbox.enqueue(file: source2, playlist: manifest, fileName: two.tracks[0].fileName)
        try FileManager.default.removeItem(at: source2)
        var complete = false
        let install: (BackgroundMusicInbox.Delivery, URL) -> Bool = { delivery, file in
            do {
                let track = try XCTUnwrap(delivery.playlist.tracks.first { $0.fileName == delivery.fileName })
                let target = libraryRoot.appendingPathComponent(delivery.playlist.id.uuidString).appendingPathComponent(delivery.fileName)
                try OfflineMusicTransfer.saveVerified(Data(contentsOf: file), to: target, track: track)
                complete = try OfflineMusicLibrary.installIfComplete(delivery.playlist, at: libraryRoot)
                return true // Durable verified file, even while other songs are pending.
            } catch { XCTFail("\(error)"); return false }
        }
        inbox.installPending(install)
        XCTAssertFalse(complete)
        let playlistFile = libraryRoot.appendingPathComponent("playlist.json")
        XCTAssertEqual(try JSONDecoder().decode(OfflineMusicLibrary.self, from: Data(contentsOf: playlistFile)).directory, one.id.uuidString)
        try inbox.enqueue(file: source1, playlist: manifest, fileName: one.tracks[0].fileName)
        try FileManager.default.removeItem(at: source1)
        BackgroundMusicInbox(root: inboxRoot).installPending(install)
        XCTAssertTrue(complete)
        let installed = try JSONDecoder().decode(OfflineMusicLibrary.self, from: Data(contentsOf: playlistFile))
        XCTAssertEqual(installed.directory, manifest.id.uuidString)
        XCTAssertEqual(installed.tracks, manifest.tracks)
        XCTAssertEqual(try Data(contentsOf: libraryRoot.appendingPathComponent(installed.directory).appendingPathComponent(two.tracks[0].fileName)), bytes2)
        XCTAssertEqual(try Data(contentsOf: oldDirectory.appendingPathComponent(one.tracks[0].fileName)), bytes1)
    }
    func testOutOfOrderDeliveriesAreRecoveredInGenerationOrder() throws {
        let (newFile, newer, _) = try fixture(9, generation: 2)
        let (oldFile, older, _) = try fixture(8, generation: 1)
        let inbox = BackgroundMusicInbox(root: root.appendingPathComponent("inbox"))
        try inbox.enqueue(file: newFile, playlist: newer, fileName: newer.tracks[0].fileName)
        try inbox.enqueue(file: oldFile, playlist: older, fileName: older.tracks[0].fileName)
        XCTAssertEqual(inbox.pending().map { $0.playlist.id }, [older.id, newer.id])
    }
    func testIncompleteOrCorruptDeliveryCannotBecomePendingInstallation() throws {
        let (source, playlist, _) = try fixture()
        let inbox = BackgroundMusicInbox(root: root.appendingPathComponent("inbox"))
        try Data([1, 2]).write(to: source)
        XCTAssertThrowsError(try inbox.enqueue(file: source, playlist: playlist, fileName: playlist.tracks[0].fileName))
        let incomplete = inbox.root.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: incomplete, withIntermediateDirectories: true)
        try Data([3]).write(to: incomplete.appendingPathComponent("audio"))
        XCTAssertTrue(inbox.pending().isEmpty)
    }
    func testUnknownTrackRejectedAndForgetDeletesQueuedPrivateAudio() throws {
        let (source, playlist, _) = try fixture()
        let inbox = BackgroundMusicInbox(root: root.appendingPathComponent("inbox"))
        XCTAssertThrowsError(try inbox.enqueue(file: source, playlist: playlist, fileName: "../audio"))
        let delivery = try inbox.enqueue(file: source, playlist: playlist, fileName: playlist.tracks[0].fileName)
        let privateFile = inbox.file(for: delivery)
        XCTAssertTrue(FileManager.default.fileExists(atPath: privateFile.path))
        try inbox.removeAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: privateFile.path))
        XCTAssertTrue(inbox.pending().isEmpty)
    }
}
