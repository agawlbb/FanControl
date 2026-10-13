package dev.fancontrol.wear;

import java.io.IOException;
import java.util.concurrent.TimeUnit;
import okhttp3.Call;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import org.json.JSONObject;

public final class HomeAssistantClient {
    private final ConnectionSettings settings;
    private final OkHttpClient http;
    private volatile Call active;
    private volatile boolean cancelled;

    public HomeAssistantClient(ConnectionSettings settings) {
        this(settings, new OkHttpClient.Builder().callTimeout(2500, TimeUnit.MILLISECONDS)
                .connectTimeout(2, TimeUnit.SECONDS).readTimeout(2, TimeUnit.SECONDS)
                .retryOnConnectionFailure(false).followRedirects(false).followSslRedirects(false)
                .connectionPool(new okhttp3.ConnectionPool(0, 1, TimeUnit.SECONDS)).build());
    }

    HomeAssistantClient(ConnectionSettings settings, OkHttpClient http) {
        this.settings = settings;
        this.http = http;
    }

    public void cancel() {
        cancelled = true;
        Call call = active;
        if (call != null) call.cancel();
    }

    private String request(String path, JSONObject body) throws Exception {
        if (cancelled) throw new IOException("Cancelled");
        Request.Builder request = new Request.Builder().url(settings.baseUrl() + "/api/" + path)
                .header("Authorization", "Bearer " + settings.token());
        if (body != null) request.post(RequestBody.create(body.toString(), MediaType.get("application/json")));
        Call call = http.newCall(request.build());
        active = call;
        if (cancelled) call.cancel();
        try (Response response = call.execute()) {
            if (!response.isSuccessful()) {
                String message = switch (response.code()) {
                    case 401, 403 -> "Check access token";
                    case 404 -> "Check fan entity ID";
                    default -> "Home Assistant error";
                };
                throw new IOException(message);
            }
            if (response.body() == null) throw new IOException("Empty response");
            return response.body().string();
        } finally { active = null; }
    }

    public FanState read() throws Exception {
        return FanState.parse(request("states/" + settings.entityId(), null));
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
        request("services/fan/" + service, data);
        return read();
    }
}
