package dev.fancontrol.wear;

import org.junit.Test;
import static org.junit.Assert.*;

public class FanStateTest {
    @Test public void allSixSpeedsMapToHomeAssistantPercentages() {
        int[] expected = {16, 33, 50, 66, 83, 100};
        for (int speed = 1; speed <= 6; speed++) {
            assertEquals(expected[speed - 1], FanState.percentageForSpeed(speed));
            assertEquals(speed, FanState.speedForPercentage(expected[speed - 1]));
        }
    }
    @Test(expected = IllegalArgumentException.class) public void zeroIsNotASelectableSpeed() { FanState.percentageForSpeed(0); }
    @Test(expected = IllegalArgumentException.class) public void sevenIsNotASelectableSpeed() { FanState.percentageForSpeed(7); }
    @Test public void offOverridesRememberedSpeed() throws Exception {
        FanState state = FanState.parse("{\"state\":\"off\",\"attributes\":{\"percentage\":83,\"supported_features\":1}}");
        assertFalse(state.on()); assertEquals(0, state.speed()); assertTrue(state.speedSupported());
    }
    @Test public void unsupportedAndUnavailableAreExplicit() throws Exception {
        FanState state = FanState.parse("{\"state\":\"unavailable\",\"attributes\":{}}");
        assertFalse(state.available()); assertFalse(state.speedSupported());
        assertEquals("Unavailable", state.label());
    }
    @Test public void missingPercentageIsUnknownWhenOn() throws Exception {
        assertEquals("On · Speed ?", FanState.parse("{\"state\":\"on\",\"attributes\":{}}").label());
    }
}
