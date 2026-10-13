package dev.fancontrol.wear;

import java.net.URI;

public record ConnectionSettings(String baseUrl, String token, String entityId) {
    @Override public String toString() { return "ConnectionSettings[redacted]"; }
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
