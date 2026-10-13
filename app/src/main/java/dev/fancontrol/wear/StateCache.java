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
    void clear() { preferences.edit().clear().apply(); }
}
