import Foundation

public struct AppMessage: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let message: String
    public let at_ms: Int64
    public init(id: String, title: String, message: String, atMS: Int64) {
        self.id = id; self.title = title; self.message = message; self.at_ms = atMS
    }
}
