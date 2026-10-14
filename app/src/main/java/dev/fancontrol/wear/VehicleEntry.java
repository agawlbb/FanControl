package dev.fancontrol.wear;

import java.io.IOException;
import java.util.function.BooleanSupplier;
import java.util.function.LongSupplier;

/** One wake dispatch, then bounded read-only checks. A cancelled entry never replays wake. */
final class VehicleEntry {
    interface Wake { void run() throws Exception; }
    interface Read { WorkMorningState run() throws Exception; }
    interface Sleep { void run(long milliseconds) throws Exception; }
    static WorkMorningState await(Wake wake, Read read, BooleanSupplier cancelled, LongSupplier clock, Sleep sleep) throws Exception {
        long deadline = clock.getAsLong() + 30_000;
        check(cancelled); wake.run();
        // Wake response is not readiness evidence; require a subsequent state read.
        for (int attempt = 0; attempt < 15 && clock.getAsLong() < deadline; attempt++) {
            check(cancelled);
            WorkMorningState state = read.run();
            check(cancelled);
            if (clock.getAsLong() >= deadline) break;
            if (state.ready()) return state;
            for (int tick = 0; tick < 20 && clock.getAsLong() < deadline; tick++) {
                check(cancelled); sleep.run(100);
            }
        }
        throw new IOException("Vehicle not ready");
    }
    private static void check(BooleanSupplier cancelled) throws IOException {
        if (cancelled.getAsBoolean()) throw new IOException("Cancelled");
    }
}
