import Foundation
import FanControlCore

// Requested labels are presentation only; observation storage never includes them.
struct RequestedPresentation {
    static func label(command: String, original: String) -> String {
        switch command {
        case "turn_on": return "ON"
        case "turn_off": return "OFF"
        case "climate_on": return "Climate ON"
        case "climate_off": return "Climate OFF"
        case "activate": return original
        case "leave", "honk", "start_exercise", "stop_exercise": return original
        default:
            if command.hasSuffix("_open") { return original.components(separatedBy: "\n")[0] + "\nOPEN" }
            if command.hasSuffix("_close") { return original.components(separatedBy: "\n")[0] + "\nCLOSED" }
            return original
        }
    }
}
