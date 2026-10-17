package dev.fancontrol.wear;

import android.content.Context;

/** Tile clicks carry one-use grants; command delivery never opens a waiting activity. */
final class PanelCommands {
    static final String PREFIX = "panel-command:";
    static void start(Context context, PanelDefinition panel, String action, String watchId) {
        if (!VehicleCommandAttempt.supported(panel, action)) return;
        ExerciseStopService.begin(context, new ExerciseLaunch.Grant(panel, action, watchId, 0));
    }
    static boolean click(Context context, String id) {
        if (id == null || !id.startsWith(PREFIX)) return false;
        ExerciseLaunch.Grant grant = ExerciseLaunch.consume(id.substring(PREFIX.length()));
        ConnectionSettings settings = new SecureSettings(context).load();
        if (grant != null && settings != null && settings.watchId().equals(grant.watchId())
                && settings.devices().stream().anyMatch(d -> grant.panel().equals(d.panel())))
            start(context, grant.panel(), grant.action(), grant.watchId());
        return true;
    }
}
