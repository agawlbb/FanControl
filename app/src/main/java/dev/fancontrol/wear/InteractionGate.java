package dev.fancontrol.wear;

/** Batches are historical. Only a fresh final ENTER is a reason to connect. */
final class InteractionGate {
    enum Decision { IGNORE, LEAVE, REFRESH }
    private long lastTimestamp = Long.MIN_VALUE;
    Decision accept(long timestamp, boolean entered, long now) {
        if (timestamp <= lastTimestamp) return Decision.IGNORE;
        lastTimestamp = timestamp;
        if (!entered) return Decision.LEAVE;
        return now >= timestamp && now - timestamp <= 2000 ? Decision.REFRESH : Decision.IGNORE;
    }
}
