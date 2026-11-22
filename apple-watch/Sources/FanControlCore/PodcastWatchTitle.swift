import Foundation

/// Presentation only; the feed title and command target remain unchanged.
public struct PodcastWatchTitle: Equatable, Sendable {
    public let heading: String
    public let title: String

    public init(_ episode: PodcastEpisode) {
        func withoutStarTrek(_ text: String) -> String {
            text.replacingOccurrences(of: #"^\s*Star\s+Trek\s*[:–—-]?\s*"#,
                                      with: "", options: [.regularExpression, .caseInsensitive])
        }
        let series = withoutStarTrek(episode.series)
        let expression = try! NSRegularExpression(
            pattern: #"\bSeason\s+(\d+)\s*[,;:]?\s*Episodes?\s+(\d+(?:\s*(?:&|and|[-–—])\s*\d+)*)"#,
            options: .caseInsensitive)
        let raw = episode.title
        if let match = expression.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
           let season = Range(match.range(at: 1), in: raw),
           let episodes = Range(match.range(at: 2), in: raw),
           let whole = Range(match.range, in: raw) {
            let numbers = raw[episodes]
                .replacingOccurrences(of: #"\s+and\s+"#, with: "&", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: "-", with: "–")
                .replacingOccurrences(of: "—", with: "–")
            heading = "\(series) S\(raw[season]) E\(numbers)"
            let name = raw[whole.upperBound...].trimmingCharacters(in:
                CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:–—-\"“”")))
            title = name.isEmpty ? series : name
        } else {
            heading = series + (episode.season.map { " S\($0)" } ?? "")
            title = withoutStarTrek(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
