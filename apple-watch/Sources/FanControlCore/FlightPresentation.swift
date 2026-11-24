import Foundation

public enum FlightPresentation {
    // FlightSync's supported airport registry. Never guess by stripping a prefix:
    // Canadian and international ICAO identifiers do not follow the US pattern.
    private static let airportAliases: [String: String] = [
        "CYVR": "YVR",
        "KALB": "ALB",
        "KATL": "ATL",
        "KAUS": "AUS",
        "KAVL": "AVL",
        "KBDL": "BDL",
        "KBGR": "BGR",
        "KBNA": "BNA",
        "KBOS": "BOS",
        "KBUF": "BUF",
        "KCHS": "CHS",
        "KCID": "CID",
        "KCLT": "CLT",
        "KCMH": "CMH",
        "KCVG": "CVG",
        "KDCA": "DCA",
        "KDEN": "DEN",
        "KDFW": "DFW",
        "KDSM": "DSM",
        "KDTW": "DTW",
        "KECP": "ECP",
        "KEWR": "EWR",
        "KEYW": "EYW",
        "KFLL": "FLL",
        "KIAD": "IAD",
        "KIAH": "IAH",
        "KILM": "ILM",
        "KIND": "IND",
        "KJAX": "JAX",
        "KJFK": "JFK",
        "KLAS": "LAS",
        "KLAX": "LAX",
        "KLGA": "LGA",
        "KMCI": "MCI",
        "KMCO": "MCO",
        "KMDW": "MDW",
        "KMEM": "MEM",
        "KMIA": "MIA",
        "KMKE": "MKE",
        "KMSN": "MSN",
        "KMSP": "MSP",
        "KMSY": "MSY",
        "KOKC": "OKC",
        "KOMA": "OMA",
        "KONT": "ONT",
        "KORD": "ORD",
        "KPBI": "PBI",
        "KPDX": "PDX",
        "KPHL": "PHL",
        "KPHX": "PHX",
        "KPIT": "PIT",
        "KPVD": "PVD",
        "KPWM": "PWM",
        "KRDU": "RDU",
        "KRIC": "RIC",
        "KROC": "ROC",
        "KRSW": "RSW",
        "KSAN": "SAN",
        "KSAV": "SAV",
        "KSDF": "SDF",
        "KSEA": "SEA",
        "KSFO": "SFO",
        "KSLC": "SLC",
        "KSMF": "SMF",
        "KSRQ": "SRQ",
        "KSTL": "STL",
        "KSYR": "SYR",
        "KTPA": "TPA",
        "KVPS": "VPS",
        "MDPC": "PUJ",
        "MDSD": "SDQ",
        "MKJS": "MBJ",
        "MMUN": "CUN",
        "MUCM": "CMW",
        "MWCR": "GCM",
        "MYNN": "NAS",
        "TIST": "STT"
    ]

    public static func airportCode(_ raw: String) -> String {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let iata = airportAliases[code] { return iata }
        if code.count == 3, code.unicodeScalars.allSatisfy({ (65...90).contains($0.value) }) { return code }
        return "—"
    }

    public static func airportPair(_ raw: String?) -> String {
        guard let raw else { return "—" }
        let parts = raw.components(separatedBy: "→")
        guard parts.count == 2 else { return "—" }
        return airportCode(parts[0]) + " → " + airportCode(parts[1])
    }

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
