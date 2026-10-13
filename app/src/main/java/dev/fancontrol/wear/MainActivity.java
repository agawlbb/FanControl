package dev.fancontrol.wear;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Color;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import androidx.wear.tiles.TileService;

/** Home Assistant discovery is the only new-connection setup path. */
public final class MainActivity extends Activity {
    private TextView status;
    private Button openControls, forget;
    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        ScrollView scroll = new ScrollView(this); scroll.setBackgroundColor(Color.BLACK);
        LinearLayout column = new LinearLayout(this); column.setOrientation(LinearLayout.VERTICAL);
        column.setGravity(Gravity.CENTER_HORIZONTAL); column.setPadding(dp(30), dp(40), dp(30), dp(40)); scroll.addView(column);
        TextView title = new TextView(this); title.setText("Fan Control"); title.setTextSize(21); title.setTextColor(Color.WHITE); column.addView(title);
        Button discover = new Button(this); discover.setText("Find Home Assistant"); column.addView(discover);
        discover.setOnClickListener(view -> startActivity(new android.content.Intent(this, DiscoveryActivity.class)));
        openControls = new Button(this); openControls.setText("Open device controls"); column.addView(openControls);
        openControls.setOnClickListener(view -> startActivity(new android.content.Intent(this, ControlsActivity.class)));
        status = new TextView(this); status.setTextColor(Color.WHITE); status.setTextSize(13); status.setGravity(Gravity.CENTER); column.addView(status);
        forget = new Button(this); forget.setText("Forget connection"); column.addView(forget);
        forget.setOnClickListener(view -> {
            try {
                new SecureSettings(this).clear(); new StateCache(this).clear(); updateStatus();
                TileService.getUpdater(this).requestUpdate(FanTileService.class);
            } catch (Exception ignored) { status.setText("Could not clear. Try again."); }
        });
        setContentView(scroll);
    }
    @Override protected void onResume() { super.onResume(); updateStatus(); }
    private void updateStatus() {
        ConnectionSettings current = new SecureSettings(this).load();
        openControls.setVisibility(current == null ? View.GONE : View.VISIBLE);
        forget.setVisibility(current == null ? View.GONE : View.VISIBLE);
        status.setText(current == null ? "Find Home Assistant on your home Wi-Fi, then approve the code in HA." : current.integration()
                ? "Connected. Manage devices in Home Assistant. Watch ID:\n" + current.watchId() : "Existing connection saved. Find Home Assistant to switch to integration pairing.");
    }
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }
}
