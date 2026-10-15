package dev.fancontrol.wear;
import org.junit.Test;
import org.json.JSONObject;
import static org.junit.Assert.*;

public class ExerciseDefinitionTest {
    private JSONObject panel() throws Exception { return new JSONObject().put("type","exercise").put("id","exercise").put("name","Exercise")
        .put("lock_entity","lock.example").put("climate_entity","climate.example").put("wake_entity","button.example").put("awake_entity","binary_sensor.example"); }
    @Test public void explicitRolesRoundTripWithoutWorkMorningEntities() throws Exception {
        PanelDefinition p=PanelDefinition.fromJson(panel()); assertTrue(p.exercise()); assertTrue(p.vehicle());
        assertEquals(p,PanelDefinition.fromJson(p.toJson())); assertFalse(p.toString().contains("example"));
    }
    @Test(expected=IllegalArgumentException.class) public void wrongLockDomainRejected() throws Exception { PanelDefinition.fromJson(panel().put("lock_entity","script.example")); }
    @Test(expected=IllegalArgumentException.class) public void missingWakeRejected() throws Exception { PanelDefinition.fromJson(panel().put("wake_entity","")); }
}
