import SwiftUI
import FanControlCore

/// Each visible entry opens once on the locally chosen flight; all rows remain scrollable.
struct FlightTileView: View {
    let state: [String: Any]
    let fresh: Bool
    let onSwipe: (Int) -> Void
    @State private var positioned = false

    private var flights: [[String: Any]] { state["flights"] as? [[String: Any]] ?? [] }
    private var openingIndex: Int? {
        guard !flights.isEmpty else { return nil }
        return min(max(state["opening_flight_index"] as? Int ?? 0, 0), flights.count - 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        if flights.isEmpty {
                            Text(state["flightsync_paired"] as? Bool == false ? "Pair FlightSync in the iPhone app" : "No flight")
                                .foregroundStyle(.gray)
                        }
                        ForEach(Array(flights.enumerated()), id: \.offset) { index, flight in
                            if index > 0 { Divider().padding(.vertical, 12) }
                            flightInfo(flight)
                                .foregroundStyle(fresh && state["available"] as? Bool == true ? Color.mint : Color.gray)
                                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
                                .id(index)
                        }
                    }
                    .padding(.horizontal, 5)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
                    .tileSwipe(onSwipe: onSwipe)
                }
                .task(id: openingIndex) {
                    // Wait for the current rows to be laid out, including a first phone response.
                    await Task.yield()
                    guard !Task.isCancelled, !positioned, let openingIndex else { return }
                    proxy.scrollTo(openingIndex, anchor: .top)
                    positioned = true
                }
            }
        }
    }

    private func flightInfo(_ flight: [String: Any]) -> some View {
        let departure = FlightPresentation.departure(flight["departure"] as? String)
        let arrival = FlightPresentation.departure(flight["arrival"] as? String)
        return VStack(spacing: 12) {
            Text(flight["number"] as? String ?? "—").font(.headline)
            Text(flight["city_pair"] as? String ?? "—").font(.title2.bold())
            if let departure {
                VStack(spacing: 2) {
                    Text("Departure").font(.caption)
                    Text(departure, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.body)
                }
                VStack(spacing: 2) {
                    Text("Time to go").font(.caption)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(FlightPresentation.timeToGo(departure: departure, now: context.date)).font(.title2.monospacedDigit())
                    }
                }
            }
            if let arrival {
                VStack(spacing: 2) {
                    Text("Arrival").font(.caption)
                    Text(arrival, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.body)
                }
            }
            if let status = flight["status"] as? String { Text(status.replacingOccurrences(of: "_", with: " ")).font(.caption) }
        }
    }
}
