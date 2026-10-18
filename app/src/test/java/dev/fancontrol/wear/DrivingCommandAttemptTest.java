package dev.fancontrol.wear;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import org.json.JSONObject;
import org.junit.Test;
import static org.junit.Assert.*;

public class DrivingCommandAttemptTest {
    @Test public void immediateOpenWaitsForOnlineAndNeverBecomesCloseAfterARead() throws Exception {
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(DrivingStateTest.panel(),"trunk_open","id",0);
        List<String> commands=new ArrayList<>(); boolean[] awake={false};
        VehicleCommandAttempt.Request request=body->{
            String command=body.optString("command"); commands.add(command);
            assertNotEquals("trunk_close",command);
            if(!command.isEmpty()) assertEquals(DrivingStateTest.panel(),PanelDefinition.fromJson(body.getJSONObject("panel_config")));
            return DrivingStateTest.state("closed",command.equals("trunk_open")?"open":"closed").put("trunk_open_available",awake[0]);
        };
        assertFalse(attempt.step(request)); awake[0]=true; assertTrue(attempt.step(request));
        assertEquals(List.of("","","trunk_open"),commands);
    }
    @Test public void ambiguousCoverDispatchIsNeverReplayedButLaterObservationCanConfirm() throws Exception {
        for(String action:List.of("garage_open","garage_close","trunk_open","trunk_close")) {
            VehicleCommandAttempt attempt=new VehicleCommandAttempt(DrivingStateTest.panel(),action,"id",0);
            String role=action.startsWith("garage")?"garage":"trunk", desired=action.endsWith("_open")?"open":"closed";
            String opposite=desired.equals("open")?"closed":"open"; int[] writes={0};
            VehicleCommandAttempt.Request lost=body->{
                if(body.optString("command").equals(action)) { writes[0]++; throw new IOException("lost response"); }
                return DrivingStateTest.state(opposite,opposite);
            };
            try { attempt.step(lost); fail(); } catch(IOException expected) { }
            assertFalse(attempt.step(lost)); assertEquals(1,writes[0]);
            assertTrue(attempt.step(body->{ assertFalse(body.has("command")); return DrivingStateTest.state(opposite,opposite).put(role+"_state",desired); }));
            assertEquals(1,writes[0]);
        }
    }
    @Test public void garageDoesNotWaitForVehicleReadiness() throws Exception {
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(DrivingStateTest.panel(),"garage_open","id",0);
        assertTrue(attempt.step(body->DrivingStateTest.state(body.optString("command").equals("garage_open")?"open":"closed","unknown")
                .put("vehicle_ready",false).put("trunk_open_available",false)));
    }
    @Test public void climateIsOnOnlyAndCannotConfirmOffOrUnavailable() throws Exception {
        PanelDefinition panel=DrivingStateTest.panel(); assertFalse(VehicleCommandAttempt.supported(panel,"climate_off"));
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(panel,"climate_on","id",0);
        assertFalse(attempt.step(body->{ assertNotEquals("climate_off",body.optString("command")); return DrivingStateTest.state("closed","closed"); }));
        assertTrue(attempt.step(body->{ assertFalse(body.has("command")); return DrivingStateTest.state("closed","closed").put("climate_on",true); }));
    }
    @Test public void movingOrUnavailableResponseDoesNotConfirmACover() throws Exception {
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(DrivingStateTest.panel(),"trunk_open","id",0);
        assertFalse(attempt.step(body->DrivingStateTest.state("closed","opening")));
        assertFalse(attempt.step(body->{ assertFalse(body.has("command")); return DrivingStateTest.state("closed","open").put("trunk_open_available",false); }));
    }
    @Test public void cancellationBetweenReadAndDispatchPreventsThePhysicalCommand() throws Exception {
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(DrivingStateTest.panel(),"trunk_open","id",0);
        boolean[] allowed={true}; List<String> commands=new ArrayList<>();
        try {
            attempt.step(body->{ commands.add(body.optString("command")); if(!body.has("command")) allowed[0]=false; return DrivingStateTest.state("closed","closed"); },()->allowed[0]);
            fail();
        } catch(InterruptedException expected) { }
        assertEquals(List.of(""),commands);
    }
}
