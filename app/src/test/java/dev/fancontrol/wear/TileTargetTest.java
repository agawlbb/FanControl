package dev.fancontrol.wear;

import java.util.List;
import org.junit.Test;
import static org.junit.Assert.*;

public class TileTargetTest {
    private ConnectionSettings settings(String watch, String entity) {
        return new ConnectionSettings("http://homeassistant.local:8123", "12".repeat(32), entity, List.of(new DeviceDefinition(entity,"Device")),"",watch);
    }
    @Test public void currentDeviceAllowsCommand() {
        ConnectionSettings current=settings("ab".repeat(16),"fan.example");
        assertEquals("speed4",TileTarget.action(current,"speed4",TileTarget.key(current)));
    }
    @Test public void changedDeviceOrRepairedWatchOnlyRefreshes() {
        ConnectionSettings old=settings("ab".repeat(16),"fan.example");
        assertEquals("refresh",TileTarget.action(settings("ab".repeat(16),"light.example"),"toggle",TileTarget.key(old)));
        assertEquals("refresh",TileTarget.action(settings("cd".repeat(16),"fan.example"),"toggle",TileTarget.key(old)));
        assertEquals("refresh",TileTarget.action(old,"toggle",""));
    }
    @Test public void targetDoesNotExposeDeviceOrWatchId() {
        String key=TileTarget.key(settings("ab".repeat(16),"fan.example"));
        assertTrue(key.matches("[a-f0-9]{16}")); assertFalse(key.contains("fan"));
    }
}
