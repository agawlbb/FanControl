import Foundation

/// FlightSync owns selection and trip order. Neither app infers progress from clocks.
public struct TripFlight: Codable, Sendable, Equatable {
    public let number: String
    public let city_pair: String
    public let departure: String
    public let arrival: String
    public let scheduled_departure: String?
    public let scheduled_arrival: String?
    public let actual_departure: String?
    public let actual_arrival: String?
    public let status: String?
    public let route: String?
    public let delay_minutes: Double?
}

public struct FlightTrip: Codable, Sendable, Equatable {
    public let version: Int
    public let available: Bool
    public let flights: [TripFlight]
    public let source_last_success: String?
    public func validated() throws -> FlightTrip {
        guard version == 1, flights.count <= 200 else { throw ControlError.invalidResponse }
        for flight in flights {
            guard !flight.number.isEmpty, flight.number.count <= 160,
                  !flight.city_pair.isEmpty, flight.city_pair.count <= 160,
                  FlightPresentation.departure(flight.departure) != nil,
                  FlightPresentation.departure(flight.arrival) != nil else { throw ControlError.invalidResponse }
        }
        return self
    }
    public func state(now: Date = Date()) -> [String: Any] {
        let source = FlightPresentation.departure(source_last_success)
        let fresh = available && source.map { (0...180).contains(now.timeIntervalSince($0)) } == true
        let raw = (try? JSONEncoder().encode(flights)).flatMap { try? JSONSerialization.jsonObject(with: $0) } ?? []
        return ["version": 1, "flights": raw, "available": fresh, "flightsync_paired": true]
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
