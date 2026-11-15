import Foundation

public struct MusicSyncAttempt: Sendable {
    public let id: UUID
    public let watchID: String
    public let deadline: Date
    public private(set) var submitted = false
    public init(watchID: String, id: UUID = UUID(), now: Date = Date()) {
        self.watchID = watchID; self.id = id; deadline = now.addingTimeInterval(15)
    }
    public mutating func claim(activated: Bool, reachable: Bool, watchID: String, now: Date = Date()) -> Bool {
        guard !submitted, activated, reachable, self.watchID == watchID, now < deadline else { return false }
        submitted = true
        return true
    }
}

public enum MusicSyncFailure: String, Codable, Error, Sendable {
    case notLinked, differentWatch, transferUnavailable, invalidReply
    public var message: String {
        switch self {
        case .notLinked: return "iPhone app is not linked to a watch. Link it in iPhone Settings."
        case .differentWatch: return "iPhone app is linked to a different watch. Relink it in iPhone Settings."
        case .transferUnavailable: return "iPhone could not prepare music. Check the error in the iPhone app."
        case .invalidReply: return "iPhone returned no matching music playlist. Check both app versions."
        }
    }
}
public struct MusicSyncReply: Codable, Sendable {
    public let requestID: UUID
    public let watchID: String?
    public let playlist: OfflinePlaylist?
    public let failure: MusicSyncFailure?
    public init(requestID: UUID, watchID: String?, playlist: OfflinePlaylist? = nil, failure: MusicSyncFailure? = nil) {
        self.requestID = requestID; self.watchID = watchID; self.playlist = playlist; self.failure = failure
    }
    public func resolved(requestID: UUID, watchID: String) throws -> OfflinePlaylist {
        guard self.requestID == requestID else { throw MusicSyncFailure.invalidReply }
        if let failure { throw failure }
        guard self.watchID == watchID, let playlist, playlist.watchID == watchID else { throw MusicSyncFailure.invalidReply }
        try playlist.validate()
        return playlist
    }
}
