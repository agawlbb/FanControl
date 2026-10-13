package dev.fancontrol.wear;

/** Opaque tile target binding: never redirect a stale tap to another watch/profile/device. */
final class TileTarget {
    static String key(ConnectionSettings settings) {
        if (settings == null) return "0".repeat(16);
        String identity = (settings.integration() ? settings.watchId() : settings.baseUrl()) + "\n" + settings.entityId();
        try { return IntegrationClient.hex(java.security.MessageDigest.getInstance("SHA-256").digest(identity.getBytes(java.nio.charset.StandardCharsets.UTF_8))).substring(0,16); }
        catch(Exception impossible) { throw new IllegalStateException(impossible); }
    }
    static String action(ConnectionSettings current, String action, String displayedTarget) {
        return current.integration() && !action.equals("refresh") && !key(current).equals(displayedTarget) ? "refresh" : action;
    }
}
