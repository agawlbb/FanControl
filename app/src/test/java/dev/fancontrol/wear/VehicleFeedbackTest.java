package dev.fancontrol.wear;

import org.junit.Test;
import static org.junit.Assert.*;

public class VehicleFeedbackTest {
    private final PanelDefinition panel = new PanelDefinition("morning","Morning","sensor.battery","climate.car","script.leave","Climate","Leave");
    @Test public void pendingClimateKeepsRequestedStateDespiteOldOrUnknownReads() {
        VehicleFeedback feedback = new VehicleFeedback(panel,"watch","climate_on",true,false);
        assertEquals("ON",feedback.climateState("OFF"));
        assertEquals("ON",feedback.climateState("?"));
        assertTrue(feedback.pending());
        assertFalse(feedback.confirmed());
    }
    @Test public void confirmedClimateRetainsTargetDuringNextRefresh() {
        VehicleFeedback feedback = new VehicleFeedback(panel,"watch","climate_off",false,true);
        assertEquals("OFF",feedback.climateState("ON"));
        assertFalse(feedback.pending());
    }
    @Test public void failedCommandReturnsToObservedStateAndOtherActionsDoNotAlterClimate() {
        assertEquals("OFF",new VehicleFeedback(panel,"watch","climate_on",false,false).climateState("OFF"));
        assertEquals("ON",new VehicleFeedback(panel,"watch","leave",true,false).climateState("ON"));
    }
}
