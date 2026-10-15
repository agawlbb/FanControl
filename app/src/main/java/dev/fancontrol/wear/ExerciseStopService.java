package dev.fancontrol.wear;

import android.app.*;
import android.content.*;
import android.os.*;
import org.json.JSONObject;
import java.util.concurrent.*;

/** Explicit-user-action foreground delivery, bounded to 2 minutes; never restored on reboot. */
public final class ExerciseStopService extends Service {
    private static final String CHANNEL="exercise_stop";
    private static final int NOTICE=430;
    private static volatile ExerciseStopService running;
    private static volatile String latestStatus="Stop received; sending to Home Assistant";
    static String status() { return latestStatus; }
    static boolean pending() { return running!=null && running.grant!=null; }
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    private final java.util.concurrent.atomic.AtomicInteger generation=new java.util.concurrent.atomic.AtomicInteger();
    private volatile IntegrationClient active;
    private volatile ExerciseLaunch.Grant grant;
    private volatile String operation;
    private volatile long issued;
    private PowerManager.WakeLock wakeLock;
    static void begin(Context context, ExerciseLaunch.Grant grant) {
        context.startForegroundService(new Intent(context,ExerciseStopService.class).putExtra("grant",
                ExerciseLaunch.issue(grant.panel(),"stop_exercise",grant.watchId())));
    }
    static void cancel(Context context) {
        ExerciseStopService service=running;
        if(service!=null) service.cancelPending();
    }
    @Override public void onCreate() {
        super.onCreate(); running=this;
        getSystemService(NotificationManager.class).createNotificationChannel(new NotificationChannel(CHANNEL,"Pending Exercise Stop",NotificationManager.IMPORTANCE_LOW));
    }
    @Override public android.os.IBinder onBind(Intent intent) { return null; }
    @Override public int onStartCommand(Intent intent,int flags,int startId) {
        if(intent==null) { stopSelf(); return START_NOT_STICKY; }
        if("cancel".equals(intent.getAction())) { cancelPending(); return START_NOT_STICKY; }
        ExerciseLaunch.Grant next=ExerciseLaunch.consume(intent.getStringExtra("grant"));
        if(next==null || !next.action().equals("stop_exercise")) { stopSelf(); return START_NOT_STICKY; }
        // One current operation; a second tap cannot create another server retry stream.
        if(grant!=null) {
            if(!grant.panel().equals(next.panel()) || !grant.watchId().equals(next.watchId())) progress("Existing Stop pending; cancel before changing vehicle");
            return START_NOT_STICKY;
        }
        int ticket=generation.incrementAndGet(); grant=next; operation=java.util.UUID.randomUUID().toString(); issued=System.currentTimeMillis();
        latestStatus="Stop received; sending to Home Assistant";
        startForeground(NOTICE,notification(latestStatus,true));
        wakeLock=getSystemService(PowerManager.class).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"FanControl:ExerciseStop");
        wakeLock.acquire(125_000);
        String id=operation; long started=issued;
        worker.execute(() -> deliver(ticket,next,id,started));
        return START_NOT_STICKY;
    }
    private void deliver(int ticket,ExerciseLaunch.Grant target,String id,long started) {
        long deadline=SystemClock.elapsedRealtime()+120_000;
        int attempt=0;
        boolean accepted=false;
        try {
            while(ticket==generation.get() && SystemClock.elapsedRealtime()<deadline) {
                try {
                    ConnectionSettings settings=new SecureSettings(this).load();
                    if(settings==null || !settings.watchId().equals(target.watchId())) { finish(ticket,"Stop cancelled: pairing changed"); return; }
                    IntegrationClient client=new IntegrationClient(settings); active=client;
                    if(ticket!=generation.get()) { client.cancel(); return; }
                    ConnectionSettings updated=client.configuration(); // Read fallback resolves a reachable route; commands themselves never auto-replay.
                    PanelDefinition selected=updated.devices().stream().filter(d -> d.panel()!=null && d.panel().id().equals(target.panel().id())).map(DeviceDefinition::panel).findFirst().orElse(null);
                    if(!target.panel().equals(selected)) { finish(ticket,"Stop cancelled: target changed"); return; }
                    if(ticket!=generation.get() || SystemClock.elapsedRealtime()>=deadline) return;
                    JSONObject result=client.request(new JSONObject().put("action","panel_command").put("panel_id",selected.id()).put("command","stop_exercise")
                            .put("operation_id",id).put("issued_at_ms",started).put("panel_config",selected.toJson()));
                    accepted=true;
                    String status=result.optString("operation_status","unsupported");
                    if(status.equals("complete")) { finish(ticket,"Stop steps confirmed; check current car state"); return; }
                    if(!status.equals("pending")) { finish(ticket,"Stop ended: "+status+"; check car"); return; }
                    progress("HA accepted Stop; waiting for car. Cancel available");
                } catch(IntegrationClient.Rejected rejected) {
                    finish(ticket,"Stop rejected; check Home Assistant access"); return;
                } catch(Exception transientFailure) {
                    if(ticket!=generation.get()) return;
                    progress(accepted ? "HA accepted Stop; connection lost, checking again" : "Stop pending; retrying delivery to Home Assistant");
                } finally { active=null; }
                long delay=Math.min(15000,2000L << Math.min(attempt++,3));
                long until=Math.min(deadline,SystemClock.elapsedRealtime()+delay);
                while(ticket==generation.get() && SystemClock.elapsedRealtime()<until) Thread.sleep(100);
            }
            finish(ticket,"Stop retry window ended; check car before retrying");
        } catch(InterruptedException cancelled) { Thread.currentThread().interrupt(); }
    }
    private void cancelPending() {
        int cancelTicket=generation.incrementAndGet(); IntegrationClient client=active; if(client!=null) client.cancel();
        ExerciseLaunch.Grant target=grant; String id=operation; grant=null;
        // Cancellation is best effort over a failing network; HA expiry remains authoritative.
        worker.execute(() -> {
            try {
                ConnectionSettings settings=new SecureSettings(this).load();
                if(target!=null && settings!=null && settings.watchId().equals(target.watchId())) {
                    IntegrationClient cancel=new IntegrationClient(settings);
                    try { cancel.request(new JSONObject().put("action","panel_command").put("panel_id",target.panel().id()).put("command","cancel_stop").put("operation_id",id)); }
                    finally { cancel.cancel(); }
                }
            } catch(Exception ignored) { }
            finish(cancelTicket,"Stop cancellation requested; HA may finish in-flight work until expiry");
        });
    }
    private Notification notification(String message,boolean pending) {
        Notification.Builder builder=new Notification.Builder(this,CHANNEL).setSmallIcon(dev.fancontrol.wear.R.drawable.ic_fan)
                .setContentTitle("Exercise Stop").setContentText(message).setStyle(new Notification.BigTextStyle().bigText(message)).setOngoing(pending);
        if(pending) builder.addAction(new Notification.Action.Builder(android.R.drawable.ic_menu_close_clear_cancel,"Cancel",
                PendingIntent.getService(this,0,new Intent(this,ExerciseStopService.class).setAction("cancel"),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT)).build());
        return builder.build();
    }
    private void progress(String message) { latestStatus=message; getSystemService(NotificationManager.class).notify(NOTICE,notification(message,true)); }
    private void finish(int ticket,String message) { if(ticket==generation.get()) end(message); }
    private void end(String message) {
        latestStatus=message;
        stopForeground(STOP_FOREGROUND_REMOVE);
        getSystemService(NotificationManager.class).notify(NOTICE,notification(message,false));
        if(wakeLock!=null && wakeLock.isHeld()) wakeLock.release();
        grant=null; stopSelf();
    }
    @Override public void onDestroy() {
        generation.incrementAndGet(); IntegrationClient client=active; if(client!=null) client.cancel();
        if(wakeLock!=null && wakeLock.isHeld()) wakeLock.release();
        worker.shutdownNow(); if(running==this) running=null; super.onDestroy();
    }
}
