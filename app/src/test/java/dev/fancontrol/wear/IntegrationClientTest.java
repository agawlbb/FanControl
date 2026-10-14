package dev.fancontrol.wear;

import org.junit.Test;
import org.json.*;
import okhttp3.*;
import okhttp3.mockwebserver.*;
import okhttp3.mockwebserver.Dispatcher;
import javax.crypto.Cipher;
import javax.crypto.spec.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.TimeUnit;
import static org.junit.Assert.*;

public class IntegrationClientTest {
    private static final String KEY = "12".repeat(32), ID = "ab".repeat(16);
    private ConnectionSettings settings(String url, String remote) {
        return new ConnectionSettings(url, KEY, "fan.example", List.of(new DeviceDefinition("fan.example", "Fan")), remote, ID);
    }
    private MockResponse encrypted(RecordedRequest request, JSONObject result) throws Exception {
        assertNull(request.getHeader("Authorization"));
        JSONObject packet = new JSONObject(request.getBody().readUtf8());
        String aad = "fan-control-v1:" + packet.getString("watch_id") + ":" + packet.getLong("timestamp") + ":" + packet.getString("nonce");
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(IntegrationClient.unhex(KEY), "AES"), new GCMParameterSpec(128, Base64.getDecoder().decode(packet.getString("iv"))));
        cipher.updateAAD(aad.getBytes(StandardCharsets.US_ASCII));
        JSONObject body = new JSONObject(new String(cipher.doFinal(Base64.getDecoder().decode(packet.getString("ciphertext"))), StandardCharsets.UTF_8));
        assertFalse(packet.toString().contains("fan.example")); assertTrue(body.has("action"));
        byte[] iv = new byte[12]; new java.security.SecureRandom().nextBytes(iv);
        cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(IntegrationClient.unhex(KEY), "AES"), new GCMParameterSpec(128, iv));
        cipher.updateAAD((aad + ":response").getBytes(StandardCharsets.US_ASCII));
        return new MockResponse().setBody(new JSONObject().put("iv", Base64.getEncoder().encodeToString(iv))
                .put("ciphertext", Base64.getEncoder().encodeToString(cipher.doFinal(result.toString().getBytes(StandardCharsets.UTF_8)))).toString());
    }
    @Test public void encryptsRequestsAndAuthenticatesResponses() throws Exception {
        try(MockWebServer server = new MockWebServer()) {
            server.setDispatcher(new Dispatcher() { public MockResponse dispatch(RecordedRequest request) {
                try { assertEquals("/api/fan_control/watch/request",request.getPath()); return encrypted(request, new JSONObject().put("state","on")); }
                catch(Exception error) { throw new AssertionError(error); }
            }});
            server.start(); IntegrationClient client = new IntegrationClient(settings(server.url("/").toString(), ""));
            assertEquals("on",client.request(new JSONObject().put("action","state").put("entity","fan.example")).getString("state"));
        }
    }
    @Test public void rejectedAccessDoesNotFallBack() throws Exception {
        try(MockWebServer local = new MockWebServer(); MockWebServer remote = new MockWebServer()) {
            local.start(); remote.start(); local.enqueue(new MockResponse().setResponseCode(403));
            // A test interceptor sends the HTTPS remote URL to this local fake only if called.
            OkHttpClient http = new OkHttpClient.Builder().addInterceptor(chain -> chain.proceed(chain.request().url().host().equals("remote.example.com") ? chain.request().newBuilder().url(remote.url("/api/fan_control/watch/request")).build() : chain.request())).build();
            IntegrationClient client = new IntegrationClient(settings(local.url("/").toString(), "https://remote.example.com"), http);
            try { client.request(new JSONObject().put("action","config")); fail(); } catch(java.io.IOException expected) { }
            assertEquals(0,remote.getRequestCount());
        }
    }
    @Test public void readFallbackSelectsRemoteForFollowingCommand() throws Exception {
        try(MockWebServer local = new MockWebServer(); MockWebServer remote = new MockWebServer()) {
            local.start(); remote.start(); local.enqueue(new MockResponse().setSocketPolicy(SocketPolicy.DISCONNECT_AT_START));
            remote.setDispatcher(new Dispatcher() { public MockResponse dispatch(RecordedRequest request) { try { return encrypted(request,new JSONObject().put("state","on")); } catch(Exception error) { throw new AssertionError(error); } }});
            OkHttpClient http = new OkHttpClient.Builder().retryOnConnectionFailure(false).addInterceptor(chain -> chain.proceed(chain.request().url().host().equals("remote.example.com") ? chain.request().newBuilder().url(remote.url("/api/fan_control/watch/request")).build() : chain.request())).build();
            IntegrationClient client = new IntegrationClient(settings(local.url("/").toString(), "https://remote.example.com"),http);
            client.request(new JSONObject().put("action","state")); client.request(new JSONObject().put("action","command"));
            assertEquals(2,remote.getRequestCount()); assertEquals(1,local.getRequestCount());
        }
    }
    @Test public void ambiguousCommandIsNeverReplayed() throws Exception {
        try(MockWebServer local = new MockWebServer(); MockWebServer remote = new MockWebServer()) {
            local.start(); remote.start(); local.enqueue(new MockResponse().setSocketPolicy(SocketPolicy.DISCONNECT_AT_START));
            IntegrationClient client = new IntegrationClient(settings(local.url("/").toString(), "https://remote.example.com"), new OkHttpClient.Builder().retryOnConnectionFailure(false).build());
            try { client.request(new JSONObject().put("action","command")); fail(); } catch(java.io.IOException expected) { }
            assertEquals(0,remote.getRequestCount());
        }
    }
    @Test public void tamperedResponseIsRejected() throws Exception {
        try(MockWebServer server = new MockWebServer()) {
            server.start(); server.enqueue(new MockResponse().setBody("{\"iv\":\"AAAAAAAAAAAAAAAA\",\"ciphertext\":\"AAAAAAAAAAAAAAAAAAAAAA==\"}"));
            try { new IntegrationClient(settings(server.url("/").toString(), "")).request(new JSONObject().put("action","config")); fail(); }
            catch(javax.crypto.AEADBadTagException expected) { }
        }
    }
    @Test public void ambiguousPanelCommandIsNeverReplayedThroughRemote() throws Exception {
        try (MockWebServer local = new MockWebServer(); MockWebServer remote = new MockWebServer()) {
            local.start(); remote.start();
            local.enqueue(new MockResponse().setSocketPolicy(SocketPolicy.DISCONNECT_AFTER_REQUEST));
            OkHttpClient http = new OkHttpClient.Builder().retryOnConnectionFailure(false)
                    .addInterceptor(chain -> chain.proceed(chain.request().url().host().equals("remote.example.com")
                            ? chain.request().newBuilder().url(remote.url("/api/fan_control/watch/request")).build() : chain.request())).build();
            IntegrationClient client = new IntegrationClient(settings(local.url("/").toString(), "https://remote.example.com"), http);
            try { client.request(new JSONObject().put("action", "panel_command").put("panel_id", "work_morning").put("command", "leave")); fail(); }
            catch (java.io.IOException expected) { }
            assertEquals(1, local.getRequestCount()); assertEquals(0, remote.getRequestCount());
        }
    }
    @Test public void ambiguousWakeIsNeverReplayedThroughRemote() throws Exception {
        try (MockWebServer local = new MockWebServer(); MockWebServer remote = new MockWebServer()) {
            local.start(); remote.start();
            local.enqueue(new MockResponse().setSocketPolicy(SocketPolicy.DISCONNECT_AFTER_REQUEST));
            OkHttpClient http = new OkHttpClient.Builder().retryOnConnectionFailure(false)
                    .addInterceptor(chain -> chain.proceed(chain.request().url().host().equals("remote.example.com")
                            ? chain.request().newBuilder().url(remote.url("/api/fan_control/watch/request")).build() : chain.request())).build();
            IntegrationClient client = new IntegrationClient(settings(local.url("/").toString(), "https://remote.example.com"), http);
            try { client.request(new JSONObject().put("action", "panel_command").put("panel_id", "work_morning").put("command", "wake")); fail(); }
            catch (java.io.IOException expected) { }
            assertEquals(1, local.getRequestCount()); assertEquals(0, remote.getRequestCount());
        }
    }
    @Test public void cancellationPreventsNetwork() throws Exception {
        try(MockWebServer server = new MockWebServer()) {
            server.start(); IntegrationClient client = new IntegrationClient(settings(server.url("/").toString(), "")); client.cancel();
            try { client.request(new JSONObject().put("action","config")); fail(); } catch(java.io.IOException expected) { }
            assertEquals(0,server.getRequestCount());
        }
    }
    @Test public void managedConfigurationAllowsNonFanAndRoundTrips() throws Exception {
        JSONObject config = new JSONObject().put("integration",true).put("watch_id",ID).put("url","http://homeassistant.local:8123").put("remote_url","https://remote.example.com")
                .put("token",KEY).put("entity","light.example").put("devices",new JSONArray().put(new JSONObject().put("entity","fan.example").put("title","Fan")).put(new JSONObject().put("entity","light.example").put("title","Light")));
        ConnectionSettings settings = ConnectionSettings.fromJson(config); assertTrue(settings.integration());
        assertEquals("light.example",settings.devices().get(0).entityId()); assertEquals(settings,ConnectionSettings.fromJson(settings.toJson()));
        ConnectionSettings fan = settings.forFan(settings.devices().get(1)); assertTrue(fan.integration()); assertEquals(settings.remoteUrl(),fan.remoteUrl());
    }
    @Test public void remoteAddressMustUseHttps() {
        try { settings("http://192.168.1.2:8123", "http://remote.example.com"); fail(); } catch(IllegalArgumentException expected) { }
        try { settings("http://example.com", "https://remote.example.com"); fail(); } catch(IllegalArgumentException expected) { }
    }
    @Test public void malformedManagedPayloadCannotDowngradeToBearerHttp() throws Exception {
        JSONObject config = new JSONObject().put("integration",true).put("watch_id", "").put("token",KEY).put("entity","fan.example").put("url","http://192.168.1.2:8123");
        try { ConnectionSettings.fromJson(config); fail(); } catch(IllegalArgumentException expected) { }
    }
}
