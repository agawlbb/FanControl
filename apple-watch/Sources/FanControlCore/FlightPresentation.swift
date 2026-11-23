import Foundation

public enum FlightPresentation {
    public static func departure(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: raw)
    }
    public static func timeToGo(departure: Date, now: Date) -> String {
        let seconds = departure.timeIntervalSince(now)
        guard seconds > 0 else { return "0m" }
        let minutes = Int(ceil(seconds / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
    public static func departureTime(_ raw: String?, timeZoneIdentifier: String?, locale: Locale = .current) -> String {
        guard let date = departure(raw), let timeZoneIdentifier,
              let zone = TimeZone(identifier: timeZoneIdentifier) else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = zone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
