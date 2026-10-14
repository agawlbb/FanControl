package dev.fancontrol.wear;

import org.junit.Test;
import static org.junit.Assert.*;

public class SpeedSelectionTest {
    @Test public void burstAccumulatesAndRestartsQuietWindow() {
        SpeedSelection selection = new SpeedSelection();
        selection.tap(2, 1, "a", 0); selection.tap(2, 1, "a", 300); selection.tap(2, 1, "a", 600);
        assertEquals(5, selection.displayed(2));
        assertNull(selection.take(1599)); assertEquals("speed5", selection.take(1600)); assertNull(selection.take(6000));
    }
    @Test public void reversingDirectionChangesDesiredSpeedRatherThanStaleState() {
        SpeedSelection selection = new SpeedSelection();
        selection.tap(3, 1, "a", 0); selection.tap(3, 1, "a", 100); selection.tap(3, -1, "a", 200);
        assertEquals("speed4", selection.take(1200));
    }
    @Test public void boundsStayOneThroughSixAndOffStartsAtOne() {
        SpeedSelection selection = new SpeedSelection(); selection.tap(0, 1, "a", 0);
        assertEquals(1, selection.displayed(0));
        for (int i = 0; i < 10; i++) selection.tap(0, 1, "a", i);
        assertEquals(6, selection.displayed(0));
    }
    @Test public void leavingDiscardsDraftAndDeviceChangeNeverReusesIt() {
        SpeedSelection selection = new SpeedSelection(); selection.tap(2, 1, "a", 0); selection.clear();
        assertNull(selection.take(4000));
        selection.tap(2, 1, "a", 0); selection.tap(5, -1, "b", 100);
        assertEquals("b", selection.target()); assertEquals("speed4", selection.take(1100));
    }
}
