import XCTest
@testable import FanControlCore

final class ExerciseMusicTests: XCTestCase {
    func testOnlyPreferredHeadsetOrExplicitSpeakerChoiceMayPlay() {
        XCTAssertTrue(ExerciseAudioRoute.isPreferred(name: "Joseph's Buds2 Pro", uid: "new", rememberedUID: "old"))
        XCTAssertTrue(ExerciseAudioRoute.isPreferred(name: "Joseph’s Buds2 Pro", uid: "", rememberedUID: nil))
        XCTAssertFalse(ExerciseAudioRoute.isPreferred(name: "Other headphones", uid: "other", rememberedUID: "buds"))
        XCTAssertTrue(ExerciseAudioRoute.mayPlay(preferredHeadset: true, builtInSpeaker: false, speakerChosen: false))
        XCTAssertFalse(ExerciseAudioRoute.mayPlay(preferredHeadset: false, builtInSpeaker: true, speakerChosen: false))
        XCTAssertTrue(ExerciseAudioRoute.mayPlay(preferredHeadset: false, builtInSpeaker: true, speakerChosen: true))
        XCTAssertFalse(ExerciseAudioRoute.mayPlay(preferredHeadset: false, builtInSpeaker: false, speakerChosen: true))
    }
    func testPrivateManifestRejectsPathsInvalidHashesAndOversizedFiles() throws {
        func track(_ name: String, _ size: Int = 10, _ digest: String = String(repeating: "a", count: 64)) throws -> ExerciseTrack {
            let data = try JSONSerialization.data(withJSONObject: ["name":name, "size":size, "sha256":digest])
            return try JSONDecoder().decode(ExerciseTrack.self, from:data)
        }
        let valid = try track("01 Song.MP3")
        XCTAssertNoThrow(try valid.validate())
        XCTAssertEqual(valid.fileName, String(repeating:"a",count:64) + ".mp3")
        for name in ["../secret.mp3", "folder\\song.mp3", "file.exe", ""] {
            XCTAssertThrowsError(try track(name).validate())
        }
        XCTAssertThrowsError(try track("song.mp3", 0).validate())
        XCTAssertThrowsError(try track("song.mp3", 31 * 1024 * 1024).validate())
        XCTAssertThrowsError(try track("song.mp3", 100, "../bad").validate())
    }
}
