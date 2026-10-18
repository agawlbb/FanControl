package dev.fancontrol.wear;
import java.util.ArrayDeque;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executor;
import org.json.JSONObject;
import org.junit.Test;
import static org.junit.Assert.*;

public class VisiblePanelWakeTest {
    @Test public void onlyTheSettledVisibleCarPageWakesWhileRefreshAndOtherPagesDoNot() throws Exception {
        PanelDefinition first=DrivingStateTest.panel();
        PanelDefinition other=PanelDefinition.fromJson(first.toJson().put("id","other").put("wake_entity","button.other_wake").put("trunk_entity","cover.other_trunk"));
        List<DeviceDefinition> pages=List.of(new DeviceDefinition("fan.example","Fan"),new DeviceDefinition("panel.driving","Car A",first),new DeviceDefinition("panel.other","Car B",other));
        ArrayDeque<Runnable> jobs=new ArrayDeque<>(); Map<String,Integer> wakes=new HashMap<>();
        VisibleDeviceSession session=new VisibleDeviceSession(pages,device->new DeviceController() {
            public Snapshot enter() { if(device.panel()!=null&&device.panel().vehicle()) wakes.merge(device.panel().wakeEntity(),1,Integer::sum); return read(); }
            public Snapshot read() { return new Snapshot("Observed",List.of()); }
            public Snapshot command(String action) { return read(); }
            public void cancel() { }
        },jobs::add,update->{});
        session.resume(); while(!jobs.isEmpty()) jobs.remove().run(); assertTrue(wakes.isEmpty());
        session.suspend(); session.select(1); session.select(2); while(!jobs.isEmpty()) jobs.remove().run(); assertTrue(wakes.isEmpty());
        session.resume(); while(!jobs.isEmpty()) jobs.remove().run(); assertEquals(Map.of("button.other_wake",1),wakes);
        session.refresh(); while(!jobs.isEmpty()) jobs.remove().run(); assertEquals(Map.of("button.other_wake",1),wakes);
        session.suspend(); session.select(1); session.resume(); session.suspend();
        while(!jobs.isEmpty()) jobs.remove().run(); assertEquals(Map.of("button.other_wake",1),wakes);
        session.resume(); while(!jobs.isEmpty()) jobs.remove().run(); assertEquals(1,(int)wakes.get("button.wake"));
    }
    @Test public void pendingOrScreenOffCommandAttemptsNeverRequestWake() throws Exception {
        PanelDefinition driving=DrivingStateTest.panel();
        for(String action:List.of("garage_open","garage_close","trunk_open","trunk_close","climate_on")) {
            VehicleCommandAttempt operation=new VehicleCommandAttempt(driving,action,"id",0);
            VehicleCommandAttempt.Request request=body->{
                assertNotEquals("wake",body.optString("command"));
                return DrivingStateTest.state("unknown","unknown").put("garage_open_available",false).put("garage_close_available",false)
                        .put("trunk_open_available",false).put("trunk_close_available",false).put("vehicle_ready",false);
            };
            assertFalse(operation.step(request)); assertFalse(operation.step(request));
        }
    }
}
