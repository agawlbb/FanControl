# Fan Control

A standalone Wear OS 3+ app with a Home Assistant fan tile. No phone companion is required.

The tile shows confirmed on/off state, highlights the current speed, offers one power toggle and six speed buttons, and refreshes when viewed or tapped. Black backgrounds and short, bounded HTTPS requests keep battery use low.

## Setup

1. Build and install the APK on a Wear OS watch (Android API 30 or newer).
2. Open **Fan Control** on the watch. Enter your Home Assistant HTTPS base address, a long-lived access token, and the fan entity ID. Save the connection.
3. Add **Fan Control** from the watch's tile picker. Swipe to the tile to fetch the state.

### Optional website pairing

Set `fancontrol.pairingUrl=https://pair.example.com/FanControl` in the ignored `local.properties` file before building to enable **Pair with website**. The endpoint is compiled into that APK but not committed to Git. The matching pairing website is a separate project using protocol v1.

The watch displays an eight-digit code and public-key fingerprint. Enter the code on the website, compare fingerprints, and provide the connection details there. The browser encrypts the settings to an ephemeral RSA key held only by this watch; decrypted settings are stored in Android Keystore-backed encrypted storage. Setup polls at five-second intervals only while its screen is foreground, for at most ten minutes. Leaving setup cancels the connection and discards the session; return to generate a new code. This setup-only polling never contacts Home Assistant. Successful receipt is acknowledged to delete the relay package; unacknowledged packages expire on the server.

Create a long-lived access token in your Home Assistant profile's security section. Prefer a dedicated, non-administrator account; treat the token as a password. The watch needs network access to the server. Use a trusted HTTPS certificate; HTTP and certificate bypasses are deliberately unsupported. A watch may use its existing Wi-Fi or phone network transport, but this app does not require a companion app.

Speeds 1–6 map to 16%, 33%, 50%, 66%, 83%, and 100%, matching Home Assistant's integer percentage convention for a six-speed fan. Selecting a speed uses `fan.set_percentage` (which normally turns on the fan). Power uses `fan.turn_on` or `fan.turn_off` after checking the server's current state. The fan must support percentage speed control; fans exposing only preset names need an adapter/template fan in Home Assistant. For fans with a different number of physical speeds, these buttons represent six percentage levels and may map to fewer physical speeds.

## Battery and state freshness

- No WebSocket subscriptions, polling loop, background jobs, alarms, push notifications, foreground service, or wake locks.
- Ordinary tile requests and resource requests render locally and do not contact Home Assistant. Opening/saving setup does not connect either.
- A view-entry event performs one state read. A tap performs a read, a command if applicable, and a confirming read. Each request has a 2.5-second total timeout; redirects and automatic retries are disabled. Connections are not retained in an idle pool.
- Leaving/removing the tile or destroying its service cancels outstanding work when Wear OS delivers the corresponding event. No further refresh is scheduled.
- Wear OS can batch/delay interaction events. The app ignores historical enter events older than two seconds and batches ending in leave. Consequently some watches may need a tap on the footer to refresh. The OS does not provide a strict real-time visibility guarantee; a bounded request already started may finish after the tile leaves view if the leave notification is delayed.
- State is a snapshot at view/tap time, not a live stream while the tile remains open. Tap the footer to check external changes. Cached/error states are labeled **Last:**; missing state is **State unknown**. Command results are never guessed. Hardware/integrations with delayed state reporting may need a second refresh.

## Privacy

No server addresses, access tokens, entity IDs, personal names, or local paths belong in this repository. Enter connection details only on the watch. All connection settings are AES-GCM encrypted with a non-exportable Android Keystore key. Android backups are disabled, setup screenshots are blocked, and network responses and credentials are not logged. **Forget connection** erases saved settings and the key. Uninstalling also removes app data; revoke the token in Home Assistant when no longer needed.

`local.properties`, build output, local tooling, environment files, and signing keys are ignored. Commit authors use a generic project identity. Debug APKs are for testing; use your own private signing key for releases and keep it outside Git. GitHub ownership/activity remain visible if the repository is made public later.

## Build and checks

Use Android Studio or JDK 17+ with Android SDK 36. Configure your local SDK through Android Studio or an ignored `local.properties` file.

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
```

On Windows use `gradlew.bat`. Output: `app/build/outputs/apk/debug/app-debug.apk`.

The GitHub workflow runs compilation, unit tests, and lint, and retains a debug APK for seven days. Unit tests cover speed conversion, unknown/unavailable state, safe settings validation, historical/duplicate events, REST authentication and service payloads, redirects, cancellation, and failed commands. Real watch layout, tile event delivery, Keystore behavior, and the actual fan should also be verified before relying on the app.

## References

- [Wear OS tile lifecycle](https://developer.android.com/reference/androidx/wear/tiles/TileService)
- [Home Assistant REST API](https://developers.home-assistant.io/docs/api/rest/)
- [Home Assistant fan services](https://www.home-assistant.io/integrations/fan/)
- [Home Assistant percentage conversion](https://github.com/home-assistant/core/blob/dev/homeassistant/util/percentage.py)
