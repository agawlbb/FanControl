import Foundation

public struct CompanionSettings: Codable, Equatable, Sendable {
    public var order: [String]
    public var headset: String
    public init(order: [String] = [], headset: String = "Joseph's Buds2 Pro") { self.order = order; self.headset = headset }
    public func ordered(_ entities: [String]) -> [String] {
        var seen = Set<String>()
        return (order + entities).filter { entities.contains($0) && seen.insert($0).inserted }
    }
}

// Contains no credential. The receiver supplies its own independently scoped key.
public struct CompanionSnapshot: Codable, Sendable {
    public let configuration: Data
    public let states: [String: Data]
    public let sequence: Int
    public let atMS: Int64
    public let watchID: String
    public let server: String
    public let updateID: String?
    public init(response: [String: Any], connection: Connection, updateID: String? = nil) throws {
        guard var config = response["configuration"] as? [String: Any],
              let observations = response["states"] as? [String: [String: Any]],
              let sequence = response["sequence"] as? Int, sequence > 0,
              let at = response["at_ms"] as? Int64 else { throw ControlError.invalidResponse }
        for key in ["token", "secret", "watch_id", "companion"] { config.removeValue(forKey: key) }
        configuration = try JSONSerialization.data(withJSONObject: config)
        states = try observations.mapValues { try JSONSerialization.data(withJSONObject: $0) }
        self.sequence = sequence; atMS = at; watchID = connection.watch_id; server = connection.url; self.updateID = updateID
    }
    public func resolved(for original: Connection) throws -> Connection {
        guard watchID == original.watch_id, server == original.url else { throw ControlError.invalidConfiguration }
        guard var config = try JSONSerialization.jsonObject(with: configuration) as? [String: Any] else { throw ControlError.invalidResponse }
        config["watch_id"] = original.watch_id; config["token"] = original.token
        config["companion"] = original.companion
        return try JSONDecoder().decode(Connection.self, from: JSONSerialization.data(withJSONObject: config)).validated()
    }
}

public struct OfflinePlaylist: Codable, Equatable, Sendable {
    public let id: UUID
    public let watchID: String
    public let generation: Int64
    public let tracks: [ExerciseTrack]
    public init(watchID: String, tracks: [ExerciseTrack], id: UUID = UUID(), generation: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) throws {
        self.id = id; self.watchID = watchID; self.generation = generation; self.tracks = tracks; try validate()
    }
    public func validate() throws {
        guard generation > 0, tracks.count <= 25, Set(tracks.map(\.fileName)).count == tracks.count else { throw ControlError.invalidResponse }
        try tracks.forEach { try $0.validate() }
        guard tracks.reduce(0, { $0 + $1.size }) <= 200 * 1024 * 1024 else { throw ControlError.invalidResponse }
    }
}
