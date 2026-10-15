package dev.fancontrol.wear;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import androidx.recyclerview.widget.RecyclerView;
import androidx.viewpager2.widget.ViewPager2;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Full-screen device controls. Vertical gestures belong here, outside the system tile carousel. */
public final class ControlsActivity extends Activity {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final Map<Integer, DeviceController.Snapshot> snapshots = new HashMap<>();
    private final Map<Integer, String> messages = new HashMap<>();
    private final Map<String, Page> attached = new HashMap<>();
    private ConnectionSettings settings;
    private VisibleDeviceSession session;
    private ViewPager2 pager;
    private boolean resumed;
    private int selected;
    private int loading = -1;
    private int configurationGeneration;
    private volatile IntegrationClient configuration;
    private boolean configurationReady;

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        settings = new SecureSettings(this).load();
        if (settings == null) {
            startActivity(new android.content.Intent(this, MainActivity.class)); finish(); return;
        }
        pager = new ViewPager2(this);
        pager.setBackgroundColor(Color.BLACK);
        pager.setOrientation(ViewPager2.ORIENTATION_VERTICAL);
        session = new VisibleDeviceSession(settings.devices(), device -> DeviceControllers.create(settings, device), worker,
                update -> handler.post(() -> {
                    if (!resumed || !session.accepts(update) || update.page() != selected || pager.getScrollState() != ViewPager2.SCROLL_STATE_IDLE) return;
                    // Never reuse a panel's prior readings after a new read starts or fails.
                    if (settings.devices().get(update.page()).panel() != null && settings.devices().get(update.page()).panel().vehicle() && update.snapshot() == null)
                        snapshots.remove(update.page());
                    if (update.snapshot() == null && update.error() == null) {
                        loading = update.page(); messages.put(update.page(), "Updating…");
                    } else {
                        loading = -1;
                        if (update.snapshot() != null) snapshots.put(update.page(), update.snapshot());
                        messages.put(update.page(), update.error() == null ? "" : update.error());
                    }
                    Page page = attached.get(settings.devices().get(update.page()).entityId()); if (page != null) page.render();
                }));
        pager.setAdapter(new Pages());
        pager.registerOnPageChangeCallback(new ViewPager2.OnPageChangeCallback() {
            @Override public void onPageSelected(int position) { selected = position; session.select(position); }
            @Override public void onPageScrollStateChanged(int state) {
                if (state != ViewPager2.SCROLL_STATE_IDLE) {
                    // Neighbour page creation and gestures must not prefetch network state.
                    session.suspend(); loading = -1; clearVehicleSnapshots();
                } else if (resumed && configurationReady) session.resume();
            }
        });
        selected = saved == null ? 0 : Math.min(Math.max(0, saved.getInt("selected", 0)), settings.devices().size() - 1);
        session.select(selected); pager.setCurrentItem(selected, false);
        setContentView(pager);
    }

    private void clearVehicleSnapshots() {
        for (int i = 0; settings != null && i < settings.devices().size(); i++) {
            PanelDefinition panel = settings.devices().get(i).panel();
            if (panel != null && panel.vehicle()) snapshots.remove(i);
        }
        for (Page page : attached.values()) page.render();
    }

    @Override protected void onResume() {
        super.onResume(); resumed = true;
        configurationReady = false;
        if (session != null && !settings.equals(new SecureSettings(this).load())) { session.suspend(); recreate(); return; }
        if (session != null && settings.integration()) {
            session.suspend();
            int ticket = ++configurationGeneration;
            IntegrationClient client = new IntegrationClient(settings); configuration = client;
            worker.execute(() -> {
                try {
                    ConnectionSettings updated = client.configuration();
                    handler.post(() -> {
                        if (!resumed || ticket != configurationGeneration) return;
                        try {
                            if (!settings.equals(updated)) {
                                if (!settings.devices().get(0).equals(updated.devices().get(0))) new StateCache(this).clear();
                                new SecureSettings(this).save(updated); selected = 0; recreate(); return;
                            }
                        } catch (Exception ignored) { }
                        configurationReady = true;
                        if (pager.getScrollState() == ViewPager2.SCROLL_STATE_IDLE) session.resume();
                    });
                } catch (Exception ignored) {
                    handler.post(() -> { if (resumed && ticket == configurationGeneration) { configurationReady = true; if (pager.getScrollState() == ViewPager2.SCROLL_STATE_IDLE) session.resume(); } });
                } finally { if(configuration == client) configuration = null; }
            });
        } else if (session != null) { configurationReady = true; if (pager.getScrollState() == ViewPager2.SCROLL_STATE_IDLE) session.resume(); }
    }
    @Override protected void onPause() {
        resumed = false; clearVehicleSnapshots();
        configurationGeneration++; IntegrationClient client = configuration; if(client != null) client.cancel(); configuration = null;
        if (session != null) session.suspend();
        handler.removeCallbacksAndMessages(null); loading = -1;
        super.onPause();
    }
    @Override protected void onDestroy() {
        if (session != null) session.suspend();
        worker.shutdownNow(); super.onDestroy();
    }
    @Override protected void onSaveInstanceState(Bundle state) { state.putInt("selected", selected); super.onSaveInstanceState(state); }

    private final class Pages extends RecyclerView.Adapter<Page> {
        @Override public Page onCreateViewHolder(ViewGroup parent, int type) {
            LinearLayout root = new LinearLayout(ControlsActivity.this);
            root.setLayoutParams(new RecyclerView.LayoutParams(-1, -1));
            root.setOrientation(LinearLayout.VERTICAL); root.setGravity(Gravity.CENTER);
            root.setPadding(dp(24), dp(8), dp(24), dp(8));
            return new Page(root);
        }
        @Override public void onBindViewHolder(Page page, int position) {
            if (page.device != null) attached.remove(page.device.entityId(), page);
            page.device = settings.devices().get(position); attached.put(page.device.entityId(), page); page.render();
            // Binding adjacent pages renders cached/unknown state only. No reads or commands here.
        }
        @Override public void onViewRecycled(Page page) {
            if (page.device != null) attached.remove(page.device.entityId(), page);
            page.device = null;
        }
        @Override public int getItemCount() { return settings.devices().size(); }
    }

    private final class Page extends RecyclerView.ViewHolder {
        private final LinearLayout root;
        private DeviceDefinition device;
        Page(LinearLayout root) { super(root); this.root = root; }
        void render() {
            int position = getBindingAdapterPosition();
            if (position == RecyclerView.NO_POSITION || device == null) return;
            root.removeAllViews();
            DeviceController.Snapshot snapshot = snapshots.get(position);
            if (device.panel() != null && device.panel().vehicle() && (!resumed || !configurationReady || loading == position
                    || pager.getScrollState() != ViewPager2.SCROLL_STATE_IDLE)) snapshot = null;
            label(root, device.title(), 14);
            String message = messages.getOrDefault(position, "");
            if (device.panel() != null && device.panel().exercise()) {
                label(root, snapshot == null ? "Updating" : snapshot.status(), 12);
                for (String action : java.util.List.of("start_exercise", "stop_exercise")) {
                    Button exercise = button(action.equals("start_exercise") ? "Start exercise" : "Stop exercise", false);
                    exercise.setEnabled(position == selected && (action.equals("stop_exercise") || snapshot != null && snapshot.controls().stream().anyMatch(c -> c.action().equals(action) && c.enabled()) && loading != position));
                    exercise.setOnClickListener(v -> ExerciseActivity.open(ControlsActivity.this, device.panel().id(), action));
                    root.addView(exercise, new LinearLayout.LayoutParams(dp(160), dp(48)));
                }
                return;
            }
            if (device.panel() != null) {
                LinearLayout top = new LinearLayout(ControlsActivity.this); top.setGravity(Gravity.CENTER); root.addView(top);
                TextView battery = new TextView(ControlsActivity.this); battery.setTextColor(Color.WHITE); battery.setTextSize(28); battery.setGravity(Gravity.CENTER);
                battery.setText(snapshot == null ? "?%" : snapshot.readings().getOrDefault("battery", "?") + "%");
                top.addView(battery, new LinearLayout.LayoutParams(dp(78), dp(64)));
                DeviceController.Control climate = snapshot == null ? new DeviceController.Control("climate", "", false, false) : snapshot.controls().get(0);
                addButton(top, new DeviceController.Control("climate", device.panel().climateLabel() + "\n" + (snapshot == null ? "?" : snapshot.readings().getOrDefault("climate", "?")), climate.enabled(), climate.selected()), 78, 64);
                DeviceController.Control script = snapshot == null ? new DeviceController.Control("leave", "", false, false) : snapshot.controls().get(1);
                addButton(root, new DeviceController.Control("leave", device.panel().scriptLabel(), script.enabled(), false), 160, 48);
                label(root, message, 12);
            } else {
                label(root, !message.isEmpty() ? message : snapshot == null ? "State unknown" : snapshot.status(), 12);
                if (snapshot != null) {
                    LinearLayout row = null;
                    for (int i = 0; i < snapshot.controls().size(); i++) {
                        DeviceController.Control control = snapshot.controls().get(i);
                        if (i == 0) addButton(root, control, 120, 30);
                        else {
                            if ((i - 1) % 3 == 0) { row = new LinearLayout(ControlsActivity.this); row.setGravity(Gravity.CENTER); root.addView(row); }
                            addButton(row, control, 40, 34);
                        }
                    }
                }
            }
            Button refresh = button("Refresh", false);
            refresh.setEnabled(position == selected && loading != position);
            refresh.setOnClickListener(view -> { if (getBindingAdapterPosition() == selected) session.refresh(); });
            root.addView(refresh, new LinearLayout.LayoutParams(dp(120), dp(26)));
            label(root, (position + 1) + " / " + settings.devices().size(), 10);
        }
        private void addButton(LinearLayout parent, DeviceController.Control control, int width, int height) {
            Button button = button(control.label(), control.selected());
            int position = getBindingAdapterPosition();
            button.setEnabled(control.enabled() && position == selected && loading != position);
            button.setContentDescription(control.label() + (control.selected() ? ", selected" : ""));
            button.setOnClickListener(view -> { if (getBindingAdapterPosition() == selected) session.command(control.action()); });
            LinearLayout.LayoutParams size = new LinearLayout.LayoutParams(dp(width), dp(height));
            size.setMargins(dp(2), dp(2), dp(2), dp(2)); parent.addView(button, size);
        }
    }

    private Button button(String label, boolean selected) {
        Button button = new Button(this); button.setText(label); button.setTextSize(13); button.setAllCaps(false);
        button.setMinHeight(0); button.setMinimumHeight(0); button.setMinWidth(0); button.setMinimumWidth(0); button.setPadding(0, 0, 0, 0);
        button.setTextColor(selected ? Color.BLACK : Color.WHITE);
        GradientDrawable background = new GradientDrawable(); background.setColor(selected ? 0xFF70E2C2 : 0xFF24332F);
        background.setCornerRadius(dp(14)); button.setBackground(background); return button;
    }
    private void label(LinearLayout parent, String value, int size) {
        TextView text = new TextView(this); text.setText(value); text.setTextSize(size); text.setTextColor(Color.WHITE);
        text.setGravity(Gravity.CENTER); text.setMaxLines(1); parent.addView(text);
    }
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }
}
