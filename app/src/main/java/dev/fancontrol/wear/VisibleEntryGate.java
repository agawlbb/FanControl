package dev.fancontrol.wear;

/** Tracks settled visible targets, independent of refresh/poll controller replacement. */
final class VisibleEntryGate {
    static String safeAction(String action, boolean vehicle, boolean ready) {
        return vehicle && !ready ? "refresh" : action;
    }
    static boolean tileMayConnect(boolean screenOn, boolean activityVisible) { return screenOn && !activityVisible; }
    private String target;
    synchronized boolean claim(String next) {
        if (next.equals(target)) return false;
        target = next; return true;
    }
    synchronized void leave() { target = null; }
}
