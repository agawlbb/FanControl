package dev.fancontrol.wear;

import java.util.List;
import java.util.Map;
import org.junit.Test;
import static org.junit.Assert.*;

public class CommandFeedbackTest {
    @Test public void offToOnIsImmediateButAllProjectedControlsRemainDisabled() {
        DeviceController.Snapshot actual = DeviceControllers.Fan.snapshot(new FanState(false,0,true,true));
        String action = CommandFeedback.action(actual,"toggle");
        DeviceController.Snapshot requested = CommandFeedback.requested(actual,action);
        assertEquals("turn_on",action); assertEquals("On",requested.status());
        assertEquals("ON",requested.controls().get(0).label());
        assertTrue(requested.controls().get(0).selected());
        assertTrue(requested.controls().stream().noneMatch(DeviceController.Control::enabled));
        assertEquals("Off · Speed 0",actual.status()); assertTrue(actual.controls().get(0).enabled());
    }
    @Test public void onToOffDoesNotLeaveOldSpeedSelected() {
        DeviceController.Snapshot actual = DeviceControllers.Fan.snapshot(new FanState(true,6,true,true));
        DeviceController.Snapshot requested = CommandFeedback.requested(actual,CommandFeedback.action(actual,"toggle"));
        assertEquals("Off",requested.status()); assertEquals("OFF",requested.controls().get(0).label());
        assertTrue(requested.controls().stream().noneMatch(DeviceController.Control::selected));
    }
    @Test public void speedRequestShowsDesiredSpeedWithoutChangingConfirmedSnapshot() {
        DeviceController.Snapshot actual = DeviceControllers.Fan.snapshot(new FanState(true,2,true,true));
        DeviceController.Snapshot requested = CommandFeedback.requested(actual,"speed5");
        assertEquals("On · Speed 5",requested.status());
        assertTrue(requested.controls().stream().anyMatch(c -> c.action().equals("speed5") && c.selected()));
        assertTrue(actual.controls().stream().anyMatch(c -> c.action().equals("speed2") && c.selected()));
    }
    @Test public void genericSwitchDisplaysOnAndResolvesAnAbsoluteIntent() {
        DeviceController.Snapshot actual = new DeviceController.Snapshot("Off",List.of(new DeviceController.Control("toggle","OFF",true,false)));
        assertEquals("turn_on",CommandFeedback.action(actual,"toggle"));
        assertEquals("ON",CommandFeedback.requested(actual,"turn_on").controls().get(0).label());
    }
    @Test public void climateRequestPreservesBatteryAndIsSeparateFromConfirmedReadings() {
        DeviceController.Snapshot actual = new WorkMorningState("80",true,true,true).snapshot();
        String action=CommandFeedback.action(actual,"climate");
        DeviceController.Snapshot requested=CommandFeedback.requested(actual,action);
        assertEquals("climate_off",action); assertEquals("OFF",requested.readings().get("climate"));
        assertEquals("80",requested.readings().get("battery")); assertEquals("ON",actual.readings().get("climate"));
    }
    @Test public void scriptShowsRequestedNotCompletedAndDoesNotChangeClimate() {
        DeviceController.Snapshot actual = new WorkMorningState("80",true,true,true).snapshot();
        DeviceController.Snapshot requested=CommandFeedback.requested(actual,"leave");
        assertEquals("REQUESTED",requested.controls().get(1).label());
        assertEquals("ON",requested.readings().get("climate"));
        assertTrue(requested.controls().stream().noneMatch(DeviceController.Control::enabled));
    }
    @Test public void sceneRequestIsNotReportedAsAConfirmedPhysicalState() {
        DeviceController.Snapshot actual=new DeviceController.Snapshot("Ready",List.of(new DeviceController.Control("activate","Run",true,false)),Map.of());
        assertEquals("REQUESTED",CommandFeedback.requested(actual,"activate").controls().get(0).label());
        assertEquals("Run",actual.controls().get(0).label());
    }
    @Test public void explicitVehicleClimateIntentIsKnownEvenWhenCurrentStateIsUnknown() {
        assertEquals("climate_on",CommandFeedback.vehicleAction("climate",false));
        assertEquals("Climate ON",CommandFeedback.title("climate_on"));
        assertEquals("LOCKED",CommandFeedback.title("start_exercise"));
    }
    @Test public void vehicleFeedbackCannotApplyToAnotherWatchOrEditedPanel() {
        PanelDefinition panel=new PanelDefinition("morning","Morning","sensor.battery","climate.car","script.leave","Climate","Leave","button.wake","binary_sensor.awake");
        VehicleFeedback feedback=new VehicleFeedback(panel,"watch-a","climate_on",true,false);
        assertTrue(feedback.matches(panel,"watch-a")); assertFalse(feedback.confirmed());
        assertFalse(feedback.matches(panel,"watch-b"));
        PanelDefinition edited=new PanelDefinition("morning","Morning","sensor.battery","climate.other","script.leave","Climate","Leave","button.wake","binary_sensor.awake");
        assertFalse(feedback.matches(edited,"watch-a"));
    }
}
