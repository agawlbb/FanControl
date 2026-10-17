package dev.fancontrol.wear;

import org.junit.Test;
import org.json.JSONObject;
import java.util.List;
import static org.junit.Assert.*;

public class DeviceConfigurationTest {
    private ConnectionSettings connection() {
        return new ConnectionSettings("https://ha.example.com", "test-token", "fan.example", List.of(
                new DeviceDefinition("fan.example", "Fan Control"), new DeviceDefinition("light.example", "Light")));
    }
    @Test public void migratesExistingSingleFanPayload() throws Exception {
        ConnectionSettings settings = ConnectionSettings.fromJson(new JSONObject("{\"url\":\"https://ha.example.com\",\"token\":\"test-token\",\"entity\":\"fan.example\"}"));
        assertEquals(1, settings.devices().size()); assertEquals("fan.example", settings.devices().get(0).entityId());
    }
    @Test public void deviceOrderAndTitlesRoundTrip() throws Exception {
        ConnectionSettings settings = connection(); assertEquals(settings, ConnectionSettings.fromJson(settings.toJson()));
        assertEquals("light", settings.devices().get(1).domain());
    }
    @Test public void editingPrimaryFanKeepsAdditionalPages() {
        ConnectionSettings next = connection().replacePrimary(ConnectionSettings.validate("https://ha.example.com", "new-token", "fan.other"));
        assertEquals("fan.other", next.devices().get(0).entityId()); assertEquals("light.example", next.devices().get(1).entityId());
        assertEquals("new-token", next.token());
    }
    @Test public void changingServerDoesNotCarryOldDevicePages() {
        ConnectionSettings next = connection().replacePrimary(ConnectionSettings.validate("https://other.example.com", "new-token", "fan.other"));
        assertEquals(1, next.devices().size());
    }
    @Test(expected = IllegalArgumentException.class) public void rejectsDuplicateEntities() {
        new ConnectionSettings("https://ha.example.com", "test-token", "fan.example", List.of(
                new DeviceDefinition("fan.example", "Fan"), new DeviceDefinition("fan.example", "Duplicate")));
    }
    @Test(expected = IllegalArgumentException.class) public void rejectsReplacingTileFanWithAnotherDomain() throws Exception {
        ConnectionSettings.fromJson(new JSONObject("{\"url\":\"https://ha.example.com\",\"token\":\"test-token\",\"entity\":\"light.example\"}"));
    }
    @Test public void unsupportedTypesHaveNoCommandsOrNetworkAdapter() throws Exception {
        DeviceController controller = DeviceControllers.create(connection(), connection().devices().get(1));
        assertTrue(controller.read().controls().isEmpty()); assertEquals("Controls not available yet", controller.read().status());
        try { controller.command("toggle"); fail(); } catch (IllegalArgumentException expected) { }
    }
    @Test public void fanAdapterPreservesPowerAndAllSixSpeeds() {
        DeviceController.Snapshot snapshot = DeviceControllers.Fan.snapshot(new FanState(true, 4, true, true));
        assertEquals(7, snapshot.controls().size()); assertEquals("toggle", snapshot.controls().get(0).action());
        assertEquals("ON", snapshot.controls().get(0).label());
        assertTrue(snapshot.controls().get(0).selected());
        for (int speed = 1; speed <= 6; speed++) {
            assertEquals("speed" + speed, snapshot.controls().get(speed).action());
            assertEquals(speed == 4, snapshot.controls().get(speed).selected());
        }
    }
}
