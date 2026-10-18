package dev.fancontrol.wear;

import androidx.wear.tiles.EventBuilders;
import androidx.wear.tiles.RequestBuilders;
import androidx.wear.tiles.TileBuilders;
import androidx.wear.tiles.TileService;
import androidx.wear.protolayout.LayoutElementBuilders;
import androidx.wear.protolayout.ResourceBuilders;
import androidx.wear.protolayout.TimelineBuilders;
import com.google.common.util.concurrent.Futures;
import com.google.common.util.concurrent.ListenableFuture;

/** Exactly one configured Driving panel; cached configuration can accept an immediate trunk tap. */
public final class DrivingTileService extends TileService {
    private static volatile Session current;
    static void pauseForActivity() { Session value=current; if(value!=null) value.leave(); }
    static boolean isVisible() { Session value=current; return value!=null&&value.visible; }
    private Session session() {
        synchronized(DrivingTileService.class) {
            if(current==null) current=new Session(getApplicationContext());
            return current;
        }
    }
    @Override protected ListenableFuture<TileBuilders.Tile> onTileRequest(RequestBuilders.TileRequest request) {
        PanelCommands.click(this,request.getCurrentState().getLastClickableId());
        return Futures.immediateFuture(session().tile());
    }
    @Override protected ListenableFuture<ResourceBuilders.Resources> onTileResourcesRequest(RequestBuilders.ResourcesRequest request) {
        return Futures.immediateFuture(new ResourceBuilders.Resources.Builder().setVersion("1").build());
    }
    @SuppressWarnings("deprecation") @Override protected void onTileEnterEvent(EventBuilders.TileEnterEvent event) { session().enter(); }
    @SuppressWarnings("deprecation") @Override protected void onTileLeaveEvent(EventBuilders.TileLeaveEvent event) { session().leave(); }
    @Override protected void onTileRemoveEvent(EventBuilders.TileRemoveEvent event) { session().leave(); }
    @Override protected ListenableFuture<Void> onRecentInteractionEventsAsync(java.util.List<EventBuilders.TileInteractionEvent> events) {
        EventBuilders.TileInteractionEvent latest=events.stream().max(java.util.Comparator.comparing(EventBuilders.TileInteractionEvent::getTimestamp)
                .thenComparingInt(EventBuilders.TileInteractionEvent::getEventType)).orElse(null);
        if(latest!=null) {
            Session value=session();
            InteractionGate.Decision decision=value.gate.accept(latest.getTimestamp().toEpochMilli(),latest.getEventType()==EventBuilders.TileInteractionEvent.ENTER,System.currentTimeMillis());
            if(decision==InteractionGate.Decision.LEAVE) value.leave();
            if(decision==InteractionGate.Decision.REFRESH) value.enter();
        }
        return Futures.immediateVoidFuture();
    }
    private static final class Session extends android.content.ContextWrapper {
        final InteractionGate gate=new InteractionGate();
        final android.os.Handler handler=new android.os.Handler(android.os.Looper.getMainLooper());
        final java.util.concurrent.ExecutorService worker=java.util.concurrent.Executors.newSingleThreadExecutor();
        final java.util.concurrent.atomic.AtomicInteger generation=new java.util.concurrent.atomic.AtomicInteger();
        volatile boolean visible;
        volatile DeviceController active;
        volatile IntegrationClient configuration;
        volatile DeviceController.Snapshot state;
        volatile PanelDefinition enteredPanel;
        volatile String enteredWatch="";
        final Runnable poll=()->refresh(false);
        Session(android.content.Context context) {
            super(context);
            android.content.BroadcastReceiver receiver=new android.content.BroadcastReceiver() {
                public void onReceive(android.content.Context context,android.content.Intent intent) { leave(); }
            };
            android.content.IntentFilter filter=new android.content.IntentFilter(android.content.Intent.ACTION_SCREEN_OFF);
            if(android.os.Build.VERSION.SDK_INT>=33) registerReceiver(receiver,filter,android.content.Context.RECEIVER_NOT_EXPORTED);
            else registerReceiver(receiver,filter);
        }
        void publish() { TileService.getUpdater(getApplicationContext()).requestUpdate(DrivingTileService.class); }
        synchronized void enter() {
            if(visible||!VisibleEntryGate.tileMayConnect(getSystemService(android.os.PowerManager.class).isInteractive(),FanControlApplication.activityVisible())) return;
            visible=true; state=null; enteredPanel=null; enteredWatch="";
            BackgroundConfigurationJob.cancelActive(); refresh(true);
        }
        synchronized void leave() {
            visible=false; generation.incrementAndGet(); handler.removeCallbacks(poll);
            if(active!=null) active.cancel(); if(configuration!=null) configuration.cancel();
            active=null; configuration=null; state=null; enteredPanel=null; enteredWatch=""; publish();
        }
        synchronized void refresh(boolean entry) {
            if(!visible||!VisibleEntryGate.tileMayConnect(getSystemService(android.os.PowerManager.class).isInteractive(),FanControlApplication.activityVisible())) { leave(); return; }
            int ticket=generation.incrementAndGet();
            worker.execute(()->{
                DeviceController controller=null; IntegrationClient config=null;
                try {
                    if(ticket!=generation.get()) return;
                    ConnectionSettings saved=new SecureSettings(this).load();
                    if(saved==null||!saved.integration()) throw new IllegalStateException();
                    config=new IntegrationClient(saved); configuration=config;
                    if(ticket!=generation.get()) { config.cancel(); return; }
                    ConnectionSettings updated=config.configuration();
                    PanelDefinition panel=DrivingPanels.unique(updated);
                    if(panel==null) throw new IllegalStateException();
                    // Changing the watch/roles while visible requires a new entry; a poll cannot wake another car.
                    if(!entry&&(enteredPanel==null||!enteredPanel.equals(panel)||!enteredWatch.equals(updated.watchId()))) throw new IllegalStateException();
                    if(entry) { enteredPanel=panel; enteredWatch=updated.watchId(); }
                    new SecureSettings(this).saveIfCurrent(saved,updated);
                    controller=new DrivingController(updated,panel); active=controller;
                    if(ticket!=generation.get()) { controller.cancel(); return; }
                    VehicleFeedback beforeRead=ExerciseStopService.feedback(panel,updated.watchId());
                    DeviceController.Snapshot result=entry?controller.enter():controller.read();
                    if(ticket==generation.get()&&visible) { state=result; ExerciseStopService.observed(beforeRead); }
                } catch(Exception ignored) { if(ticket==generation.get()) state=null; }
                finally {
                    if(active==controller) active=null; if(configuration==config) configuration=null;
                    if(ticket==generation.get()) { publish(); if(visible) handler.postDelayed(poll,5000); }
                }
            });
        }
        TileBuilders.Tile tile() {
            ConnectionSettings saved=new SecureSettings(this).load();
            PanelDefinition panel=DrivingPanels.unique(saved);
            String watchId=saved==null?"":saved.watchId();
            boolean matching=visible&&panel!=null&&panel.equals(enteredPanel)&&watchId.equals(enteredWatch);
            VehicleFeedback feedback=panel==null?null:ExerciseStopService.feedback(panel,watchId);
            LayoutElementBuilders.Column content=DrivingTileLayout.content(getPackageName(),panel,watchId,matching?state:null,feedback);
            return new TileBuilders.Tile.Builder().setResourcesVersion("1").setTileTimeline(new TimelineBuilders.Timeline.Builder()
                    .addTimelineEntry(new TimelineBuilders.TimelineEntry.Builder().setLayout(new LayoutElementBuilders.Layout.Builder().setRoot(content).build()).build()).build()).build();
        }
    }
}
