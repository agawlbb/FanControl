package dev.fancontrol.wear;

import java.util.concurrent.TimeUnit;
import okhttp3.OkHttpClient;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import okhttp3.mockwebserver.RecordedRequest;
import org.json.JSONObject;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import static org.junit.Assert.*;

public class HomeAssistantClientTest {
    private MockWebServer server;
    private HomeAssistantClient client;
    private static final String ON = "{\"state\":\"on\",\"attributes\":{\"percentage\":50,\"supported_features\":1}}";
    private static final String OFF = "{\"state\":\"off\",\"attributes\":{\"percentage\":50,\"supported_features\":1}}";
    @Before public void setup() throws Exception {
        server = new MockWebServer(); server.start();
        client = new HomeAssistantClient(new ConnectionSettings(server.url("/").toString().replaceAll("/+$", ""), "test-token", "fan.example"),
                new OkHttpClient.Builder().callTimeout(500, TimeUnit.MILLISECONDS).followRedirects(false).retryOnConnectionFailure(false).build());
    }
    @After public void teardown() throws Exception { server.shutdown(); }
    @Test public void readsAuthenticatedState() throws Exception {
        server.enqueue(new MockResponse().setBody(ON));
        assertEquals(3, client.read().speed());
        RecordedRequest request = server.takeRequest();
        assertEquals("/api/states/fan.example", request.getPath());
        assertEquals("Bearer test-token", request.getHeader("Authorization"));
    }
    @Test public void displayedOnIntentCannotBeInvertedByLaterServerState() throws Exception {
        server.enqueue(new MockResponse().setBody(ON));
        server.enqueue(new MockResponse().setBody("[]"));
        server.enqueue(new MockResponse().setBody(ON));
        assertTrue(client.command("turn_on").on());
        server.takeRequest();
        assertEquals("/api/services/fan/turn_on",server.takeRequest().getPath());
    }
    @Test public void toggleRechecksStateAndReportsConfirmedResult() throws Exception {
        server.enqueue(new MockResponse().setBody(ON));
        server.enqueue(new MockResponse().setBody("[]"));
        server.enqueue(new MockResponse().setBody(OFF));
        assertFalse(client.command("toggle").on());
        assertEquals("GET", server.takeRequest().getMethod());
        RecordedRequest command = server.takeRequest();
        assertEquals("/api/services/fan/turn_off", command.getPath());
        assertEquals("fan.example", new JSONObject(command.getBody().readUtf8()).getString("entity_id"));
        assertEquals("GET", server.takeRequest().getMethod());
    }
    @Test public void speedUsesCorrectServiceAndPercentage() throws Exception {
        server.enqueue(new MockResponse().setBody(OFF));
        server.enqueue(new MockResponse().setBody("[]"));
        server.enqueue(new MockResponse().setBody(ON));
        assertTrue(client.command("speed3").on());
        server.takeRequest();
        RecordedRequest command = server.takeRequest();
        assertEquals("/api/services/fan/set_percentage", command.getPath());
        assertEquals(50, new JSONObject(command.getBody().readUtf8()).getInt("percentage"));
    }
    @Test public void unauthorizedResponseDoesNotExposeServerBody() throws Exception {
        server.enqueue(new MockResponse().setResponseCode(401).setBody("sensitive-server-detail"));
        try { client.read(); fail(); } catch (Exception error) { assertEquals("Check access token", error.getMessage()); }
    }
    @Test public void redirectIsNotFollowed() throws Exception {
        server.enqueue(new MockResponse().setResponseCode(302).setHeader("Location", server.url("/other")));
        try { client.read(); fail(); } catch (Exception expected) { assertEquals(1, server.getRequestCount()); }
    }
    @Test public void cancellationPreventsNetworkRequest() throws Exception {
        client.cancel();
        try { client.read(); fail(); } catch (Exception expected) { assertEquals(0, server.getRequestCount()); }
    }
    @Test public void unsupportedSpeedDoesNotPost() throws Exception {
        server.enqueue(new MockResponse().setBody("{\"state\":\"on\",\"attributes\":{\"supported_features\":0}}"));
        try { client.command("speed6"); fail(); } catch (Exception error) {
            assertEquals("Speed control unsupported", error.getMessage()); assertEquals(1, server.getRequestCount());
        }
    }
    @Test public void failedCommandIsNeverDisplayedAsSuccess() throws Exception {
        server.enqueue(new MockResponse().setBody(ON));
        server.enqueue(new MockResponse().setResponseCode(500));
        try { client.command("toggle"); fail(); } catch (Exception error) {
            assertEquals("Home Assistant error", error.getMessage()); assertEquals(2, server.getRequestCount());
        }
    }
    @Test public void delayedFanStateIsReadUntilConfirmedWithoutResendingCommand() throws Exception {
        server.enqueue(new MockResponse().setBody(ON));
        server.enqueue(new MockResponse().setBody("[]"));
        server.enqueue(new MockResponse().setBody(ON));
        server.enqueue(new MockResponse().setBody(OFF));
        assertFalse(client.command("toggle").on());
        assertEquals(4, server.getRequestCount());
        server.takeRequest();
        assertEquals("POST", server.takeRequest().getMethod());
        assertEquals("GET", server.takeRequest().getMethod());
        assertEquals("GET", server.takeRequest().getMethod());
    }
    @Test public void fasterUsesFreshServerSpeedAndOriginalPercentageMapping() throws Exception {
        server.enqueue(new MockResponse().setBody(ON));
        server.enqueue(new MockResponse().setBody("[]"));
        server.enqueue(new MockResponse().setBody(ON.replace("50", "66")));
        assertEquals(4, client.command("faster").speed());
        server.takeRequest();
        assertEquals(66, new JSONObject(server.takeRequest().getBody().readUtf8()).getInt("percentage"));
    }
    @Test public void fasterAtMaximumDoesNotSendAnotherCommand() throws Exception {
        server.enqueue(new MockResponse().setBody(ON.replace("50", "100")));
        assertEquals(6, client.command("faster").speed());
        assertEquals(1, server.getRequestCount());
    }
    @Test public void unconfirmedStateIsNotReportedAsSuccess() throws Exception {
        server.enqueue(new MockResponse().setBody(ON));
        server.enqueue(new MockResponse().setBody("[]"));
        for (int i = 0; i < 6; i++) server.enqueue(new MockResponse().setBody(ON));
        try { client.command("toggle"); fail(); }
        catch (java.io.IOException expected) { assertEquals("Waiting for fan confirmation", expected.getMessage()); }
        assertEquals(8, server.getRequestCount());
    }
}
