package dev.fancontrol.wear;

import androidx.wear.tiles.EventBuilders;
import androidx.wear.tiles.RequestBuilders;
import androidx.wear.tiles.TileBuilders;
import androidx.wear.tiles.TileService;
import androidx.wear.protolayout.ResourceBuilders;
import com.google.common.util.concurrent.ListenableFuture;
import java.util.List;

/** Renderer bindings are temporary; visibility and commands belong to the app session. */
public final class FanTileService extends TileService {
    private TileSession session() { return TileSession.get(getApplicationContext()); }
    @Override protected ListenableFuture<TileBuilders.Tile> onTileRequest(RequestBuilders.TileRequest request) { return session().onTileRequest(request); }
    @Override protected ListenableFuture<ResourceBuilders.Resources> onTileResourcesRequest(RequestBuilders.ResourcesRequest request) { return session().onTileResourcesRequest(request); }
    @Override protected ListenableFuture<Void> onRecentInteractionEventsAsync(List<EventBuilders.TileInteractionEvent> events) { return session().onRecentInteractionEventsAsync(events); }
    @SuppressWarnings("deprecation")
    @Override protected void onTileEnterEvent(EventBuilders.TileEnterEvent event) { session().onTileEnterEvent(event); }
    @SuppressWarnings("deprecation")
    @Override protected void onTileLeaveEvent(EventBuilders.TileLeaveEvent event) { session().onTileLeaveEvent(event); }
    @Override protected void onTileRemoveEvent(EventBuilders.TileRemoveEvent event) { session().onTileRemoveEvent(event); }
}
