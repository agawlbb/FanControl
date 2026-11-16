import Foundation

// Delegate callbacks can queue persistence on an actor after WCSession reports
// no pending content. Keep the OS wake alive until both queues are drained.
public final class ConnectivityDrain: @unchecked Sendable {
    private let lock = NSLock()
    private var deliveries = 0
    public init() {}
    public func begin() { lock.lock(); defer { lock.unlock() }; deliveries += 1 }
    public func end() { lock.lock(); defer { lock.unlock() }; deliveries = max(0, deliveries - 1) }
    public func canComplete(activated: Bool, hasContentPending: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return activated && !hasContentPending && deliveries == 0
    }
}
