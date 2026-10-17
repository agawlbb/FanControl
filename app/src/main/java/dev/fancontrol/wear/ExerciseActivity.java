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
    private TextView requested;
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
        if (saved == null) {
            ExerciseLaunch.Grant start = ExerciseLaunch.consume(getIntent().getStringExtra("exercise_grant"));
            if (start != null && start.action().equals("start_exercise")) {
                ConnectionSettings current = new SecureSettings(this).load();
                if (current != null && current.watchId().equals(start.watchId())
                        && current.devices().stream().anyMatch(d -> start.panel().equals(d.panel()))) {
                    ExerciseStopService.begin(this,start);
                    Intent spotify = getPackageManager().getLaunchIntentForPackage("com.spotify.music");
                    if (spotify != null) try { startActivity(spotify); } catch (RuntimeException ignored) { }
                }
                finish(); return;
            }
            // Preserve a non-Start grant for the legacy entry point below.
            if (start != null) getIntent().putExtra("exercise_grant",ExerciseLaunch.issue(start.panel(),start.action(),start.watchId()));
        } else { finish(); return; } // A restored handoff never replays a command.
        LinearLayout root=new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL); root.setGravity(android.view.Gravity.CENTER);
        root.setPadding(24,40,24,24);
        status=new TextView(this); status.setText("Button pressed; preparing command"); status.setTextColor(android.graphics.Color.WHITE); status.setGravity(android.view.Gravity.CENTER); root.addView(status);
        requested=new TextView(this); requested.setTextSize(28); requested.setGravity(android.view.Gravity.CENTER); requested.setEnabled(false);
        requested.setTypeface(android.graphics.Typeface.DEFAULT_BOLD); requested.setPadding(8,16,8,16);
        requested.setTextColor(0xFFB0B0B0); requested.setBackgroundColor(0xFF383838);
        root.addView(requested,new LinearLayout.LayoutParams(-1,android.view.ViewGroup.LayoutParams.WRAP_CONTENT));
        root.removeView(status); root.addView(status);
        android.widget.ScrollView scroll=new android.widget.ScrollView(this); scroll.setFillViewport(true); scroll.addView(root); setContentView(scroll);
        Button cancel=new Button(this); cancel.setText("Cancel pending command");
        cancel.setOnClickListener(view -> ExerciseStopService.cancel(this)); root.addView(cancel);
        if(saved!=null) {
            monitor=saved.getBoolean("monitor"); watchId=saved.getString("watch",""); panelId=saved.getString("panel","");
            status.setText(ExerciseStopService.status()); return;
        } // Never replay a restored tap.
        ExerciseLaunch.Grant grant=ExerciseLaunch.consume(getIntent().getStringExtra("exercise_grant"));
        if(grant==null || !VehicleCommandAttempt.supported(grant.panel(),grant.action())) { status.setText("Open a current vehicle button"); return; }
        watchId=grant.watchId(); panelId=grant.panel().id();
        requested.setText(CommandFeedback.title(grant.action()));
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
        VehicleFeedback feedback=ExerciseStopService.feedback();
        if(feedback!=null && feedback.watchId().equals(watchId) && feedback.panel().id().equals(panelId)) {
            requested.setText(feedback.title());
            requested.setEnabled(feedback.confirmed());
            requested.setTextColor(feedback.confirmed()?android.graphics.Color.BLACK:0xFFB0B0B0);
            requested.setBackgroundColor(feedback.confirmed()?0xFF70E2C2:0xFF383838);
        }
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
