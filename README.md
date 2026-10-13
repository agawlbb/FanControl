# Fan Control

A standalone Wear OS 3+ app for Home Assistant controls. Pair locally through the [Fan Control HA integration](https://github.com/agawlbb/FanControlHA), without typing a password or access token on the watch. No phone companion or hosted website is required for integration pairing.

## Setup with Home Assistant

1. Install the custom HA integration, restart HA, and add **Fan Control** from **Settings → Devices & services**.
2. Install this app on your watch and connect it directly to home Wi-Fi. Choose **Find Home Assistant**, then select your discovered instance. Manual address entry is available when discovery is blocked.
3. Keep the watch pairing screen visible. On a phone or computer, open **Fan Control → Configure → Pair a watch** in HA and enter the eight-digit code.
4. Compare every fingerprint character, approve the match, and choose the watch's devices, active tile device, and local/remote addresses. Remote addresses must be working HTTPS endpoints; the integration suggests HA's external or Home Assistant Cloud address when available.
5. Add the Fan Control tile. View it or tap Refresh to read your device's state.

HA's Configure screen manages devices, addresses and revocation. Each watch also has a **Tile device** select entity for changing the active device through HA or automations. Scripts/automations can use `fan_control.set_active_device`; its Watch ID appears on the watch setup screen. Changes arrive on the next visible refresh or controls opening, without waking an unseen watch.

Fans support power and six speeds, preserving **16%, 33%, 50%, 66%, 83%, 100%**. Lights, switches and input booleans support power; scenes and scripts have Run. Only explicitly approved devices and supported commands can be accessed. Other domains have no network control adapter.

Tap the tile's device title or **Open device controls** for vertical swipe pages. The active tile device is the first page; other devices follow. Native tiles use the system's horizontal carousel, so vertical paging lives in the full-screen controls activity. Neighbouring pages render without connecting; only a visible settled page reads state. Starting a swipe or leaving cancels previous work.

## Connections and battery

- Local discovery uses HA's `_home-assistant._tcp.` mDNS advertisement during a bounded 20-second setup scan. The watch needs direct Wi-Fi access and a network allowing discovery traffic. Its multicast lock is released on timeout/pause.
- Pairing polls every five seconds while its screen is foreground, for up to ten minutes. Leaving cancels the session; return to generate another code.
- Ordinary tile/resources/prefetch requests render locally. Configuration/state reads occur on tile entry, explicit refresh/tap, or visible settled controls pages.
- No periodic updates, WebSocket subscriptions, background jobs, alarms, push notifications, foreground service, or idle connection pool.
- Integration reads try the local address, then HTTPS remote access if the local connection fails. Commands use the endpoint established by a preceding read and are never automatically replayed after ambiguous failures.
- Requests have a 2.5-second timeout per endpoint; fallback can require two attempts. Leaving cancels outstanding calls when the platform delivers the event.
- Wear OS can delay/batch visibility events. Historical entries older than two seconds and batches ending in leave are ignored. Some watches may need Refresh. An already-started bounded request can finish before a delayed leave event arrives.
- State is a confirmed snapshot, not a live stream. Cached states show **Last:**. Stale button taps become refreshes if an automation changed the selected device, preventing the action being redirected to a new device.

Remote control needs internet access and remote access already enabled in HA. Changing every reachable HA address at once requires pairing again.

## Security and privacy

Integration pairing uses an ephemeral RSA-2048 key, OAEP-SHA256/MGF1-SHA256 and AES-256-GCM. Verify the fingerprint in the authenticated HA interface. The watch receives an independent revocable key, not an HA bearer token, limited to the integration's approved devices and commands.

Paired messages use AES-256-GCM with fresh IVs and authenticated watch ID, timestamp and nonce. The integration persists consumed nonces before commands and rejects replay. Watch clocks must be within 60 seconds of HA. Local HTTP is permitted only for integration mode on private addresses and `.local` names, with application-level encryption. Remote access requires HTTPS and normal certificate validation. Network observers can see host addresses, opaque watch IDs, message sizes and timing.

Saved addresses, credentials, names and entity IDs are encrypted using Android Keystore. Backups/transfers are disabled; setup screenshots are blocked. Credentials and responses are not logged. Tile caches hold generic states and control labels. **Forget connection** clears watch settings; revoke access in HA as well.

Repositories contain no personal addresses, installed entity IDs, tokens, signing keys or watch configuration. Test values are synthetic. Local configuration, output and tooling are ignored; commits use a generic identity. GitHub ownership/activity remain visible if repositories become public.

## Existing manual and website pairing

Existing saved fan connections and website protocol-v1 handoffs still work. Manual setup requires HTTPS, an HA access token and a `fan.…` entity. Prefer a dedicated non-administrator account for manual tokens. Standard fan service calls retain the original speed mappings; preset-only fans need an HA adapter.

Optional website pairing is enabled through `fancontrol.pairingUrl=https://pair.example.com/FanControl` in ignored `local.properties`, compiled into that APK only. The website encrypts settings to the ephemeral watch key. Its setup polling never contacts HA. This mode is not needed by integration pairing.

## Build and validation

Use Android Studio or JDK 17+ with Android SDK 36. Configure the local SDK through Android Studio or ignored `local.properties`.

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
```

On Windows use `gradlew.bat`. Output: `app/build/outputs/apk/debug/app-debug.apk`. CI retains debug APKs for seven days. Keep release signing keys outside Git.

Tests cover fan conversions, settings migration, encrypted traffic, tamper rejection, revoked access, endpoint fallback, command non-replay, cancellation, visible-page gating, REST payloads and tile events. Real-watch discovery, layout, platform timing, Keystore behavior and physical control still need a hardware check.

## References

- [HA discovery](https://developers.home-assistant.io/docs/api/instance_discovery/)
- [Tile lifecycle](https://developer.android.com/reference/androidx/wear/tiles/TileService)
- [Fan services](https://www.home-assistant.io/integrations/fan/)
- [Percentage conversion](https://github.com/home-assistant/core/blob/dev/homeassistant/util/percentage.py)
