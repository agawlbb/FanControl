import SwiftUI
import FanControlCore

/// Each visible entry opens once on the locally chosen flight; all rows remain scrollable.
struct FlightTileView: View {
    let state: [String: Any]
    let fresh: Bool
    let onSwipe: (Int) -> Void
    @State private var positioned = false
    @State private var scrollPosition: Int?

    init(state: [String: Any], fresh: Bool, onSwipe: @escaping (Int) -> Void) {
        self.state = state
        self.fresh = fresh
        self.onSwipe = onSwipe
        let flights = state["flights"] as? [[String: Any]] ?? []
        let index = flights.isEmpty ? nil : min(max(state["opening_flight_index"] as? Int ?? 0, 0), flights.count - 1)
        _scrollPosition = State(initialValue: index)
    }

    private var flights: [[String: Any]] { state["flights"] as? [[String: Any]] ?? [] }
    private var openingIndex: Int? {
        guard !flights.isEmpty else { return nil }
        return min(max(state["opening_flight_index"] as? Int ?? 0, 0), flights.count - 1)
    }

    var body: some View {
        GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if flights.isEmpty {
                            Text(state["flightsync_paired"] as? Bool == false ? "Pair FlightSync in the iPhone app" : "No flight")
                                .foregroundStyle(.gray)
                        }
                        ForEach(Array(flights.enumerated()), id: \.offset) { index, flight in
                            // A single target per flight avoids a ForEach frame spanning
                            // the previous divider/row when restoring a scroll position.
                            VStack(spacing: 0) {
                                flightInfo(flight)
                                    .foregroundStyle(fresh && state["available"] as? Bool == true ? Color.mint : Color.gray)
                                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
                                if index < flights.count - 1 { Divider().padding(.vertical, 12) }
                            }
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 5)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
                    .contentShape(Rectangle())
                }
                // Observe horizontal swipes alongside native scrolling. A high-priority
                // drag captures vertical movement before its onEnded direction check.
                .simultaneousGesture(DragGesture(minimumDistance: TileSwipe.minimumDistance)
                    .onEnded { value in
                        if let direction = TileSwipe.direction(x: value.translation.width, y: value.translation.height) {
                            onSwipe(direction)
                        }
                    })
                .scrollPosition(id: $scrollPosition, anchor: .top)
                .onChange(of: openingIndex, initial: true) { _, index in
                    // Initial data can arrive after entry. Set the first position
                    // declaratively; later phone updates must not reset manual scrolling.
                    guard !positioned, let index else { return }
                    scrollPosition = index
                    positioned = true
                }
        }
    }

    private func flightInfo(_ flight: [String: Any]) -> some View {
        let departure = FlightPresentation.departure(flight["departure"] as? String)
        let completed = flight["completed"] as? Bool == true
        return VStack(spacing: 12) {
            Text(flight["number"] as? String ?? "—").font(.headline)
            Text(flight["city_pair"] as? String ?? "—").font(.title2.bold())
            if completed {
                VStack(spacing: 2) {
                    Text("Arrival").font(.caption)
                    Text(FlightPresentation.departureTime(flight["arrival"] as? String,
                        timeZoneIdentifier: flight["departure_timezone"] as? String)).font(.title3)
                }
                Text("Completed").font(.caption)
            } else if let departure {
                VStack(spacing: 2) {
                    Text("Departure").font(.caption)
                    Text(FlightPresentation.departureTime(flight["departure"] as? String,
                        timeZoneIdentifier: flight["departure_timezone"] as? String)).font(.title3)
                }
                VStack(spacing: 2) {
                    Text("Time to go").font(.caption)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(FlightPresentation.timeToGo(departure: departure, now: context.date)).font(.title2.monospacedDigit())
                    }
                }
            }
        }
    }
}
