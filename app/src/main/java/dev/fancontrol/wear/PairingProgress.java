package dev.fancontrol.wear;

/** Persist only an opaque baseline so restored setup recognizes a completed connection. */
final class PairingProgress {
    private final String originalKey;
    PairingProgress(String originalKey) { this.originalKey = originalKey; }
    String originalKey() { return originalKey; }
    boolean hasConnected(ConnectionSettings current, boolean completed) {
        return current != null && (completed || !key(current).equals(originalKey));
    }
    static String key(ConnectionSettings settings) {
        if (settings == null) return "";
        String identity = settings.baseUrl() + "\n" + settings.watchId() + "\n" + settings.token();
        try { return IntegrationClient.hex(java.security.MessageDigest.getInstance("SHA-256").digest(identity.getBytes(java.nio.charset.StandardCharsets.UTF_8))); }
        catch (Exception impossible) { throw new IllegalStateException(impossible); }
    }
}
