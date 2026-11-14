import Foundation
import CryptoKit

// Local navigation preference, separate from HA's authenticated selection.
public final class DefaultWatchTile {
    private let defaults: UserDefaults
    private let key = "defaultWatchTile"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    private func scope(_ connection: Connection) -> String {
        var value = connection
        value.companion_settings = nil
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return SHA256.hash(data: (try? encoder.encode(value)) ?? Data()).map { String(format: "%02x", $0) }.joined()
    }
    public func save(_ entity: String, connection: Connection) {
        guard entity == PodcastTile.id || connection.devices.contains(where: { $0.entity == entity }) else { return }
        defaults.set(["scope": scope(connection), "entity": entity], forKey: key)
    }
    public func load(_ connection: Connection) -> String? {
        guard let saved = defaults.dictionary(forKey: key) as? [String: String] else { return nil }
        guard saved["scope"] == scope(connection), let entity = saved["entity"],
              (entity == PodcastTile.id || connection.devices.contains(where: { $0.entity == entity })) else {
            clear(); return nil
        }
        return entity
    }
    public func clear() { defaults.removeObject(forKey: key) }
}
