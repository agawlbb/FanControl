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

/** Shared bounded, cancellable REST transport for device-specific controllers. */
final class HomeAssistantTransport {
    private final ConnectionSettings settings;
    private final OkHttpClient http;
    private final IntegrationClient integration;
    private volatile Call active;
    private volatile boolean cancelled;

    HomeAssistantTransport(ConnectionSettings settings) {
        this(settings, new OkHttpClient.Builder().callTimeout(6000, TimeUnit.MILLISECONDS)
                .connectTimeout(2, TimeUnit.SECONDS).readTimeout(5, TimeUnit.SECONDS)
                .retryOnConnectionFailure(false).followRedirects(false).followSslRedirects(false)
                .connectionPool(new okhttp3.ConnectionPool(0, 1, TimeUnit.SECONDS)).build());
    }
    HomeAssistantTransport(ConnectionSettings settings, OkHttpClient http) { this.settings = settings; this.http = http; integration = settings.integration() ? new IntegrationClient(settings, http) : null; }
    void cancel() { cancelled = true; Call call = active; if (call != null) call.cancel(); if (integration != null) integration.cancel(); }
    String readEntity(String entity) throws Exception {
        new DeviceDefinition(entity, "Device");
        if (integration != null) return integration.request(new JSONObject().put("action", "state").put("entity", entity)).toString();
        return request("states/" + entity, null);
    }
    void callService(String domain, String service, JSONObject data) throws Exception {
        if (!domain.matches("[a-z_][a-z0-9_]*") || !service.matches("[a-z_][a-z0-9_]*"))
            throw new IllegalArgumentException("Invalid service");
        DeviceDefinition entity = new DeviceDefinition(data.getString("entity_id"), "Device");
        if (!entity.domain().equals(domain)) throw new IllegalArgumentException("Service domain must match the device");
        if (integration != null) {
            String action = service;
            if (service.equals("set_percentage")) {
                int percentage = data.getInt("percentage"); action = "";
                for (int speed = 1; speed <= 6; speed++) if (FanState.percentageForSpeed(speed) == percentage) action = "speed" + speed;
                if (action.isEmpty()) throw new IllegalArgumentException("Unsupported speed");
            } else if (domain.equals("script") || domain.equals("scene")) action = "activate";
            integration.request(new JSONObject().put("action", "command").put("entity", entity.entityId()).put("command", action)); return;
        }
        request("services/" + domain + "/" + service, data);
    }
    private String request(String path, JSONObject body) throws Exception {
        if (cancelled) throw new IOException("Cancelled");
        Request.Builder request = new Request.Builder().url(settings.baseUrl() + "/api/" + path)
                .header("Authorization", "Bearer " + settings.token());
        if (body != null) request.post(RequestBody.create(body.toString(), MediaType.get("application/json")));
        Call call = http.newCall(request.build()); active = call;
        if (cancelled) call.cancel();
        try (Response response = call.execute()) {
            if (!response.isSuccessful()) throw new IOException(switch (response.code()) {
                case 401, 403 -> "Check access token";
                case 404 -> "Check device entity ID";
                default -> "Home Assistant error";
            });
            if (response.body() == null) throw new IOException("Empty response");
            return response.body().string();
        } finally { active = null; }
    }
}
