package dev.fancontrol.wear;

/** A visible-only draft; only its final absolute speed is sent after the quiet window. */
final class SpeedSelection {
    private int desired = -1;
    private long due;
    private String target = "";
    boolean pending() { return desired >= 1; }
    int displayed(int confirmed) { return pending() ? desired : confirmed; }
    String target() { return target; }
    boolean tap(int confirmed, int delta, String device, long now) {
        if (confirmed < 0 || confirmed > 6 || (delta != -1 && delta != 1)) return false;
        if (pending() && !target.equals(device)) clear();
        desired = Math.max(1, Math.min(6, displayed(confirmed) + delta));
        target = device; due = now + 3000;
        return true;
    }
    String take(long now) {
        if (!pending() || now < due) return null;
        String action = "speed" + desired; clear(); return action;
    }
    void clear() { desired = -1; due = 0; target = ""; }
}
