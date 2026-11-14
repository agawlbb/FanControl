import XCTest
@testable import FanControlCore

final class PodcastTests: XCTestCase {
    private func episode(_ n: Int) -> PodcastEpisode {
        PodcastEpisode(id: "e\(n)", title: "Voyager Season 1 Episode \(n)", published: Date(timeIntervalSince1970: Double(n)), audioURL: URL(string: "https://example.com/\(n).mp3")!, series: "Voyager", season: 1)
    }
    func testFeedFiltersExtrasDeduplicatesAndOrdersOldestFirst() throws {
        func item(_ id: String, _ title: String, _ day: String, _ kind: String = "full") -> String {
            "<item><guid>\(id)</guid><title><![CDATA[\(title)]]></title><pubDate>Thu, \(day) Nov 2026 08:00:00 +0000</pubDate><itunes:episodeType>\(kind)</itunes:episodeType><enclosure url=\"http://example.com/\(id).mp3?source=rss&amp;v=1\" type=\"audio/mpeg\" length=\"1000\"/></item>"
        }
        let xml = "<rss xmlns:itunes=\"http://www.itunes.com/dtds/podcast-1.0.dtd\"><channel>" +
            item("new", "Star Trek: Enterprise, Season 1, Episode 5, Unexpected", "12") +
            item("bonus", "Star Trek: Voyager, Season 6 Wrap Up", "05", "bonus") +
            item("supp", "SUPPLEMENTAL: Star Trek Voyager Season 6", "05") +
            item("film", "Star Trek: First Contact", "05") +
            item("extra", "Happy New Year from Mission Log!", "05") +
            item("new", "Star Trek: Enterprise, Season 1, Episode 5, Unexpected", "12") + "</channel></rss>"
        let parsed = try PodcastFeed.parse(Data(xml.utf8))
        XCTAssertEqual(parsed.map(\.id), ["film", "new"])
        XCTAssertEqual(parsed.last?.series, "Enterprise")
        XCTAssertEqual(parsed.last?.season, 1)
        XCTAssertEqual(parsed.first?.series, "Films")
        XCTAssertEqual(parsed.last?.audioURL.scheme, "https")
        XCTAssertEqual(parsed.last?.audioURL.query, "source=rss&v=1")
        XCTAssertThrowsError(try PodcastFeed.parse(Data("<html>Not a feed</html>".utf8)))
    }
    func testSeriesSeasonAndSpecialClassification() {
        for series in PodcastEpisode.seriesOrder where series != "Films" {
            XCTAssertEqual(PodcastEpisode.category(title: "Star Trek: \(series), Season 7, Episodes 1-2", kind: "full")?.0, series)
            XCTAssertEqual(PodcastEpisode.category(title: "Star Trek: \(series), Season 7, Episodes 1-2", kind: "full")?.1, 7)
        }
        for title in ["A Brief Transmission", "Vegan Bacon", "011011000110111101100111", "STLV FOMO 2025", "Star Trek V: The Final Frontier - Pod Crawl Special Edition"] {
            XCTAssertNil(PodcastEpisode.category(title: title, kind: "full"))
        }
        XCTAssertNil(PodcastEpisode.category(title: "Voyager Season 2", kind: "trailer"))
        XCTAssertNil(PodcastEpisode.category(title: "SUPPLEMENTAL 86: Voyager Season 2", kind: "full"))
    }
    func testWindowProgressCompletionAndReplay() throws {
        var queue = PodcastQueue(); queue.merge((1...8).map(episode)); queue.select("e2")
        XCTAssertEqual(queue.window.map(\.id), ["e2", "e3", "e4", "e5", "e6"])
        queue.save(position: 123); let revision = queue.revision
        let restored = try JSONDecoder().decode(PodcastQueue.self, from: JSONEncoder().encode(queue))
        XCTAssertEqual(restored.history["e2"]?.position, 123)
        queue.complete()
        XCTAssertTrue(queue.history["e2"]?.completed == true)
        XCTAssertEqual(queue.currentID, "e3")
        XCTAssertEqual(queue.history["e3"]?.position, 0)
        XCTAssertNotEqual(queue.revision, revision)
        queue.select("e2")
        XCTAssertFalse(queue.history["e2"]!.completed)
        XCTAssertEqual(queue.history["e2"]?.position, 0)
    }
    func testCellularExceptionOnlyForLastDownloadedEpisode() {
        var queue = PodcastQueue(); queue.merge((1...7).map(episode)); queue.select("e2")
        XCTAssertEqual(queue.cellularSuccessor(downloaded: ["e2"])?.id, "e3")
        XCTAssertNil(queue.cellularSuccessor(downloaded: ["e2", "e3"]))
        XCTAssertNil(queue.cellularSuccessor(downloaded: []))
        queue.select("e7")
        XCTAssertNil(queue.cellularSuccessor(downloaded: ["e7"]))
    }
    func testCompletionSkipsPlayedAndNewReleaseContinuesQueue() {
        var queue = PodcastQueue(); queue.merge((1...3).map(episode)); queue.select("e1")
        queue.history["e2"] = PodcastHistory(completed: true)
        queue.complete(); XCTAssertEqual(queue.currentID, "e3")
        queue.complete(); XCTAssertNil(queue.currentID)
        queue.merge((1...4).map(episode)); XCTAssertEqual(queue.currentID, "e4")
        XCTAssertEqual(queue.window.map(\.id), ["e4"])
        queue.merge([episode(5)])
        XCTAssertEqual(queue.currentID, "e4", "A shortened feed must not remove the selected episode")
    }
    func testAbsoluteCommandRejectsStaleEpisodeRevisionExpiryAndInvalidSeek() {
        var queue = PodcastQueue(); queue.merge((1...3).map(episode)); queue.select("e1")
        let now = Date()
        let command = PodcastCommand(action: .complete, episodeID: "e1", revision: queue.revision, issued: now)
        XCTAssertTrue(command.valid(for: queue, now: now))
        XCTAssertFalse(command.valid(for: queue, now: now.addingTimeInterval(11)))
        queue.complete()
        XCTAssertFalse(command.valid(for: queue, now: now), "Retry must not complete the following episode")
        XCTAssertFalse(PodcastCommand(action: .pause, episodeID: "e2", revision: UUID()).valid(for: queue))
        XCTAssertFalse(PodcastCommand(action: .seek, episodeID: "e2", revision: queue.revision, position: .nan).valid(for: queue))
        XCTAssertFalse(PodcastCommand(action: .seek, episodeID: "e2", revision: queue.revision, position: -15).valid(for: queue))
        XCTAssertTrue(PodcastCommand(action: .seek, episodeID: "e2", revision: queue.revision, position: 15).valid(for: queue))
    }
    func testPodcastTileOrderingAndNavigationAreLocal() {
        let order = PodcastTile.order(devices: ["a", "b"], index: 1)
        XCTAssertEqual(order, ["a", PodcastTile.id, "b"])
        XCTAssertEqual(WatchPage.next(.device("a"), entities: order, direction: 1), .podcast)
        XCTAssertEqual(WatchPage.next(.podcast, entities: order, direction: 1), .device("b"))
        XCTAssertEqual(WatchPage.next(.podcast, entities: order, direction: -1), .device("a"))
        XCTAssertEqual(PodcastTile.order(devices: ["a"], index: 99), ["a", PodcastTile.id])
        XCTAssertEqual(CompanionSettings(order: order).ordered(["a", "b"]), ["a", "b"])
    }
}
