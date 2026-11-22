import XCTest
@testable import FanControlCore

final class PodcastWatchTitleTests: XCTestCase {
    private func display(_ title: String, series: String = "Voyager", season: Int? = 4) -> PodcastWatchTitle {
        PodcastWatchTitle(PodcastEpisode(id: "fixture", title: title, published: Date(),
            audioURL: URL(string: "https://example.com/fixture.mp3")!, series: series, season: season))
    }

    func testPhotoTitleSeparatesSeriesNumbersAndQuotedEpisodeName() {
        let value = display("Star Trek: Voyager, Season 4, Episode 8 & 9 - \"Year of Hell Part I & Part II\"")
        XCTAssertEqual(value.heading, "Voyager S4 E8&9")
        XCTAssertEqual(value.title, "Year of Hell Part I & Part II")
    }

    func testSingleEpisodeAndAlternateRangeSeparators() {
        XCTAssertEqual(display("Voyager Season 4 Episode 8: Year of Hell").heading, "Voyager S4 E8")
        XCTAssertEqual(display("Voyager Season 4 Episode 8: Year of Hell").title, "Year of Hell")
        for separator in ["-", "–", "—"] {
            let value = display("Voyager, Season 4, Episodes 8 \(separator) 9 — Year of Hell")
            XCTAssertEqual(value.heading, "Voyager S4 E8–9")
            XCTAssertEqual(value.title, "Year of Hell")
        }
        XCTAssertEqual(display("Voyager Season 4 Episodes 8 and 9, Year of Hell").heading, "Voyager S4 E8&9")
    }

    func testFilmAndUnrecognizedTitleKeepUsefulTextWithoutInventedEpisodeNumbers() {
        let film = display("Star Trek: First Contact", series: "Films", season: nil)
        XCTAssertEqual(film.heading, "Films")
        XCTAssertEqual(film.title, "First Contact")
        let unknown = display("A discussion of 1996", series: "Star Trek: Voyager")
        XCTAssertEqual(unknown.heading, "Voyager S4")
        XCTAssertEqual(unknown.title, "A discussion of 1996")
        XCTAssertEqual(display("Voyager Season 4 Episode 8").title, "Voyager")
    }
}
