import Foundation

public enum ToggleIntent {
    // Transitional evidence stays gray but still presents an absolute toggle target.
    public static func coverPresentation(_ observed: String?) -> String {
        ["open", "opening"].contains(observed ?? "") ? "OPEN" : "CLOSED"
    }
    public static func family(_ command: String) -> String? {
        if ["turn_on", "turn_off"].contains(command) { return "power" }
        if ["climate_on", "climate_off"].contains(command) { return "climate" }
        if ["garage_open", "garage_close"].contains(command) { return "garage" }
        if ["trunk_open", "trunk_close"].contains(command) { return "trunk" }
        return nil
    }
    public static func opposite(_ command: String) -> String? {
        switch command {
        case "turn_on": return "turn_off"
        case "turn_off": return "turn_on"
        case "climate_on": return "climate_off"
        case "climate_off": return "climate_on"
        case "garage_open": return "garage_close"
        case "garage_close": return "garage_open"
        case "trunk_open": return "trunk_close"
        case "trunk_close": return "trunk_open"
        default: return nil
        }
    }
    public static func replaces(_ command: String, _ previous: String?) -> Bool {
        guard let family = family(command), let previous else { return false }
        return family == self.family(previous)
    }
}
