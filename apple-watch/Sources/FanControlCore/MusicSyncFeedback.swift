import Foundation

public struct MusicSyncFeedback: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable { case idle, connecting, receiving, paused, failed, ready }
    public private(set) var id: UUID?
    public private(set) var phase: Phase = .idle
    public private(set) var message = ""
    public private(set) var history: [String] = []
    public init() {}
    public mutating func begin(_ id: UUID, message: String) {
        self.id = id; phase = .connecting; self.message = message
        append(message)
    }
    public mutating func progress(_ id: UUID, message: String) {
        guard self.id == id, phase != .failed, phase != .ready else { return }
        phase = .receiving; self.message = message
    }
    public mutating func pause(_ id: UUID, message: String) {
        guard self.id == id, phase != .failed, phase != .ready else { return }
        phase = .paused; self.message = message; append(message)
    }
    public mutating func fail(_ id: UUID, message: String) {
        guard self.id == id, phase != .failed, phase != .ready else { return }
        phase = .failed; self.message = message; append(message)
    }
    public mutating func verified(_ id: UUID, tracks: Int) {
        guard self.id == id else { return }
        phase = .ready; message = "\(tracks) \(tracks == 1 ? "track" : "tracks") ready offline"
        append(message)
    }
    private mutating func append(_ value: String) {
        guard history.last != value else { return }
        history.append(value); history = Array(history.suffix(8))
    }
    public static func failure(stage: String, error: Error) -> String {
        if let error = error as? MusicSyncFailure { return "\(stage): \(error.message)" }
        if let error = error as? MusicFileFailure { return "\(stage): \(error.message)" }
        let error = error as NSError
        return "\(stage) failed (\(error.domain) \(error.code))."
    }
}
public enum MusicFileFailure: Error, Sendable {
    case invalidSize, wrongOffset, checksumMismatch, mismatchedReply
    public var message: String {
        switch self {
        case .invalidSize: return "The audio chunk has the wrong length."
        case .wrongOffset: return "The audio chunk arrived at the wrong file position."
        case .checksumMismatch: return "The completed audio file did not pass SHA-256 verification."
        case .mismatchedReply: return "The iPhone returned no matching audio chunk."
        }
    }
}
