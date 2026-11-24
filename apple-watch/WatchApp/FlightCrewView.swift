import SwiftUI
import FanControlCore

/// Crew scrolling owns the Crown while presented; the flight page stays selected.
struct FlightCrewView: View {
    let flight: [String: Any]

    private var crew: [FlightCrewMember] {
        guard let raw = flight["crew"], JSONSerialization.isValidJSONObject(raw),
              let data = try? JSONSerialization.data(withJSONObject: raw),
              let people = try? JSONDecoder().decode([FlightCrewMember].self, from: data) else { return [] }
        return people
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(flight["number"] as? String ?? "—").font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if crew.isEmpty {
                        Text("No crew information").foregroundStyle(.gray)
                    }
                    ForEach(Array(crew.enumerated()), id: \.offset) { _, member in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.displayName).font(.body)
                            Text(member.employee_number).font(.caption.monospacedDigit())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 5)
    }
}
