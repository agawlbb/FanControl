package dev.fancontrol.wear;

/** Only a successful, available fan result in this visible session is current. */
final class FanTileState {
    private volatile DeviceController.Snapshot current;
    DeviceController.Snapshot current() { return current; }
    void clear() { current = null; }
    void confirm(DeviceController.Snapshot state) {
        current = state != null && !state.controls().isEmpty() && state.controls().get(0).enabled() ? state : null;
    }
}
