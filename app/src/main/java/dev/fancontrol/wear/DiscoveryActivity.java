package dev.fancontrol.wear;

import android.app.Activity;
import android.net.ConnectivityManager;
import android.net.NetworkCapabilities;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.graphics.Color;
import android.widget.*;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.ArrayDeque;

/** Short, explicit setup scan. No discovery receiver or periodic background work. */
public final class DiscoveryActivity extends Activity {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final HashSet<String> addresses = new HashSet<>();
    private final ArrayDeque<NsdServiceInfo> pending = new ArrayDeque<>();
    private NsdManager nsd;
    private NsdManager.DiscoveryListener discovery;
    private WifiManager.MulticastLock multicast;
    private LinearLayout results;
    private TextView status;
    private int generation;
    private boolean resolving;
    private VisibleWifi wifi;
    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        ScrollView scroll = new ScrollView(this); scroll.setBackgroundColor(Color.BLACK);
        LinearLayout column = new LinearLayout(this); column.setOrientation(LinearLayout.VERTICAL); column.setPadding(24,24,24,24); scroll.addView(column);
        status = new TextView(this); status.setTextColor(Color.WHITE); status.setTextSize(14); column.addView(status);
        results = new LinearLayout(this); results.setOrientation(LinearLayout.VERTICAL); column.addView(results);
        Button scan = new Button(this); scan.setText("Search again"); column.addView(scan); scan.setOnClickListener(view -> startScan());
        setContentView(scroll); nsd = getSystemService(NsdManager.class);
    }
    @Override protected void onResume() { super.onResume(); startScan(); }
    @Override protected void onPause() { stopScan(); super.onPause(); }
    private void pair(String url) {
        try {
            String safe = ConnectionSettings.integrationAddress(url, false);
            startActivity(new android.content.Intent(this, PairingActivity.class).putExtra("ha_url", safe)
                    .putExtra(PairingActivity.REPLACE_CONNECTION, new SecureSettings(this).load() != null));
            finish(); // Successful setup must not leave a discovery/pairing screen atop the app task.
        } catch (Exception ignored) { status.setText("Use an HTTPS address or a local HTTP address, such as http://homeassistant.local:8123"); }
    }
    private void startScan() {
        stopScan(); addresses.clear(); pending.clear(); resolving = false; results.removeAllViews();
        status.setText("Connecting Wi-Fi…");
        wifi = new VisibleWifi(this);
        wifi.whenReady(this::scanConnected);
    }
    private void scanConnected() {
        ConnectivityManager connectivity = getSystemService(ConnectivityManager.class);
        boolean wifi = false;
        for (android.net.Network network : connectivity.getAllNetworks()) {
            NetworkCapabilities caps = connectivity.getNetworkCapabilities(network);
            if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) wifi = true;
        }
        if (!wifi) { status.setText("Connect your watch directly to home Wi-Fi, then search again. Check that your saved home Wi-Fi is in range."); return; }
        status.setText("Searching home Wi-Fi for 20 seconds…"); int ticket = ++generation;
        WifiManager manager = (WifiManager)getApplicationContext().getSystemService(WIFI_SERVICE);
        multicast = manager.createMulticastLock("fan-control-setup"); multicast.setReferenceCounted(false); multicast.acquire();
        discovery = new NsdManager.DiscoveryListener() {
            public void onDiscoveryStarted(String type) { }
            public void onDiscoveryStopped(String type) { }
            public void onStartDiscoveryFailed(String type, int error) { handler.post(() -> { if(ticket==generation) { stopScan(); status.setText("Discovery unavailable. Check home Wi-Fi and search again."); } }); }
            public void onStopDiscoveryFailed(String type, int error) { }
            public void onServiceLost(NsdServiceInfo service) { }
            public void onServiceFound(NsdServiceInfo service) { handler.post(() -> { if(ticket==generation && pending.size()<16) { pending.add(service); resolveNext(ticket); } }); }
        };
        try { nsd.discoverServices("_home-assistant._tcp.", NsdManager.PROTOCOL_DNS_SD, discovery); }
        catch (Exception ignored) { stopScan(); status.setText("Discovery unavailable. Check home Wi-Fi and search again."); return; }
        handler.postDelayed(() -> { if(ticket==generation) { stopScan(); status.setText(addresses.isEmpty() ? "No HA found. Check Wi-Fi or enter the address." : "Choose your Home Assistant."); } }, 20000);
    }
    @SuppressWarnings("deprecation")
    private void resolveNext(int ticket) {
        if(resolving || pending.isEmpty() || ticket!=generation) return; resolving=true;
        nsd.resolveService(pending.remove(), new NsdManager.ResolveListener() {
            public void onResolveFailed(NsdServiceInfo info, int error) { handler.post(() -> { if(ticket==generation) { resolving=false; resolveNext(ticket); } }); }
            public void onServiceResolved(NsdServiceInfo info) { handler.post(() -> {
                if(ticket!=generation) return; resolving=false;
                try {
                    byte[] advertised = info.getAttributes().get("internal_url");
                    String url = advertised == null ? "" : new String(advertised, StandardCharsets.UTF_8);
                    if(url.isBlank()) { String host=info.getHost().getHostAddress(); if(host.contains(":")) host="["+host+"]"; url="http://"+host+":"+info.getPort(); }
                    url=ConnectionSettings.integrationAddress(url,false);
                    if(addresses.add(url) && addresses.size()<=16) { String selected=url; Button button=new Button(DiscoveryActivity.this); button.setText(info.getServiceName()); results.addView(button); button.setOnClickListener(view -> pair(selected)); }
                } catch(Exception ignored) { }
                resolveNext(ticket);
            }); }
        });
    }
    private void stopScan() {
        generation++; handler.removeCallbacksAndMessages(null); pending.clear();
        if (wifi != null) wifi.close(); wifi = null;
        if(discovery!=null) { try { nsd.stopServiceDiscovery(discovery); } catch(Exception ignored) { } discovery=null; }
        if(multicast!=null && multicast.isHeld()) multicast.release(); multicast=null;
    }
}
