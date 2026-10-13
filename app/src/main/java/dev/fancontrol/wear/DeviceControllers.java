package dev.fancontrol.wear;

import java.util.ArrayList;
import java.util.List;

/** Add one domain adapter here when implementing another type of device. */
final class DeviceControllers {
    static DeviceController create(ConnectionSettings connection, DeviceDefinition device) {
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

    static final class Simple implements DeviceController {
        private final DeviceDefinition device;
        private final HomeAssistantTransport transport;
        Simple(ConnectionSettings connection, DeviceDefinition device) { this.device = device; transport = new HomeAssistantTransport(connection); }
        public Snapshot read() throws Exception {
            org.json.JSONObject state = new org.json.JSONObject(transport.readEntity(device.entityId()));
            String value = state.getString("state"); boolean available = !value.equals("unavailable") && !value.equals("unknown");
            boolean activate = device.domain().equals("script") || device.domain().equals("scene");
            return new Snapshot(activate ? available ? "Ready" : "Unavailable" : value.equals("on") ? "On" : value.equals("off") ? "Off" : "Unavailable",
                    List.of(new Control(activate ? "activate" : "toggle", activate ? "Run" : value.equals("on") ? "Turn off" : "Turn on", available, false)));
        }
        public Snapshot command(String action) throws Exception {
            Snapshot current = read();
            if (!current.controls().get(0).enabled()) throw new IllegalStateException("Device unavailable");
            String expected = current.controls().get(0).action(); if (!action.equals(expected)) throw new IllegalArgumentException("Unknown action");
            String service = action.equals("activate") ? "turn_on" : current.status().equals("On") ? "turn_off" : "turn_on";
            transport.callService(device.domain(), service, new org.json.JSONObject().put("entity_id", device.entityId())); return read();
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
            controls.add(new Control("toggle", state.on() ? "Turn off" : "Turn on", state.available(), false));
            for (int speed = 1; speed <= 6; speed++) controls.add(new Control("speed" + speed, Integer.toString(speed),
                    state.available() && state.speedSupported(), state.on() && state.speed() == speed));
            return new Snapshot(state.label(), controls);
        }
    }
}
