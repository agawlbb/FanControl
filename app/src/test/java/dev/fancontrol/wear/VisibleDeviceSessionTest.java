package dev.fancontrol.wear;

import org.junit.Test;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Executor;
import static org.junit.Assert.*;

public class VisibleDeviceSessionTest {
    private static final class Queue implements Executor {
        final ArrayDeque<Runnable> tasks = new ArrayDeque<>();
        public void execute(Runnable command) { tasks.add(command); }
        void drain() { while (!tasks.isEmpty()) tasks.remove().run(); }
    }
    private static final class Controller implements DeviceController {
        int reads, commands; boolean cancelled; Runnable onRead;
        public Snapshot read() {
            reads++; if (onRead != null) onRead.run();
            return new Snapshot("Confirmed", List.of());
        }
        public Snapshot command(String action) { commands++; return new Snapshot(action, List.of()); }
        public void cancel() { cancelled = true; }
    }
    private final Queue queue = new Queue();
    private final List<Controller> created = new ArrayList<>();
    private final List<VisibleDeviceSession.Update> updates = new ArrayList<>();
    private VisibleDeviceSession session() {
        return new VisibleDeviceSession(List.of(new DeviceDefinition("fan.first", "First"), new DeviceDefinition("fan.second", "Second")),
                device -> { Controller controller = new Controller(); created.add(controller); return controller; }, queue, updates::add);
    }
    @Test public void selectingOffscreenPagesNeverConnects() {
        VisibleDeviceSession session = session(); session.select(1); session.refresh(); session.command("toggle"); queue.drain();
        assertTrue(created.isEmpty()); assertTrue(updates.isEmpty());
    }
    @Test public void onlyCurrentPageLoadsOnResume() {
        VisibleDeviceSession session = session(); session.select(1); session.resume(); queue.drain();
        assertEquals(1, created.size()); assertEquals(1, created.get(0).reads);
        assertEquals(1, updates.get(updates.size() - 1).page());
    }
    @Test public void swipingCancelsPreviousWorkAndDoesNotLoadUntilSettled() {
        VisibleDeviceSession session = session(); session.resume(); session.suspend(); session.select(1); queue.drain();
        assertEquals(0, created.get(0).reads); assertTrue(created.get(0).cancelled);
        assertEquals(1, created.size()); session.resume(); queue.drain(); assertEquals(1, created.get(1).reads);
    }
    @Test public void leavingDuringReadDiscardsResult() {
        VisibleDeviceSession session = session(); session.resume(); created.get(0).onRead = session::suspend; queue.drain();
        assertTrue(updates.stream().noneMatch(update -> update.snapshot() != null));
        assertTrue(created.get(0).cancelled);
    }
    @Test public void staleQueuedUiUpdatesAreRejectedAfterPageChange() {
        VisibleDeviceSession session = session(); session.resume(); queue.drain();
        VisibleDeviceSession.Update old = updates.get(updates.size() - 1); assertTrue(session.accepts(old));
        session.select(1); assertFalse(session.accepts(old));
    }
    @Test public void commandsAreScopedToTheSelectedVisiblePage() {
        VisibleDeviceSession session = session(); session.resume(); queue.drain(); session.select(1); queue.drain();
        session.command("toggle"); queue.drain();
        assertEquals(0, created.get(0).commands); assertEquals(1, created.get(created.size() - 1).commands);
        session.suspend(); int count = created.size(); session.command("toggle"); assertEquals(count, created.size());
    }
    @Test public void repeatedResumeDoesNotPoll() {
        VisibleDeviceSession session = session(); session.resume(); session.resume(); queue.drain();
        assertEquals(1, created.size()); assertEquals(1, created.get(0).reads); assertTrue(queue.tasks.isEmpty());
    }
    @Test(expected = IllegalArgumentException.class) public void invalidPageDoesNotChangeSelection() { session().select(2); }
}
