package dev.fancontrol.wear;

import org.json.JSONArray;
import org.json.JSONObject;

/** A tap fixes one intent. Retries never invert climate again or replay an ambiguous script. */
final class VehicleCommandAttempt {
    static final long WINDOW_MS = 60_000;
    interface Request { JSONObject send(JSONObject body) throws Exception; }
    private final PanelDefinition panel;
    private final String action, identity;
    private final long issued;
    private boolean dispatched, acknowledged;
    private Boolean desiredClimate;
    VehicleCommandAttempt(PanelDefinition panel, String action, String identity, long issued) {
        if (!supported(panel, action)) throw new IllegalArgumentException("Unsupported vehicle action");
        this.panel = panel; this.action = action; this.identity = identity; this.issued = issued;
        if (action.equals("climate_on") || action.equals("climate_off")) desiredClimate = action.equals("climate_on");
    }
    static boolean supported(PanelDefinition panel, String action) {
        if (panel.driving()) return java.util.List.of("garage_open","garage_close","trunk_open","trunk_close","climate_on").contains(action);
        return (panel.exercise() ? java.util.List.of("start_exercise", "stop_exercise").contains(action)
                : java.util.List.of("climate", "climate_on", "climate_off", "leave").contains(action));
    }
    private boolean ready(JSONObject state) { return !panel.vehicle() || Boolean.TRUE.equals(state.opt("vehicle_ready")); }
    boolean spotifyReady() { return action.equals("start_exercise") && acknowledged; }
    private JSONObject body(String command) throws Exception {
        JSONObject body = new JSONObject().put("action", command == null ? "panel_state" : "panel_command").put("panel_id", panel.id());
        if (command != null) {
            body.put("command", command);
            if (panel.driving()) body.put("panel_config", panel.toJson());
        }
        return body;
    }
    /** True means observed target state, or script dispatch acknowledgment (not script completion). */
    boolean step(Request request, java.util.function.BooleanSupplier allowed) throws Exception {
        return step(body -> {
            if (!allowed.getAsBoolean()) throw new InterruptedException();
            return request.send(body);
        });
    }
    boolean step(Request request) throws Exception {
        if (action.equals("stop_exercise")) {
            JSONObject result = request.send(body(action).put("operation_id", identity).put("issued_at_ms", issued).put("panel_config", panel.toJson()));
            String status = result.optString("operation_status");
            if (status.equals("complete")) return true;
            if (!status.equals("pending")) throw new IllegalStateException("Stop not confirmed");
            return false;
        }
        JSONObject state = request.send(body(null));
        if (panel.driving() && (action.startsWith("garage_") || action.startsWith("trunk_"))) {
            String role=action.startsWith("garage_")?"garage":"trunk";
            String desired=action.endsWith("_open")?"open":"closed";
            boolean available=state.optBoolean(action+"_available");
            if (available && desired.equals(state.optString(role+"_state"))) return true;
            if (dispatched || !available) return false;
            dispatched=true; // Covers dispatch at most once, even when a response is lost.
            JSONObject result=request.send(body(action));
            return result.optBoolean(action+"_available") && desired.equals(result.optString(role+"_state"));
        }
        if (!ready(state)) return false;
        if (action.equals("leave")) {
            if (dispatched || !state.optBoolean("script_available")) return false;
            dispatched = true; // A script may have executed even if its response is lost.
            request.send(body("leave")); acknowledged = true; return true;
        }
        if (java.util.List.of("climate", "climate_on", "climate_off").contains(action)) {
            if (desiredClimate == null) desiredClimate = !state.getBoolean("climate_on");
            if (dispatched && state.optBoolean("climate_available") && state.getBoolean("climate_on") == desiredClimate) return true;
            if (!state.optBoolean("climate_available")) return false;
            dispatched = true;
            JSONObject result = request.send(body(desiredClimate ? "climate_on" : "climate_off"));
            return ready(result) && result.optBoolean("climate_available") && result.getBoolean("climate_on") == desiredClimate;
        }
        if (dispatched && state.optBoolean("locked")) { acknowledged = true; return true; }
        if (!state.optBoolean("start_available")) return false;
        dispatched = true;
        JSONObject result = request.send(body("start_exercise"));
        JSONArray steps = result.optJSONArray("steps");
        acknowledged = steps != null && steps.length() > 0;
        if (steps != null) for (int i = 0; i < steps.length(); i++) acknowledged &= steps.getJSONObject(i).optString("status").equals("requested");
        return ready(result) && result.optBoolean("locked");
    }
}
