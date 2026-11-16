#if DEBUG
import Foundation
import FanControlCore

// Explicit simulator-only launch fixtures; never pair, save credentials or send requests.
enum ControlPreview {
    static func snapshot() -> (Connection, [String: Any])? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--preview-driving") || args.contains("--preview-exercise") else { return nil }
        let type = args.contains("--preview-exercise") ? "exercise" : "driving"
        let json = """
        {"url":"https://example.invalid","token":"\(String(repeating: "a", count: 64))","watch_id":"\(String(repeating: "b", count: 32))",
        "entity":"panel.preview","devices":[{"entity":"panel.preview","title":"Preview","panel":{
        "id":"preview","name":"Preview","type":"\(type)","color":[112,226,194],"garage_entity":"cover.garage",
        "trunk_entity":"cover.trunk","climate_entity":"climate.car","lock_entity":"lock.car",
        "horn_entity":"button.horn","podcast_entity":"script.podcast","wake_entity":"button.wake","awake_entity":"binary_sensor.online"}}]}
        """
        guard let c = try? JSONDecoder().decode(Connection.self, from: Data(json.utf8)).validated() else { return nil }
        return (c, ["vehicle_ready":true,"garage_state":"closed","trunk_state":"open",
                    "garage_open_available":true,"garage_close_available":true,"trunk_open_available":true,"trunk_close_available":true,
                    "climate_available":true,"climate_off_available":true,"climate_on":true,"honk_available":true,"podcast_available":true,
                    "start_available":true,"stop_available":true,"locked":true])
    }
}
#endif
