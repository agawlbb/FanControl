package dev.fancontrol.wear;

import java.util.ArrayList;
import java.util.List;

/** Add one domain adapter here when implementing another type of device. */
final class DeviceControllers {
    static DeviceController create(ConnectionSettings connection, DeviceDefinition device) {
        if (connection.integration() && device.panel()!=null && device.panel().driving()) return new DrivingController(connection,device.panel());
        if (connection.integration() && device.panel() != null && device.panel().exercise()) return new ExerciseController(connection, device.panel());
        if (connection.integration() && device.panel() != null) return new WorkMorning(connection, device.panel());
        if (device.domain().equals("fan")) return new Fan(new HomeAssistantClient(connection.forFan(device)));
        if (connection.integration() && List.of("light", "switch", "input_boolean", "script", "scene").contains(device.domain()))
            return new Simple(connection, device);
        // Future/unknown types never guess a service or open a connection.
        return new DeviceController() {
            public Snapshot read() { return new Snapshot("Controls not available yet", List.of()); }
            public Snapshot command(String action) { throw new IllegalArgumentException("Device type unsupported"); }
            public void cancel() { }
        };
    }

    static final class WorkMorning implements DeviceController {
        private final PanelDefinition panel;
        private volatile boolean cancelled;
        private final IntegrationClient client;
        WorkMorning(ConnectionSettings settings, PanelDefinition panel) { this.panel = panel; client = new IntegrationClient(settings); }
        private WorkMorningState state() throws Exception {
            return WorkMorningState.parse(client.request(new org.json.JSONObject().put("action", "panel_state").put("panel_id", panel.id())), panel.vehicle());
        }
        public Snapshot read() throws Exception { return state().snapshot(); }
        public Snapshot enter() throws Exception {
            if (!panel.vehicle()) return read();
            try {
                client.request(new org.json.JSONObject().put("action", "panel_command")
                        .put("panel_id", panel.id()).put("command", "wake"));
            } catch (Exception ignored) { } // Readiness is display state, not permission to accept a tap.
            if (cancelled) throw new java.io.IOException("Cancelled");
            return read();
        }
        public Snapshot command(String action) throws Exception {
            WorkMorningState before = state();
            boolean desired = action.equals("climate_on") || action.equals("climate") && !before.climateOn();
            String command;
            if (List.of("climate", "climate_on", "climate_off").contains(action) && before.climateAvailable()) command = desired ? "climate_on" : "climate_off";
            else if (action.equals("leave") && before.scriptAvailable()) command = "leave";
            else throw new IllegalArgumentException("Panel action unavailable");
            WorkMorningState result = WorkMorningState.parse(client.request(new org.json.JSONObject().put("action", "panel_command")
                    .put("panel_id", panel.id()).put("command", command)), panel.vehicle());
            if (action.equals("leave")) return result.snapshot(); // Acknowledges dispatch, not script completion. Never replay.
            for (int attempt = 0; attempt < 6; attempt++) {
                if (result.climateAvailable() && result.climateOn() == desired) return result.snapshot();
                if (attempt < 5) { Thread.sleep(350); result = state(); }
            }
            throw new java.io.IOException("Waiting for climate confirmation");
        }
        public void cancel() { cancelled = true; client.cancel(); }
    }

    static final class Simple implements DeviceController {
        private final DeviceDefinition device;
        private final HomeAssistantTransport transport;
        Simple(ConnectionSettings connection, DeviceDefinition device) { this.device = device; transport = new HomeAssistantTransport(connection); }
        public Snapshot read() throws Exception {
            org.json.JSONObject state = new org.json.JSONObject(transport.readEntity(device.entityId()));
            String value = state.getString("state"); boolean available = !value.equals("unavailable") && !value.equals("unknown");
            boolean activate = device.domain().equals("script") || device.domain().equals("scene");
            return new Snapshot(activate ? available ? "Ready" : "Unavailable" : value.equals("on") ? "On" : value.equals("off") ? "Off" : "Unavailable",
                    List.of(new Control(activate ? "activate" : "toggle", activate ? "Run" : value.equals("on") ? "ON" : "OFF", available, value.equals("on"))));
        }
        public Snapshot command(String action) throws Exception {
            Snapshot current = read();
            if (!current.controls().get(0).enabled()) throw new IllegalStateException("Device unavailable");
            String expected = current.controls().get(0).action();
            if (!action.equals(expected) && !(expected.equals("toggle") && List.of("turn_on", "turn_off").contains(action))) throw new IllegalArgumentException("Unknown action");
            String service = List.of("turn_on", "turn_off").contains(action) ? action : action.equals("activate") ? "turn_on" : current.status().equals("On") ? "turn_off" : "turn_on";
            transport.callService(device.domain(), service, new org.json.JSONObject().put("entity_id", device.entityId()));
            if (action.equals("activate")) return new Snapshot("Request accepted", List.of(new Control("activate", "REQUESTED", true, true)));
            for (int attempt = 0; attempt < 6; attempt++) {
                if (attempt > 0) Thread.sleep(350);
                Snapshot confirmed = read();
                if (confirmed.status().equals(service.equals("turn_on") ? "On" : "Off")) return confirmed;
            }
            throw new java.io.IOException("Waiting for device confirmation");
        }
        public void cancel() { transport.cancel(); }
    }

    static final class Fan implements DeviceController {
        private final HomeAssistantClient client;
        Fan(HomeAssistantClient client) { this.client = client; }
        public Snapshot read() throws Exception { return snapshot(client.read()); }
        public Snapshot command(String action) throws Exception { return snapshot(client.command(action)); }
        public void cancel() { client.cancel(); }
        static Snapshot snapshot(FanState state) {
            ArrayList<Control> controls = new ArrayList<>();
            controls.add(new Control("toggle", state.on() ? "ON" : "OFF", state.available(), state.on()));
            for (int speed = 1; speed <= 6; speed++) controls.add(new Control("speed" + speed, Integer.toString(speed),
                    state.available() && state.speedSupported(), state.on() && state.speed() == speed));
            return new Snapshot(state.label(), controls);
        }
    }
}
