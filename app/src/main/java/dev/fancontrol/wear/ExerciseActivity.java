package dev.fancontrol.wear;

import android.app.Activity;
import android.os.Bundle;
import android.content.Intent;
import android.widget.TextView;
import android.widget.LinearLayout;
import android.widget.Button;
import java.util.concurrent.Executors;

/** A foreground, one-shot action runner. Recreation/resume never replays a command. */
public final class ExerciseActivity extends Activity {
    private final java.util.concurrent.ExecutorService worker = Executors.newSingleThreadExecutor();
    private volatile DeviceController active;
    private volatile boolean stopped;
    private TextView status;
    static void open(Activity activity, String panel, String action) {
        ConnectionSettings settings = new SecureSettings(activity).load();
        if (settings == null) return;
        PanelDefinition selected = settings.devices().stream().filter(d -> d.panel()!=null && d.panel().exercise() && d.panel().id().equals(panel)).map(DeviceDefinition::panel).findFirst().orElse(null);
        if (selected != null) activity.startActivity(new Intent(activity, ExerciseActivity.class).putExtra("exercise_grant", ExerciseLaunch.issue(selected, action, settings.watchId())));
    }
    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        LinearLayout root = new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL); root.setGravity(android.view.Gravity.CENTER);
        status = new TextView(this); status.setText("Checking Exercise controls"); status.setTextColor(android.graphics.Color.WHITE); status.setGravity(android.view.Gravity.CENTER); root.addView(status);
        Button access = new Button(this); access.setText("Enable watch Spotify pause");
        access.setOnClickListener(view -> {
            try { startActivity(new Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); }
            catch (RuntimeException unavailable) { status.setText("Notification access settings unavailable on this watch"); }
        });
        if (!WatchSpotify.hasAccess(this)) root.addView(access);
        setContentView(root);
        if (saved != null) { status.setText("Previous action may have completed. Check the car; it was not repeated."); return; }
        ExerciseLaunch.Grant grant = ExerciseLaunch.consume(getIntent().getStringExtra("exercise_grant"));
        if (grant == null) { status.setText("Open a current Exercise button"); return; }
        String panelId = grant.panel().id(), action = grant.action();
        if (!java.util.List.of("start_exercise", "stop_exercise").contains(action == null ? "" : action)) { status.setText("Open an Exercise button"); return; }
        worker.execute(() -> {
            IntegrationClient config = null;
            try {
                ConnectionSettings settings = new SecureSettings(this).load();
                if (settings == null || !settings.integration() || !settings.watchId().equals(grant.watchId())) throw new IllegalStateException();
                config = new IntegrationClient(settings);
                ConnectionSettings updated = config.configuration();
                DeviceDefinition device = updated.devices().stream().filter(d -> d.panel()!=null && d.panel().exercise() && d.panel().id().equals(panelId)).findFirst().orElseThrow();
                if (stopped) return;
                if (!device.panel().equals(grant.panel())) throw new IllegalStateException("Exercise target changed");
                DeviceController controller = new ExerciseController(updated, device.panel()); active = controller;
                if (stopped) { controller.cancel(); return; }
                // The visible tile/page already owns waking. Here, revalidate readiness without another wake.
                DeviceController.Snapshot result = controller.command(action);
                runOnUiThread(() -> {
                    if (stopped) return;
                    if (!device.panel().equals(grant.panel())) throw new IllegalStateException("Exercise target changed");
                    status.setText(result.status());
                    if (action.equals("stop_exercise")) status.setText(result.status() + "; " + WatchSpotify.pause(this));
                    if ("yes".equals(result.readings().get("launch_spotify"))) {
                        Intent launch = getPackageManager().getLaunchIntentForPackage("com.spotify.music");
                        if (launch == null) { status.setText("Lock requested; Spotify is not installed on this watch"); return; }
                        try { startActivity(launch); } catch (RuntimeException unavailable) { status.setText("Lock requested; Spotify could not open"); }
                    }
                });
            } catch (Exception ignored) {
                runOnUiThread(() -> { if (!stopped) {
                    String message = "Car action not confirmed. Check the car before retrying";
                    status.setText(message + (action.equals("stop_exercise") ? "; " + WatchSpotify.pause(this) : "; Spotify was not opened"));
                } });
            } finally { active = null; if (config != null) config.cancel(); }
        });
    }
    @Override protected void onPause() { stopped = true; DeviceController controller = active; if(controller!=null) controller.cancel(); super.onPause(); }
    @Override protected void onDestroy() { worker.shutdownNow(); super.onDestroy(); }
}
