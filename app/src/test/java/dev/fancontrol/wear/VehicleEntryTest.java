package dev.fancontrol.wear;
import org.junit.Test;
import java.io.IOException;
import static org.junit.Assert.*;

public class VehicleEntryTest {
    private final WorkMorningState ready = new WorkMorningState("80", false, true, true);
    private final WorkMorningState unavailable = new WorkMorningState("?", false, false, false);
    @Test public void wakesOnceThenWaitsForSubsequentReadyRead() throws Exception {
        int[] calls = {0,0}; long[] time = {0};
        assertEquals(ready, VehicleEntry.await(() -> calls[0]++, () -> ++calls[1] == 3 ? ready : unavailable,
            () -> false, () -> time[0], ms -> time[0] += ms));
        assertEquals(1, calls[0]); assertEquals(3, calls[1]);
    }
    @Test public void timeoutIsBoundedAndNeverRepeatsWake() throws Exception {
        int[] calls = {0,0}; long[] time = {0};
        try { VehicleEntry.await(() -> calls[0]++, () -> { calls[1]++; return unavailable; },
            () -> false, () -> time[0], ms -> time[0] += ms); fail(); }
        catch (IOException expected) { assertEquals("Vehicle not ready", expected.getMessage()); }
        assertEquals(1, calls[0]); assertEquals(15, calls[1]); assertEquals(30_000, time[0]);
    }
    @Test public void leavingDuringWaitStopsReads() throws Exception {
        boolean[] cancelled = {false}; int[] reads = {0};
        try { VehicleEntry.await(() -> {}, () -> { reads[0]++; return unavailable; },
            () -> cancelled[0], () -> 0L, ms -> cancelled[0] = true); fail(); }
        catch (IOException expected) { assertEquals("Cancelled", expected.getMessage()); }
        assertEquals(1, reads[0]);
    }
    @Test public void cancelledBeforeEntryNeverWakes() throws Exception {
        try { VehicleEntry.await(() -> fail(), () -> ready, () -> true, () -> 0L, ms -> {}); fail(); }
        catch (IOException expected) { assertEquals("Cancelled", expected.getMessage()); }
    }
    @Test public void ambiguousWakeFailureIsNotRetried() throws Exception {
        int[] calls = {0};
        try { VehicleEntry.await(() -> { calls[0]++; throw new IOException("ambiguous"); },
            () -> { fail(); return ready; }, () -> false, () -> 0L, ms -> {}); fail(); }
        catch (IOException expected) { assertEquals("ambiguous", expected.getMessage()); }
        assertEquals(1, calls[0]);
    }
    @Test public void staleVehicleTapRefreshesBeforeControlsWhileOtherPanelsAreUnchanged() {
        assertEquals("refresh", VisibleEntryGate.safeAction("leave", true, false));
        assertEquals("climate", VisibleEntryGate.safeAction("climate", true, true));
        assertEquals("toggle", VisibleEntryGate.safeAction("toggle", false, false));
    }
    @Test public void duplicateVisibleCallbacksAndPollsDoNotReenter() {
        VisibleEntryGate gate = new VisibleEntryGate();
        assertTrue(gate.claim("one")); assertFalse(gate.claim("one"));
        assertTrue(gate.claim("two")); assertFalse(gate.claim("two"));
        gate.leave(); assertTrue(gate.claim("two"));
    }
}
