package dev.fancontrol.wear;

import android.app.job.JobParameters;
import android.app.job.JobService;
import android.os.Handler;
import android.os.Looper;
import androidx.wear.tiles.TileService;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.TimeUnit;
import okhttp3.ConnectionPool;
import okhttp3.OkHttpClient;

public final class BackgroundConfigurationJob extends JobService {
    private static volatile BackgroundConfigurationCheck running;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final Handler handler = new Handler(Looper.getMainLooper());
    private BackgroundConfigurationCheck check;
    static void cancelActive() { BackgroundConfigurationCheck current = running; if (current != null) current.cancel(); }
    @Override public boolean onStartJob(JobParameters parameters) {
        SecureSettings settings = new SecureSettings(this);
        ConnectionSettings original = settings.load();
        if (original == null || !original.integration()) { BackgroundConfigurationScheduler.ensure(this, original); return false; }
        if (FanControlApplication.foreground()) return false;
        BackgroundConfigurationCheck task = new BackgroundConfigurationCheck(new BackgroundConfigurationCheck.Store() {
            public ConnectionSettings load() { return settings.load(); }
            public boolean replace(ConnectionSettings expected, ConnectionSettings updated) throws Exception {
                if (!settings.saveIfCurrent(expected, updated)) return false;
                if (!expected.devices().get(0).equals(updated.devices().get(0))) new StateCache(BackgroundConfigurationJob.this).clear();
                return true;
            }
            public boolean revoke(ConnectionSettings expected) throws Exception {
                if (!settings.clearIfCurrent(expected)) return false;
                new StateCache(BackgroundConfigurationJob.this).clear(); return true;
            }
        }, connection -> new IntegrationClient(connection, new OkHttpClient.Builder()
                .callTimeout(4, TimeUnit.SECONDS).connectTimeout(1, TimeUnit.SECONDS).readTimeout(3, TimeUnit.SECONDS)
                .retryOnConnectionFailure(false).followRedirects(false).followSslRedirects(false)
                .connectionPool(new ConnectionPool(0, 1, TimeUnit.SECONDS)).build()),
                FanControlApplication::foreground,
                () -> TileService.getUpdater(getApplicationContext()).requestUpdate(FanTileService.class));
        check = task; running = task;
        worker.execute(() -> {
            task.run();
            handler.post(() -> {
                if (check != task) return;
                check = null; if (running == task) running = null;
                jobFinished(parameters, false);
            });
        });
        return true;
    }
    @Override public boolean onStopJob(JobParameters parameters) {
        stop(); return false; // No immediate retry; the periodic job retains its next window.
    }
    private void stop() {
        BackgroundConfigurationCheck task = check; check = null;
        if (task != null) { task.cancel(); if (running == task) running = null; }
    }
    @Override public void onDestroy() { stop(); worker.shutdownNow(); handler.removeCallbacksAndMessages(null); super.onDestroy(); }
}
