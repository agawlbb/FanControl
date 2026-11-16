import Foundation

// Shared timing and terminal-outcome policy; transport acceptance is not evidence.
public enum VehicleOperation {
    public static let deliverySeconds: TimeInterval = 180
    public static let finalSeconds: TimeInterval = 15
    public static let alertSeconds = deliverySeconds + finalSeconds
    public static func terminal(_ status: String) -> Bool {
        ["complete", "accepted", "failed", "unconfirmed", "cancelled", "unknown"].contains(status)
    }
}
