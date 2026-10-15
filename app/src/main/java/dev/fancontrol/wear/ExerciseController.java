package dev.fancontrol.wear;

import org.json.JSONObject;
import org.json.JSONArray;
import java.util.List;
import java.util.Map;

final class ExerciseController implements DeviceController {
    private final IntegrationClient client;
    private final PanelDefinition panel;
    private volatile boolean cancelled;
    ExerciseController(ConnectionSettings settings, PanelDefinition panel) { this.panel = panel; client = new IntegrationClient(settings); }
    private JSONObject request(String action, String command) throws Exception {
        JSONObject body = new JSONObject().put("action", action).put("panel_id", panel.id());
        if (command != null) body.put("command", command);
        return client.request(body);
    }
    private JSONObject state() throws Exception { return request("panel_state", null); }
    public Snapshot read() throws Exception { return snapshot(state(), ""); }
    public Snapshot enter() throws Exception {
        final JSONObject[] latest = {null};
        VehicleEntry.await(() -> request("panel_command", "wake"), () -> {
            latest[0] = state();
            boolean ready = Boolean.TRUE.equals(latest[0].opt("vehicle_ready"));
            return new WorkMorningState(ready ? "0" : "?", false, ready, false);
        }, () -> cancelled, () -> System.nanoTime()/1_000_000L, Thread::sleep);
        return snapshot(latest[0], "");
    }
    public Snapshot command(String action) throws Exception {
        if (!List.of("start_exercise", "stop_exercise").contains(action)) throw new IllegalArgumentException("Unsupported Exercise action");
        JSONObject before = state();
        if (!Boolean.TRUE.equals(before.opt(action.equals("start_exercise") ? "start_available" : "stop_available"))) throw new IllegalStateException("Exercise unavailable");
        JSONObject result = request("panel_command", action);
        JSONArray steps = result.optJSONArray("steps");
        StringBuilder message = new StringBuilder();
        boolean requested = steps != null && steps.length() > 0;
        if (steps != null) for (int i=0;i<steps.length();i++) {
            JSONObject step = steps.getJSONObject(i);
            String status = step.optString("status");
            requested &= status.equals("requested");
            if (i>0) message.append("; ");
            message.append(step.optString("step").replace('_',' ')).append(": ").append(status);
        }
        // User requested no observed-lock wait: launch after dispatch acknowledgement only.
        boolean launch = ExerciseOutcome.launchSpotify(action, requested);
        if (action.equals("start_exercise") && requested) message = new StringBuilder("Lock requested");
        Snapshot snapshot = snapshot(result, message.toString());
        return new Snapshot(snapshot.status(), snapshot.controls(), Map.of("launch_spotify", launch ? "yes" : "no"));
    }
    private Snapshot snapshot(JSONObject state, String status) {
        boolean ready = Boolean.TRUE.equals(state.opt("vehicle_ready"));
        return new Snapshot(status.isEmpty() ? ready ? "Ready" : "Vehicle unavailable" : status,
                List.of(new Control("start_exercise", "Start exercise", ready && Boolean.TRUE.equals(state.opt("start_available")), false),
                        new Control("stop_exercise", "Stop exercise", ready && Boolean.TRUE.equals(state.opt("stop_available")), false)));
    }
    public void cancel() { cancelled = true; client.cancel(); }
}
