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
    private final AtomicInteger generation = new AtomicInteger();
    private final InteractionGate gate = new InteractionGate();
    private volatile HomeAssistantClient active;
    private volatile String message = "Last known state";
    private volatile boolean fresh;
    private static final int MINT = 0xFF70E2C2;
    private static final int WHITE = 0xFFF4F7F6;

    @Override protected ListenableFuture<TileBuilders.Tile> onTileRequest(RequestBuilders.TileRequest request) {
        String click = request.getCurrentState().getLastClickableId();
        SharedPreferences handled = getSharedPreferences("actions", MODE_PRIVATE);
        // Click IDs are unique per layout. Wear may repeat a request containing the last click.
        if (click != null && click.matches("(toggle|speed[1-6]|refresh):[a-f0-9-]+")
                && !click.equals(handled.getString("last", ""))) {
            handled.edit().putString("last", click).commit();
            int ticket = startOperation();
            return worker.submit(() -> {
                fetch(click.substring(0, click.indexOf(':')), ticket);
                return tile();
            });
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
        if (decision == InteractionGate.Decision.LEAVE) stopOperation();
        if (decision == InteractionGate.Decision.REFRESH) return refreshOnView();
        return Futures.immediateVoidFuture();
    }

    @SuppressWarnings("deprecation")
    @Override protected void onTileEnterEvent(EventBuilders.TileEnterEvent event) { refreshOnView(); }

    @SuppressWarnings("deprecation")
    @Override protected void onTileLeaveEvent(EventBuilders.TileLeaveEvent event) { stopOperation(); }

    @Override protected void onTileRemoveEvent(EventBuilders.TileRemoveEvent event) { stopOperation(); }

    private int startOperation() {
        stopOperation();
        return generation.get();
    }

    private void stopOperation() {
        generation.incrementAndGet();
        HomeAssistantClient client = active;
        if (client != null) client.cancel();
        fresh = false;
    }

    private ListenableFuture<Void> refreshOnView() {
        int ticket = startOperation();
        return worker.submit(() -> {
            fetch("refresh", ticket);
            if (ticket == generation.get()) getUpdater(this).requestUpdate(FanTileService.class);
            return null;
        });
    }

    private void fetch(String action, int ticket) {
        if (ticket != generation.get()) return;
        ConnectionSettings settings = new SecureSettings(this).load();
        if (settings == null) { message = "Open app to set up"; return; }
        HomeAssistantClient client = new HomeAssistantClient(settings);
        active = client;
        try {
            if (ticket != generation.get()) { client.cancel(); return; }
            FanState state = action.equals("refresh") ? client.read() : client.command(action);
            if (ticket == generation.get()) {
                new StateCache(this).save(state);
                fresh = true;
                message = !state.available() ? "Fan unavailable" : state.speedSupported() ? "Tap to refresh" : "On/off only";
            }
        } catch (Exception error) {
            if (ticket == generation.get()) {
                fresh = false;
                // Whitelist safe messages; never display raw network errors, URLs, or response bodies.
                String text = error.getMessage();
                message = List.of("Check access token", "Check fan entity ID", "Fan unavailable",
                        "Speed control unsupported", "Home Assistant error").contains(text == null ? "" : text)
                        ? text : "Offline · tap to retry";
            }
        } finally { if (active == client) active = null; }
    }

    private TileBuilders.Tile tile() {
        FanState state = new StateCache(this).read();
        boolean configured = new SecureSettings(this).load() != null;
        LayoutElementBuilders.Column.Builder content = new LayoutElementBuilders.Column.Builder()
                .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER);
        content.addContent(text("Fan Control", 14, WHITE));
        content.addContent(spacer(2));
        content.addContent(text(state == null ? "State unknown" : (fresh ? "" : "Last: ") + state.label(), 13, MINT));
        content.addContent(spacer(4));
        content.addContent(button(configured ? state != null && state.on() ? "Turn off" : "Turn on" : "Set up",
                "toggle", 124, 32, configured, false, "Toggle fan power"));
        content.addContent(spacer(4));
        for (int row = 0; row < 2; row++) {
            LayoutElementBuilders.Row.Builder speeds = new LayoutElementBuilders.Row.Builder();
            for (int column = 0; column < 3; column++) {
                int speed = row * 3 + column + 1;
                if (column != 0) speeds.addContent(new LayoutElementBuilders.Spacer.Builder().setWidth(dp(4)).build());
                boolean supported = configured && (state == null || state.speedSupported());
                speeds.addContent(button(Integer.toString(speed), "speed" + speed, 44, 40,
                        supported, state != null && state.on() && state.speed() == speed, "Set fan speed " + speed));
            }
            content.addContent(speeds.build());
            if (row == 0) content.addContent(spacer(4));
        }
        content.addContent(spacer(4));
        content.addContent(new LayoutElementBuilders.Box.Builder().setWidth(dp(144)).setHeight(dp(22))
                .setModifiers(new ModifiersBuilders.Modifiers.Builder().setClickable(configured ? click("refresh") : setupClick())
                        .setSemantics(new ModifiersBuilders.Semantics.Builder().setContentDescription(configured ? "Refresh fan state" : "Open setup").build()).build())
                .addContent(text(configured ? message : "Open app to set up", 10, WHITE)).build());
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

    private LayoutElementBuilders.Text text(String value, int size, int color) {
        return new LayoutElementBuilders.Text.Builder().setText(value).setMaxLines(1)
                .setFontStyle(new LayoutElementBuilders.FontStyle.Builder().setSize(sp(size))
                        .setColor(ColorBuilders.argb(color)).build()).build();
    }

    private LayoutElementBuilders.Spacer spacer(int height) {
        return new LayoutElementBuilders.Spacer.Builder().setHeight(dp(height)).build();
    }

    private ModifiersBuilders.Clickable click(String action) {
        return new ModifiersBuilders.Clickable.Builder().setId(action + ":" + UUID.randomUUID())
                .setOnClick(new ActionBuilders.LoadAction.Builder().build()).build();
    }

    private ModifiersBuilders.Clickable setupClick() {
        return new ModifiersBuilders.Clickable.Builder().setId("setup").setOnClick(new ActionBuilders.LaunchAction.Builder()
                .setAndroidActivity(new ActionBuilders.AndroidActivity.Builder().setPackageName(getPackageName())
                        .setClassName(MainActivity.class.getName()).build()).build()).build();
    }

    private LayoutElementBuilders.Box button(String label, String action, int width, int height,
                                              boolean enabled, boolean selected, String description) {
        ModifiersBuilders.Modifiers.Builder modifiers = new ModifiersBuilders.Modifiers.Builder()
                .setBackground(new ModifiersBuilders.Background.Builder().setColor(ColorBuilders.argb(selected ? MINT : 0xFF24332F))
                        .setCorner(new ModifiersBuilders.Corner.Builder().setRadius(dp(16)).build()).build())
                .setSemantics(new ModifiersBuilders.Semantics.Builder().setContentDescription(description + (selected ? ", selected" : "")).build());
        if (enabled) modifiers.setClickable(click(action));
        else if (new SecureSettings(this).load() == null) modifiers.setClickable(setupClick());
        return new LayoutElementBuilders.Box.Builder().setWidth(dp(width)).setHeight(dp(height))
                .setModifiers(modifiers.build()).addContent(text(label, 16, selected ? 0xFF001F16 : enabled ? WHITE : 0xFF87918D)).build();
    }

    @Override public void onDestroy() {
        stopOperation();
        worker.shutdownNow();
        super.onDestroy();
    }
}
