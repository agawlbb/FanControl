package dev.fancontrol.wear;

import android.content.Context;
import android.content.SharedPreferences;

/** Only generic fan status is cached; no entity names or connection details. */
final class StateCache {
    private final SharedPreferences preferences;
    StateCache(Context context) { preferences = context.getSharedPreferences("state", Context.MODE_PRIVATE); }
    FanState read() {
        if (!preferences.contains("on")) return null;
        return new FanState(preferences.getBoolean("on", false), preferences.getInt("speed", -1),
                preferences.getBoolean("supported", false), preferences.getBoolean("available", false));
    }
    void save(FanState state) {
        preferences.edit().putBoolean("on", state.on()).putInt("speed", state.speed())
                .putBoolean("supported", state.speedSupported()).putBoolean("available", state.available()).apply();
    }
    DeviceController.Snapshot readSnapshot() {
        String value = preferences.getString("snapshot", null);
        if (value == null) { FanState fan = read(); return fan == null ? null : DeviceControllers.Fan.snapshot(fan); }
        try {
            org.json.JSONObject json = new org.json.JSONObject(value); java.util.ArrayList<DeviceController.Control> controls = new java.util.ArrayList<>();
            org.json.JSONArray array = json.getJSONArray("controls");
            for (int i=0;i<array.length();i++) { org.json.JSONObject item=array.getJSONObject(i); controls.add(new DeviceController.Control(item.getString("action"), item.getString("label"), item.getBoolean("enabled"), item.getBoolean("selected"))); }
            java.util.Map<String,String> readings = new java.util.HashMap<>();
            org.json.JSONObject values = json.optJSONObject("readings");
            if (values != null) for (String key : java.util.List.of("battery", "climate"))
                if (values.has(key)) readings.put(key, values.getString(key));
            return new DeviceController.Snapshot(json.getString("status"), controls, readings);
        } catch(Exception ignored) { return null; }
    }
    void saveSnapshot(DeviceController.Snapshot snapshot) throws Exception {
        org.json.JSONArray array = new org.json.JSONArray();
        for (DeviceController.Control control : snapshot.controls()) array.put(new org.json.JSONObject().put("action", control.action()).put("label", control.label()).put("enabled",control.enabled()).put("selected",control.selected()));
        preferences.edit().putString("snapshot", new org.json.JSONObject().put("status",snapshot.status()).put("controls",array).put("readings",new org.json.JSONObject(snapshot.readings())).toString()).apply();
    }
    void clear() { preferences.edit().clear().apply(); }
}
