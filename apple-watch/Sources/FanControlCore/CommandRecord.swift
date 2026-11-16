import Foundation

// Persist the original absolute intent; retries must never recompute a toggle.
public struct CommandRecord: Codable {
    public let id: String
    public let connection: Connection
    public let entity: String
    public let body: Data
    public let issued: Date
    public var accepted = false
    public var retries: Int?
    public var result: Data?
    public var timings: [String: Double]?
    public var events: [String]?
    public func awaitingHandoff(now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(issued)
        return !accepted && result == nil && age >= 0 && age < Connection.handoffSeconds
    }
    // Persist this boundary before scheduling: inactivity and a transport failure
    // may race, but must schedule at most one continuation of the captured intent.
    public mutating func beginBackgroundContinuation(now: Date = Date()) -> Bool {
        guard awaitingHandoff(now: now), timings?["background_continuation"] == nil else { return false }
        mark("background_continuation", at: now)
        return true
    }
    // Receipt evidence can arrive after the UI deadline, but only for this pairing/target.
    public func matchesCurrentTarget(_ current: Connection?) -> Bool {
        guard let current, current.watch_id == connection.watch_id, current.token == connection.token,
              let captured = connection.devices.first(where: { $0.entity == entity }) else { return false }
        return current.devices.contains { $0.sameCommandTarget(as: captured) }
    }
    public var acknowledgedDuringHandoff: Bool {
        guard let ack = timings?["ack_received"] else { return false }
        let age = ack / 1000 - issued.timeIntervalSince1970
        return age >= 0 && age < Connection.handoffSeconds
    }
    public func showsActionReceipt(now: Date = Date()) -> Bool {
        guard accepted, acknowledgedDuringHandoff, let ack = timings?["ack_received"] else { return false }
        let age = now.timeIntervalSince1970 - ack / 1000
        return age >= 0 && age < ActionReceipts.acceptedSeconds
    }
    public mutating func mark(_ phase: String, at: Date = Date()) {
        var times = timings ?? [:]
        if times[phase] == nil { times[phase] = at.timeIntervalSince1970 * 1000 }
        timings = times
        var list = events ?? []
        if list.last != phase { list.append(phase) }
        events = Array(list.suffix(40))
    }
    public init(id: String, connection: Connection, entity: String, body: Data, issued: Date) {
        self.id = id; self.connection = connection; self.entity = entity; self.body = body; self.issued = issued
    }
}
