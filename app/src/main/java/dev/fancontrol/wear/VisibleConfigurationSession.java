package dev.fancontrol.wear;

import java.util.concurrent.Executor;
import java.util.function.Consumer;
import java.util.function.Function;

/** Independent configuration reads cannot be held up by device state or command work. */
final class VisibleConfigurationSession {
    interface Client { ConnectionSettings configuration() throws Exception; void cancel(); }
    record Update(ConnectionSettings original, ConnectionSettings updated, long generation) { }
    private final Executor executor;
    private final Function<ConnectionSettings, Client> factory;
    private final Consumer<Update> listener;
    private Client active;
    private long generation;
    VisibleConfigurationSession(Executor executor, Function<ConnectionSettings, Client> factory, Consumer<Update> listener) {
        this.executor = executor; this.factory = factory; this.listener = listener;
    }
    synchronized void refresh(ConnectionSettings settings) {
        if (active != null || settings == null || !settings.integration()) return;
        long ticket = generation;
        Client client = factory.apply(settings); active = client;
        executor.execute(() -> {
            try {
                ConnectionSettings updated = client.configuration();
                synchronized (this) {
                    if (ticket == generation) listener.accept(new Update(settings, updated, ticket));
                }
            } catch (Exception ignored) { } // State refresh reports connectivity failures without exposing details.
            finally { synchronized (this) { if (active == client) active = null; } }
        });
    }
    synchronized boolean accepts(Update update) { return update.generation() == generation; }
    synchronized void close() { generation++; if (active != null) active.cancel(); active = null; }
}
