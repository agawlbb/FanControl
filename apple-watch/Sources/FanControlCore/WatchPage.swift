import Foundation

public enum TileSwipe {
    public static let minimumDistance: CGFloat = 12

    public static func direction(x: CGFloat, y: CGFloat) -> Int? {
        guard abs(x) >= minimumDistance, abs(x) > abs(y) * 1.5 else { return nil }
        return x < 0 ? 1 : -1
    }
}

// Settings is a local page after the approved controls, never an HA selection.
public enum WatchPage: Equatable, Sendable {
    case device(String)
    case settings
    case podcast

    public static func next(_ current: Self, entities: [String], active: String? = nil, direction: Int) -> Self {
        let pages = entities.map { $0 == PodcastTile.id ? Self.podcast : Self.device($0) }
        guard !pages.isEmpty else { return current }
        let index = pages.firstIndex(of: current) ?? 0
        let delta = direction >= 0 ? 1 : -1
        return pages[min(pages.count - 1, max(0, index + delta))]
    }
}
