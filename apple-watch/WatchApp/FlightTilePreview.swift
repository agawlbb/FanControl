#if DEBUG && targetEnvironment(simulator)
import SwiftUI

/// Synthetic simulator-only fixture: no pairing, persistence or network requests.
struct FlightTilePreview: View {
    private let args = ProcessInfo.processInfo.arguments
    @State private var loaded = false
    private var state: [String: Any] {
        if args.contains("--preview-flight-delayed") && !loaded { return ["flights": []] }
        let flights: [[String: Any]] = (0..<6).map { index in
            ["number": "AA\(100 + index)", "city_pair": index == 5 ? "KBOS → KCLT" : "KCLT → KBOS",
             "departure": Date.now.addingTimeInterval(7200).ISO8601Format(),
             "arrival": Date.now.addingTimeInterval(14400).ISO8601Format(),
             "departure_timezone": "America/New_York", "scheduled_departure": "2026-11-24T12:00:00Z", "completed": index < 5,
             "crew": [["first_name": "Lex", "last_name": "Example", "employee_number": "000001"],
                      ["first_name": "Sam", "last_name": "Sample", "employee_number": "000002"]]]
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
