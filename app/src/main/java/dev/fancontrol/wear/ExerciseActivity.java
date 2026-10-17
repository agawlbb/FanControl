package dev.fancontrol.wear;

import android.app.Activity;
import android.os.Bundle;
import android.content.Intent;
import android.widget.TextView;
import android.widget.LinearLayout;
import android.widget.Button;

/** Immediately acknowledges one vehicle tap; delivery belongs to the bounded service. */
public final class ExerciseActivity extends Activity {
    private TextView status;
    private final android.os.Handler progress=new android.os.Handler(android.os.Looper.getMainLooper());
    private String spotify="";
    private boolean monitor;
    private String watchId="", panelId="";
    static void open(Activity activity,String panel,String action) {
        ConnectionSettings settings=new SecureSettings(activity).load(); if(settings==null) return;
        PanelDefinition selected=settings.devices().stream().filter(d -> d.panel()!=null && d.panel().id().equals(panel)).map(DeviceDefinition::panel).findFirst().orElse(null);
        if(selected!=null && VehicleCommandAttempt.supported(selected,action)) activity.startActivity(new Intent(activity,ExerciseActivity.class)
                .putExtra("exercise_grant",ExerciseLaunch.issue(selected,action,settings.watchId())));
    }
    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        LinearLayout root=new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL); root.setGravity(android.view.Gravity.CENTER);
        root.setPadding(24,40,24,24);
        status=new TextView(this); status.setText("Button pressed; preparing command"); status.setTextColor(android.graphics.Color.WHITE); status.setGravity(android.view.Gravity.CENTER); root.addView(status);
        setContentView(root);
        Button cancel=new Button(this); cancel.setText("Cancel pending command");
        cancel.setOnClickListener(view -> ExerciseStopService.cancel(this)); root.addView(cancel);
        if(saved!=null) {
            monitor=saved.getBoolean("monitor"); watchId=saved.getString("watch",""); panelId=saved.getString("panel","");
            status.setText(ExerciseStopService.status()); return;
        } // Never replay a restored tap.
        ExerciseLaunch.Grant grant=ExerciseLaunch.consume(getIntent().getStringExtra("exercise_grant"));
        if(grant==null || !VehicleCommandAttempt.supported(grant.panel(),grant.action())) { status.setText("Open a current vehicle button"); return; }
        watchId=grant.watchId(); panelId=grant.panel().id();
        root.post(() -> root.performHapticFeedback(android.view.HapticFeedbackConstants.CONFIRM));
        if(grant.action().equals("stop_exercise")) spotify=WatchSpotify.pause(this); // Exactly once, outside retries.
        try {
            ExerciseStopService.begin(this,grant);
            monitor=true;
            status.setText("Button pressed; command queued. Trying for up to 1 minute. "+spotify);
        } catch(RuntimeException failure) { status.setText("Button pressed, but delivery could not start. Please try again"); return; }
        if(android.os.Build.VERSION.SDK_INT>=33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)!=android.content.pm.PackageManager.PERMISSION_GRANTED)
            requestPermissions(new String[]{android.Manifest.permission.POST_NOTIFICATIONS},52);
        if(grant.panel().exercise() && !WatchSpotify.hasAccess(this)) {
            Button access=new Button(this); access.setText("Enable watch Spotify pause");
            access.setOnClickListener(view -> {
                try { startActivity(new Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); }
                catch(RuntimeException unavailable) { status.setText("Notification access settings unavailable"); }
            }); root.addView(access);
        }
    }
    private void poll() {
        if(!monitor) return;
        status.setText(ExerciseStopService.status()+(spotify.isEmpty()?"":"; "+spotify));
        String launch=ExerciseStopService.takeSpotifyGrant();
        ConnectionSettings settings=new SecureSettings(this).load();
        if(launch.equals(watchId+":"+panelId) && settings!=null && settings.watchId().equals(watchId)) {
            Intent intent=getPackageManager().getLaunchIntentForPackage("com.spotify.music");
            if(intent!=null) { try { startActivity(intent); return; } catch(RuntimeException ignored) { } }
            status.setText(ExerciseStopService.status()+"; Spotify could not open on watch");
        }
        if(ExerciseStopService.pending()) progress.postDelayed(this::poll,500);
    }
    @Override protected void onResume() { super.onResume(); progress.postDelayed(this::poll,500); }
    @Override protected void onPause() { progress.removeCallbacksAndMessages(null); super.onPause(); }
    @Override protected void onSaveInstanceState(Bundle state) {
        state.putBoolean("monitor",monitor); state.putString("watch",watchId); state.putString("panel",panelId); super.onSaveInstanceState(state);
    }
}
