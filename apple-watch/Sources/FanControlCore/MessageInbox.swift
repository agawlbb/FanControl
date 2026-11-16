import Foundation

/// Phone-owned messages. Dismissal IDs prevent an in-flight banner import restoring a removed row.
public struct MessageInbox: Equatable, Sendable {
    public static let lifetimeMS: Int64 = 12 * 60 * 60 * 1000
    public private(set) var messages: [AppMessage]
    public private(set) var dismissed: [String: Int64]

    public init(messages: [AppMessage] = [], dismissed: [String: Int64] = [:]) {
        self.messages = messages
        self.dismissed = dismissed
    }
    @discardableResult public mutating func expire(now: Int64) -> [String] {
        let expired = messages.filter { $0.at_ms <= now - Self.lifetimeMS }.map(\.id)
        messages.removeAll { expired.contains($0.id) }
        dismissed = dismissed.filter { $0.value > now - Self.lifetimeMS }
        return expired
    }
    @discardableResult public mutating func receive(_ message: AppMessage, now: Int64) -> Bool {
        expire(now: now)
        guard message.at_ms > now - Self.lifetimeMS, dismissed[message.id] == nil else { return false }
        guard !messages.contains(where: { $0.id == message.id }) else { return true }
        messages.append(AppMessage(id: message.id, title: message.title, message: message.message, atMS: min(message.at_ms, now)))
        messages.sort { $0.at_ms > $1.at_ms }
        return true
    }
    public mutating func dismiss(_ id: String, now: Int64) {
        if let message = messages.first(where: { $0.id == id }) { dismissed[id] = message.at_ms }
        messages.removeAll { $0.id == id }
        expire(now: now)
    }
}
