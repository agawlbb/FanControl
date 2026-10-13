package dev.fancontrol.wear;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import androidx.wear.tiles.TileService;

/** Local-only watch setup. Opening or saving this screen never contacts Home Assistant. */
public final class MainActivity extends Activity {
    private EditText url, token, entity;
    private TextView status;

    // Personal sideload app: a self-hosted server token is entered once, masked and encrypted.
    // No phone companion or public OAuth client registration is required.
    @android.annotation.SuppressLint("WearPasswordInput")
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(Color.BLACK);
        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        column.setGravity(Gravity.CENTER_HORIZONTAL);
        column.setPadding(dp(28), dp(30), dp(28), dp(36));
        scroll.addView(column);
        heading(column, "Fan Control", 21);
        if (!BuildConfig.PAIRING_BASE_URL.isBlank()) {
            Button pair = new Button(this);
            pair.setText("Pair with website");
            column.addView(pair);
            pair.setOnClickListener(view -> startActivity(new android.content.Intent(this, PairingActivity.class)));
        }
        heading(column, "Connect directly from your watch. Add the tile after saving.", 13);
        url = field(column, "Home Assistant HTTPS URL", "https://ha.example.com", InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_URI);
        entity = field(column, "Fan entity ID", "fan.example", InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        token = field(column, "Long-lived access token", "Access token", InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        token.setImportantForAutofill(android.view.View.IMPORTANT_FOR_AUTOFILL_NO);
        ConnectionSettings saved = new SecureSettings(this).load();
        if (saved != null) {
            url.setText(saved.baseUrl());
            entity.setText(saved.entityId());
            token.setHint("Saved · leave blank to keep");
        }
        Button save = new Button(this);
        save.setText("Save connection");
        column.addView(save);
        status = heading(column, "Settings stay encrypted on this watch. HTTPS is required. No background polling.", 12);
        save.setOnClickListener(view -> {
            try {
                SecureSettings storage = new SecureSettings(this);
                ConnectionSettings previous = storage.load();
                String secret = token.getText().toString();
                if (secret.isBlank() && previous != null) {
                    if (!url.getText().toString().trim().replaceAll("/+$", "").equals(previous.baseUrl()))
                        throw new IllegalArgumentException("Enter a token when changing the server");
                    secret = previous.token();
                }
                storage.save(ConnectionSettings.validate(url.getText().toString(), secret, entity.getText().toString()));
                new StateCache(this).clear();
                token.setText("");
                token.setHint("Saved · leave blank to keep");
                status.setText("Saved. View the Fan Control tile to connect.");
                TileService.getUpdater(this).requestUpdate(FanTileService.class);
            } catch (IllegalArgumentException error) { status.setText(error.getMessage()); }
            catch (Exception ignored) { status.setText("Could not save. Try again."); }
        });
        Button clear = new Button(this);
        clear.setText("Forget connection");
        column.addView(clear);
        clear.setOnClickListener(view -> {
            try {
                new SecureSettings(this).clear();
                new StateCache(this).clear();
                url.setText(""); entity.setText(""); token.setText(""); token.setHint("Access token");
                status.setText("Connection removed.");
                TileService.getUpdater(this).requestUpdate(FanTileService.class);
            } catch (Exception ignored) { status.setText("Could not clear. Try again."); }
        });
        setContentView(scroll);
    }

    private TextView heading(LinearLayout parent, String text, int size) {
        TextView label = new TextView(this);
        label.setText(text); label.setTextSize(size); label.setTextColor(Color.WHITE);
        label.setGravity(Gravity.CENTER); label.setPadding(0, dp(4), 0, dp(6));
        parent.addView(label);
        return label;
    }

    private EditText field(LinearLayout parent, String label, String hint, int type) {
        heading(parent, label, 13);
        EditText field = new EditText(this);
        field.setHint(hint); field.setTextColor(Color.WHITE); field.setHintTextColor(Color.LTGRAY);
        field.setTextSize(13); field.setInputType(type); field.setSingleLine(true);
        field.setContentDescription(label);
        parent.addView(field, new LinearLayout.LayoutParams(-1, dp(48)));
        return field;
    }
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }
}
