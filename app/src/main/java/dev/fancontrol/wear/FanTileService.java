package dev.fancontrol.wear;

import android.content.SharedPreferences;
import androidx.wear.tiles.EventBuilders;
import androidx.wear.tiles.RequestBuilders;
import androidx.wear.tiles.TileBuilders;
import androidx.wear.tiles.TileService;
import androidx.wear.protolayout.ActionBuilders;
import androidx.wear.protolayout.ColorBuilders;
import androidx.wear.protolayout.DimensionBuilders;
import androidx.wear.protolayout.LayoutElementBuilders;
import androidx.wear.protolayout.ModifiersBuilders;
import androidx.wear.protolayout.ResourceBuilders;
import androidx.wear.protolayout.TimelineBuilders;
import com.google.common.util.concurrent.Futures;
import com.google.common.util.concurrent.ListenableFuture;
import com.google.common.util.concurrent.ListeningExecutorService;
import com.google.common.util.concurrent.MoreExecutors;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;
import static androidx.wear.protolayout.DimensionBuilders.dp;
import static androidx.wear.protolayout.DimensionBuilders.sp;

public final class FanTileService extends TileService {
    private final ListeningExecutorService worker = MoreExecutors.listeningDecorator(Executors.newSingleThreadExecutor());
    private final java.util.concurrent.ExecutorService configurationWorker = Executors.newSingleThreadExecutor();
    private VisibleConfigurationSession selectionSession;
    private final AtomicInteger generation = new AtomicInteger();
    private final InteractionGate gate = new InteractionGate();
    private volatile DeviceController active;
    private volatile IntegrationClient configuration;
    private volatile String message = "Last known state";
    private volatile boolean fresh;
    private boolean visible, commandBusy;
    private final SpeedSelection speedSelection = new SpeedSelection();
    private int sendingSpeed = -1;
    private final Runnable sendSpeed = () -> {
        if (!visible) { speedSelection.clear(); return; }
        String target = speedSelection.target();
        String action = speedSelection.take(android.os.SystemClock.elapsedRealtime());
        if (action != null) { sendingSpeed = Integer.parseInt(action.substring(5)); runOperation(action, target); }
    };
    private final android.os.Handler handler = new android.os.Handler(android.os.Looper.getMainLooper());
    private final Runnable poll = () -> {
        if (visible && getSystemService(android.os.PowerManager.class).isInteractive()) refreshOnView();
        else leave();
    };
    private final Runnable checkSelection = new Runnable() {
        @Override public void run() {
            if (!visible || !getSystemService(android.os.PowerManager.class).isInteractive()) { leave(); return; }
            selectionSession.refresh(new SecureSettings(FanTileService.this).load());
            handler.postDelayed(this, 2000);
        }
    };
    private void watchSelection() { handler.removeCallbacks(checkSelection); handler.post(checkSelection); }
    private static final int MINT = 0xFF70E2C2;
    private static final int WHITE = 0xFFF4F7F6;
    private final android.content.BroadcastReceiver screenOff = new android.content.BroadcastReceiver() {
        @Override public void onReceive(android.content.Context context, android.content.Intent intent) { leave(); }
    };

    @Override public void onCreate() {
        super.onCreate();
        selectionSession = new VisibleConfigurationSession(configurationWorker, IntegrationClient::new, update -> handler.post(() -> {
            if (!visible || !selectionSession.accepts(update)) return;
            SecureSettings storage = new SecureSettings(this);
            ConnectionSettings current = storage.load();
            if (current == null || !current.equals(update.original()) || current.equals(update.updated())) return;
            try {
                boolean changed = !current.devices().get(0).equals(update.updated().devices().get(0));
                storage.save(update.updated());
                if (changed) {
                    clearSpeed(); sendingSpeed = -1; commandBusy = false;
                    stopOperation(); new StateCache(this).clear(); message = "Updating…";
                }
                getUpdater(this).requestUpdate(FanTileService.class); // Publish the new layout before slow device reads.
                if (changed) runOperation("refresh", "");
            } catch (Exception ignored) { }
        }));
        android.content.IntentFilter filter = new android.content.IntentFilter(android.content.Intent.ACTION_SCREEN_OFF);
        if (android.os.Build.VERSION.SDK_INT >= 33) registerReceiver(screenOff, filter, android.content.Context.RECEIVER_NOT_EXPORTED);
        else registerReceiver(screenOff, filter);
    }

    @Override protected ListenableFuture<TileBuilders.Tile> onTileRequest(RequestBuilders.TileRequest request) {
        String click = request.getCurrentState().getLastClickableId();
        SharedPreferences handled = getSharedPreferences("actions", MODE_PRIVATE);
        // Click IDs are unique per layout. Wear may repeat a request containing the last click.
        if (click != null && click.matches("(toggle|activate|climate|leave|slower|faster|speed[1-6]|refresh):([a-f0-9]{16}:)?[a-f0-9-]+")
                && !click.equals(handled.getString("last", ""))) {
            handled.edit().putString("last", click).commit();
            String[] pieces = click.split(":");
            if (!commandBusy) {
                visible = true; watchSelection();
                String target = pieces.length == 3 ? pieces[1] : "";
                if (pieces[0].equals("slower") || pieces[0].equals("faster")) selectSpeed(pieces[0], target);
                else { clearSpeed(); runOperation(pieces[0], target); }
            }
            return Futures.immediateFuture(tile());
        }
        // Prefetch, add, resource, and other unsolicited requests never open a connection.
        return Futures.immediateFuture(tile());
    }

    @Override protected ListenableFuture<ResourceBuilders.Resources> onTileResourcesRequest(RequestBuilders.ResourcesRequest request) {
        return Futures.immediateFuture(new ResourceBuilders.Resources.Builder().setVersion("1").build());
    }

    @Override protected ListenableFuture<Void> onRecentInteractionEventsAsync(List<EventBuilders.TileInteractionEvent> events) {
        // Collapse the entire batch before acting: ENTER followed by LEAVE is offline.
        EventBuilders.TileInteractionEvent latest = events.stream()
                .max(Comparator.comparing(EventBuilders.TileInteractionEvent::getTimestamp)
                        .thenComparingInt(EventBuilders.TileInteractionEvent::getEventType)).orElse(null);
        if (latest == null) return Futures.immediateVoidFuture();
        boolean enter = latest.getEventType() == EventBuilders.TileInteractionEvent.ENTER;
        InteractionGate.Decision decision = gate.accept(latest.getTimestamp().toEpochMilli(), enter, System.currentTimeMillis());
        if (decision == InteractionGate.Decision.LEAVE) leave();
        if (decision == InteractionGate.Decision.REFRESH && getSystemService(android.os.PowerManager.class).isInteractive()) return refreshOnView();
        return Futures.immediateVoidFuture();
    }

    @SuppressWarnings("deprecation")
    @Override protected void onTileEnterEvent(EventBuilders.TileEnterEvent event) { refreshOnView(); }

    @SuppressWarnings("deprecation")
    @Override protected void onTileLeaveEvent(EventBuilders.TileLeaveEvent event) { leave(); }

    @Override protected void onTileRemoveEvent(EventBuilders.TileRemoveEvent event) { leave(); }

    private int startOperation() {
        stopOperation();
        return generation.get();
    }

    private void stopOperation() {
        generation.incrementAndGet();
        DeviceController client = active;
        if (client != null) client.cancel();
        IntegrationClient config = configuration; if (config != null) config.cancel();
        fresh = false;
    }

    private static int confirmedSpeed(DeviceController.Snapshot state) {
        if (state == null) return -1;
        if (state.status().startsWith("Off")) return 0;
        for (DeviceController.Control control : state.controls())
            if (control.selected() && control.action().matches("speed[1-6]")) return Integer.parseInt(control.action().substring(5));
        return -1;
    }
    private void clearSpeed() { handler.removeCallbacks(sendSpeed); speedSelection.clear(); }
    private void selectSpeed(String action, String target) {
        ConnectionSettings settings = new SecureSettings(this).load();
        if (settings == null || !TileTarget.key(settings).equals(target)) { clearSpeed(); runOperation("refresh", ""); return; }
        if (!speedSelection.pending()) { handler.removeCallbacks(poll); stopOperation(); }
        if (speedSelection.tap(confirmedSpeed(new StateCache(this).readSnapshot()), action.equals("faster") ? 1 : -1,
                target, android.os.SystemClock.elapsedRealtime())) {
            handler.removeCallbacks(sendSpeed); handler.postDelayed(sendSpeed, 3000);
        }
    }
    private void leave() { handler.removeCallbacks(checkSelection); if (selectionSession != null) selectionSession.close(); clearSpeed(); sendingSpeed = -1; visible = false; handler.removeCallbacks(poll); commandBusy = false; stopOperation(); }
    private ListenableFuture<Void> refreshOnView() {
        visible = true; watchSelection();
        if (!commandBusy && !speedSelection.pending()) runOperation("refresh", "");
        return Futures.immediateVoidFuture();
    }
    private void runOperation(String action, String target) {
        handler.removeCallbacks(poll);
        int ticket = startOperation(); commandBusy = !action.equals("refresh");
        if (commandBusy) message = "Updating…";
        worker.execute(() -> {
            fetch(action, ticket, target);
            handler.post(() -> {
                if (ticket != generation.get()) return;
                commandBusy = false; sendingSpeed = -1; getUpdater(this).requestUpdate(FanTileService.class);
                if (visible) handler.postDelayed(poll, 5000);
            });
        });
    }

    private void fetch(String action, int ticket, String displayedDevice) {
        if (ticket != generation.get()) return;
        ConnectionSettings settings = new SecureSettings(this).load();
        if (settings == null) { message = "Open app to set up"; return; }
        DeviceController client = null;
        try {
            if (settings.integration() && !action.equals("refresh")) {
                IntegrationClient config = new IntegrationClient(settings); configuration = config;
                if (ticket != generation.get()) { config.cancel(); return; }
                ConnectionSettings updated = config.configuration();
                if (ticket != generation.get()) return;
                if (!settings.devices().get(0).equals(updated.devices().get(0))) new StateCache(this).clear();
                new SecureSettings(this).save(updated); settings = updated;
                handler.post(() -> { if (ticket == generation.get()) getUpdater(this).requestUpdate(FanTileService.class); });
            }
            action = TileTarget.action(settings, action, displayedDevice);
            client = DeviceControllers.create(settings, settings.devices().get(0)); active = client;
            if (ticket != generation.get()) { client.cancel(); return; }
            DeviceController.Snapshot state = action.equals("refresh") ? client.read() : client.command(action);
            if (ticket == generation.get()) {
                new StateCache(this).saveSnapshot(state);
                fresh = true;
                message = action.equals("leave") ? "Script requested" : "Updated";
            }
        } catch (Exception error) {
            if (ticket == generation.get()) {
                fresh = false;
                // Whitelist safe messages; never display raw network errors, URLs, or response bodies.
                String text = error.getMessage();
                message = List.of("Check access token", "Check fan entity ID", "Fan unavailable",
                        "Speed control unsupported", "Home Assistant error").contains(text == null ? "" : text)
                        ? text : ("Waiting for fan confirmation".equals(text) || "Waiting for climate confirmation".equals(text)) ? "Not confirmed · refresh" : "Offline · tap to retry";
            }
        } finally { if (active == client) active = null; configuration = null; }
    }

    private TileBuilders.Tile tile() {
        DeviceController.Snapshot state = new StateCache(this).readSnapshot();
        ConnectionSettings settings = new SecureSettings(this).load();
        boolean configured = settings != null;
        LayoutElementBuilders.Column.Builder content = new LayoutElementBuilders.Column.Builder()
                .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER);
        List<DeviceController.Control> controls = state == null ? List.of() : state.controls();
        boolean fan = configured && settings.devices().get(0).domain().equals("fan");
        boolean on = state != null && state.status().startsWith("On");
        boolean available = !controls.isEmpty() && controls.get(0).enabled();
        PanelDefinition panel = configured ? settings.devices().get(0).panel() : null;
        if (panel != null) {
            String climate = state == null ? "?" : state.readings().getOrDefault("climate", "?");
            LayoutElementBuilders.Row.Builder top = new LayoutElementBuilders.Row.Builder();
            top.addContent(new LayoutElementBuilders.Box.Builder().setWidth(dp(78)).setHeight(dp(72))
                    .addContent(text(state == null ? "?%" : state.readings().getOrDefault("battery", "?") + "%", 32, WHITE)).build());
            top.addContent(new LayoutElementBuilders.Spacer.Builder().setWidth(dp(4)).build());
            top.addContent(climateButton(panel.climateLabel(), climate, available && !commandBusy));
            content.addContent(top.build());
            content.addContent(spacer(8));
            content.addContent(button(panel.scriptLabel(), "leave", 160, 56,
                    controls.size() > 1 && controls.get(1).enabled() && !commandBusy, false, "Run configured script", 18));
        } else {
        String power = !configured ? "SET UP" : controls.isEmpty() ? "REFRESH" : !available ? "UNKNOWN" : fan ? on ? "ON" : "OFF" : controls.get(0).label();
        content.addContent(button(power, controls.isEmpty() ? "refresh" : controls.get(0).action(), 160, 60,
                configured && !commandBusy && (controls.isEmpty() || available), on, "Toggle power", available ? 30 : 22));
        content.addContent(spacer(8));
        if (fan) {
            int speed = sendingSpeed >= 1 ? sendingSpeed : speedSelection.displayed(confirmedSpeed(state));
            boolean enabled = controls.size() > 1 && controls.get(1).enabled() && !commandBusy && speed >= 0;
            LayoutElementBuilders.Row.Builder row = new LayoutElementBuilders.Row.Builder();
            row.addContent(button("−", "slower", 54, 58, enabled && speed > 1, false, "Slower", 34));
            row.addContent(new LayoutElementBuilders.Box.Builder().setWidth(dp(52)).setHeight(dp(58))
                    .addContent(text(state == null || !available || speed < 0 ? "?" : Integer.toString(speed), 40, WHITE)).build());
            row.addContent(button("+", "faster", 54, 58, enabled && speed < 6, false, "Faster", 34));
            content.addContent(row.build());
        } else content.addContent(text(state == null ? "State unknown" : state.status(), 20, WHITE));
        }
        content.addContent(spacer(6));
        content.addContent(new LayoutElementBuilders.Box.Builder().setWidth(dp(150)).setHeight(dp(22))
                .setModifiers(new ModifiersBuilders.Modifiers.Builder().setClickable(configured ? click("refresh") : setupClick()).build())
                .addContent(text(speedSelection.pending() ? "Sending in 3 seconds" : commandBusy ? "Updating…" : configured ? fresh ? message : message.equals("Last known state") ? "Last known · refresh" : message : "Open app to set up", 11, WHITE)).build());
        content.addContent(new LayoutElementBuilders.Box.Builder().setWidth(dp(120)).setHeight(dp(18))
                .setModifiers(new ModifiersBuilders.Modifiers.Builder().setClickable(configured ? controlsClick() : setupClick()).build())
                .addContent(text("More controls", 10, WHITE)).build());
        LayoutElementBuilders.Box root = new LayoutElementBuilders.Box.Builder()
                .setWidth(DimensionBuilders.expand()).setHeight(DimensionBuilders.expand())
                .setModifiers(new ModifiersBuilders.Modifiers.Builder().setBackground(new ModifiersBuilders.Background.Builder()
                        .setColor(ColorBuilders.argb(0xFF000000)).build()).build())
                .addContent(content.build()).build();
        return new TileBuilders.Tile.Builder().setResourcesVersion("1")
                // No freshness interval: no periodic wakeups or background polling.
                .setTileTimeline(new TimelineBuilders.Timeline.Builder().addTimelineEntry(
                        new TimelineBuilders.TimelineEntry.Builder().setLayout(new LayoutElementBuilders.Layout.Builder()
                                .setRoot(root).build()).build()).build()).build();
    }

    private LayoutElementBuilders.Box climateButton(String label, String state, boolean enabled) {
        boolean on = state.equals("ON");
        int color = on ? 0xFF001F16 : enabled ? WHITE : 0xFF87918D;
        ModifiersBuilders.Modifiers.Builder modifiers = new ModifiersBuilders.Modifiers.Builder()
                .setBackground(new ModifiersBuilders.Background.Builder().setColor(ColorBuilders.argb(on ? MINT : 0xFF24332F))
                        .setCorner(new ModifiersBuilders.Corner.Builder().setRadius(dp(16)).build()).build())
                .setSemantics(new ModifiersBuilders.Semantics.Builder().setContentDescription(label + " " + state).build());
        if (enabled) modifiers.setClickable(click("climate"));
        return new LayoutElementBuilders.Box.Builder().setWidth(dp(78)).setHeight(dp(72)).setModifiers(modifiers.build())
                .addContent(new LayoutElementBuilders.Column.Builder().setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
                        .addContent(text(label, 12, color)).addContent(text(state, 24, color)).build()).build();
    }

    private LayoutElementBuilders.Text text(String value, int size, int color) {
        return new LayoutElementBuilders.Text.Builder().setText(value).setMaxLines(1)
                .setFontStyle(new LayoutElementBuilders.FontStyle.Builder().setSize(sp(size))
                        .setColor(ColorBuilders.argb(color)).build()).build();
    }

    private LayoutElementBuilders.Spacer spacer(int height) {
        return new LayoutElementBuilders.Spacer.Builder().setHeight(dp(height)).build();
    }

    private ModifiersBuilders.Clickable click(String action) {
        ConnectionSettings settings = new SecureSettings(this).load();
        return new ModifiersBuilders.Clickable.Builder().setId(action + ":" + TileTarget.key(settings) + ":" + UUID.randomUUID())
                .setOnClick(new ActionBuilders.LoadAction.Builder().build()).build();
    }

    private ModifiersBuilders.Clickable setupClick() {
        return new ModifiersBuilders.Clickable.Builder().setId("setup").setOnClick(new ActionBuilders.LaunchAction.Builder()
                .setAndroidActivity(new ActionBuilders.AndroidActivity.Builder().setPackageName(getPackageName())
                        .setClassName(MainActivity.class.getName()).build()).build()).build();
    }

    private ModifiersBuilders.Clickable controlsClick() {
        return new ModifiersBuilders.Clickable.Builder().setId("controls").setOnClick(new ActionBuilders.LaunchAction.Builder()
                .setAndroidActivity(new ActionBuilders.AndroidActivity.Builder().setPackageName(getPackageName())
                        .setClassName(ControlsActivity.class.getName()).build()).build()).build();
    }

    private LayoutElementBuilders.Box button(String label, String action, int width, int height,
                                              boolean enabled, boolean selected, String description, int fontSize) {
        ModifiersBuilders.Modifiers.Builder modifiers = new ModifiersBuilders.Modifiers.Builder()
                .setBackground(new ModifiersBuilders.Background.Builder().setColor(ColorBuilders.argb(selected ? MINT : 0xFF24332F))
                        .setCorner(new ModifiersBuilders.Corner.Builder().setRadius(dp(16)).build()).build())
                .setSemantics(new ModifiersBuilders.Semantics.Builder().setContentDescription(description + (selected ? ", selected" : "")).build());
        if (enabled) modifiers.setClickable(click(action));
        else if (new SecureSettings(this).load() == null) modifiers.setClickable(setupClick());
        return new LayoutElementBuilders.Box.Builder().setWidth(dp(width)).setHeight(dp(height))
                .setModifiers(modifiers.build()).addContent(text(label, fontSize, selected ? 0xFF001F16 : enabled ? WHITE : 0xFF87918D)).build();
    }

    @Override public void onDestroy() {
        leave();
        handler.removeCallbacksAndMessages(null);
        unregisterReceiver(screenOff);
        worker.shutdownNow();
        configurationWorker.shutdownNow();
        super.onDestroy();
    }
}
