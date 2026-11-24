import Foundation

/// One selected flight, retained across passive updates. Swipes never wrap.
public struct FlightPageSelection: Equatable, Sendable {
    public private(set) var index: Int?
    private var keys: [String] = []
    public init() {}

    public mutating func update(keys newKeys: [String], openingIndex: Int?) {
        let selected = index.flatMap { keys.indices.contains($0) ? keys[$0] : nil }
        keys = newKeys
        guard !keys.isEmpty else { index = nil; return }
        if let selected, let retained = keys.firstIndex(of: selected) {
            index = retained
        } else {
            index = min(max(openingIndex ?? 0, 0), keys.count - 1)
        }
    }

    public mutating func step(_ direction: Int) {
        guard let index, direction != 0 else { return }
        self.index = min(max(index + (direction > 0 ? 1 : -1), 0), keys.count - 1)
    }

    public mutating func crown(_ position: Double) {
        guard !keys.isEmpty, position.isFinite else { return }
        let bounded = min(max(position, 0), Double(keys.count - 1))
        index = Int(bounded.rounded())
    }

    public static func verticalDirection(x: CGFloat, y: CGFloat) -> Int? {
        guard abs(y) >= TileSwipe.minimumDistance, abs(y) > abs(x) * 1.5 else { return nil }
        return y < 0 ? 1 : -1
    }
}
