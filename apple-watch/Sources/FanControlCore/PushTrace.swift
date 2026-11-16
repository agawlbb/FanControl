import Foundation
import CryptoKit

public struct PushTraceEvent: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let update_id: String?
    public let watch_id: String
    public let phase: String
    public let at_ms: Int64
    public let panel: String
    public let revision: Int?
    public var reported: Bool = false
}

// Diagnostic evidence only: never selects a panel or writes observed state.
// A bounded persistent outbox survives suspension and retries with stable event IDs.
public final class PushTrace: @unchecked Sendable {
    private let defaults: UserDefaults
    private let lock = NSLock()
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    private func key(_ c: Connection?) -> String {
        guard let c else { return "pushtrace.unscoped" }
        return "pushtrace." + SHA256.hash(data: Data((c.watch_id + "|" + c.url + "|" + c.token).utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private func read(_ key: String) -> [PushTraceEvent] {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([PushTraceEvent].self, from: $0) } ?? []
    }
    private func write(_ events: [PushTraceEvent], _ key: String) {
        if let data = try? JSONEncoder().encode(Array(events.suffix(120))) { defaults.set(data, forKey: key) }
    }
    public func latestUpdate(_ c: Connection) -> String? {
        lock.lock(); defer { lock.unlock() }
        return (read(key(c)) + read(key(nil)).filter { $0.watch_id == c.watch_id }).filter { $0.phase == "received" }.max { $0.at_ms < $1.at_ms }?.update_id
    }
    public func record(_ phase: String, connection: Connection?, updateID: String? = nil, watchID: String? = nil, now: Date = Date()) {
        let update = updateID ?? (phase == "opened" ? connection.flatMap { latestUpdate($0) } : nil)
        let event = PushTraceEvent(id: UUID().uuidString.lowercased(), update_id: update,
            watch_id: connection?.watch_id ?? watchID ?? "", phase: phase,
            at_ms: Int64(now.timeIntervalSince1970 * 1000), panel: connection?.entity ?? "", revision: connection?.revision)
        lock.lock(); defer { lock.unlock() }
        let k = key(connection); write(read(k) + [event], k)
    }
    public func history(_ c: Connection?) -> [PushTraceEvent] {
        lock.lock(); defer { lock.unlock() }
        return (read(key(c)) + (c == nil ? [] : read(key(nil)))).sorted { $0.at_ms < $1.at_ms }
    }
    public func pending(_ c: Connection) -> [PushTraceEvent] {
        history(c).filter { !$0.reported && $0.watch_id == c.watch_id }.prefix(12).map { $0 }
    }
    public func acknowledge(_ ids: Set<String>, connection: Connection) {
        lock.lock(); defer { lock.unlock() }
        for k in [key(connection), key(nil)] {
            write(read(k).map { event in
                var next = event
                if next.watch_id == connection.watch_id && ids.contains(next.id) { next.reported = true }
                return next
            }, k)
        }
    }
    public func clear() {
        lock.lock(); defer { lock.unlock() }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("pushtrace.") { defaults.removeObject(forKey: key) }
    }
}
