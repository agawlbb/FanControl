package dev.fancontrol.wear;

import java.util.List;
import java.util.Map;
import org.json.JSONObject;

record WorkMorningState(String battery, boolean climateOn, boolean climateAvailable, boolean scriptAvailable) {
    static WorkMorningState parse(JSONObject json, boolean vehicle) throws Exception {
        if (vehicle && !Boolean.TRUE.equals(json.opt("vehicle_ready"))) return new WorkMorningState("?", false, false, false);
        return parse(json);
    }
    // Vehicle parsing hides battery unless HA confirmed online status and valid fields.
    boolean ready() { return !battery.equals("?"); }
    static WorkMorningState parse(JSONObject json) throws Exception {
        String battery = "?";
        if (!json.isNull("battery")) {
            double value = json.getDouble("battery");
            if (Double.isFinite(value) && value >= 0 && value <= 100) battery = Long.toString(Math.round(value));
        }
        return new WorkMorningState(battery, json.getBoolean("climate_on"), json.getBoolean("climate_available"), json.getBoolean("script_available"));
    }
    DeviceController.Snapshot snapshot() {
        String climate = climateAvailable ? climateOn ? "ON" : "OFF" : "?";
        return new DeviceController.Snapshot("Climate " + climate, List.of(
                new DeviceController.Control("climate", "Climate " + climate, climateAvailable, climateOn),
                new DeviceController.Control("leave", "Leave for work", scriptAvailable, false)), Map.of("battery", battery, "climate", climate));
    }
}
