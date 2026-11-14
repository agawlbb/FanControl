import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public struct PodcastEpisode: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let published: Date
    public let audioURL: URL
    public let series: String
    public let season: Int?
    public var group: String { season.map { "Season \($0)" } ?? "Films" }
    public init(id: String, title: String, published: Date, audioURL: URL, series: String, season: Int?) {
        self.id = id; self.title = title; self.published = published; self.audioURL = audioURL; self.series = series; self.season = season
    }
    public static let seriesOrder = ["The Original Series", "The Animated Series", "The Next Generation", "Deep Space Nine", "Voyager", "Enterprise", "Films"]
    public static func category(title: String, kind: String) -> (String, Int?)? {
        let lower = title.lowercased()
        guard !["bonus", "trailer"].contains(kind.lowercased()), !lower.contains("supplemental") else { return nil }
        for series in seriesOrder where series != "Films" && lower.contains(series.lowercased()) {
            guard lower.range(of: #"episodes?\s+[0-9]+"#, options: .regularExpression) != nil,
                  let range = lower.range(of: #"season\s+([0-9]+)"#, options: .regularExpression),
                  let season = Int(lower[range].split(whereSeparator: { !$0.isNumber }).joined()), season > 0 else { continue }
            return (series, season)
        }
        let films = ["Star Trek: The Motion Picture", "Star Trek II: The Wrath of Khan", "Star Trek III: The Search for Spock", "Star Trek IV: The Voyage Home", "Star Trek V: The Final Frontier", "Star Trek VI: The Undiscovered Country", "Star Trek: Generations", "Star Trek: First Contact", "Star Trek: Insurrection", "Star Trek: Nemesis"]
        return films.contains(where: { $0.lowercased() == lower.trimmingCharacters(in: .whitespacesAndNewlines) }) ? ("Films", nil) : nil
    }
}

public final class PodcastFeed: NSObject, XMLParserDelegate {
    public static let url = URL(string: "https://missionlog.libsyn.com/rss")!
    private var episodes: [PodcastEpisode] = []
    private var item: [String: String]?
    private var field = ""
    private var text = ""
    private var enclosure: String?
    public static func parse(_ data: Data) throws -> [PodcastEpisode] {
        let delegate = PodcastFeed(); let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false; parser.delegate = delegate
        guard parser.parse(), !delegate.episodes.isEmpty else { throw PodcastError.invalidFeed }
        var seen = Set<String>()
        return delegate.episodes.filter { seen.insert($0.id).inserted }.sorted { $0.published == $1.published ? $0.id < $1.id : $0.published < $1.published }
    }
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        if elementName == "item" { item = [:]; enclosure = nil }
        if elementName == "enclosure", let type = attributes["type"], type.lowercased() == "audio/mpeg" { enclosure = attributes["url"] }
        field = elementName; text = ""
    }
    public func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }
    public func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) { text += String(data: CDATABlock, encoding: .utf8) ?? "" }
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if item != nil, field == elementName { item?[field] = text.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard elementName == "item", let value = item else { return }
        defer { item = nil }
        let date = DateFormatter(); date.locale = Locale(identifier: "en_US_POSIX"); date.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        guard let id = value["guid"], !id.isEmpty, let title = value["title"],
              let category = PodcastEpisode.category(title: title, kind: value["itunes:episodeType"] ?? "full"),
              let published = value["pubDate"].flatMap(date.date(from:)),
              let raw = enclosure, var parts = URLComponents(string: raw), ["http", "https"].contains(parts.scheme?.lowercased() ?? "") else { return }
        parts.scheme = "https"
        guard let url = parts.url, url.host != nil else { return }
        episodes.append(PodcastEpisode(id: id, title: title, published: published, audioURL: url, series: category.0, season: category.1))
    }
}

public enum PodcastError: Error { case invalidFeed, unavailable, staleCommand }
public struct PodcastHistory: Codable, Equatable, Sendable {
    public var position: Double = 0
    public var completed = false
    public init(position: Double = 0, completed: Bool = false) { self.position = position; self.completed = completed }
}
public struct PodcastQueue: Codable, Sendable {
    public var episodes: [PodcastEpisode] = []
    public var history: [String: PodcastHistory] = [:]
    public private(set) var lastCompletedID: String?
    public private(set) var currentID: String?
    public private(set) var revision = UUID()
    public init() {}
    public var current: PodcastEpisode? { episodes.first { $0.id == currentID } }
    public var window: [PodcastEpisode] {
        guard let index = episodes.firstIndex(where: { $0.id == currentID }) else { return [] }
        return Array(([episodes[index]] + episodes.dropFirst(index + 1).filter { history[$0.id]?.completed != true }).prefix(5))
    }
    public mutating func merge(_ fresh: [PodcastEpisode]) {
        let retained = episodes.filter { old in !fresh.contains { $0.id == old.id } }
        episodes = (fresh + retained).sorted { $0.published == $1.published ? $0.id < $1.id : $0.published < $1.published }
        if currentID == nil, let lastCompletedID, let index = episodes.firstIndex(where: { $0.id == lastCompletedID }),
           let next = episodes.dropFirst(index + 1).first(where: { history[$0.id]?.completed != true }) { select(next.id) }
    }
    public mutating func select(_ id: String) {
        guard episodes.contains(where: { $0.id == id }) else { return }
        currentID = id; revision = UUID()
        if history[id]?.completed == true { history[id] = PodcastHistory() }
    }
    public mutating func save(position: Double) {
        guard let currentID, position.isFinite else { return }
        var value = history[currentID] ?? PodcastHistory(); value.position = max(0, position); history[currentID] = value
    }
    public mutating func complete() {
        guard let id = currentID else { return }
        let next = window.dropFirst().first
        lastCompletedID = id
        var value = history[id] ?? PodcastHistory(); value.completed = true; history[id] = value
        currentID = next?.id; revision = UUID()
        if let currentID { history[currentID] = PodcastHistory() }
    }
    public func cellularSuccessor(downloaded: Set<String>) -> PodcastEpisode? {
        guard let currentID, downloaded.contains(currentID), window.filter({ downloaded.contains($0.id) }).last?.id == currentID else { return nil }
        return window.dropFirst().first
    }
}

public enum PodcastAction: String, Codable, Sendable { case playCurrent, play, pause, seek, backward15, forward15, complete, state }
public struct PodcastCommand: Codable, Equatable, Sendable {
    public let id: UUID
    public let action: PodcastAction
    public let episodeID: String?
    public let revision: UUID?
    public let position: Double?
    public let issued: Date
    public init(action: PodcastAction, episodeID: String? = nil, revision: UUID? = nil, position: Double? = nil, id: UUID = UUID(), issued: Date = Date()) {
        self.id = id; self.action = action; self.episodeID = episodeID; self.revision = revision; self.position = position; self.issued = issued
    }
    public func valid(for queue: PodcastQueue, now: Date = Date()) -> Bool {
        guard now.timeIntervalSince(issued) >= -2, now.timeIntervalSince(issued) <= 10 else { return false }
        if action == .state || action == .playCurrent { return true }
        guard queue.currentID != nil, episodeID == queue.currentID, revision == queue.revision else { return false }
        return action != .seek || position.map { $0.isFinite && $0 >= 0 } == true
    }
}
public struct PodcastSnapshot: Codable, Equatable, Sendable {
    public var episode: PodcastEpisode?
    public var revision: UUID
    public var sequence: Int64
    public var position: Double
    public var duration: Double
    public var playing: Bool
    public var downloaded: Bool
    public var status: String
    public var at: Date
    public init(episode: PodcastEpisode?, revision: UUID, sequence: Int64, position: Double, duration: Double, playing: Bool, downloaded: Bool, status: String, at: Date = Date()) {
        self.episode = episode; self.revision = revision; self.sequence = sequence; self.position = position; self.duration = duration; self.playing = playing; self.downloaded = downloaded; self.status = status; self.at = at
    }
}
public struct PodcastReply: Codable, Sendable {
    public let commandID: UUID
    public let accepted: Bool
    public let snapshot: PodcastSnapshot
    public let error: String?
    public init(commandID: UUID, accepted: Bool, snapshot: PodcastSnapshot, error: String? = nil) {
        self.commandID = commandID; self.accepted = accepted; self.snapshot = snapshot; self.error = error
    }
}

// Podcast placement is phone/watch-local; never serialize this ID into HA device order.
public enum PodcastTile {
    public static let id = "local:podcast"
    public static func order(devices: [String], index: Int?) -> [String] {
        var result = devices.filter { $0 != id }
        result.insert(id, at: min(result.count, max(0, index ?? result.count)))
        return result
    }
    public static func time(_ seconds: Double) -> String {
        let value = seconds.isFinite ? Int(max(0, min(seconds, 99_999_999))) : 0
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

public extension PodcastReply {
    // Delivery alone is never playback evidence. Bind the result to this exact
    // command and episode/queue, including completion's intentional queue change.
    func confirms(_ command: PodcastCommand, now: Date = Date()) -> Bool {
        guard commandID == command.id, accepted,
              now.timeIntervalSince(command.issued) <= 10,
              snapshot.at.timeIntervalSince(command.issued) >= -2 else { return false }
        if command.action == .state { return true }
        if command.action == .playCurrent { return snapshot.episode != nil && snapshot.playing }
        if command.action == .complete {
            return !snapshot.playing && snapshot.revision != command.revision && snapshot.episode?.id != command.episodeID
        }
        guard snapshot.episode?.id == command.episodeID, snapshot.revision == command.revision else { return false }
        switch command.action {
        case .play: return snapshot.playing
        case .pause: return !snapshot.playing
        case .seek:
            guard let position = command.position else { return false }
            return abs(snapshot.position - min(position, max(0, snapshot.duration - 0.05))) < 1
        case .backward15, .forward15: return snapshot.position.isFinite
        default: return false
        }
    }
}
