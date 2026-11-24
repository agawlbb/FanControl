#if DEBUG && targetEnvironment(simulator)
import SwiftUI

/// Synthetic simulator-only fixture: no pairing, persistence or network requests.
struct FlightTilePreview: View {
    private let args = ProcessInfo.processInfo.arguments
    @State private var loaded = false
    private var state: [String: Any] {
        if args.contains("--preview-flight-delayed") && !loaded { return ["flights": []] }
        let flights: [[String: Any]] = (0..<6).map { index in
            ["number": "AA\(100 + index)", "city_pair": index == 5 ? "BOS → CLT" : "CLT → BOS",
             "departure": Date.now.addingTimeInterval(7200).ISO8601Format(),
             "arrival": Date.now.addingTimeInterval(14400).ISO8601Format(),
             "departure_timezone": "America/New_York", "completed": index < 5]
        }
        return ["flights": flights, "available": true,
                "opening_flight_index": args.contains("--preview-flight-completed") ? 4 : 5]
    }
    var body: some View {
        FlightTileView(state: state, fresh: true, onSwipe: { _ in })
            .persistentSystemOverlays(.hidden)
            .task {
                try? await Task.sleep(for: .seconds(1))
                loaded = true
            }
    }
}
#endif
