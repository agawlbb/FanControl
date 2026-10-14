package dev.fancontrol.wear;

import org.junit.Test;
import org.json.*;
import static org.junit.Assert.*;

public class WorkMorningTest {
    private JSONObject panel() throws Exception {
        return new JSONObject().put("type", "work_morning").put("id", "work_morning").put("name", "Work Morning")
                .put("battery_entity", "sensor.example_battery").put("climate_entity", "climate.example_car")
                .put("script_entity", "script.example_leave").put("climate_label", "Climate").put("script_label", "Leave for work");
    }
    @Test public void managedPanelReordersAndRoundTripsEncryptedSettings() throws Exception {
        JSONObject json = new JSONObject().put("url", "http://homeassistant.local:8123").put("remote_url", "https://ha.example.com")
                .put("token", "12".repeat(32)).put("watch_id", "ab".repeat(16)).put("integration", true).put("entity", "panel.work_morning")
                .put("devices", new JSONArray().put(new JSONObject().put("entity", "fan.example").put("title", "Fan"))
                        .put(new JSONObject().put("entity", "panel.work_morning").put("title", "Work Morning").put("panel", panel())));
        ConnectionSettings settings = ConnectionSettings.fromJson(json);
        assertEquals("script.example_leave", settings.devices().get(0).panel().scriptEntity());
        assertEquals(settings, ConnectionSettings.fromJson(settings.toJson()));
        assertFalse(settings.toString().contains("example"));
        assertFalse(settings.devices().get(0).panel().toString().contains("example"));
    }
    @Test public void editedPanelRolesInvalidateOldTileTaps() throws Exception {
        PanelDefinition first = PanelDefinition.fromJson(panel());
        PanelDefinition second = PanelDefinition.fromJson(panel().put("script_entity", "script.example_other"));
        ConnectionSettings old = new ConnectionSettings("http://homeassistant.local:8123", "12".repeat(32), "panel.work_morning",
                java.util.List.of(new DeviceDefinition("panel.work_morning", "Work Morning", first)), "", "ab".repeat(16));
        ConnectionSettings updated = new ConnectionSettings(old.baseUrl(), old.token(), old.entityId(),
                java.util.List.of(new DeviceDefinition("panel.work_morning", "Work Morning", second)), "", old.watchId());
        assertNotEquals(TileTarget.key(old), TileTarget.key(updated));
        assertEquals("refresh", TileTarget.action(updated, "leave", TileTarget.key(old)));
    }
    @Test public void unavailableRolesDisableOnlyTheirOwnButtons() throws Exception {
        DeviceController.Snapshot state = WorkMorningState.parse(new JSONObject().put("battery", JSONObject.NULL)
                .put("climate_on", false).put("climate_available", false).put("script_available", true)).snapshot();
        assertEquals("?", state.readings().get("battery")); assertEquals("?", state.readings().get("climate"));
        assertFalse(state.controls().get(0).enabled()); assertTrue(state.controls().get(1).enabled());
    }
    @Test public void vehicleMissingReadinessFailsClosedEvenWithCachedFields() throws Exception {
        JSONObject state = new JSONObject().put("battery", 82).put("climate_on", true)
                .put("climate_available", true).put("script_available", true);
        assertEquals("?", WorkMorningState.parse(state, true).snapshot().readings().get("battery"));
        assertFalse(WorkMorningState.parse(state, true).snapshot().controls().get(1).enabled());
        assertTrue(WorkMorningState.parse(state.put("vehicle_ready", true), true).ready());
    }
    @Test public void vehicleRolesRoundTripAndBindTileIdentity() throws Exception {
        PanelDefinition p = PanelDefinition.fromJson(panel().put("wake_entity", "button.example_wake").put("awake_entity", "binary_sensor.example_online"));
        assertTrue(p.vehicle()); assertEquals(p, PanelDefinition.fromJson(p.toJson()));
        assertFalse(PanelDefinition.fromJson(panel()).vehicle());
    }
    @Test(expected = IllegalArgumentException.class) public void incompleteVehicleConfigurationRejected() throws Exception {
        PanelDefinition.fromJson(panel().put("wake_entity", "button.example_wake"));
    }
    @Test public void percentageAndConfirmedClimateAreSeparate() throws Exception {
        DeviceController.Snapshot state = WorkMorningState.parse(new JSONObject().put("battery", 82)
                .put("climate_on", true).put("climate_available", true).put("script_available", false)).snapshot();
        assertEquals("82", state.readings().get("battery")); assertTrue(state.controls().get(0).selected());
        assertFalse(state.controls().get(1).enabled());
    }
    @Test(expected = IllegalArgumentException.class) public void rejectsUnsupportedRoleDomain() throws Exception {
        PanelDefinition.fromJson(panel().put("script_entity", "lock.example"));
    }
    @Test(expected = IllegalArgumentException.class) public void panelCannotMasqueradeAsAnotherTarget() throws Exception {
        new DeviceDefinition("panel.other", "Example", PanelDefinition.fromJson(panel()));
    }
}
