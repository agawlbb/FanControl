package dev.fancontrol.wear;

import androidx.wear.tiles.EventBuilders;
import androidx.wear.tiles.RequestBuilders;
import androidx.wear.tiles.TileBuilders;
import androidx.wear.tiles.TileService;
import androidx.wear.protolayout.ActionBuilders;
import androidx.wear.protolayout.ColorBuilders;
import androidx.wear.protolayout.LayoutElementBuilders;
import androidx.wear.protolayout.ModifiersBuilders;
import androidx.wear.protolayout.ResourceBuilders;
import androidx.wear.protolayout.TimelineBuilders;
import com.google.common.util.concurrent.Futures;
import com.google.common.util.concurrent.ListenableFuture;
import static androidx.wear.protolayout.DimensionBuilders.dp;
import static androidx.wear.protolayout.DimensionBuilders.sp;

/** Separate Exercise tile. Renderer prefetch only draws; visible entry owns all I/O. */
public final class ExerciseTileService extends TileService {
    private static Session current;
    private synchronized Session session() {
        synchronized (ExerciseTileService.class) {
            if (current == null) current = new Session(getApplicationContext());
            return current;
        }
    }
    @Override protected ListenableFuture<TileBuilders.Tile> onTileRequest(RequestBuilders.TileRequest request) { return Futures.immediateFuture(session().tile()); }
    @Override protected ListenableFuture<ResourceBuilders.Resources> onTileResourcesRequest(RequestBuilders.ResourcesRequest request) {
        return Futures.immediateFuture(new ResourceBuilders.Resources.Builder().setVersion("1").build());
    }
    @SuppressWarnings("deprecation") @Override protected void onTileEnterEvent(EventBuilders.TileEnterEvent event) { session().enter(); }
    @SuppressWarnings("deprecation") @Override protected void onTileLeaveEvent(EventBuilders.TileLeaveEvent event) { session().leave(); }
    @Override protected void onTileRemoveEvent(EventBuilders.TileRemoveEvent event) { session().leave(); }
    @Override protected ListenableFuture<Void> onRecentInteractionEventsAsync(java.util.List<EventBuilders.TileInteractionEvent> events) {
        EventBuilders.TileInteractionEvent latest = events.stream().max(java.util.Comparator.comparing(EventBuilders.TileInteractionEvent::getTimestamp)
                .thenComparingInt(EventBuilders.TileInteractionEvent::getEventType)).orElse(null);
        if (latest != null) {
            Session s = session();
            InteractionGate.Decision decision = s.gate.accept(latest.getTimestamp().toEpochMilli(), latest.getEventType()==EventBuilders.TileInteractionEvent.ENTER, System.currentTimeMillis());
            if (decision == InteractionGate.Decision.LEAVE) s.leave();
            if (decision == InteractionGate.Decision.REFRESH) s.enter();
        }
        return Futures.immediateVoidFuture();
    }
    static ModifiersBuilders.Clickable action(String packageName, PanelDefinition panel, String action, String watchId) {
        String token = ExerciseLaunch.issue(panel, action, watchId);
        return new ModifiersBuilders.Clickable.Builder().setId(token).setOnClick(new ActionBuilders.LaunchAction.Builder()
                .setAndroidActivity(new ActionBuilders.AndroidActivity.Builder().setPackageName(packageName).setClassName(ExerciseActivity.class.getName())
                        .addKeyToExtraMapping("exercise_grant", new ActionBuilders.AndroidStringExtra.Builder().setValue(token).build()).build()).build()).build();
    }
    private static final class Session extends android.content.ContextWrapper {
        final InteractionGate gate = new InteractionGate();
        final android.os.Handler handler = new android.os.Handler(android.os.Looper.getMainLooper());
        final java.util.concurrent.ExecutorService worker = java.util.concurrent.Executors.newSingleThreadExecutor();
        final java.util.concurrent.atomic.AtomicInteger generation = new java.util.concurrent.atomic.AtomicInteger();
        volatile boolean visible;
        volatile DeviceController controller;
        volatile IntegrationClient config;
        volatile DeviceController.Snapshot snapshot;
        volatile PanelDefinition panel;
        volatile String watchId = "";
        volatile String message = "Open to connect";
        final Runnable poll = () -> refresh(false);
        Session(android.content.Context context) {
            super(context);
            android.content.BroadcastReceiver receiver = new android.content.BroadcastReceiver() {
                public void onReceive(android.content.Context c, android.content.Intent intent) { leave(); }
            };
            android.content.IntentFilter filter = new android.content.IntentFilter(android.content.Intent.ACTION_SCREEN_OFF);
            if (android.os.Build.VERSION.SDK_INT >= 33) registerReceiver(receiver, filter, android.content.Context.RECEIVER_NOT_EXPORTED);
            else registerReceiver(receiver, filter);
        }
        void publish() { TileService.getUpdater(getApplicationContext()).requestUpdate(ExerciseTileService.class); }
        synchronized void enter() {
            if (visible || !getSystemService(android.os.PowerManager.class).isInteractive()) return;
            visible=true; refresh(true);
        }
        synchronized void leave() {
            visible=false; generation.incrementAndGet(); handler.removeCallbacks(poll);
            if(controller!=null) controller.cancel(); if(config!=null) config.cancel();
            snapshot=null; panel=null; message="Open to connect"; publish();
        }
        synchronized void refresh(boolean entry) {
            if (!visible || !getSystemService(android.os.PowerManager.class).isInteractive()) { leave(); return; }
            int ticket=generation.incrementAndGet(); snapshot=null; message=entry ? "Waking vehicle" : "Updating"; publish();
            worker.execute(() -> {
                try {
                    if (!visible || ticket!=generation.get()) return;
                    ConnectionSettings saved=new SecureSettings(this).load();
                    if(saved==null || !saved.integration()) throw new IllegalStateException();
                    IntegrationClient client=new IntegrationClient(saved); config=client;
                    if(ticket!=generation.get()) { client.cancel(); return; }
                    ConnectionSettings settings=client.configuration();
                    java.util.List<DeviceDefinition> matches=settings.devices().stream().filter(d -> d.panel()!=null && d.panel().exercise()).collect(java.util.stream.Collectors.toList());
                    if(matches.size()!=1) throw new IllegalStateException();
                    PanelDefinition selected=matches.get(0).panel();
                    DeviceController active=new ExerciseController(settings,selected); controller=active;
                    if(ticket!=generation.get()) { active.cancel(); return; }
                    // Configuration polls cannot wake newly selected targets: require another visible entry.
                    boolean changed = panel!=null && !panel.equals(selected);
                    if(changed) throw new IllegalStateException();
                    DeviceController.Snapshot result=entry ? active.enter() : active.read();
                    if(ticket==generation.get() && visible) { panel=selected; watchId=settings.watchId(); snapshot=result; message=result.status(); }
                } catch(Exception ignored) {
                    if(ticket==generation.get()) { snapshot=null; message="Unavailable; reopen tile"; }
                } finally {
                    if(ticket==generation.get()) { controller=null; config=null; publish(); if(visible) handler.postDelayed(poll,5000); }
                }
            });
        }
        TileBuilders.Tile tile() {
            DeviceController.Snapshot state=visible ? snapshot : null;
            PanelDefinition selected=panel;
            if (selected==null) {
                ConnectionSettings saved=new SecureSettings(this).load();
                if(saved!=null) {
                    java.util.List<DeviceDefinition> candidates=saved.devices().stream().filter(d -> d.panel()!=null && d.panel().exercise()).collect(java.util.stream.Collectors.toList());
                    if(candidates.size()==1) { selected=candidates.get(0).panel(); watchId=saved.watchId(); }
                }
            }
            LayoutElementBuilders.Column.Builder column=new LayoutElementBuilders.Column.Builder().setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER);
            VehicleFeedback feedback=selected==null?null:ExerciseStopService.feedback(selected,watchId);
            boolean waiting=feedback!=null && feedback.pending();
            column.addContent(text("Exercise",20));
            for(int i=0;i<2;i++) {
                String command=i==0 ? "start_exercise" : "stop_exercise";
                boolean enabled=selected!=null && !waiting;
                ModifiersBuilders.Modifiers.Builder modifiers=new ModifiersBuilders.Modifiers.Builder().setBackground(new ModifiersBuilders.Background.Builder().setColor(ColorBuilders.argb(enabled?0xFF245C4F:0xFF242A28)).build());
                if(enabled) modifiers.setClickable(action(getPackageName(),selected,command,watchId));
                String label=i==0?"Start exercise":"Stop exercise";
                if(waiting) label=feedback.label(command,label);
                column.addContent(new LayoutElementBuilders.Box.Builder().setWidth(dp(160)).setHeight(dp(52)).setModifiers(modifiers.build())
                        .addContent(new LayoutElementBuilders.Text.Builder().setText(label).setMaxLines(2).setFontStyle(new LayoutElementBuilders.FontStyle.Builder()
                                .setSize(sp(18)).setColor(ColorBuilders.argb(waiting?0xFFB0B0B0:0xFFFFFFFF)).build()).build()).build());
                column.addContent(new LayoutElementBuilders.Spacer.Builder().setHeight(dp(4)).build());
            }
            column.addContent(text(message,11));
            return new TileBuilders.Tile.Builder().setResourcesVersion("1").setTileTimeline(new TimelineBuilders.Timeline.Builder().addTimelineEntry(new TimelineBuilders.TimelineEntry.Builder()
                    .setLayout(new LayoutElementBuilders.Layout.Builder().setRoot(column.build()).build()).build()).build()).build();
        }
        LayoutElementBuilders.Text text(String value,int size) { return new LayoutElementBuilders.Text.Builder().setText(value).setMaxLines(2).setFontStyle(new LayoutElementBuilders.FontStyle.Builder().setSize(sp(size)).setColor(ColorBuilders.argb(0xFFFFFFFF)).build()).build(); }
    }
}
