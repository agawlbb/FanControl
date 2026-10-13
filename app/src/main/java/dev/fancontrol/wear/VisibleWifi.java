package dev.fancontrol.wear;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.os.Handler;
import android.os.Looper;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/** A short-lived Wi-Fi request owned by a visible screen or an explicit tile operation. */
final class VisibleWifi implements AutoCloseable {
    private static final Set<VisibleWifi> owners = new HashSet<>();
    private final ConnectivityManager manager;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final CountDownLatch ready = new CountDownLatch(1);
    private Network network;
    private boolean closed, registered;
    private Runnable continuation;
    private final Runnable timeout = this::continueOnce;
    private final ConnectivityManager.NetworkCallback callback = new ConnectivityManager.NetworkCallback() {
        @Override public void onAvailable(Network available) {
            synchronized (owners) {
                if (closed) return;
                network = available; manager.bindProcessToNetwork(available);
            }
            ready.countDown(); handler.post(VisibleWifi.this::continueOnce);
        }
        @Override public void onLost(Network lost) {
            synchronized (owners) {
                if (lost.equals(network)) { network = null; rebind(); }
            }
        }
        @Override public void onUnavailable() { ready.countDown(); handler.post(VisibleWifi.this::continueOnce); }
    };

    VisibleWifi(Context context) {
        manager = context.getSystemService(ConnectivityManager.class);
        synchronized (owners) {
            owners.add(this);
            try {
                manager.requestNetwork(new NetworkRequest.Builder()
                        .addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build(), callback, 10000);
                registered = true;
            } catch (RuntimeException ignored) { ready.countDown(); }
        }
    }

    // After ten seconds, allow the existing remote-address fallback over the default network.
    void whenReady(Runnable action) {
        continuation = action;
        if (ready.getCount() == 0) handler.post(timeout);
        else handler.postDelayed(timeout, 10000);
    }
    private void continueOnce() {
        if (closed || continuation == null) return;
        Runnable action = continuation; continuation = null; handler.removeCallbacks(timeout); action.run();
    }
    void await() throws InterruptedException { ready.await(10, TimeUnit.SECONDS); }
    private void rebind() {
        Network remaining = owners.stream().filter(owner -> !owner.closed && owner.network != null)
                .map(owner -> owner.network).findFirst().orElse(null);
        manager.bindProcessToNetwork(remaining);
    }
    @Override public void close() {
        synchronized (owners) {
            if (closed) return;
            closed = true; owners.remove(this); ready.countDown();
            handler.removeCallbacksAndMessages(null); continuation = null;
            if (registered) try { manager.unregisterNetworkCallback(callback); } catch (RuntimeException ignored) { }
            rebind();
        }
    }
}
