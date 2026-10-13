package dev.fancontrol.wear;

import java.util.ArrayList;
import java.util.List;

/** Add one domain adapter here when implementing another type of device. */
final class DeviceControllers {
    static DeviceController create(ConnectionSettings connection, DeviceDefinition device) {
        if (device.domain().equals("fan")) return new Fan(new HomeAssistantClient(connection.forFan(device)));
        // Future/unknown types never guess a service or open a connection.
        return new DeviceController() {
            public Snapshot read() { return new Snapshot("Controls not available yet", List.of()); }
            public Snapshot command(String action) { throw new IllegalArgumentException("Device type unsupported"); }
            public void cancel() { }
        };
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
