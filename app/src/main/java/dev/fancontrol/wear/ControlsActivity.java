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

/** Full-screen controls for the device or panel selected in Home Assistant. */
public final class ControlsActivity extends Activity {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final Map<Integer, DeviceController.Snapshot> snapshots = new HashMap<>();
    private final Map<Integer, String> messages = new HashMap<>();
    private final Map<Integer, DeviceController.Snapshot> requested = new HashMap<>();
    private final Map<Integer, VehicleFeedback> feedbackAtRead = new HashMap<>();
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
    private VehicleFeedback lastVehicleFeedback;
    private final Runnable vehicleFeedbackPoll = new Runnable() {
        public void run() {
            if (!resumed) return;
            VehicleFeedback current = ExerciseStopService.feedback();
            if (current != lastVehicleFeedback) {
                boolean completed = lastVehicleFeedback != null && lastVehicleFeedback.pending() && current != null && !current.pending();
                lastVehicleFeedback = current;
                for (Page page : attached.values()) page.render();
                // Keep the confirmed/failed button result visible before a subsequent observed-state read.
                if (completed && session != null) handler.postDelayed(() -> {
                    if (resumed && ExerciseStopService.feedback() == current && requested.isEmpty() && loading == -1
                            && pager.getScrollState() == ViewPager2.SCROLL_STATE_IDLE
                            && current.matches(settings.devices().get(selected).panel(), settings.watchId())) session.refresh();
                }, 5000);
            }
            handler.postDelayed(this, 500);
        }
    };

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        settings = new SecureSettings(this).load();
        if (settings == null) {
            startActivity(new android.content.Intent(this, MainActivity.class)); finish(); return;
        }
        pager = new ViewPager2(this);
        pager.setBackgroundColor(Color.BLACK);
        pager.setUserInputEnabled(false);
        session = new VisibleDeviceSession(settings.devices(), device -> DeviceControllers.create(settings, device), worker,
                update -> handler.post(() -> {
                    if (!resumed || !session.accepts(update) || update.page() != selected || pager.getScrollState() != ViewPager2.SCROLL_STATE_IDLE) return;
                    // Never reuse a panel's prior readings after a new read starts or fails.
                    if (settings.devices().get(update.page()).panel() != null && settings.devices().get(update.page()).panel().vehicle() && update.snapshot() == null)
                        snapshots.remove(update.page());
                    if (update.snapshot() == null && update.error() == null) {
                        PanelDefinition panel = settings.devices().get(update.page()).panel();
                        feedbackAtRead.put(update.page(), panel == null ? null : ExerciseStopService.feedback(panel, settings.watchId()));
                        loading = update.page(); messages.put(update.page(), "");
                    } else {
                        loading = -1;
                        requested.remove(update.page());
                        if (update.snapshot() != null) {
                            snapshots.put(update.page(), update.snapshot());
                            ExerciseStopService.observed(feedbackAtRead.remove(update.page()));
                        }
                        else snapshots.remove(update.page());
                        messages.put(update.page(), update.error() == null ? "" : update.error());
                    }
                    Page page = attached.get(settings.devices().get(update.page()).entityId()); if (page != null) page.render();
                }));
        pager.setAdapter(new Pages());
        pager.registerOnPageChangeCallback(new ViewPager2.OnPageChangeCallback() {
            @Override public void onPageSelected(int position) {
                session.suspend(); selected=position; session.select(position);
                if(resumed && configurationReady && pager.getScrollState()==ViewPager2.SCROLL_STATE_IDLE) session.resume();
            }
            @Override public void onPageScrollStateChanged(int state) {
                if (state != ViewPager2.SCROLL_STATE_IDLE) {
                    // Neighbour page creation and gestures must not prefetch network state.
                    session.suspend(); loading = -1;
                    for (Integer page : requested.keySet()) snapshots.remove(page);
                    requested.clear(); clearVehicleSnapshots();
                } else if (resumed && configurationReady) session.resume();
            }
        });
        selected = 0;
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
        for (Page page : attached.values()) page.render(); // Stored approved roles can accept taps before HA replies.
        handler.post(vehicleFeedbackPoll);
        if (session != null && !settings.equals(new SecureSettings(this).load())) { session.suspend(); selected=0; recreate(); return; }
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
        resumed = false; for (Integer page : requested.keySet()) snapshots.remove(page); requested.clear(); clearVehicleSnapshots();
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
        @Override public int getItemCount() { return 1; }
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
            boolean pending = requested.containsKey(position);
            if (pending) snapshot = requested.get(position);
            VehicleFeedback vehicleFeedback = device.panel() == null ? null : ExerciseStopService.feedback(device.panel(), settings.watchId());
            boolean vehiclePending = vehicleFeedback != null && vehicleFeedback.pending();
            if (device.panel() != null && device.panel().driving()) {
            View identification=new View(ControlsActivity.this);
            identification.setBackgroundColor(PanelColor.display(device.panel()));
            LinearLayout.LayoutParams stripe=new LinearLayout.LayoutParams(dp(160),dp(8)); stripe.setMargins(0,0,0,dp(4)); root.addView(identification,stripe);
            }
            label(root, device.title()+" · "+(position+1)+" / "+settings.devices().size(), 12);
            String message = messages.getOrDefault(position, "");
            if (device.panel() != null && device.panel().driving()) {
                for (DrivingState.Control control : DrivingState.controls(snapshot,vehicleFeedback,true)) {
                    Button driving=button(control.label(),control.selected());
                    driving.setEnabled(control.enabled() && position==selected && resumed && pager.getScrollState()==ViewPager2.SCROLL_STATE_IDLE);
                    style(driving,control.selected(),driving.isEnabled(),control.unconfirmed());
                    driving.setContentDescription(control.label());
                    driving.setOnClickListener(v -> {
                        PanelCommands.start(ControlsActivity.this,device.panel(),control.action(),settings.watchId()); render();
                    });
                    root.addView(driving,new LinearLayout.LayoutParams(dp(160),dp(44)));
                }
                return;
            }
            if (device.panel() != null && device.panel().exercise()) {
                if (snapshot != null) label(root, snapshot.status(), 12);
                for (String action : java.util.List.of("start_exercise", "stop_exercise")) {
                    String label = action.equals("start_exercise") ? "Start exercise" : "Stop exercise";
                    Button exercise = button(vehicleFeedback == null ? label : vehicleFeedback.label(action, label), false);
                    exercise.setEnabled(!vehiclePending && position == selected && resumed && pager.getScrollState() == ViewPager2.SCROLL_STATE_IDLE);
                    boolean confirmed = vehicleFeedback != null && vehicleFeedback.selected(action);
                    style(exercise, confirmed, exercise.isEnabled(), vehicleFeedback != null && vehicleFeedback.unconfirmed(action));
                    exercise.setOnClickListener(v -> {
                        if (action.equals("start_exercise")) ExerciseActivity.open(ControlsActivity.this,device.panel().id(),action);
                        else PanelCommands.start(ControlsActivity.this, device.panel(), action, settings.watchId());
                        render();
                    });
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
                String climateText = snapshot == null ? "?" : snapshot.readings().getOrDefault("climate", "?");
                if (vehicleFeedback != null) climateText = vehicleFeedback.climateState(climateText);
                String climateLabel = device.panel().climateLabel() + "\n" + climateText;
                if (vehicleFeedback != null && vehicleFeedback.appliesTo("climate") && !vehicleFeedback.pending() && !vehicleFeedback.confirmed()) climateLabel += "\nNot confirmed";
                addButton(top, new DeviceController.Control("climate", climateLabel, climate.enabled(), climateText.equals("ON")), 78, 64);
                DeviceController.Control script = snapshot == null ? new DeviceController.Control("leave", "", false, false) : snapshot.controls().get(1);
                addButton(root, new DeviceController.Control("leave", vehicleFeedback != null ? vehicleFeedback.label("leave", device.panel().scriptLabel()) : pending && script.label().equals("REQUESTED") ? "REQUESTED" : device.panel().scriptLabel(), script.enabled(), vehicleFeedback != null && vehicleFeedback.selected("leave")), 160, 48);
                label(root, message, 12);
            } else {
                label(root, !message.isEmpty() ? message : snapshot == null ? "State unknown" : snapshot.status(), 12, pending);
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
            style(refresh, false, refresh.isEnabled());
            refresh.setOnClickListener(view -> { if (getBindingAdapterPosition() == selected) session.refresh(); });
            root.addView(refresh, new LinearLayout.LayoutParams(dp(120), dp(26)));

        }
        private void addButton(LinearLayout parent, DeviceController.Control control, int width, int height) {
            Button button = button(control.label(), control.selected());
            int position = getBindingAdapterPosition();
            boolean vehicle = device.panel() != null;
            VehicleFeedback feedback = vehicle ? ExerciseStopService.feedback(device.panel(), settings.watchId()) : null;
            button.setEnabled(position == selected && resumed && pager.getScrollState() == ViewPager2.SCROLL_STATE_IDLE
                    && !requested.containsKey(position) && !(feedback != null && feedback.pending()) && (vehicle || control.enabled() && loading != position));
            style(button, control.selected(), button.isEnabled(), feedback != null && feedback.unconfirmed(control.action()));
            button.setContentDescription(control.label() + (control.selected() ? ", selected" : ""));
            button.setOnClickListener(view -> {
                if (getBindingAdapterPosition() != selected) return;
                if (vehicle) {
                    PanelCommands.start(ControlsActivity.this, device.panel(), CommandFeedback.vehicleAction(control.action(), control.selected()), settings.watchId());
                    render();
                }
                else {
                    String action = CommandFeedback.action(snapshots.get(position), control.action());
                    DeviceController.Snapshot projection = CommandFeedback.requested(snapshots.get(position), action);
                    if (projection != null) requested.put(position, projection);
                    render(); session.command(action);
                }
            });
            LinearLayout.LayoutParams size = new LinearLayout.LayoutParams(dp(width), dp(height));
            size.setMargins(dp(2), dp(2), dp(2), dp(2)); parent.addView(button, size);
        }
    }

    private Button button(String label, boolean selected) {
        Button button = new Button(this); button.setText(label); button.setTextSize(13); button.setAllCaps(false);
        button.setMinHeight(0); button.setMinimumHeight(0); button.setMinWidth(0); button.setMinimumWidth(0); button.setPadding(0, 0, 0, 0);
        style(button, selected, true); return button;
    }
    private void style(Button button, boolean selected, boolean enabled) {
        style(button, selected, enabled, false);
    }
    private void style(Button button, boolean selected, boolean enabled, boolean unconfirmed) {
        button.setTextColor(CommandFeedback.foreground(unconfirmed || !enabled, selected));
        GradientDrawable background = new GradientDrawable(); background.setColor(CommandFeedback.background(unconfirmed || !enabled, selected));
        background.setCornerRadius(dp(14)); button.setBackground(background);
    }
    private void label(LinearLayout parent, String value, int size) {
        label(parent, value, size, false);
    }
    private void label(LinearLayout parent, String value, int size, boolean unconfirmed) {
        TextView text = new TextView(this); text.setText(value); text.setTextSize(size); text.setTextColor(unconfirmed ? CommandFeedback.GRAY : Color.WHITE);
        text.setGravity(Gravity.CENTER); text.setMaxLines(1); parent.addView(text);
    }
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }
}
