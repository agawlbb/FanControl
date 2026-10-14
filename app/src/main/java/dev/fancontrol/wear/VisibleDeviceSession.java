package dev.fancontrol.wear;

import java.util.List;
import java.util.concurrent.Executor;
import java.util.function.Consumer;
import java.util.function.Function;

/** Pager binding/prefetch does not activate a controller. Only a settled, visible page does. */
final class VisibleDeviceSession {
    record Update(int page, DeviceController.Snapshot snapshot, String error, long generation) { }
    private final List<DeviceDefinition> devices;
    private final Function<DeviceDefinition, DeviceController> factory;
    private final Executor executor;
    private final Consumer<Update> listener;
    private boolean visible;
    private int page;
    private long generation;
    private DeviceController active;

    VisibleDeviceSession(List<DeviceDefinition> devices, Function<DeviceDefinition, DeviceController> factory,
                         Executor executor, Consumer<Update> listener) {
        if (devices.isEmpty()) throw new IllegalArgumentException("No device pages");
        this.devices = List.copyOf(devices); this.factory = factory; this.executor = executor; this.listener = listener;
    }
    synchronized void select(int page) {
        if (page < 0 || page >= devices.size()) throw new IllegalArgumentException("Invalid device page");
        if (this.page == page) return;
        stop(); this.page = page;
        if (visible) start("@enter");
    }
    synchronized void resume() { if (!visible) { visible = true; start("@enter"); } }
    synchronized void suspend() { visible = false; stop(); }
    synchronized void refresh() { if (visible) start(null); }
    synchronized void command(String action) { if (visible) start(action); }
    synchronized boolean accepts(Update update) { return current(update.generation(), update.page()); }
    private void stop() { generation++; if (active != null) active.cancel(); active = null; }
    private void start(String action) {
        stop();
        long ticket = generation;
        int selected = page;
        DeviceController controller = factory.apply(devices.get(selected)); active = controller;
        listener.accept(new Update(selected, null, null, ticket));
        executor.execute(() -> {
            if (!current(ticket, selected)) return;
            try {
                DeviceController.Snapshot state = action == null ? controller.read() : action.equals("@enter") ? controller.enter() : controller.command(action);
                deliver(ticket, selected, state, null);
            } catch (Exception ignored) {
                // Never expose a URL, device identity, response body, or credential through an exception.
                deliver(ticket, selected, null, "Could not update · tap Refresh");
            }
        });
    }
    private synchronized boolean current(long ticket, int selected) { return visible && ticket == generation && selected == page; }
    private synchronized void deliver(long ticket, int selected, DeviceController.Snapshot state, String error) {
        if (current(ticket, selected)) listener.accept(new Update(selected, state, error, ticket));
    }
}
