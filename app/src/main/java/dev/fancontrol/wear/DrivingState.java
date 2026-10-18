package dev.fancontrol.wear;

import java.util.List;
import java.util.Map;
import org.json.JSONObject;

/** Initial CLOSED is a presentation assumption only, never observed/cached vehicle state. */
final class DrivingState {
    record Control(String action, String label, boolean enabled, boolean unconfirmed, boolean selected) { }
    static DeviceController.Snapshot snapshot(JSONObject state) {
        String garage=cover(state.optString("garage_state")), trunk=cover(state.optString("trunk_state"));
        boolean climateAvailable=Boolean.TRUE.equals(state.opt("climate_available"));
        String climate=climateAvailable ? Boolean.TRUE.equals(state.opt("climate_on")) ? "ON" : "OFF" : "?";
        return new DeviceController.Snapshot("Driving",List.of(),Map.of("garage",garage,"trunk",trunk,"climate",climate,
                "garage_open_available",Boolean.toString(state.optBoolean("garage_open_available")),
                "garage_close_available",Boolean.toString(state.optBoolean("garage_close_available")),
                "trunk_open_available",Boolean.toString(state.optBoolean("trunk_open_available")),
                "trunk_close_available",Boolean.toString(state.optBoolean("trunk_close_available"))));
    }
    private static String cover(String state) {
        return List.of("open","closed","opening","closing").contains(state) ? state.toUpperCase(java.util.Locale.ROOT) : "?";
    }
    static List<Control> controls(DeviceController.Snapshot state, VehicleFeedback feedback, boolean configured) {
        return List.of(coverControl("garage","Garage",state,feedback,configured),
                climateControl(state,feedback,configured),coverControl("trunk","Trunk",state,feedback,configured));
    }
    private static Control coverControl(String role,String title,DeviceController.Snapshot state,VehicleFeedback feedback,boolean configured) {
        String observed=state==null?"?":state.readings().getOrDefault(role,"?");
        boolean assumed=observed.equals("?");
        String shown=assumed?"CLOSED":observed;
        boolean known=observed.equals("OPEN") || observed.equals("CLOSED");
        String action=role+(observed.equals("OPEN")?"_close":"_open");
        boolean enabled=configured && (assumed || known && Boolean.parseBoolean(state.readings().getOrDefault(action+"_available","false")));
        boolean unconfirmed=!known, selected=observed.equals("OPEN");
        if(feedback!=null && feedback.action().startsWith(role+"_")) {
            shown=feedback.action().endsWith("_open")?"OPEN":"CLOSED";
            unconfirmed=!feedback.confirmed(); selected=shown.equals("OPEN") && feedback.confirmed();
            // A failed result may be retried with the SAME intent, never an assumed reverse toggle.
            action=feedback.confirmed()?role+(shown.equals("OPEN")?"_close":"_open"):feedback.action();
            enabled=configured;
            if(!feedback.pending()&&!feedback.confirmed()) shown+="\nNot confirmed";
        }
        if(feedback!=null&&feedback.pending()) { enabled=false; unconfirmed=true; }
        return new Control(action,title+"\n"+shown,enabled,unconfirmed,selected);
    }
    private static Control climateControl(DeviceController.Snapshot state,VehicleFeedback feedback,boolean configured) {
        String observed=state==null?"?":state.readings().getOrDefault("climate","?");
        boolean confirmed=observed.equals("ON"), unconfirmed=observed.equals("?");
        String label="Climate ON";
        if(feedback!=null&&feedback.appliesTo("climate_on")) {
            confirmed=feedback.confirmed(); unconfirmed=!confirmed;
            if(!feedback.pending()&&!confirmed) label+="\nNot confirmed";
        }
        if(feedback!=null&&feedback.pending()) unconfirmed=true;
        return new Control("climate_on",label,configured&&(feedback==null||!feedback.pending()),unconfirmed,confirmed);
    }
    private DrivingState() { }
}
