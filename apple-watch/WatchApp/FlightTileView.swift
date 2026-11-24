import SwiftUI
import FanControlCore

/// Each entry opens on the chosen flight; swipe or Crown steps between whole pages.
struct FlightTileView: View {
    let state: [String: Any]
    let fresh: Bool
    let onSwipe: (Int) -> Void
    @State private var selection = FlightPageSelection()
    @State private var crownPosition = 0.0
    @FocusState private var crownFocused: Bool

    private var flights: [[String: Any]] { state["flights"] as? [[String: Any]] ?? [] }
    private var openingIndex: Int? {
        guard !flights.isEmpty else { return nil }
        return min(max(state["opening_flight_index"] as? Int ?? 0, 0), flights.count - 1)
    }

    private var flightKeys: [String] {
        flights.map {
            ($0["number"] as? String ?? "") + "|" +
            ($0["scheduled_departure"] as? String ?? $0["departure"] as? String ?? "")
        }
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let index = selection.index ?? openingIndex, flights.indices.contains(index) {
                    flightInfo(flights[index])
                        .foregroundStyle(fresh && state["available"] as? Bool == true ? Color.mint : Color.gray)
                } else {
                    Text(state["flightsync_paired"] as? Bool == false ? "Pair FlightSync in the iPhone app" : "No flight")
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
            .contentShape(Rectangle())
            .clipped()
            .gesture(DragGesture(minimumDistance: TileSwipe.minimumDistance)
                .onEnded { value in
                    if let direction = TileSwipe.direction(x: value.translation.width, y: value.translation.height) {
                        onSwipe(direction)
                    } else if let direction = FlightPageSelection.verticalDirection(x: value.translation.width, y: value.translation.height) {
                        selection.step(direction)
                        crownPosition = Double(selection.index ?? 0)
                    }
                })
            .focusable()
            .focused($crownFocused)
            .digitalCrownRotation($crownPosition, from: 0, through: Double(max(flights.count - 1, 1)),
                                  by: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
            .onChange(of: crownPosition) { _, value in
                selection.crown(value)
            }
            .onChange(of: flightKeys, initial: true) { _, keys in
                selection.update(keys: keys, openingIndex: openingIndex)
                crownPosition = Double(selection.index ?? 0)
            }
            .onAppear { crownFocused = true }
        }
    }

    private func flightInfo(_ flight: [String: Any]) -> some View {
        let departure = FlightPresentation.departure(flight["departure"] as? String)
        let completed = flight["completed"] as? Bool == true
        return VStack(spacing: 0) {
            Text(flight["number"] as? String ?? "—").font(.headline)
            Text(FlightPresentation.airportPair(flight["city_pair"] as? String)).font(.title2.bold())
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
