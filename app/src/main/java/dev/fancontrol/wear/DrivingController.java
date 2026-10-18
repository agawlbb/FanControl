package dev.fancontrol.wear;

import org.json.JSONObject;

final class DrivingController implements DeviceController {
    private final IntegrationClient client;
    private final PanelDefinition panel;
    private volatile boolean cancelled;
    DrivingController(ConnectionSettings settings,PanelDefinition panel) { this.panel=panel; client=new IntegrationClient(settings); }
    private JSONObject request(String command) throws Exception {
        JSONObject body=new JSONObject().put("action",command==null?"panel_state":"panel_command").put("panel_id",panel.id());
        if(command!=null) body.put("command",command).put("panel_config",panel.toJson());
        return client.request(body);
    }
    public Snapshot read() throws Exception { return DrivingState.snapshot(request(null)); }
    public Snapshot enter() throws Exception {
        try { request("wake"); } catch(Exception ignored) { }
        if(cancelled) throw new java.io.IOException("Cancelled");
        return read();
    }
    public Snapshot command(String action) { throw new IllegalStateException("Driving actions require bounded foreground delivery"); }
    public void cancel() { cancelled=true; client.cancel(); }
}
