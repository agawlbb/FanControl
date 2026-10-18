package dev.fancontrol.wear;

import java.util.List;
import org.json.JSONObject;
import org.junit.Test;
import static org.junit.Assert.*;

public class DrivingStateTest {
    static PanelDefinition panel() throws Exception {
        return PanelDefinition.fromJson(new JSONObject().put("type","driving").put("id","driving").put("name","Driving")
                .put("garage_entity","cover.garage").put("trunk_entity","cover.trunk").put("climate_entity","climate.car")
                .put("wake_entity","button.wake").put("awake_entity","binary_sensor.online"));
    }
    static JSONObject state(String garage,String trunk) throws Exception {
        return new JSONObject().put("vehicle_ready",true).put("garage_state",garage).put("trunk_state",trunk)
                .put("garage_open_available",true).put("garage_close_available",true)
                .put("trunk_open_available",true).put("trunk_close_available",true)
                .put("climate_on",false).put("climate_available",true);
    }
    @Test public void initialTrunkIsGrayClosedAndImmediateTapAlwaysOpens() {
        List<DrivingState.Control> controls=DrivingState.controls(null,null,true);
        assertEquals("Trunk\nCLOSED",controls.get(2).label());
        assertEquals("trunk_open",controls.get(2).action());
        assertTrue(controls.get(2).enabled()); assertTrue(controls.get(2).unconfirmed());
        assertTrue(controls.get(0).enabled()); assertTrue(controls.get(0).unconfirmed()); assertEquals("Garage\nCLOSED",controls.get(0).label());
        assertEquals("garage_open",controls.get(0).action());
        assertEquals("climate_on",controls.get(1).action()); assertTrue(controls.get(1).enabled());
    }
    @Test public void assumedClosedNeverEntersAnObservedSnapshot() throws Exception {
        DeviceController.Snapshot snapshot=DrivingState.snapshot(new JSONObject());
        assertEquals("?",snapshot.readings().get("trunk"));
        assertEquals("Trunk\nCLOSED",DrivingState.controls(snapshot,null,true).get(2).label());
        assertEquals("?",snapshot.readings().get("trunk"));
    }
    @Test public void knownOpenAndClosedToggleInOppositeDirectionsWithConfirmedColors() throws Exception {
        List<DrivingState.Control> controls=DrivingState.controls(DrivingState.snapshot(state("closed","open")),null,true);
        assertEquals("garage_open",controls.get(0).action()); assertFalse(controls.get(0).unconfirmed());
        assertEquals("trunk_close",controls.get(2).action()); assertFalse(controls.get(2).unconfirmed()); assertTrue(controls.get(2).selected());
        assertEquals(CommandFeedback.CONFIRMED,CommandFeedback.background(controls.get(2).unconfirmed(),controls.get(2).selected()));
    }
    @Test public void lateClosedReadCannotOverwritePendingOpenIntent() throws Exception {
        VehicleFeedback feedback=new VehicleFeedback(panel(),"watch","trunk_open",true,false);
        List<DrivingState.Control> controls=DrivingState.controls(DrivingState.snapshot(state("closed","closed")),feedback,true);
        assertEquals("Trunk\nOPEN",controls.get(2).label());
        assertTrue(controls.stream().noneMatch(DrivingState.Control::enabled));
        assertTrue(controls.stream().allMatch(DrivingState.Control::unconfirmed));
    }
    @Test public void completedOpenChangesColorAndNextTapClosesButFailedOpenRetriesOpen() throws Exception {
        VehicleFeedback confirmed=new VehicleFeedback(panel(),"watch","trunk_open",false,true);
        DrivingState.Control result=DrivingState.controls(null,confirmed,true).get(2);
        assertTrue(result.selected()); assertFalse(result.unconfirmed()); assertEquals("trunk_close",result.action());
        VehicleFeedback failed=new VehicleFeedback(panel(),"watch","trunk_open",false,false);
        result=DrivingState.controls(null,failed,true).get(2);
        assertTrue(result.enabled()); assertTrue(result.unconfirmed()); assertFalse(result.selected());
        assertEquals("trunk_open",result.action()); assertTrue(result.label().contains("Not confirmed"));
    }
    @Test public void everyDrivingCommandProjectsGrayThenOnlyItsMatchingConfirmation() throws Exception {
        for(String action:List.of("garage_open","garage_close","trunk_open","trunk_close","climate_on")) {
            int index=action.startsWith("garage")?0:action.startsWith("trunk")?2:1;
            VehicleFeedback pending=new VehicleFeedback(panel(),"watch",action,true,false);
            VehicleFeedback confirmed=new VehicleFeedback(panel(),"watch",action,false,true);
            assertTrue(DrivingState.controls(null,pending,true).get(index).unconfirmed());
            assertFalse(DrivingState.controls(null,confirmed,true).get(index).unconfirmed());
        }
    }
    @Test public void movingCoversAreNotConfirmedAndCannotBeToggledAgain() throws Exception {
        List<DrivingState.Control> controls=DrivingState.controls(DrivingState.snapshot(state("opening","closing")),null,true);
        assertTrue(controls.get(0).unconfirmed()); assertFalse(controls.get(0).enabled());
        assertTrue(controls.get(2).unconfirmed()); assertFalse(controls.get(2).enabled());
    }
    @Test public void noPanelMeansNoCommandsEvenThoughTrunkHasAPresentationDefault() {
        assertTrue(DrivingState.controls(null,null,false).stream().noneMatch(DrivingState.Control::enabled));
    }
    @Test public void rolesRoundTripAndUnknownTypesCannotBecomeDrivingPanels() throws Exception {
        PanelDefinition panel=panel(); assertTrue(panel.driving()); assertTrue(panel.vehicle());
        assertEquals(panel,PanelDefinition.fromJson(panel.toJson()));
        assertEquals("cover.garage",panel.garageEntity()); assertFalse(panel.toString().contains("cover.garage"));
        try { PanelDefinition.fromJson(panel.toJson().put("type","unknown")); fail(); } catch(IllegalArgumentException expected) { }
        try { PanelDefinition.fromJson(panel.toJson().put("trunk_entity","cover.garage")); fail(); } catch(IllegalArgumentException expected) { }
    }
    @Test public void separateTileRejectsAmbiguousDrivingPanelsAndKeepsOtherPanelTypes() throws Exception {
        PanelDefinition panel=panel();
        ConnectionSettings saved=new ConnectionSettings("https://ha.example.com","a".repeat(64),"panel.driving",
                List.of(new DeviceDefinition("panel.driving","Driving",panel)),"","b".repeat(32));
        assertEquals(panel,DrivingPanels.unique(saved));
        PanelDefinition other=PanelDefinition.fromJson(panel.toJson().put("id","other"));
        ConnectionSettings ambiguous=new ConnectionSettings(saved.baseUrl(),saved.token(),saved.entityId(),
                List.of(saved.devices().get(0),new DeviceDefinition("panel.other","Other",other)),"",saved.watchId());
        assertEquals(panel,DrivingPanels.unique(ambiguous)); assertNull(DrivingPanels.unique(null));
    }
}
