package dev.fancontrol.wear;

import java.io.IOException;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.Test;
import static org.junit.Assert.*;

public class BackgroundConfigurationCheckTest {
    private ConnectionSettings connection(String entity) {
        return new ConnectionSettings("http://homeassistant.local:8123", "12".repeat(32), entity,
                List.of(new DeviceDefinition(entity, "Device")), "https://remote.example.com", "ab".repeat(16));
    }
    private final class Store implements BackgroundConfigurationCheck.Store {
        ConnectionSettings current = connection("fan.first");
        int writes, revocations;
        public ConnectionSettings load() { return current; }
        public boolean replace(ConnectionSettings expected, ConnectionSettings updated) {
            if (!expected.equals(current)) return false;
            current = updated; writes++; return true;
        }
        public boolean revoke(ConnectionSettings expected) {
            if (!expected.equals(current)) return false;
            current = null; revocations++; return true;
        }
    }
    private static final class Client implements VisibleConfigurationSession.Client {
        ConnectionSettings result;
        Exception failure;
        Runnable during = () -> { };
        int reads;
        boolean cancelled;
        public ConnectionSettings configuration() throws Exception { reads++; during.run(); if (failure != null) throw failure; return result; }
        public void cancel() { cancelled = true; }
    }
    @Test public void periodicWindowIsFifteenMinutesWithBatteryFriendlyFlex() {
        assertEquals(900000, BackgroundConfigurationScheduler.INTERVAL_MS);
        assertEquals(300000, BackgroundConfigurationScheduler.FLEX_MS);
    }
    @Test public void changedConfigurationIsSavedAndPublishedOnce() {
        Store store = new Store(); Client client = new Client(); client.result = connection("fan.second");
        int[] updates = {0};
        new BackgroundConfigurationCheck(store, settings -> client, () -> false, () -> updates[0]++).run();
        assertEquals(1, client.reads); assertEquals(1, store.writes); assertEquals(client.result, store.current); assertEquals(1, updates[0]);
    }
    @Test public void cancelledBeforeStartDoesNotConnect() {
        Store store = new Store(); Client client = new Client();
        BackgroundConfigurationCheck check = new BackgroundConfigurationCheck(store, settings -> client, () -> false, () -> fail());
        check.cancel(); check.run();
        assertEquals(0, client.reads); assertEquals(0, store.writes);
    }
    @Test public void unchangedConfigurationDoesNotWriteOrRequestTileUpdate() {
        Store store = new Store(); Client client = new Client(); client.result = store.current;
        new BackgroundConfigurationCheck(store, settings -> client, () -> false, () -> fail("Unexpected tile update")).run();
        assertEquals(1, client.reads); assertEquals(0, store.writes);
    }
    @Test public void missingOrLegacyConnectionNeverOpensClient() {
        Store store = new Store(); store.current = null;
        BackgroundConfigurationCheck first = new BackgroundConfigurationCheck(store, settings -> { fail(); return null; }, () -> false, () -> fail());
        first.run();
        store.current = new ConnectionSettings("https://ha.example.com", "legacy", "fan.example");
        new BackgroundConfigurationCheck(store, settings -> { fail(); return null; }, () -> false, () -> fail()).run();
    }
    @Test public void visibleTileOrActivitySkipsCheckAndBecomingVisibleSuppressesWrite() {
        Store store = new Store(); Client client = new Client(); client.result = connection("fan.second");
        AtomicBoolean foreground = new AtomicBoolean(true);
        new BackgroundConfigurationCheck(store, settings -> client, foreground::get, () -> fail()).run();
        assertEquals(0, client.reads);
        foreground.set(false); client.during = () -> foreground.set(true);
        new BackgroundConfigurationCheck(store, settings -> client, foreground::get, () -> fail()).run();
        assertEquals(1, client.reads); assertEquals(0, store.writes);
    }
    @Test public void changedPairingOrForgottenConnectionCannotBeOverwritten() {
        Store store = new Store(); Client client = new Client(); client.result = connection("fan.second");
        ConnectionSettings replacement = connection("fan.third"); client.during = () -> store.current = replacement;
        new BackgroundConfigurationCheck(store, settings -> client, () -> false, () -> fail()).run();
        assertSame(replacement, store.current); assertEquals(0, store.writes);
        client.during = () -> store.current = null;
        new BackgroundConfigurationCheck(store, settings -> client, () -> false, () -> fail()).run();
        assertNull(store.current); assertEquals(0, store.writes);
    }
    @Test public void cancellationStopsClientAndLateResponseCannotWrite() throws Exception {
        Store store = new Store(); Client client = new Client(); client.result = connection("fan.second");
        CountDownLatch entered = new CountDownLatch(1), release = new CountDownLatch(1);
        client.during = () -> { entered.countDown(); try { if (!release.await(2, TimeUnit.SECONDS)) throw new AssertionError("No release"); } catch (InterruptedException error) { throw new AssertionError(error); } };
        BackgroundConfigurationCheck check = new BackgroundConfigurationCheck(store, settings -> client, () -> false, () -> fail());
        Thread worker = new Thread(check::run); worker.start();
        try { assertTrue(entered.await(2, TimeUnit.SECONDS)); check.cancel(); assertTrue(client.cancelled); }
        finally { release.countDown(); worker.join(2000); }
        assertFalse(worker.isAlive()); assertEquals(0, store.writes);
    }
    @Test public void transientFailureDoesNotRetryOrRevoke() {
        for (Exception failure : List.of(new IOException("offline"), new IntegrationClient.Rejected(500), new IntegrationClient.Rejected(429))) {
            Store store = new Store(); Client client = new Client(); client.failure = failure;
            new BackgroundConfigurationCheck(store, settings -> client, () -> false, () -> fail()).run();
            assertEquals(1, client.reads); assertEquals(0, store.revocations); assertNotNull(store.current);
        }
    }
    @Test public void revokedAccessClearsOnlyOriginalConnectionAndPublishesSetup() {
        for (int code : List.of(401, 403)) {
            Store store = new Store(); Client client = new Client(); client.failure = new IntegrationClient.Rejected(code);
            int[] updates = {0};
            new BackgroundConfigurationCheck(store, settings -> client, () -> false, () -> updates[0]++).run();
            assertNull(store.current); assertEquals(1, store.revocations); assertEquals(1, updates[0]);
        }
        Store store = new Store(); Client client = new Client(); client.failure = new IntegrationClient.Rejected(403);
        ConnectionSettings replacement = connection("fan.third"); client.during = () -> store.current = replacement;
        new BackgroundConfigurationCheck(store, settings -> client, () -> false, () -> fail()).run();
        assertSame(replacement, store.current); assertEquals(0, store.revocations);
    }
}
