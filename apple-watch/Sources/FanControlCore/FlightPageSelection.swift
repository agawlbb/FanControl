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

}

/// Flight-only routing: choose the dominant axis without a diagonal dead zone.
/// A recognized drag that returns to its starting point is ignored, never a tap.
public enum FlightTileSwipe: Equatable, Sendable {
    case flight(Int)
    case tile(Int)

    public static func direction(x: CGFloat, y: CGFloat) -> Self? {
        guard x.isFinite, y.isFinite,
              hypot(Double(x), Double(y)) >= Double(TileSwipe.minimumDistance) else { return nil }
        if abs(y) >= abs(x) { return .flight(y < 0 ? 1 : -1) }
        return .tile(x < 0 ? 1 : -1)
    }
}
