package dev.fancontrol.wear;

import org.json.JSONObject;

/** State is confirmed by the server, never guessed after a command. */
public record FanState(boolean on, int speed, boolean speedSupported, boolean available) {
    public static int percentageForSpeed(int speed) {
        if (speed < 1 || speed > 6) throw new IllegalArgumentException("Speed must be 1–6");
        return Math.round(speed * 100 / 6.0f);
    }

    public static int speedForPercentage(double percentage) {
        if (!Double.isFinite(percentage) || percentage <= 0) return 0;
        return Math.min(6, Math.max(1, (int) Math.round(percentage * 6 / 100.0)));
    }

    public static FanState parse(String json) throws Exception {
        JSONObject state = new JSONObject(json);
        String value = state.getString("state");
        JSONObject attributes = state.optJSONObject("attributes");
        boolean supported = attributes != null && (attributes.optInt("supported_features", 0) & 1) != 0;
        boolean known = value.equals("on") || value.equals("off");
        int speed = attributes == null || attributes.isNull("percentage") ? -1
                : speedForPercentage(attributes.optDouble("percentage", Double.NaN));
        return new FanState(value.equals("on"), value.equals("off") ? 0 : speed, supported, known);
    }

    public String label() {
        if (!available) return "Unavailable";
        return on ? "On · Speed " + (speed > 0 ? speed : "?") : "Off · Speed 0";
    }
}
