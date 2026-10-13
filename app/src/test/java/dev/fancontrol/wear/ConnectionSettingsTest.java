package dev.fancontrol.wear;

import org.junit.Test;
import static org.junit.Assert.*;

public class ConnectionSettingsTest {
    @Test public void normalizesAndRedactsSettings() {
        ConnectionSettings settings = ConnectionSettings.validate(" https://ha.example.com/ ", "test-token", " fan.example ");
        assertEquals("https://ha.example.com", settings.baseUrl());
        assertEquals("fan.example", settings.entityId());
        assertFalse(settings.toString().contains("test-token"));
        assertFalse(settings.toString().contains("ha.example"));
    }
    @Test public void rejectsUnsafeConnectionInputs() {
        String[] urls = {"http://ha.example.com", "https://user:password@ha.example.com", "https://ha.example.com?token=test", "https://ha.example.com#secret", "invalid"};
        for (String url : urls) {
            try { ConnectionSettings.validate(url, "test-token", "fan.example"); fail(url); }
            catch (IllegalArgumentException expected) { }
        }
    }
    @Test(expected = IllegalArgumentException.class) public void rejectsNonFanEntity() {
        ConnectionSettings.validate("https://ha.example.com", "test-token", "light.example");
    }
    @Test(expected = IllegalArgumentException.class) public void rejectsHeaderInjection() {
        ConnectionSettings.validate("https://ha.example.com", "test\nheader", "fan.example");
    }
}
