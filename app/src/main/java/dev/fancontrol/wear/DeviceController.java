package dev.fancontrol.wear;

import java.util.List;

/** Each device type supplies confirmed state and its own available actions. */
interface DeviceController {
    record Control(String action, String label, boolean enabled, boolean selected) { }
    record Snapshot(String status, List<Control> controls) {
        public Snapshot { controls = List.copyOf(controls); }
    }
    Snapshot read() throws Exception;
    Snapshot command(String action) throws Exception;
    void cancel();
}
