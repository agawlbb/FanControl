package dev.fancontrol.wear;
import java.util.List;
import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Test;
import static org.junit.Assert.*;

public class PanelColorTest {
    @Test public void absentColorsPreserveLegacyCommandConfiguration() throws Exception {
        PanelDefinition panel=DrivingStateTest.panel();
        assertEquals(0,panel.barColor()); assertFalse(panel.toJson().has("color"));
        assertEquals(CommandFeedback.CONFIRMED,PanelColor.display(panel));
        assertEquals(panel,PanelDefinition.fromJson(panel.toJson()));
    }
    @Test public void rgbColorsRoundTripForEveryPanelTypeIncludingBlack() throws Exception {
        PanelDefinition driving=DrivingStateTest.panel();
        PanelDefinition morning=new PanelDefinition("morning","Morning","sensor.battery","climate.car","script.leave","Climate","Leave");
        PanelDefinition exercise=new PanelDefinition("exercise","Exercise","","climate.car","","Start","Stop","button.wake","binary_sensor.online","exercise","lock.car");
        for(PanelDefinition panel:List.of(driving,morning,exercise)) for(int color:new int[]{0xFF000000,0xFFFFFFFF,0xFF245AFF}) {
            PanelDefinition colored=PanelDefinition.fromJson(panel.toJson().put("color",new JSONArray().put((color>>16)&255).put((color>>8)&255).put(color&255)));
            assertEquals(color,colored.barColor()); assertEquals(color,PanelColor.display(colored));
            assertEquals(colored,PanelDefinition.fromJson(colored.toJson()));
        }
    }
    @Test public void malformedColorsCannotBecomeAValidPanel() throws Exception {
        for(JSONArray value:List.of(new JSONArray().put(1),new JSONArray().put(-1).put(2).put(3),
                new JSONArray().put(256).put(2).put(3),new JSONArray().put(true).put(2).put(3),new JSONArray().put(1.5).put(2).put(3))) {
            try { PanelDefinition.fromJson(DrivingStateTest.panel().toJson().put("color",value)); fail(); }
            catch(IllegalArgumentException expected) { }
        }
    }
    @Test public void haSelectedDefaultIsFirstButEveryConfiguredPageRemainsReachable() throws Exception {
        PanelDefinition first=DrivingStateTest.panel().withColor(0xFF245AFF);
        PanelDefinition second=PanelDefinition.fromJson(first.toJson().put("id","other").put("color",new JSONArray().put(255).put(255).put(255)));
        JSONObject config=new JSONObject().put("url","https://ha.example.com").put("remote_url","").put("token","a".repeat(64)).put("watch_id","b".repeat(32))
                .put("integration",true).put("entity","panel.other").put("devices",new JSONArray()
                        .put(new JSONObject().put("entity","fan.example").put("title","Fan"))
                        .put(new JSONObject().put("entity","panel.driving").put("title","Driving").put("panel",first.toJson()))
                        .put(new JSONObject().put("entity","panel.other").put("title","Other").put("panel",second.toJson())));
        ConnectionSettings saved=ConnectionSettings.fromJson(config);
        assertEquals(3,saved.devices().size()); assertEquals("panel.other",saved.devices().get(0).entityId());
        assertEquals("fan.example",saved.devices().get(1).entityId()); assertEquals("panel.driving",saved.devices().get(2).entityId());
        assertEquals(second,DrivingPanels.unique(saved));
    }
}
