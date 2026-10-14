package dev.fancontrol.wear;

import java.util.function.BooleanSupplier;
import java.util.function.Function;

/** One read-only check; writes compare the settings revision that started it. */
final class BackgroundConfigurationCheck {
    interface Store {
        ConnectionSettings load();
        boolean replace(ConnectionSettings expected, ConnectionSettings updated) throws Exception;
        boolean revoke(ConnectionSettings expected) throws Exception;
    }
    private final Store store;
    private final Function<ConnectionSettings, VisibleConfigurationSession.Client> factory;
    private final BooleanSupplier foreground;
    private final Runnable changed;
    private VisibleConfigurationSession.Client active;
    private boolean cancelled;
    BackgroundConfigurationCheck(Store store, Function<ConnectionSettings, VisibleConfigurationSession.Client> factory,
                                 BooleanSupplier foreground, Runnable changed) {
        this.store = store; this.factory = factory; this.foreground = foreground; this.changed = changed;
    }
    synchronized void cancel() { cancelled = true; if (active != null) active.cancel(); }
    void run() {
        ConnectionSettings original;
        VisibleConfigurationSession.Client client;
        synchronized (this) {
            original = store.load();
            if (cancelled || foreground.getAsBoolean() || original == null || !original.integration()) return;
            client = factory.apply(original); active = client;
        }
        try {
            ConnectionSettings updated = client.configuration();
            synchronized (this) {
                if (!cancelled && !foreground.getAsBoolean() && !original.equals(updated) && store.replace(original, updated)) changed.run();
            }
        } catch (Exception failure) {
            synchronized (this) {
                if (!cancelled && !foreground.getAsBoolean() && IntegrationClient.accessRevoked(failure)) {
                    try { if (store.revoke(original)) changed.run(); } catch (Exception ignored) { }
                }
            }
            // No immediate retry, raw error logging, device reads, or commands.
        } finally { synchronized (this) { if (active == client) active = null; } }
    }
}
