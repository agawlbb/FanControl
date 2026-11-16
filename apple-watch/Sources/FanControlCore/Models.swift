import Foundation

public enum ControlError: Error { case invalidConfiguration, invalidResponse, rejected(Int), notConfirmed }
public struct Device: Codable, Equatable, Sendable {
    public let entity: String
    public let title: String
    public let panel: Panel?
    public var domain: String { panel?.type == "fan" ? "fan" : String(entity.split(separator: ".").first ?? "") }
}
public struct Panel: Codable, Equatable, Sendable {
    public let id: String
    public let type: String
    public let name: String
    public let city_pair_entity: String?
    public let departure_entity: String?
    public let battery_entity: String?
    public let climate_entity: String?
    public let fan_entity: String?
    public let script_entity: String?
    public let climate_label: String?
    public let script_label: String?
    public let wake_entity: String?
    public let awake_entity: String?
    public let lock_entity: String?
    public let garage_entity: String?
    public let trunk_entity: String?
    public let horn_entity: String?
    public let podcast_entity: String?
    public let color: [Int]?
    public var vehicle: Bool { !(wake_entity ?? "").isEmpty }
}
public struct Connection: Codable, Equatable, Sendable {
    public static let handoffSeconds: TimeInterval = 10
    public func remoteAddress() throws -> URL {
        try Self.remoteAddress(remote_url)
    }
    public static func remoteAddress(_ raw: String?) throws -> URL {
        guard let remote = raw, !remote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ControlError.invalidConfiguration
        }
        let address = try Self.address(remote, external: true)
        let host = (address.host ?? "").lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        guard host != "localhost", !host.hasSuffix(".localhost"), host != "::1",
              host != "0.0.0.0", !host.hasPrefix("127.") else { throw ControlError.invalidConfiguration }
        return address
    }
    public var url: String
    public var remote_url: String?
    public var token: String
    public var watch_id: String
    public var entity: String
    public var devices: [Device]
    public var revision: Int?
    public var companion: Bool?
    public var companion_settings: CompanionSettings?
    // Revision is diagnostic metadata. An unchanged approved target must not
    // reject an early tap merely because an older saved record has no revision.
    public func sameTarget(as other: Self) -> Bool {
        url == other.url && remote_url == other.remote_url && token == other.token &&
        watch_id == other.watch_id && entity == other.entity && devices == other.devices
    }
    public var active: Device? { devices.first { $0.entity == entity } }
    public func validated() throws -> Self {
        guard watch_id.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil,
              token.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
              devices.count <= 16, Set(devices.map(\.entity)).count == devices.count,
              active != nil || entity.isEmpty else { throw ControlError.invalidConfiguration }
        _ = try Self.address(url)
        if let remote = remote_url, !remote.isEmpty { _ = try Self.address(remote, external: true) }
        for device in devices {
            guard device.entity.range(of: "^[a-z_][a-z0-9_]*\\.[a-z0-9_]+$", options: .regularExpression) != nil,
                  !device.title.isEmpty, device.title.count <= 80 else { throw ControlError.invalidConfiguration }
            if let p = device.panel {
                try p.validateRoles()
                guard device.entity == "panel." + p.id, ["fan", "work_morning", "exercise", "driving", "on_duty"].contains(p.type),
                      p.color == nil || (p.color!.count == 3 && p.color!.allSatisfy { (0...255).contains($0) }) else { throw ControlError.invalidConfiguration }
            }
        }
        return self
    }
    public static func address(_ raw: String, external: Bool = false) throws -> URL {
        guard let u = URLComponents(string: raw), let host = u.host?.lowercased(), u.user == nil, u.password == nil,
              u.query == nil, u.fragment == nil, let result = u.url else { throw ControlError.invalidConfiguration }
        let octets = host.split(separator: ".").compactMap { Int($0) }
        let privateIPv4 = octets.count == 4 && octets.allSatisfy { (0...255).contains($0) } &&
            (octets[0] == 10 || octets[0] == 127 || (octets[0] == 192 && octets[1] == 168) ||
             (octets[0] == 172 && (16...31).contains(octets[1])) || (octets[0] == 169 && octets[1] == 254))
        let local = host.hasSuffix(".local") || host == "localhost" || host == "::1" || host.hasPrefix("fc") && host.contains(":") || host.hasPrefix("fd") && host.contains(":") || host.hasPrefix("fe80:") || privateIPv4
        guard u.scheme == "https" || (!external && u.scheme == "http" && local) else { throw ControlError.invalidConfiguration }
        return result
    }
    public var identity: String { (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? "" }
}

public struct Feedback: Equatable, Sendable {
    public let id: UUID
    public let target: String
    public let command: String
    public let label: String
    public var phase: Phase
    public enum Phase: Sendable { case pending, confirmed, accepted, unconfirmed }
    public init(target: String, command: String, label: String) {
        id = UUID(); self.target = target; self.command = command; self.label = label; phase = .pending
    }
    public var gray: Bool { phase != .confirmed && phase != .accepted }
}
public enum Evidence {
    public static let percentages = [16, 33, 50, 66, 83, 100]
    public static func matches(_ command: String, _ state: [String: Any], panel: Panel?) -> Bool {
        if let panel, panel.type != "fan" {
            if panel.vehicle && command != "stop_exercise" && command != "garage_open" && command != "garage_close" && state["vehicle_ready"] as? Bool != true { return false }
            switch command {
            case "climate_on", "climate_off": return (state[command == "climate_off" && panel.type == "driving" ? "climate_off_available" : "climate_available"] as? Bool == true) && state["climate_on"] as? Bool == (command == "climate_on")
            case "garage_open", "garage_close", "trunk_open", "trunk_close":
                let role = command.hasPrefix("garage") ? "garage" : "trunk"
                return state[command + "_available"] as? Bool == true && state[role + "_state"] as? String == (command.hasSuffix("open") ? "open" : "closed")
            case "start_exercise": return state["locked"] as? Bool == true
            case "stop_exercise": return state["operation_status"] as? String == "complete"
            default: return false
            }
        }
        guard let observed = state["state"] as? String, observed != "unavailable", observed != "unknown" else { return false }
        if command == "turn_on" || command == "turn_off" { return observed == (command == "turn_on" ? "on" : "off") }
        if command.hasPrefix("speed"), let speed = Int(command.dropFirst(5)), (1...6).contains(speed), let attrs = state["attributes"] as? [String: Any], let value = attrs["percentage"] as? Int {
            return observed == "on" && value == percentages[speed - 1]
        }
        return false
    }
    public static func coverIntent(_ observed: String?) -> String { ToggleIntent.coverPresentation(observed) == "OPEN" ? "close" : "open" }
}


extension Panel {
    public func validateRoles() throws {
        func entity(_ value: String?, domains: String) -> Bool {
            guard let value, value.count <= 160 else { return false }
            return value.range(of: "^(\(domains))\\.[a-z0-9_]+$", options: .regularExpression) != nil
        }
        guard id.range(of:"^[a-z][a-z0-9_]{0,39}$",options:.regularExpression) != nil, id != "devices", !name.isEmpty, name.count <= 40 else { throw ControlError.invalidConfiguration }
        if vehicle || !(awake_entity ?? "").isEmpty {
            guard entity(wake_entity,domains:"button"), entity(awake_entity,domains:"binary_sensor") else { throw ControlError.invalidConfiguration }
        }
        switch type {
        case "on_duty":
            guard !vehicle, awake_entity == nil, entity(city_pair_entity, domains: "sensor"), entity(departure_entity, domains: "sensor") else { throw ControlError.invalidConfiguration }
        case "fan":
            guard entity(fan_entity, domains: "fan") else { throw ControlError.invalidConfiguration }
        case "driving":
            guard entity(garage_entity,domains:"cover"), entity(trunk_entity,domains:"cover"), garage_entity != trunk_entity, entity(climate_entity,domains:"climate"), vehicle else { throw ControlError.invalidConfiguration }
            if let horn_entity { guard entity(horn_entity, domains:"button"), horn_entity != wake_entity else { throw ControlError.invalidConfiguration } }
            if let podcast_entity { guard entity(podcast_entity, domains:"script") else { throw ControlError.invalidConfiguration } }
        case "exercise":
            guard entity(lock_entity,domains:"lock"), entity(climate_entity,domains:"climate"), vehicle else { throw ControlError.invalidConfiguration }
        case "work_morning":
            guard entity(battery_entity,domains:"sensor"), entity(climate_entity,domains:"climate|switch|input_boolean"), entity(script_entity,domains:"script") else { throw ControlError.invalidConfiguration }
        default: throw ControlError.invalidConfiguration
        }
    }
}
