package dev.fancontrol.wear;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import org.json.JSONObject;
import org.json.JSONArray;
import org.junit.Test;
import static org.junit.Assert.*;

public class VehicleCommandAttemptTest {
    @Test public void unavailableClimateCannotConfirmAnOffIntentEvenWhenItsBooleanMatches() throws Exception {
        PanelDefinition plain=new PanelDefinition("plain","Plain","sensor.battery","climate.car","script.leave","Climate","Leave");
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(plain,"climate_off","id",0);
        assertFalse(attempt.step(body -> new JSONObject().put("climate_available",!body.has("command")).put("climate_on",false)));
        assertFalse(attempt.step(body -> {
            assertFalse(body.has("command"));
            return new JSONObject().put("climate_available",false).put("climate_on",false);
        }));
        assertTrue(attempt.step(body -> {
            assertFalse(body.has("command"));
            return new JSONObject().put("climate_available",true).put("climate_on",false);
        }));
    }
    private PanelDefinition morning() {
        return new PanelDefinition("morning","Morning","sensor.battery","climate.car","script.leave","Climate","Leave","button.wake","binary_sensor.awake");
    }
    private PanelDefinition exercise() {
        return new PanelDefinition("exercise","Exercise","","climate.car","","Start","Stop","button.wake","binary_sensor.awake","exercise","lock.car");
    }
    private JSONObject state(boolean ready, boolean on) throws Exception {
        return new JSONObject().put("vehicle_ready",ready).put("climate_on",on).put("climate_available",ready).put("script_available",ready);
    }
    @Test public void tapWhileAsleepWakesOnceAndRetainsIntentUntilReady() throws Exception {
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(morning(),"climate","id",0);
        List<String> commands=new ArrayList<>(); boolean[] ready={false};
        VehicleCommandAttempt.Request request=body -> {
            String command=body.optString("command"); commands.add(command);
            return state(ready[0],command.equals("climate_on"));
        };
        assertFalse(attempt.step(request)); ready[0]=true; assertTrue(attempt.step(request));
        assertEquals(List.of("","","climate_on"),commands);
    }
    @Test public void scriptDispatchDoesNotRequestWake() throws Exception {
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(morning(),"leave","id",0);
        assertTrue(attempt.step(body -> {
            assertNotEquals("wake",body.optString("command"));
            return state(true,false);
        }));
    }
    @Test public void climateRetryKeepsAbsoluteDesiredStateAndDoesNotToggleBack() throws Exception {
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(morning(),"climate","id",0);
        int[] writes={0};
        VehicleCommandAttempt.Request lost=body -> {
            if(body.optString("command").equals("climate_on")) { writes[0]++; throw new IOException(); }
            return state(true,false);
        };
        try { attempt.step(lost); fail(); } catch(IOException expected) { }
        assertTrue(attempt.step(body -> { assertFalse(body.has("command")); return state(true,true); }));
        assertEquals(1,writes[0]);
    }
    @Test public void ambiguousScriptIsNeverRepeated() throws Exception {
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(morning(),"leave","id",0);
        int[] writes={0};
        VehicleCommandAttempt.Request request=body -> {
            if(body.optString("command").equals("leave")) { writes[0]++; throw new IOException(); }
            return state(true,false);
        };
        try { attempt.step(request); fail(); } catch(IOException expected) { }
        assertFalse(attempt.step(request)); assertFalse(attempt.step(request)); assertEquals(1,writes[0]);
    }
    @Test public void startIsAcceptedBeforeReadinessAndConfirmedByLockState() throws Exception {
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(exercise(),"start_exercise","id",0);
        boolean[] ready={false};
        VehicleCommandAttempt.Request request=body -> {
            JSONObject result=state(ready[0],false).put("start_available",ready[0]);
            if(body.optString("command").equals("start_exercise")) result.put("steps",new JSONArray().put(new JSONObject().put("status","requested")));
            return result;
        };
        assertFalse(attempt.step(request)); assertFalse(attempt.spotifyReady()); ready[0]=true;
        assertFalse(attempt.step(request)); assertTrue(attempt.spotifyReady());
        assertTrue(attempt.step(body -> state(true,false).put("locked",true)));
    }
    @Test public void stopUsesSameOperationIdentityAcrossRetries() throws Exception {
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(exercise(),"stop_exercise","stable-id",123);
        int[] calls={0};
        VehicleCommandAttempt.Request request=body -> {
            if(body.optString("command").equals("wake")) return new JSONObject();
            assertEquals("stable-id",body.getString("operation_id")); assertEquals(123,body.getLong("issued_at_ms"));
            assertEquals(exercise(),PanelDefinition.fromJson(body.getJSONObject("panel_config")));
            return new JSONObject().put("operation_status",++calls[0]==2?"complete":"pending");
        };
        assertFalse(attempt.step(request)); assertTrue(attempt.step(request));
    }
    @Test public void onlyExplicitVehicleActionsAreAcceptedAndWindowIsOneMinute() {
        assertEquals(60_000,VehicleCommandAttempt.WINDOW_MS);
        assertFalse(VehicleCommandAttempt.supported(morning(),"start_exercise"));
        assertFalse(VehicleCommandAttempt.supported(exercise(),"leave"));
        assertTrue(VehicleCommandAttempt.supported(new PanelDefinition("plain","Plain","sensor.battery","climate.car","script.leave","Climate","Leave"),"climate"));
    }
    @Test public void plainPanelRetriesRejectedClimateWithoutWakeAndConfirmsObservedState() throws Exception {
        PanelDefinition panel = new PanelDefinition("plain","Plain","sensor.battery","climate.car","script.leave","Climate","Leave");
        VehicleCommandAttempt attempt = new VehicleCommandAttempt(panel,"climate_on","id",0);
        int[] writes = {0};
        VehicleCommandAttempt.Request request = body -> {
            String command = body.optString("command");
            assertNotEquals("wake", command);
            assertNotEquals("climate_off", command);
            if (command.equals("climate_on") && ++writes[0] == 1) throw new IntegrationClient.Rejected(403);
            return new JSONObject().put("climate_available",true).put("climate_on", command.equals("climate_on"));
        };
        try { attempt.step(request); fail(); } catch (IntegrationClient.Rejected expected) { }
        assertTrue(attempt.step(request));
        assertEquals(2,writes[0]);
    }
    @Test public void plainPanelDoesNotConfirmAnUnchangedClimateResponse() throws Exception {
        PanelDefinition panel = new PanelDefinition("plain","Plain","sensor.battery","climate.car","script.leave","Climate","Leave");
        VehicleCommandAttempt attempt = new VehicleCommandAttempt(panel,"climate_on","id",0);
        assertFalse(attempt.step(body -> new JSONObject().put("climate_available",true).put("climate_on",false)));
        assertTrue(attempt.step(body -> {
            assertFalse(body.has("command"));
            return new JSONObject().put("climate_available",true).put("climate_on",true);
        }));
    }
    @Test public void displayedClimateOnRemainsOnEvenIfVehicleWakesAlreadyOn() throws Exception {
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(morning(),"climate_on","id",0);
        assertTrue(attempt.step(body -> {
            assertNotEquals("climate_off",body.optString("command"));
            return state(true,true);
        }));
    }
    @Test public void deadlineReachedDuringReadPreventsDispatch() throws Exception {
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(morning(),"climate","id",0);
        long[] now={59_999}; List<String> commands=new ArrayList<>();
        try {
            attempt.step(body -> {
                commands.add(body.optString("command"));
                if(!body.has("command")) now[0]=60_000;
                return state(true,false);
            }, () -> now[0]<VehicleCommandAttempt.WINDOW_MS);
            fail();
        } catch(InterruptedException expected) { }
        assertEquals(List.of(""),commands);
    }
    @Test public void cancelledRequestCannotSendWakeOrCommand() throws Exception {
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(exercise(),"stop_exercise","id",0);
        try { attempt.step(body -> { fail("Unexpected network request"); return null; }, () -> false); fail(); }
        catch(InterruptedException expected) { }
    }
}
