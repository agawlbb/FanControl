package dev.fancontrol.wear;

import java.net.URI;
import java.util.List;
import java.util.HashSet;
import org.json.JSONArray;
import org.json.JSONObject;

public record ConnectionSettings(String baseUrl, String token, String entityId, List<DeviceDefinition> devices, String remoteUrl, String watchId) {
    public ConnectionSettings(String baseUrl, String token, String entityId, List<DeviceDefinition> devices) {
        this(baseUrl, token, entityId, devices, "", "");
    }
    public ConnectionSettings(String baseUrl, String token, String entityId) {
        this(baseUrl, token, entityId, List.of(new DeviceDefinition(entityId, "Fan Control")));
    }
    public ConnectionSettings {
        devices = List.copyOf(devices);
        if (devices.isEmpty() || devices.size() > 16 || !devices.get(0).entityId().equals(entityId))
            throw new IllegalArgumentException("The active device must be the first device");
        HashSet<String> identities = new HashSet<>();
        for (DeviceDefinition device : devices) if (!identities.add(device.entityId()))
            throw new IllegalArgumentException("Duplicate device entity ID");
        if (!watchId.isEmpty()) {
            if (!watchId.matches("[a-f0-9]{32}") || !token.matches("[a-f0-9]{64}")) throw new IllegalArgumentException("Invalid watch credential");
            baseUrl = integrationAddress(baseUrl, false);
            if (!remoteUrl.isEmpty()) remoteUrl = integrationAddress(remoteUrl, true);
        }
    }
    @Override public String toString() { return "ConnectionSettings[redacted]"; }

    public ConnectionSettings forFan(DeviceDefinition device) {
        if (!device.domain().equals("fan")) throw new IllegalArgumentException("Expected a fan");
        return new ConnectionSettings(baseUrl, token, device.entityId(), List.of(device), remoteUrl, watchId);
    }

    public boolean integration() { return !watchId.isEmpty(); }

    public static String integrationAddress(String value, boolean external) {
        String url = value.trim().replaceAll("/+$", "");
        URI uri = URI.create(url);
        if (uri.getHost() == null || uri.getRawUserInfo() != null || uri.getRawQuery() != null || uri.getRawFragment() != null)
            throw new IllegalArgumentException("Invalid Home Assistant address");
        if ("https".equalsIgnoreCase(uri.getScheme())) return url;
        String host = uri.getHost().toLowerCase(java.util.Locale.ROOT);
        if (!external && "http".equalsIgnoreCase(uri.getScheme()) && localHost(host)) return url;
        throw new IllegalArgumentException("Use HTTPS or a local network HTTP address");
    }
    private static boolean localHost(String host) {
        if (host.endsWith(".local") || host.equals("localhost") || host.equals("[::1]")) return true;
        if (host.startsWith("[fc") || host.startsWith("[fd") || host.startsWith("[fe80:")) return true;
        if (!host.matches("[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+")) return false;
        String[] parts = host.split("\\."); int[] n = new int[4];
        for (int i = 0; i < 4; i++) { try { n[i] = Integer.parseInt(parts[i]); } catch (Exception error) { return false; } if (n[i] > 255) return false; }
        return n[0] == 10 || n[0] == 127 || n[0] == 192 && n[1] == 168 || n[0] == 172 && n[1] >= 16 && n[1] <= 31 || n[0] == 169 && n[1] == 254;
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
        for (DeviceDefinition device : devices) {
            JSONObject item = new JSONObject().put("entity", device.entityId()).put("title", device.title());
            if (device.panel() != null) item.put("panel", device.panel().toJson());
            ordered.put(item);
        }
        return new JSONObject().put("url", baseUrl).put("token", token).put("entity", entityId).put("devices", ordered)
                .put("remote_url", remoteUrl).put("watch_id", watchId).put("integration", integration());
    }

    /** Existing single-fan encrypted storage remains readable. */
    public static ConnectionSettings fromJson(JSONObject json) throws Exception {
        boolean integration = json.optBoolean("integration", false);
        if (integration && (!json.getString("watch_id").matches("[a-f0-9]{32}") || !json.getString("token").matches("[a-f0-9]{64}")))
            throw new IllegalArgumentException("Invalid watch credential");
        ConnectionSettings primary = integration ? new ConnectionSettings(json.getString("url"), json.getString("token"), json.getString("entity"),
                List.of(new DeviceDefinition(json.getString("entity"), "Device")), json.optString("remote_url", ""), json.getString("watch_id"))
                : validate(json.getString("url"), json.getString("token"), json.getString("entity"));
        if (!json.has("devices")) return primary;
        JSONArray array = json.getJSONArray("devices");
        java.util.ArrayList<DeviceDefinition> devices = new java.util.ArrayList<>();
        for (int i = 0; i < array.length(); i++) {
            JSONObject item = array.getJSONObject(i);
            devices.add(new DeviceDefinition(item.getString("entity"), item.getString("title"), item.has("panel") ? PanelDefinition.fromJson(item.getJSONObject("panel")) : null));
        }
        if (integration) {
            // HA stores swipe order separately from the active tile selection.
            DeviceDefinition chosen = devices.stream().filter(device -> device.entityId().equals(primary.entityId())).findFirst()
                    .orElseThrow(() -> new IllegalArgumentException("Active device not approved"));
            devices.remove(chosen); devices.add(0, chosen);
        }
        return new ConnectionSettings(primary.baseUrl(), primary.token(), primary.entityId(), devices, primary.remoteUrl(), primary.watchId());
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
