package dev.fancontrol.wear;

import java.io.IOException;
import java.util.List;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import org.junit.Test;
import static org.junit.Assert.*;

public class SimpleCommandFeedbackTest {
    private DeviceControllers.Simple controller(MockWebServer server, String domain) {
        ConnectionSettings settings=new ConnectionSettings(server.url("/").toString().replaceAll("/+$",""),"test-token","fan.example");
        return new DeviceControllers.Simple(settings,new DeviceDefinition(domain+".example","Example"));
    }
    private MockResponse state(String value) { return new MockResponse().setBody("{\"state\":\""+value+"\"}"); }
    @Test public void lightSwitchAndBooleanWaitForObservedPowerAfterServiceAcknowledgment() throws Exception {
        for(String domain : List.of("light","switch","input_boolean")) try(MockWebServer server=new MockWebServer()) {
            server.start(); server.enqueue(state("off")); server.enqueue(new MockResponse().setBody("[]"));
            server.enqueue(state("off")); server.enqueue(state("on"));
            DeviceController.Snapshot result=controller(server,domain).command("turn_on");
            assertEquals("On",result.status()); assertTrue(result.controls().get(0).selected());
            assertEquals(4,server.getRequestCount());
        }
    }
    @Test public void unchangedPowerCannotBecomeAConfirmedRequestedState() throws Exception {
        try(MockWebServer server=new MockWebServer()) {
            server.start(); server.enqueue(state("off")); server.enqueue(new MockResponse().setBody("[]"));
            for(int i=0;i<6;i++) server.enqueue(state("off"));
            try { controller(server,"light").command("turn_on"); fail("Acknowledgment alone cannot confirm power"); }
            catch(IOException expected) { assertEquals("Waiting for device confirmation",expected.getMessage()); }
            assertEquals(8,server.getRequestCount()); // One command, then bounded read-only confirmation.
        }
    }
    @Test public void scriptsAndScenesColorOnlyAcknowledgedDispatchWithoutClaimingCompletion() throws Exception {
        for(String domain : List.of("script","scene")) try(MockWebServer server=new MockWebServer()) {
            server.start(); server.enqueue(state("off")); server.enqueue(new MockResponse().setBody("[]"));
            DeviceController.Snapshot result=controller(server,domain).command("activate");
            assertEquals("REQUESTED",result.controls().get(0).label());
            assertEquals("Request accepted",result.status());
            assertTrue(result.controls().get(0).selected());
            assertEquals(2,server.getRequestCount());
        }
    }
    @Test public void rejectedScriptCannotProduceAConfirmedSnapshotOrBeRetried() throws Exception {
        try(MockWebServer server=new MockWebServer()) {
            server.start(); server.enqueue(state("off")); server.enqueue(new MockResponse().setResponseCode(403));
            try { controller(server,"script").command("activate"); fail("Rejected dispatch cannot be confirmed"); }
            catch(IOException expected) { assertEquals("Check access token",expected.getMessage()); }
            assertEquals(2,server.getRequestCount());
        }
    }
}
