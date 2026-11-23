import Foundation
import FanControlCore

extension Notification.Name { static let flightTripSaved = Notification.Name("flightTripSaved") }

@MainActor enum WatchFlightSync {
    private static func key(_ c: Connection) -> String { "phoneFlightTrip." + c.watch_id }
    static func state(_ c: Connection) -> [String: Any] {
        guard let raw = UserDefaults.standard.data(forKey: key(c)),
              let saved = try? JSONDecoder().decode(PhoneFlightSnapshot.self, from: raw), saved.watchID == c.watch_id,
              let trip = saved.trip else { return ["flights": [], "flightsync_paired": false, "available": false] }
        return trip.state()
    }
    static func receive(_ data: Data, watchID: String?) {
        guard let c = Vault.load(), watchID == c.watch_id,
              let value = try? JSONDecoder().decode(PhoneFlightSnapshot.self, from: data), value.watchID == c.watch_id,
              value.generation > 0 else { return }
        if let trip = value.trip, (try? trip.validated()) == nil { return }
        if let old = UserDefaults.standard.data(forKey: key(c)),
           let saved = try? JSONDecoder().decode(PhoneFlightSnapshot.self, from: old), saved.generation >= value.generation { return }
        UserDefaults.standard.set(data, forKey: key(c))
        NotificationCenter.default.post(name: .flightTripSaved, object: nil)
    }
    static func clear() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("phoneFlightTrip.") {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
