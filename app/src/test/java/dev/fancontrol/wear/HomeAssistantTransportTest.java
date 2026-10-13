package dev.fancontrol.wear;

import org.json.JSONObject;
import org.junit.Test;
import okhttp3.mockwebserver.MockWebServer;
import okhttp3.mockwebserver.MockResponse;
import static org.junit.Assert.*;

public class HomeAssistantTransportTest {
    @Test public void sharedTransportCanAddressANonFanWithoutChangingFanSettings() throws Exception {
        try (MockWebServer server = new MockWebServer()) {
            server.start(); server.enqueue(new MockResponse().setBody("{\"state\":\"off\"}")); server.enqueue(new MockResponse().setBody("[]"));
            ConnectionSettings settings = new ConnectionSettings(server.url("/").toString().replaceAll("/+$", ""), "test-token", "fan.example");
            HomeAssistantTransport transport = new HomeAssistantTransport(settings);
            transport.readEntity("light.example");
            transport.callService("light", "turn_on", new JSONObject().put("entity_id", "light.example").put("brightness", 100));
            assertEquals("/api/states/light.example", server.takeRequest().getPath());
            var request = server.takeRequest(); assertEquals("/api/services/light/turn_on", request.getPath());
            assertEquals("Bearer test-token", request.getHeader("Authorization"));
            assertEquals("fan.example", settings.entityId());
        }
    }
    @Test public void invalidAndMismatchedTargetsAreRejectedBeforeConnecting() throws Exception {
        try (MockWebServer server = new MockWebServer()) {
            server.start();
            HomeAssistantTransport transport = new HomeAssistantTransport(new ConnectionSettings(server.url("/").toString(), "test-token", "fan.example"));
            try { transport.readEntity("light.example?other=1"); fail(); } catch (IllegalArgumentException expected) { }
            try { transport.callService("fan", "turn_on", new JSONObject().put("entity_id", "light.example")); fail(); } catch (IllegalArgumentException expected) { }
            try { transport.callService("light", "../turn_on", new JSONObject().put("entity_id", "light.example")); fail(); } catch (IllegalArgumentException expected) { }
            assertEquals(0, server.getRequestCount());
        }
    }
}
