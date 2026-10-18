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

final class TileSession extends android.content.ContextWrapper {
    private static volatile TileSession instance;
    static void pauseForActivity() { TileSession value=instance; if(value!=null) value.leave(); }
    static boolean isVisible() { TileSession current = instance; return current != null && current.visible; }
    static synchronized TileSession get(android.content.Context context) {
        if (instance == null) instance = new TileSession(context.getApplicationContext());
        return instance;
    }
    private TileSession(android.content.Context context) { super(context); initialize(); }
    private final ListeningExecutorService worker = MoreExecutors.listeningDecorator(Executors.newSingleThreadExecutor());
    private final java.util.concurrent.ExecutorService configurationWorker = Executors.newSingleThreadExecutor();
    private VisibleConfigurationSession selectionSession;
    private final AtomicInteger generation = new AtomicInteger();
    private final InteractionGate gate = new InteractionGate();
    private volatile DeviceController active;
    private volatile IntegrationClient configuration;
    private volatile String message = "Last known state";
    private volatile boolean fresh;
    private volatile boolean visible;
    private final VisibleEntryGate entryGate = new VisibleEntryGate();
    private boolean commandBusy;
    private volatile DeviceController.Snapshot requestedState;
    private volatile String requestedTarget = "";
    private final SpeedSelection speedSelection = new SpeedSelection();
    private final FanTileState fanState = new FanTileState();
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
            selectionSession.refresh(new SecureSettings(TileSession.this).load());
            handler.postDelayed(this, 2000);
        }
    };
    private void watchSelection() { handler.removeCallbacks(checkSelection); handler.post(checkSelection); }
    private static final int MINT = 0xFF70E2C2;
    private static final int WHITE = 0xFFF4F7F6;
    private final android.content.BroadcastReceiver screenOff = new android.content.BroadcastReceiver() {
        @Override public void onReceive(android.content.Context context, android.content.Intent intent) { leave(); }
    };

    private void initialize() {

        selectionSession = new VisibleConfigurationSession(configurationWorker, IntegrationClient::new, update -> handler.post(() -> {
            if (!visible || !selectionSession.accepts(update)) return;
            SecureSettings storage = new SecureSettings(this);
            ConnectionSettings current = storage.load();
            if (current == null || !current.equals(update.original()) || current.equals(update.updated())) return;
            try {
                boolean changed = !current.devices().get(0).equals(update.updated().devices().get(0));
                storage.save(update.updated());
                if (changed) {
                    requestedState = null;
                    clearSpeed(); sendingSpeed = -1; commandBusy = false;
                    stopOperation(); fanState.clear(); new StateCache(this).clear(); message = "";
                }
                TileService.getUpdater(getApplicationContext()).requestUpdate(FanTileService.class); // Publish the new layout before slow device reads.
                if (changed) runOperation("refresh", "");
            } catch (Exception ignored) { }
        }));
        android.content.IntentFilter filter = new android.content.IntentFilter(android.content.Intent.ACTION_SCREEN_OFF);
        if (android.os.Build.VERSION.SDK_INT >= 33) registerReceiver(screenOff, filter, android.content.Context.RECEIVER_NOT_EXPORTED);
        else registerReceiver(screenOff, filter);
    }

    protected ListenableFuture<TileBuilders.Tile> onTileRequest(RequestBuilders.TileRequest request) {
        String click = request.getCurrentState().getLastClickableId();
        if (PanelCommands.click(this, click)) return Futures.immediateFuture(tile());
        if (BuildConfig.DEBUG) android.util.Log.d("FanTile", "request: click=" + (click == null || click.isEmpty() ? "none" : click.split(":")[0]) + " busy=" + commandBusy);
        SharedPreferences handled = getSharedPreferences("actions", MODE_PRIVATE);
        // Click IDs are unique per layout. Wear may repeat a request containing the last click.
        if (click != null && click.matches("(toggle|activate|climate|leave|slower|faster|speed[1-6]|refresh):([a-f0-9]{16}:)?[a-f0-9-]+")
                && !click.equals(handled.getString("last", ""))) {
            handled.edit().putString("last", click).commit();
            String[] pieces = click.split(":");
            if (!commandBusy) {
                visible = true; BackgroundConfigurationJob.cancelActive(); watchSelection();
                ConnectionSettings current = new SecureSettings(this).load();
                if (current != null && current.devices().get(0).domain().equals("fan") && fanState.current() == null)
                    pieces[0] = "refresh"; // A tap from an old renderer layout cannot operate an unknown fan.
                if (current != null) {
                    PanelDefinition panel = current.devices().get(0).panel();
                    pieces[0] = VisibleEntryGate.safeAction(pieces[0], panel != null && panel.vehicle(), fresh);
                }
                String target = pieces.length == 3 ? pieces[1] : "";
                if (pieces[0].equals("slower") || pieces[0].equals("faster")) selectSpeed(pieces[0], target);
                else {
                    clearSpeed();
                    ListenableFuture<Void> operation = runOperation(pieces[0], target);
                    return Futures.immediateFuture(tile()); // Publish the requested state before waiting for I/O.
                }
            }
            return Futures.immediateFuture(tile());
        }
        // Prefetch, add, resource, and other unsolicited requests never open a connection.
        return Futures.immediateFuture(tile());
    }

    protected ListenableFuture<ResourceBuilders.Resources> onTileResourcesRequest(RequestBuilders.ResourcesRequest request) {
        return Futures.immediateFuture(new ResourceBuilders.Resources.Builder().setVersion("1").build());
    }

    protected ListenableFuture<Void> onRecentInteractionEventsAsync(List<EventBuilders.TileInteractionEvent> events) {
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
    protected void onTileEnterEvent(EventBuilders.TileEnterEvent event) { refreshOnView(); }

    @SuppressWarnings("deprecation")
    protected void onTileLeaveEvent(EventBuilders.TileLeaveEvent event) { leave(); }

    protected void onTileRemoveEvent(EventBuilders.TileRemoveEvent event) { leave(); }

    private int startOperation() {
        stopOperation();
        return generation.get();
    }

    private void stopOperation() {
        if (BuildConfig.DEBUG) android.util.Log.d("FanTile", "cancel operation");
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
        if (speedSelection.tap(confirmedSpeed(fanState.current()), action.equals("faster") ? 1 : -1,
                target, android.os.SystemClock.elapsedRealtime())) {
            handler.removeCallbacks(sendSpeed); handler.postDelayed(sendSpeed, SpeedSelection.QUIET_WINDOW_MS);
        }
    }
    private void leave() { if (requestedState != null) new StateCache(this).clear(); requestedState = null; entryGate.leave(); handler.removeCallbacks(checkSelection); if (selectionSession != null) selectionSession.close(); clearSpeed(); sendingSpeed = -1; fanState.clear(); visible = false; handler.removeCallbacks(poll); commandBusy = false; stopOperation(); TileService.getUpdater(getApplicationContext()).requestUpdate(FanTileService.class); }
    private ListenableFuture<Void> refreshOnView() {
        if(!VisibleEntryGate.tileMayConnect(getSystemService(android.os.PowerManager.class).isInteractive(),FanControlApplication.activityVisible())) {
            leave(); return Futures.immediateVoidFuture();
        }
        if (visible && (active != null || configuration != null)) return Futures.immediateVoidFuture();
        BackgroundConfigurationJob.cancelActive();
        if (!visible) { fanState.clear(); message = ""; TileService.getUpdater(getApplicationContext()).requestUpdate(FanTileService.class); }
        visible = true; watchSelection();
        if (!commandBusy && !speedSelection.pending()) return runOperation("refresh", "");
        return Futures.immediateVoidFuture();
    }
    private ListenableFuture<Void> runOperation(String action, String target) {
        handler.removeCallbacks(poll);
        int ticket = startOperation(); commandBusy = !action.equals("refresh");
        DeviceController.Snapshot before = new StateCache(this).readSnapshot();
        String command = commandBusy ? CommandFeedback.action(before, action) : action;
        if (commandBusy) {
            ConnectionSettings settings = new SecureSettings(this).load();
            requestedTarget = TileTarget.key(settings);
            requestedState = CommandFeedback.requested(before, command);
            message = "Pending confirmation";
        }
        return worker.submit(() -> {
            fetch(command, ticket, target);
            handler.post(() -> {
                if (ticket != generation.get()) return;
                commandBusy = false; requestedState = null; sendingSpeed = -1; TileService.getUpdater(getApplicationContext()).requestUpdate(FanTileService.class);
                if (visible) handler.postDelayed(poll, 5000);
            });
            return null;
        });
    }

    private void fetch(String action, int ticket, String displayedDevice) {
        if (ticket != generation.get()) return;
        ConnectionSettings settings = new SecureSettings(this).load();
        if (settings == null) { message = "Open app to set up"; return; }
        DeviceController client = null;
        try {
            if (settings.integration()) {
                IntegrationClient config = new IntegrationClient(settings); configuration = config;
                if (ticket != generation.get()) { config.cancel(); return; }
                ConnectionSettings updated = config.configuration();
                if (ticket != generation.get()) return;
                if (!settings.devices().get(0).equals(updated.devices().get(0))) { fanState.clear(); new StateCache(this).clear(); }
                new SecureSettings(this).save(updated); settings = updated;
                handler.post(() -> { if (ticket == generation.get()) TileService.getUpdater(getApplicationContext()).requestUpdate(FanTileService.class); });
            }
            action = TileTarget.action(settings, action, displayedDevice);
            if (action.equals("refresh")) requestedState = null;
            if (BuildConfig.DEBUG) android.util.Log.d("FanTile", "operation: " + action);
            client = DeviceControllers.create(settings, settings.devices().get(0)); active = client;
            if (ticket != generation.get()) { client.cancel(); return; }
            boolean entry = visible && VisibleEntryGate.tileMayConnect(getSystemService(android.os.PowerManager.class).isInteractive(),FanControlApplication.activityVisible()) && entryGate.claim(TileTarget.key(settings));
            PanelDefinition panel = settings.devices().get(0).panel();
            action = VisibleEntryGate.safeAction(action, panel != null && panel.vehicle(), !entry);
            VehicleFeedback beforeRead = panel == null ? null : ExerciseStopService.feedback(panel,settings.watchId());
            DeviceController.Snapshot state = action.equals("refresh") ? (entry ? client.enter() : client.read()) : client.command(action);
            if (ticket == generation.get()) {
                new StateCache(this).saveSnapshot(state);
                ExerciseStopService.observed(beforeRead);
                if (settings.devices().get(0).domain().equals("fan")) fanState.confirm(state);
                boolean fan = settings.devices().get(0).domain().equals("fan");
                fresh = !fan || fanState.current() != null;
                message = fan && !fresh ? "Fan unavailable" : action.equals("leave") ? "Script requested" : "";
            }
        } catch (Exception error) {
            if (BuildConfig.DEBUG) android.util.Log.d("FanTile", "operation failed: " + error.getClass().getSimpleName());
            if (ticket == generation.get()) {
                fresh = false;
                fanState.clear();
                if (requestedState != null) new StateCache(this).clear();
                // Whitelist safe messages; never display raw network errors, URLs, or response bodies.
                String text = error.getMessage();
                message = List.of("Check access token", "Check fan entity ID", "Fan unavailable",
                        "Speed control unsupported", "Home Assistant error", "Vehicle not ready").contains(text == null ? "" : text)
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
        boolean fan = configured && settings.devices().get(0).domain().equals("fan");
        if (fan) state = visible ? fanState.current() : null;
        // Panel snapshots are usable only after a successful read in this visible operation.
        if (configured && settings.devices().get(0).panel() != null && settings.devices().get(0).panel().vehicle() && (!visible || !fresh)) state = null;
        boolean pending = visible && requestedState != null && requestedTarget.equals(TileTarget.key(settings));
        if (pending) state = requestedState;
        List<DeviceController.Control> controls = state == null ? List.of() : state.controls();
        boolean on = state != null && state.status().startsWith("On");
        boolean available = pending || !controls.isEmpty() && controls.get(0).enabled();
        PanelDefinition panel = configured ? settings.devices().get(0).panel() : null;
        if (panel != null && panel.driving()) {
            content.addContent(DrivingTileLayout.content(getPackageName(),panel,settings.watchId(),state,ExerciseStopService.feedback(panel,settings.watchId())));
        } else if (panel != null && panel.exercise()) {
            VehicleFeedback feedback = ExerciseStopService.feedback(panel, settings.watchId());
            boolean waiting = feedback != null && feedback.pending();
            for (int i=0;i<2;i++) {
                String action = i == 0 ? "start_exercise" : "stop_exercise";
                boolean unconfirmed = feedback != null && feedback.unconfirmed(action);
                boolean selected = feedback != null && feedback.selected(action);
                ModifiersBuilders.Modifiers.Builder modifiers = new ModifiersBuilders.Modifiers.Builder();
                modifiers.setBackground(new ModifiersBuilders.Background.Builder().setColor(ColorBuilders.argb(CommandFeedback.background(unconfirmed, selected))).build());
                if (!waiting) modifiers.setClickable(ExerciseTileService.action(getPackageName(), panel, action, settings.watchId()));
                content.addContent(new LayoutElementBuilders.Box.Builder().setWidth(dp(160)).setHeight(dp(55))
                        .setModifiers(modifiers.build()).addContent(text(feedback != null ? feedback.label(action, i == 0 ? "Start exercise" : "Stop exercise") : i == 0 ? "Start exercise" : "Stop exercise", unconfirmed && !waiting ? 14 : 18, CommandFeedback.foreground(unconfirmed, selected), 3)).build());
            }
        } else if (panel != null) {
            String climate = state == null ? "?" : state.readings().getOrDefault("climate", "?");
            LayoutElementBuilders.Row.Builder top = new LayoutElementBuilders.Row.Builder();
            top.addContent(new LayoutElementBuilders.Box.Builder().setWidth(dp(78)).setHeight(dp(72))
                    .addContent(text(state == null ? "?%" : state.readings().getOrDefault("battery", "?") + "%", 32, WHITE)).build());
            top.addContent(new LayoutElementBuilders.Spacer.Builder().setWidth(dp(4)).build());
            top.addContent(climateButton(panel.climateLabel(), climate, available && !commandBusy));
            content.addContent(top.build());
            content.addContent(spacer(8));
            content.addContent(vehicleButton(panel.scriptLabel(), panel, "leave", 160, 56));
        } else {
        String power = !configured ? "SET UP" : fan && !available ? "UNKNOWN" : controls.isEmpty() ? "REFRESH" : !available ? "UNKNOWN" : fan ? on ? "ON" : "OFF" : controls.get(0).label();
        content.addContent(button(power, controls.isEmpty() ? "refresh" : controls.get(0).action(), 160, 60,
                configured && !commandBusy && (fan ? available : controls.isEmpty() || available), on, "Toggle power", available ? 30 : 22));
        content.addContent(spacer(8));
        if (fan) {
            int speed = sendingSpeed >= 1 ? sendingSpeed : speedSelection.displayed(confirmedSpeed(state));
            boolean enabled = controls.size() > 1 && controls.get(1).enabled() && !commandBusy && speed >= 0;
            LayoutElementBuilders.Row.Builder row = new LayoutElementBuilders.Row.Builder();
            row.addContent(button("−", "slower", 54, 58, enabled && speed > 1, false, "Slower", 34));
            row.addContent(new LayoutElementBuilders.Box.Builder().setWidth(dp(52)).setHeight(dp(58))
                    .addContent(text(state == null || !available || speed < 0 ? "?" : Integer.toString(speed), 40,
                            available && !commandBusy && !speedSelection.pending() ? WHITE : 0xFFB0B0B0)).build());
            row.addContent(button("+", "faster", 54, 58, enabled && speed < 6, false, "Faster", 34));
            content.addContent(row.build());
        } else content.addContent(text(state == null ? "State unknown" : state.status(), 20, pending ? CommandFeedback.GRAY : WHITE));
        }
        content.addContent(spacer(6));
        content.addContent(new LayoutElementBuilders.Box.Builder().setWidth(dp(150)).setHeight(dp(22))
                .setModifiers(new ModifiersBuilders.Modifiers.Builder().setClickable(configured ? click("refresh") : setupClick()).build())
                .addContent(text(speedSelection.pending() ? "Sending in 1 second" : commandBusy ? "" : configured ? fresh ? message : message.equals("Last known state") ? fan ? "Unknown · refresh" : "Last known · refresh" : message : "Open app to set up", 11, WHITE)).build());
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
        ConnectionSettings settings = new SecureSettings(this).load();
        PanelDefinition panel = settings == null ? null : settings.devices().get(0).panel();
        boolean vehicle = panel != null;
        VehicleFeedback feedback = vehicle ? ExerciseStopService.feedback(panel, settings.watchId()) : null;
        boolean waiting = feedback != null && feedback.pending();
        if (vehicle) enabled = !waiting;
        if (feedback != null) state = feedback.climateState(state);
        boolean on = state.equals("ON");
        boolean unconfirmed = !enabled || feedback != null && feedback.unconfirmed("climate");
        int color = CommandFeedback.foreground(unconfirmed, on);
        ModifiersBuilders.Modifiers.Builder modifiers = new ModifiersBuilders.Modifiers.Builder()
                .setBackground(new ModifiersBuilders.Background.Builder().setColor(ColorBuilders.argb(CommandFeedback.background(unconfirmed, on)))
                        .setCorner(new ModifiersBuilders.Corner.Builder().setRadius(dp(16)).build()).build())
                .setSemantics(new ModifiersBuilders.Semantics.Builder().setContentDescription(label + " " + state).build());
        if (enabled) modifiers.setClickable(vehicle ? ExerciseTileService.action(getPackageName(), panel, CommandFeedback.vehicleAction("climate", on), settings.watchId()) : click("climate"));
        return new LayoutElementBuilders.Box.Builder().setWidth(dp(78)).setHeight(dp(72)).setModifiers(modifiers.build())
                .addContent(new LayoutElementBuilders.Column.Builder().setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
                        .addContent(text(label, 12, color)).addContent(text(state, 24, color))
                        .addContent(text(feedback != null && !feedback.pending() && !feedback.confirmed() && feedback.appliesTo("climate") ? "Not confirmed" : "", 10, color)).build()).build();
    }

    private LayoutElementBuilders.Text text(String value, int size, int color) {
        return text(value, size, color, 1);
    }
    private LayoutElementBuilders.Text text(String value, int size, int color, int lines) {
        return new LayoutElementBuilders.Text.Builder().setText(value).setMaxLines(lines)
                .setFontStyle(new LayoutElementBuilders.FontStyle.Builder().setSize(sp(size))
                        .setColor(ColorBuilders.argb(color)).build()).build();
    }

    private LayoutElementBuilders.Box vehicleButton(String label, PanelDefinition panel, String action, int width, int height) {
        ConnectionSettings settings = new SecureSettings(this).load();
        VehicleFeedback feedback = ExerciseStopService.feedback(panel, settings.watchId());
        boolean waiting = feedback != null && feedback.pending();
        if (feedback != null) label = feedback.label(action, label);
        boolean unconfirmed = feedback != null && feedback.unconfirmed(action);
        boolean selected = feedback != null && feedback.selected(action);
        ModifiersBuilders.Modifiers.Builder modifiers = new ModifiersBuilders.Modifiers.Builder().setBackground(new ModifiersBuilders.Background.Builder()
                .setColor(ColorBuilders.argb(CommandFeedback.background(unconfirmed, selected))).setCorner(new ModifiersBuilders.Corner.Builder().setRadius(dp(16)).build()).build());
        if (!waiting) modifiers.setClickable(ExerciseTileService.action(getPackageName(), panel, action, settings.watchId()));
        return new LayoutElementBuilders.Box.Builder().setWidth(dp(width)).setHeight(dp(height))
                .setModifiers(modifiers.build()).addContent(text(label, 18, CommandFeedback.foreground(unconfirmed, selected), 2)).build();
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
                .setBackground(new ModifiersBuilders.Background.Builder().setColor(ColorBuilders.argb(!enabled ? 0xFF383838 : selected ? MINT : 0xFF24332F))
                        .setCorner(new ModifiersBuilders.Corner.Builder().setRadius(dp(16)).build()).build())
                .setSemantics(new ModifiersBuilders.Semantics.Builder().setContentDescription(description + (selected ? ", selected" : "")).build());
        if (enabled) modifiers.setClickable(click(action));
        else if (new SecureSettings(this).load() == null) modifiers.setClickable(setupClick());
        return new LayoutElementBuilders.Box.Builder().setWidth(dp(width)).setHeight(dp(height))
                .setModifiers(modifiers.build()).addContent(text(label, fontSize, enabled ? selected ? 0xFF001F16 : WHITE : 0xFFB0B0B0)).build();
    }

}
