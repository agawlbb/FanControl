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
import java.net.URI;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import androidx.wear.tiles.TileService;

/** Polls only while foreground setup is visible; stops on pause, completion, or expiry. */
public final class PairingActivity extends Activity {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private volatile PairingClient client;
    private volatile KeyPair keys;
    private PairingClient.Session session;
    private TextView code, status;
    private boolean visible, completed;
    private volatile int generation;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(android.graphics.Color.BLACK);
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL); content.setGravity(Gravity.CENTER);
        int padding = Math.round(22 * getResources().getDisplayMetrics().density);
        content.setPadding(padding, padding, padding, padding); scroll.addView(content);
        label(content, "Pair your watch", 18);
        code = label(content, "Starting…", 25);
        status = label(content, "", 12);
        Button close = new Button(this); close.setText("Close"); content.addView(close);
        close.setOnClickListener(view -> finish()); setContentView(scroll);
    }

    @Override protected void onResume() {
        super.onResume(); visible = true;
        if (completed) return;
        session = null;
        int ticket = ++generation;
        code.setText("Starting…"); status.setText("Preparing secure pairing");
        worker.execute(() -> {
            try {
                KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA"); generator.initialize(2048);
                KeyPair pair = generator.generateKeyPair();
                if (ticket != generation) return;
                String local = getIntent().getStringExtra("ha_url");
                boolean integration = local != null;
                String baseUrl = integration ? local : BuildConfig.PAIRING_BASE_URL;
                PairingClient transport = new PairingClient(baseUrl, integration);
                client = transport;
                if (ticket != generation) { transport.cancel(); return; }
                PairingClient.Session created = transport.create(pair);
                handler.post(() -> {
                    if (!visible || ticket != generation) { transport.cancel(); return; }
                    keys = pair; session = created;
                    code.setText(created.code().substring(0, 4) + " " + created.code().substring(4));
                    URI url = URI.create(baseUrl);
                    String fingerprint = created.fingerprint();
                    status.setText((integration ? "In Home Assistant, open Settings → Devices & services → Fan Control → Configure → Pair a watch." : "Visit " + url.getHost() + url.getPath()) + "\n\nFingerprint:\n"
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
                        new SecureSettings(this).save(settings); new StateCache(this).clear();
                        completed = true; keys = null; session = null;
                        code.setText("Connected"); status.setText("Add the Fan Control tile. View it to check your fan.");
                        TileService.getUpdater(this).requestUpdate(FanTileService.class);
                        worker.execute(() -> { try { transport.acknowledge(pairing); } catch (Exception ignored) { } finally { transport.cancel(); } });
                    } catch (Exception ignored) { showError(ticket, "Could not save settings. Start pairing again."); }
                });
            } catch (Exception ignored) { showError(ticket, "Pairing stopped. Reopen this screen to try again."); transport.cancel(); }
        });
    }

    private void showError(int ticket, String message) {
        handler.post(() -> { if (visible && ticket == generation) { code.setText("Try again"); status.setText(message); } });
    }

    @Override protected void onPause() {
        visible = false; generation++; handler.removeCallbacksAndMessages(null);
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
