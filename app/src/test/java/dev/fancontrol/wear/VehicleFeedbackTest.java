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
    @Test public void failedClimateKeepsTheRequestedStateGrayWithoutClaimingConfirmation() {
        VehicleFeedback failed=new VehicleFeedback(panel,"watch","climate_on",false,false);
        assertEquals("ON",failed.climateState("OFF"));
        assertTrue(failed.unconfirmed("climate"));
        assertFalse(failed.selected("climate"));
        assertTrue(failed.label("climate", "Climate").contains("Not confirmed"));
        assertEquals("ON",new VehicleFeedback(panel,"watch","leave",true,false).climateState("ON"));
    }
    @Test public void everyPanelActionKeepsItsRequestedLabelAndChangesColorOnlyOnConfirmation() {
        for(String action : new String[]{"climate_on","climate_off","leave","start_exercise","stop_exercise"}) {
            VehicleFeedback pending=new VehicleFeedback(panel,"watch",action,true,false);
            VehicleFeedback confirmed=new VehicleFeedback(panel,"watch",action,false,true);
            VehicleFeedback failed=new VehicleFeedback(panel,"watch",action,false,false);
            assertEquals(CommandFeedback.title(action),pending.label(action,"Run"));
            assertEquals(pending.label(action,"Run"),confirmed.label(action,"Run"));
            assertTrue(pending.unconfirmed(action)); assertFalse(pending.selected(action));
            assertFalse(confirmed.unconfirmed(action)); assertTrue(confirmed.selected(action));
            assertEquals(CommandFeedback.CONFIRMED,CommandFeedback.background(confirmed.unconfirmed(action),confirmed.selected(action)));
            assertEquals(CommandFeedback.GRAY_BACKGROUND,CommandFeedback.background(failed.unconfirmed(action),failed.selected(action)));
            assertFalse(failed.pending()); // Retrying is separate from claiming success with a color.
        }
    }
    @Test public void unrelatedControlsCannotInheritAnotherActionsConfirmation() {
        VehicleFeedback confirmed=new VehicleFeedback(panel,"watch","leave",false,true);
        assertFalse(confirmed.selected("climate"));
        assertEquals("Climate",confirmed.label("climate","Climate"));
        assertTrue(new VehicleFeedback(panel,"watch","leave",true,false).unconfirmed("climate"));
    }
}
