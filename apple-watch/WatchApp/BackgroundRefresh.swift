import Foundation
// Periodic watch refresh is retired. Pending legacy OS tasks complete without
// network work; phone snapshots are persisted by WatchCompanion.
@MainActor enum BackgroundRefresh {
    static let identifier = "dev.fancontrol.watch.refresh"
    static func schedule() {}
    static func run() async {}
    static func refresh(updateID: String? = nil) async -> Bool { false }
}
