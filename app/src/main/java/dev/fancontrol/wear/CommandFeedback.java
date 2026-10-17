package dev.fancontrol.wear;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

/** A requested state is presentation only. It is never stored in the confirmed cache. */
final class CommandFeedback {
    static String vehicleAction(String action, boolean climateOn) {
        return action.equals("climate") ? climateOn ? "climate_off" : "climate_on" : action;
    }
    static String action(DeviceController.Snapshot before, String action) {
        if (before == null) return action;
        if (action.equals("toggle")) return before.status().startsWith("On") ? "turn_off" : "turn_on";
        if (action.equals("climate")) return vehicleAction(action, "ON".equals(before.readings().get("climate")));
        return action;
    }
    static String title(String action) {
        return switch(action) {
            case "climate_on" -> "Climate ON";
            case "climate_off" -> "Climate OFF";
            case "start_exercise" -> "LOCKED";
            case "stop_exercise" -> "UNLOCKED · Climate 63°F";
            case "leave", "activate" -> "REQUESTED";
            default -> "PENDING";
        };
    }
    static DeviceController.Snapshot requested(DeviceController.Snapshot before, String action) {
        if (before == null) return null;
        boolean on = before.status().startsWith("On");
        boolean fan = before.controls().stream().anyMatch(c -> c.action().matches("speed[1-6]"));
        boolean power = action.equals("toggle") || action.equals("turn_on") || action.equals("turn_off") || action.matches("speed[1-6]");
        boolean desired = action.equals("toggle") ? !on : !action.equals("turn_off");
        String status = power ? desired ? "On" : "Off" : title(action);
        int speed = action.matches("speed[1-6]") ? Integer.parseInt(action.substring(5)) : -1;
        if (fan && speed > 0) status += " · Speed " + speed;
        ArrayList<DeviceController.Control> controls = new ArrayList<>();
        HashMap<String,String> readings = new HashMap<>(before.readings());
        readings.put("pending_action", action);
        boolean climate = action.equals("climate") || action.startsWith("climate_");
        boolean climateOn = action.equals("climate") ? !"ON".equals(readings.get("climate")) : action.equals("climate_on");
        if (climate) readings.put("climate", climateOn ? "ON" : "OFF");
        for (DeviceController.Control control : before.controls()) {
            String label = control.label(); boolean selected = control.selected();
            if (power && control.action().equals("toggle")) { label = desired ? "ON" : "OFF"; selected = desired; }
            if (power && control.action().matches("speed[1-6]")) selected = desired && (speed < 0 ? selected : control.action().equals(action));
            if (climate && control.action().equals("climate")) { label = "Climate " + (climateOn ? "ON" : "OFF"); selected = climateOn; }
            if (control.action().equals(action) && (action.equals("activate") || action.equals("leave"))) label = "REQUESTED";
            controls.add(new DeviceController.Control(control.action(),label,false,selected));
        }
        return new DeviceController.Snapshot(status, controls, readings);
    }
}
