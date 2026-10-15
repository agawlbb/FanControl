package dev.fancontrol.wear;

/** Unforgeable, one-use foreground launch grants; external intents cannot operate a car. */
final class ExerciseLaunch {
    record Grant(PanelDefinition panel, String action, String watchId, long expires) { }
    private static final java.util.Map<String, Grant> grants = new java.util.HashMap<>();
    static synchronized String issue(PanelDefinition panel, String action, String watchId) {
        long now = android.os.SystemClock.elapsedRealtime();
        grants.values().removeIf(g -> g.expires() < now);
        if (grants.size() > 32) grants.clear();
        String token = java.util.UUID.randomUUID().toString();
        grants.put(token, new Grant(panel, action, watchId, now + 60_000));
        return token;
    }
    static synchronized Grant consume(String token) {
        Grant grant = grants.remove(token);
        return grant != null && grant.expires() >= android.os.SystemClock.elapsedRealtime() ? grant : null;
    }
}
