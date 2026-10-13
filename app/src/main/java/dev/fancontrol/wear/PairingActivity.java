package dev.fancontrol.wear;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import androidx.wear.tiles.TileService;

/** Polls only while foreground setup is visible; stops on pause, completion, or expiry. */
public final class PairingActivity extends Activity {
    static final String REPLACE_CONNECTION = "replace_connection";
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private volatile PairingClient client;
    private volatile KeyPair keys;
    private PairingClient.Session session;
    private TextView code, status;
    private boolean visible, completed;
    private volatile int generation;
    private PairingProgress progress;
    private VisibleWifi wifi;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        ConnectionSettings existing = new SecureSettings(this).load();
        String baseline = state != null ? state.getString("original_connection", "")
                : getIntent().getBooleanExtra(REPLACE_CONNECTION, false) ? PairingProgress.key(existing) : "";
        progress = new PairingProgress(baseline);
        completed = state != null && state.getBoolean("connected", false);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(android.graphics.Color.BLACK);
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL); content.setGravity(Gravity.TOP | Gravity.CENTER_HORIZONTAL);
        float density = getResources().getDisplayMetrics().density;
        int side = Math.round(32 * density), edge = Math.round(40 * density);
        content.setPadding(side, edge, side, edge); scroll.addView(content);
        label(content, "Pair your watch", 18);
        code = label(content, "Starting…", 25);
        status = label(content, "", 12);
        Button close = new Button(this); close.setText("Close"); content.addView(close);
        close.setOnClickListener(view -> finish()); setContentView(scroll);
    }

    @Override protected void onResume() {
        super.onResume(); visible = true;
        if (progress.hasConnected(new SecureSettings(this).load(), completed)) { openControls(); return; }
        completed = false;
        // Foreground setup only; clear on completion, error, expiry, or pause.
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        session = null;
        int ticket = ++generation;
        code.setText("Starting…"); status.setText("Connecting Wi-Fi…");
        wifi = new VisibleWifi(this);
        VisibleWifi connection = wifi;
        worker.execute(() -> {
            try {
                connection.await();
                if (ticket != generation) return;
                KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA"); generator.initialize(2048);
                KeyPair pair = generator.generateKeyPair();
                if (ticket != generation) return;
                String local = getIntent().getStringExtra("ha_url");
                String baseUrl = ConnectionSettings.integrationAddress(local, false);
                PairingClient transport = new PairingClient(baseUrl);
                client = transport;
                if (ticket != generation) { transport.cancel(); return; }
                PairingClient.Session created = transport.create(pair);
                handler.post(() -> {
                    if (!visible || ticket != generation) { transport.cancel(); return; }
                    keys = pair; session = created;
                    code.setText(created.code().substring(0, 4) + " " + created.code().substring(4));
                    String fingerprint = created.fingerprint();
                    status.setText("In Home Assistant, open Settings → Devices & services → Fan Control → Configure → Pair a watch." + "\n\nFingerprint:\n"
                            + fingerprint.substring(0, 4) + " " + fingerprint.substring(4, 8) + " " + fingerprint.substring(8)
                            + "\n\nKeep this screen open. Code expires in 10 minutes.");
                    handler.postDelayed(() -> poll(ticket, transport, pair, created), 5000);
                });
            } catch (Exception ignored) { showError(ticket, "Could not start pairing. Check your connection and reopen this screen."); }
        });
    }

    private void poll(int ticket, PairingClient transport, KeyPair pair, PairingClient.Session pairing) {
        if (!visible || ticket != generation || completed) return;
        if (System.currentTimeMillis() / 1000 >= pairing.expiresAt()) {
            showError(ticket, "Code expired. Reopen pairing for a new code."); transport.cancel(); return;
        }
        worker.execute(() -> {
            try {
                org.json.JSONObject envelope = transport.poll(pairing);
                if (envelope == null) {
                    handler.post(() -> { if (visible && ticket == generation) handler.postDelayed(() -> poll(ticket, transport, pair, pairing), 5000); });
                    return;
                }
                ConnectionSettings settings = PairingClient.decrypt(envelope, pairing.code(), pair);
                handler.post(() -> {
                    if (!visible || ticket != generation) return;
                    // Saving is on the visible screen's thread to avoid a pause/save race.
                    try {
                        SecureSettings storage = new SecureSettings(this);
                        storage.save(settings);
                        if (!settings.equals(storage.load())) throw new IllegalStateException("Settings verification failed");
                        new StateCache(this).clear();
                        completed = true; keys = null; session = null;
                        code.setText("Connected"); status.setText("Add the Fan Control tile. View it to check your fan.");
                        TileService.getUpdater(this).requestUpdate(FanTileService.class);
                        worker.execute(() -> {
                            try { transport.acknowledge(pairing); } catch (Exception ignored) { }
                            finally {
                                transport.cancel();
                                handler.post(() -> { if (visible && ticket == generation && completed) openControls(); });
                            }
                        });
                    } catch (Exception ignored) { showError(ticket, "Could not save settings. Start pairing again."); }
                });
            } catch (Exception ignored) { showError(ticket, "Pairing stopped. Reopen this screen to try again."); transport.cancel(); }
        });
    }

    private void showError(int ticket, String message) {
        handler.post(() -> { if (visible && ticket == generation) { getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON); if (wifi != null) wifi.close(); code.setText("Try again"); status.setText(message); } });
    }

    private void openControls() {
        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        startActivity(new android.content.Intent(this, ControlsActivity.class).addFlags(android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP));
        finish();
    }

    @Override protected void onSaveInstanceState(Bundle state) {
        state.putString("original_connection", progress.originalKey()); state.putBoolean("connected", completed);
        super.onSaveInstanceState(state);
    }

    @Override protected void onPause() {
        visible = false; generation++; handler.removeCallbacksAndMessages(null);
        if (wifi != null) wifi.close(); wifi = null;
        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        PairingClient transport = client; if (transport != null) transport.cancel();
        client = null; keys = null; session = null;
        super.onPause();
    }
    @Override protected void onDestroy() { worker.shutdownNow(); super.onDestroy(); }
    private TextView label(LinearLayout parent, String value, int size) {
        TextView text = new TextView(this); text.setText(value); text.setTextSize(size);
        text.setTextColor(android.graphics.Color.WHITE); text.setGravity(Gravity.CENTER);
        text.setPadding(0, 5, 0, 8); parent.addView(text); return text;
    }
}
