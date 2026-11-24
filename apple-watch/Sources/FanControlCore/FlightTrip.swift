import Foundation

/// FlightSync owns flight data and trip order. The watch chooses its opening scroll position locally.
public struct TripFlight: Codable, Sendable, Equatable {
    public let number: String
    public let city_pair: String
    public let departure: String
    public let departure_timezone: String?
    public let arrival: String
    public let scheduled_departure: String?
    public let scheduled_arrival: String?
    public let actual_departure: String?
    public let actual_arrival: String?
    public let status: String?
    public let route: String?
    public let delay_minutes: Double?
    public let crew: [FlightCrewMember]?
}

public struct FlightTrip: Codable, Sendable, Equatable {
    public let version: Int
    public let available: Bool
    public let flights: [TripFlight]
    public let source_last_success: String?
    public let focused_flight_index: Int?
    public func validated() throws -> FlightTrip {
        guard version == 1, flights.count <= 200,
              focused_flight_index.map({ $0 >= 0 && $0 < max(1, flights.count) }) ?? true else { throw ControlError.invalidResponse }
        for flight in flights {
            guard !flight.number.isEmpty, flight.number.count <= 160,
                  !flight.city_pair.isEmpty, flight.city_pair.count <= 160,
                  FlightPresentation.departure(flight.departure) != nil,
                  FlightPresentation.departure(flight.arrival) != nil else { throw ControlError.invalidResponse }
            guard (flight.crew?.count ?? 0) <= 20 else { throw ControlError.invalidResponse }
            for member in flight.crew ?? [] {
                guard !member.employee_number.isEmpty, member.employee_number.count <= 160,
                      (member.first_name?.count ?? 0) <= 255,
                      (member.last_name?.count ?? 0) <= 255 else { throw ControlError.invalidResponse }
            }
        }
        return self
    }
    /// A presentation assumption only: keep elapsed flights above the opening flight.
    /// Each new estimate replaces the previous cutoff; no progress is written back.
    public func openingFlightIndex(now: Date = Date()) -> Int? {
        guard !flights.isEmpty else { return nil }
        var index = focused_flight_index ?? 0
        while index < flights.count - 1,
              let departure = FlightPresentation.departure(flights[index].departure),
              now.timeIntervalSince(departure) >= 40 * 60 {
            index += 1
        }
        return index
    }
    public func state(now: Date = Date()) -> [String: Any] {
        let source = FlightPresentation.departure(source_last_success)
        let fresh = available && source.map { (0...180).contains(now.timeIntervalSince($0)) } == true
        var raw = (try? JSONEncoder().encode(flights)).flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]]
        } ?? []
        let opening = openingFlightIndex(now: now)
        for index in raw.indices {
            raw[index]["completed"] = index < (opening ?? 0)
        }
        var state: [String: Any] = ["version": 1, "flights": raw, "available": fresh, "flightsync_paired": true]
        if let index = openingFlightIndex(now: now) { state["opening_flight_index"] = index }
        return state
    }
}

/// A separate phone-owned snapshot: HA snapshots cannot overwrite this cache.
public struct PhoneFlightSnapshot: Codable, Sendable {
    public let watchID: String
    public let trip: FlightTrip?
    public let generation: Int64
    public init(watchID: String, trip: FlightTrip?, generation: Int64) {
        self.watchID = watchID; self.trip = trip; self.generation = generation
    }
}

/// Read-only crew fields from the private FlightSync snapshot; preserve leading zeros.
public struct FlightCrewMember: Codable, Sendable, Equatable {
    public let first_name: String?
    public let last_name: String?
    public let employee_number: String

    public var displayName: String {
        let parts = [first_name, last_name].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "Name unavailable" : parts.joined(separator: " ")
    }
}
