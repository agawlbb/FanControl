package dev.fancontrol.wear;

import java.io.IOException;
import okhttp3.OkHttpClient;
import org.json.JSONObject;

public final class HomeAssistantClient {
    private final ConnectionSettings settings;
    private final HomeAssistantTransport transport;

    public HomeAssistantClient(ConnectionSettings settings) {
        this.settings = settings;
        this.transport = new HomeAssistantTransport(settings);
    }

    HomeAssistantClient(ConnectionSettings settings, OkHttpClient http) {
        this.settings = settings;
        this.transport = new HomeAssistantTransport(settings, http);
    }

    public void cancel() {
        transport.cancel();
    }

    public FanState read() throws Exception {
        try { return FanState.parse(transport.readEntity(settings.entityId())); }
        catch (IOException error) {
            if ("Check device entity ID".equals(error.getMessage())) throw new IOException("Check fan entity ID");
            throw error;
        }
    }

    public FanState command(String action) throws Exception {
        // Re-read before toggling so a stale tile never inverts the wrong state.
        FanState current = read();
        if (!current.available()) throw new IOException("Fan unavailable");
        JSONObject data = new JSONObject().put("entity_id", settings.entityId());
        String service;
        if (action.equals("toggle")) service = current.on() ? "turn_off" : "turn_on";
        else if (action.matches("speed[1-6]")) {
            if (!current.speedSupported()) throw new IOException("Speed control unsupported");
            service = "set_percentage";
            data.put("percentage", FanState.percentageForSpeed(Integer.parseInt(action.substring(5))));
        } else throw new IllegalArgumentException("Unknown action");
        transport.callService("fan", service, data);
        return read();
    }
}
