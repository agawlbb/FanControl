package dev.fancontrol.wear;

import android.app.*;
import android.content.*;
import android.os.*;
import org.json.JSONObject;
import java.util.concurrent.*;

/** One explicit vehicle tap, retained across screen-off, never replayed after process death. */
public final class ExerciseStopService extends Service {
    private static final String CHANNEL="vehicle_pending", ALERT_CHANNEL="vehicle_failure";
    private static final int NOTICE=430;
    private static volatile ExerciseStopService running;
    private static volatile String latestStatus="Command received";
    private static volatile String spotifyGrant="";
    static String status() { return latestStatus; }
    static boolean pending() { return running!=null && running.grant!=null; }
    static synchronized String takeSpotifyGrant() { String value=spotifyGrant; spotifyGrant=""; return value; }
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    private final Handler handler=new Handler(Looper.getMainLooper());
    private final java.util.concurrent.atomic.AtomicInteger generation=new java.util.concurrent.atomic.AtomicInteger();
    private volatile IntegrationClient active;
    private volatile ExerciseLaunch.Grant grant;
    private volatile String operation;
    private PowerManager.WakeLock wakeLock;
    static void begin(Context context, ExerciseLaunch.Grant grant) {
        context.startForegroundService(new Intent(context,ExerciseStopService.class).putExtra("grant",
                ExerciseLaunch.issue(grant.panel(),grant.action(),grant.watchId())));
    }
    static void cancel(Context context) { ExerciseStopService service=running; if(service!=null) service.cancelPending(); }
    @Override public void onCreate() {
        super.onCreate(); running=this;
        NotificationManager manager=getSystemService(NotificationManager.class);
        manager.createNotificationChannel(new NotificationChannel(CHANNEL,"Pending vehicle command",NotificationManager.IMPORTANCE_LOW));
        NotificationChannel failures=new NotificationChannel(ALERT_CHANNEL,"Vehicle command not confirmed",NotificationManager.IMPORTANCE_HIGH);
        failures.enableVibration(true); manager.createNotificationChannel(failures);
    }
    @Override public IBinder onBind(Intent intent) { return null; }
    @Override public int onStartCommand(Intent intent,int flags,int startId) {
        if(intent==null) { stopSelf(); return START_NOT_STICKY; }
        if("cancel".equals(intent.getAction())) { cancelPending(); return START_NOT_STICKY; }
        ExerciseLaunch.Grant next=ExerciseLaunch.consume(intent.getStringExtra("grant"));
        if(next==null || !VehicleCommandAttempt.supported(next.panel(),next.action())) { if(grant==null) stopSelf(); return START_NOT_STICKY; }
        if(grant!=null) {
            if(next.action().equals("start_exercise") && grant.action().equals("stop_exercise")) {
                generation.incrementAndGet(); IntegrationClient client=active; if(client!=null) client.cancel();
                cancelServerStop(grant,operation); handler.removeCallbacksAndMessages(null);
                if(wakeLock!=null && wakeLock.isHeld()) wakeLock.release();
                grant=null; // A new Start preserves the existing behavior of superseding a pending Stop.
            } else { progress("A command is pending; cancel it before sending another"); return START_NOT_STICKY; }
        }
        int ticket=generation.incrementAndGet(); grant=next; operation=java.util.UUID.randomUUID().toString();
        long issued=System.currentTimeMillis(), deadline=SystemClock.elapsedRealtime()+VehicleCommandAttempt.WINDOW_MS;
        spotifyGrant=""; latestStatus="Button pressed; command queued while vehicle wakes";
        startForeground(NOTICE,notification(latestStatus,true,false));
        wakeLock=getSystemService(PowerManager.class).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"FanControl:VehicleCommand");
        wakeLock.acquire(VehicleCommandAttempt.WINDOW_MS+5000);
        handler.postDelayed(() -> timeout(ticket),VehicleCommandAttempt.WINDOW_MS);
        worker.execute(() -> deliver(ticket,next,operation,issued,deadline));
        return START_NOT_STICKY;
    }
    private void deliver(int ticket,ExerciseLaunch.Grant target,String id,long issued,long deadline) {
        VehicleCommandAttempt attempt=new VehicleCommandAttempt(target.panel(),target.action(),id,issued);
        int failures=0;
        boolean spotifyPublished=false;
        while(ticket==generation.get() && SystemClock.elapsedRealtime()<deadline) {
            try {
                ConnectionSettings settings=new SecureSettings(this).load();
                if(settings==null || !settings.watchId().equals(target.watchId())) { finish(ticket,"Command cancelled: pairing changed",false); return; }
                long remaining=deadline-SystemClock.elapsedRealtime();
                IntegrationClient client=new IntegrationClient(settings,new okhttp3.OkHttpClient.Builder()
                        .callTimeout(Math.max(1,Math.min(4000,remaining)),TimeUnit.MILLISECONDS).connectTimeout(1,TimeUnit.SECONDS)
                        .readTimeout(3,TimeUnit.SECONDS).retryOnConnectionFailure(false).followRedirects(false).followSslRedirects(false)
                        .connectionPool(new okhttp3.ConnectionPool(0,1,TimeUnit.SECONDS)).build());
                active=client;
                if(ticket!=generation.get()) { client.cancel(); return; }
                ConnectionSettings updated=client.configuration();
                PanelDefinition selected=updated.devices().stream().filter(d -> d.panel()!=null && d.panel().id().equals(target.panel().id())).map(DeviceDefinition::panel).findFirst().orElse(null);
                if(!target.panel().equals(selected)) { finish(ticket,"Command cancelled: panel changed",false); return; }
                boolean complete=attempt.step(client::request, () -> ticket==generation.get() && SystemClock.elapsedRealtime()<deadline);
                if(ticket!=generation.get()) return;
                if(attempt.spotifyReady() && !spotifyPublished) { spotifyGrant=target.watchId()+":"+target.panel().id(); spotifyPublished=true; }
                if(complete) {
                    finish(ticket,target.action().equals("leave") ? "Script request accepted by Home Assistant" : "Vehicle command confirmed",false); return;
                }
                progress("Command received; waiting for vehicle, retrying");
            } catch(InterruptedException cancelled) { return; }
            catch(Exception retryable) {
                if(ticket!=generation.get()) return;
                progress("Command pending; retrying until the one-minute limit");
            } finally { active=null; }
            long delay=Math.min(10000,2000L << Math.min(failures++,3));
            long until=Math.min(deadline,SystemClock.elapsedRealtime()+delay);
            try { while(ticket==generation.get() && SystemClock.elapsedRealtime()<until) Thread.sleep(100); }
            catch(InterruptedException cancelled) { Thread.currentThread().interrupt(); return; }
        }
        timeout(ticket);
    }
    private synchronized void timeout(int ticket) {
        if(ticket!=generation.get() || grant==null) return;
        generation.incrementAndGet(); IntegrationClient client=active; if(client!=null) client.cancel();
        cancelServerStop(grant,operation);
        end("Not confirmed after 1 minute. Check the vehicle before trying again",true);
    }
    private synchronized void cancelPending() {
        if(grant==null) return;
        generation.incrementAndGet(); IntegrationClient client=active; if(client!=null) client.cancel();
        cancelServerStop(grant,operation); end("Command cancelled; an in-flight action may finish",false);
    }
    private void cancelServerStop(ExerciseLaunch.Grant target,String id) {
        if(target==null || !target.action().equals("stop_exercise")) return;
        // Best effort only; server expiry still protects against a disconnected watch.
        worker.execute(() -> {
            try {
                ConnectionSettings settings=new SecureSettings(this).load();
                if(settings!=null && settings.watchId().equals(target.watchId())) new IntegrationClient(settings).request(new JSONObject()
                        .put("action","panel_command").put("panel_id",target.panel().id()).put("command","cancel_stop").put("operation_id",id));
            } catch(Exception ignored) { }
        });
    }
    private Notification notification(String message,boolean pending,boolean alert) {
        Notification.Builder builder=new Notification.Builder(this,alert?ALERT_CHANNEL:CHANNEL).setSmallIcon(dev.fancontrol.wear.R.drawable.ic_fan)
                .setContentTitle("Vehicle command").setContentText(message).setStyle(new Notification.BigTextStyle().bigText(message)).setOngoing(pending);
        if(pending) builder.addAction(new Notification.Action.Builder(android.R.drawable.ic_menu_close_clear_cancel,"Cancel",
                PendingIntent.getService(this,0,new Intent(this,ExerciseStopService.class).setAction("cancel"),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT)).build());
        return builder.build();
    }
    private synchronized void progress(String message) { if(grant==null) return; latestStatus=message; getSystemService(NotificationManager.class).notify(NOTICE,notification(message,true,false)); }
    private synchronized void finish(int ticket,String message,boolean alert) { if(ticket==generation.get()) end(message,alert); }
    private void end(String message,boolean alert) {
        generation.incrementAndGet(); handler.removeCallbacksAndMessages(null); latestStatus=message;
        stopForeground(STOP_FOREGROUND_REMOVE);
        getSystemService(NotificationManager.class).notify(NOTICE,notification(message,false,alert));
        if(alert) getSystemService(Vibrator.class).vibrate(VibrationEffect.createWaveform(new long[]{0,300,150,300},-1));
        if(wakeLock!=null && wakeLock.isHeld()) wakeLock.release();
        grant=null; stopSelf();
    }
    @Override public void onDestroy() {
        generation.incrementAndGet(); handler.removeCallbacksAndMessages(null); IntegrationClient client=active; if(client!=null) client.cancel();
        if(wakeLock!=null && wakeLock.isHeld()) wakeLock.release();
        worker.shutdown(); if(running==this) running=null; super.onDestroy();
    }
}
