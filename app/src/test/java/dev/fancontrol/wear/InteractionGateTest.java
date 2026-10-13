package dev.fancontrol.wear;

import org.junit.Test;
import static org.junit.Assert.*;
import static dev.fancontrol.wear.InteractionGate.Decision.*;

public class InteractionGateTest {
    @Test public void freshEnterRefreshesOnlyOnce() {
        InteractionGate gate = new InteractionGate();
        assertEquals(REFRESH, gate.accept(10000, true, 10100));
        assertEquals(IGNORE, gate.accept(10000, true, 10100));
    }
    @Test public void historicalEnterDoesNotConnect() {
        assertEquals(IGNORE, new InteractionGate().accept(10000, true, 15000));
    }
    @Test public void leavingCancelsAndOlderEventsCannotReviveOrCancelSession() {
        InteractionGate gate = new InteractionGate();
        assertEquals(LEAVE, gate.accept(11000, false, 11000));
        assertEquals(IGNORE, gate.accept(10000, true, 11000));
        assertEquals(REFRESH, gate.accept(12000, true, 12000));
        assertEquals(IGNORE, gate.accept(11000, false, 12000));
    }
    @Test public void futureTimestampIsNotEvidenceOfViewing() {
        assertEquals(IGNORE, new InteractionGate().accept(15000, true, 10000));
    }
}
