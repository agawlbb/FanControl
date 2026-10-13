package dev.fancontrol.wear;

import java.util.ArrayList;
import java.util.List;
import org.junit.Test;
import static org.junit.Assert.*;

public class VisibleConfigurationSessionTest {
    private ConnectionSettings settings(String entity) {
        return new ConnectionSettings("http://homeassistant.local:8123", "12".repeat(32), entity,
                List.of(new DeviceDefinition(entity, "Example")), "", "ab".repeat(16));
    }
    @Test public void configurationCanCompleteWhileDeviceWorkerIsBusy() {
        List<Runnable> queue = new ArrayList<>(); List<VisibleConfigurationSession.Update> delivered = new ArrayList<>();
        VisibleConfigurationSession session = new VisibleConfigurationSession(queue::add, original -> new VisibleConfigurationSession.Client() {
            public ConnectionSettings configuration() { return settings("light.example"); }
            public void cancel() { }
        }, delivered::add);
        session.refresh(settings("fan.example")); session.refresh(settings("fan.example"));
        assertEquals(1, queue.size()); queue.remove(0).run();
        assertEquals("light.example", delivered.get(0).updated().entityId());
    }
    @Test public void leavingCancelsAndDropsLateConfigurationResponses() {
        List<Runnable> queue = new ArrayList<>(); List<VisibleConfigurationSession.Update> delivered = new ArrayList<>(); int[] cancels = {0};
        VisibleConfigurationSession session = new VisibleConfigurationSession(queue::add, original -> new VisibleConfigurationSession.Client() {
            public ConnectionSettings configuration() { return settings("light.example"); }
            public void cancel() { cancels[0]++; }
        }, delivered::add);
        session.refresh(settings("fan.example")); session.close(); queue.remove(0).run();
        assertEquals(1, cancels[0]); assertTrue(delivered.isEmpty());
        session.refresh(settings("fan.example")); queue.remove(0).run();
        assertEquals(1, delivered.size()); session.close(); assertFalse(session.accepts(delivered.get(0)));
    }
}
