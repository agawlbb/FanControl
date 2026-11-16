import Foundation

public struct ExerciseTrack: Codable, Equatable, Sendable {
    public let name: String
    public let sha256: String
    public let size: Int
    public init(name: String, sha256: String, size: Int) { self.name = name; self.sha256 = sha256; self.size = size }
    public var fileName: String { sha256 + "." + (name as NSString).pathExtension.lowercased() }
    public func validate() throws {
        guard !name.isEmpty, name.count <= 180, !name.contains("/"), !name.contains("\\"),
              ["mp3", "m4a", "aac"].contains((name as NSString).pathExtension.lowercased()),
              sha256.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
              size > 0, size <= 30 * 1024 * 1024 else { throw ControlError.invalidResponse }
    }
}

public enum ExerciseAudioRoute {
    public static let preferredName = "Joseph's Buds2 Pro"
    public static func isPreferred(name: String, uid: String, rememberedUID: String?) -> Bool {
        // A re-pair can change the OS port UID. Fall back to the configured name.
        let normalized = name.replacingOccurrences(of: "’", with: "'")
        return (!uid.isEmpty && uid == rememberedUID) || normalized == preferredName
    }
    public static func mayPlay(preferredHeadset: Bool, builtInSpeaker: Bool, speakerChosen: Bool) -> Bool {
        preferredHeadset || (builtInSpeaker && speakerChosen)
    }
}
