package dev.fancontrol.wear;

import java.net.URI;
import java.util.List;
import java.util.HashSet;
import org.json.JSONArray;
import org.json.JSONObject;

public record ConnectionSettings(String baseUrl, String token, String entityId, List<DeviceDefinition> devices) {
    public ConnectionSettings(String baseUrl, String token, String entityId) {
        this(baseUrl, token, entityId, List.of(new DeviceDefinition(entityId, "Fan Control")));
    }
    public ConnectionSettings {
        devices = List.copyOf(devices);
        if (devices.isEmpty() || devices.size() > 16 || !devices.get(0).entityId().equals(entityId))
            throw new IllegalArgumentException("The primary fan must be the first device");
        HashSet<String> identities = new HashSet<>();
        for (DeviceDefinition device : devices) if (!identities.add(device.entityId()))
            throw new IllegalArgumentException("Duplicate device entity ID");
    }
    @Override public String toString() { return "ConnectionSettings[redacted]"; }

    public ConnectionSettings forFan(DeviceDefinition device) {
        if (!device.domain().equals("fan")) throw new IllegalArgumentException("Expected a fan");
        return new ConnectionSettings(baseUrl, token, device.entityId());
    }

    /** Preserve additional pages when editing the existing connection locally. */
    public ConnectionSettings replacePrimary(ConnectionSettings replacement) {
        if (!baseUrl.equals(replacement.baseUrl())) return replacement;
        java.util.ArrayList<DeviceDefinition> next = new java.util.ArrayList<>();
        next.add(entityId.equals(replacement.entityId()) ? devices.get(0) : replacement.devices().get(0));
        for (int i = 1; i < devices.size(); i++) if (!devices.get(i).entityId().equals(replacement.entityId())) next.add(devices.get(i));
        return new ConnectionSettings(replacement.baseUrl(), replacement.token(), replacement.entityId(), next);
    }

    public JSONObject toJson() throws Exception {
        JSONArray ordered = new JSONArray();
        for (DeviceDefinition device : devices) ordered.put(new JSONObject().put("entity", device.entityId()).put("title", device.title()));
        return new JSONObject().put("url", baseUrl).put("token", token).put("entity", entityId).put("devices", ordered);
    }

    /** Existing single-fan storage and v1 website handoffs remain valid. */
    public static ConnectionSettings fromJson(JSONObject json) throws Exception {
        ConnectionSettings primary = validate(json.getString("url"), json.getString("token"), json.getString("entity"));
        if (!json.has("devices")) return primary;
        JSONArray array = json.getJSONArray("devices");
        java.util.ArrayList<DeviceDefinition> devices = new java.util.ArrayList<>();
        for (int i = 0; i < array.length(); i++) {
            JSONObject item = array.getJSONObject(i);
            devices.add(new DeviceDefinition(item.getString("entity"), item.getString("title")));
        }
        return new ConnectionSettings(primary.baseUrl(), primary.token(), primary.entityId(), devices);
    }
    public static ConnectionSettings validate(String url, String token, String entity) {
        url = url.trim().replaceAll("/+$", "");
        entity = entity.trim();
        token = token.trim();
        URI uri;
        try { uri = URI.create(url); } catch (Exception e) { throw new IllegalArgumentException("Enter a valid HTTPS address"); }
        if (!"https".equalsIgnoreCase(uri.getScheme()) || uri.getHost() == null
                || uri.getRawUserInfo() != null || uri.getRawQuery() != null || uri.getRawFragment() != null) {
            throw new IllegalArgumentException("Use HTTPS without a password, query, or fragment in the address");
        }
        if (token.isEmpty() || token.contains("\n") || token.contains("\r"))
            throw new IllegalArgumentException("Enter a Home Assistant access token");
        if (!entity.matches("fan\\.[a-z0-9_]+"))
            throw new IllegalArgumentException("Enter a fan entity ID (fan.…)");
        return new ConnectionSettings(url, token, entity);
    }
}
