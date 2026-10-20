# Fan Control

> **Wear OS maintenance paused — October 20, 2026.** The Wear OS app is no longer actively maintained as of this date. Wear OS code changes and builds are paused unless explicitly requested by the maintainer. Existing Wear OS source and releases remain available, but updates and fixes should not be expected during the pause. This pause applies only to Wear OS; Apple Watch and the shared Home Assistant integration are outside its scope.

Licensed under GNU AGPL-3.0-only. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).

A standalone Wear OS 3+ app for Home Assistant controls. Pair locally through the [Fan Control HA integration](https://github.com/agawlbb/FanControlHA), without typing a password or access token on the watch. No phone companion or hosted website is required for integration pairing.

## Setup with Home Assistant

1. Install the custom HA integration, restart HA, and add **Fan Control** from **Settings → Devices & services**.
2. Install this app on your watch and save your home Wi-Fi network in the watch settings. Choose **Find Home Assistant**, then select your discovered instance. The app requests direct Wi-Fi during discovery and pairing, even when connected to a phone. Discovery requires both devices on the same LAN and mDNS traffic allowed.
3. Keep the watch pairing screen visible. On a phone or computer, open **Fan Control → Configure → Pair a watch** in HA and enter the eight-digit code.
4. Compare every fingerprint character, approve the match, and choose the watch's devices, active tile device, and local/remote addresses. Remote addresses must be working HTTPS endpoints; the integration suggests HA's external or Home Assistant Cloud address when available.
5. Add the Fan Control tile. View it or tap Refresh to read your device's state.

HA's Configure screen manages devices, addresses and revocation. Each watch also has a **Tile device** select entity for changing the active device through HA or automations. Scripts/automations can use `fan_control.set_active_device`; its Watch ID appears on the watch setup screen. Changes arrive on the next visible refresh or controls opening, and a periodic background configuration check can update the selected panel while the tile is unseen.

Fans support power and six speeds, preserving **16%, 33%, 50%, 66%, 83%, 100%**. Lights, switches and input booleans support power; scenes and scripts have Run. Only explicitly approved devices and supported commands can be accessed. Other domains have no network control adapter.

The fan tile has a large power toggle and **− / current speed / +** controls. Speed taps accumulate locally and send one absolute speed one second after the last tap; the displayed draft is labelled as pending. Leaving before the quiet window expires discards it. On opening, the fan tile shows gray UNKNOWN power and ? speed with controls disabled until a successful available fan response arrives. Failed or unavailable responses return the fan to this unknown state; saved fan state is never used as current tile state. Tap **More controls** or **Open device controls** to open the HA-selected device. The watch does not offer panel switching; leaving cancels previous work.

## Configurable watch panels

In **Settings → Devices & services → Fan Control → Configure → Manage watch panels**, choose a watch and **Add Work Morning panel**. Select a battery percentage sensor, a climate power entity (or switch/input boolean), and a script using HA entity pickers. Panel names and button labels are editable; no personal entity IDs are compiled into the watch. Battery sensors must use `%`; climate entities must support HA power on/off. Missing sensor values show `?%`, unavailable climate controls are disabled, and running scripts cannot be started again from the panel.

The Work Morning layout places battery percentage on the left and the climate toggle on the right of its top row, with a full-width script button in the bottom row. A script response confirms dispatch, not that the entire script completed. Existing fan controls and their speed mapping remain unchanged. The app shows only the HA-selected panel.

Choose **Select active panel** in the panel manager, or use the watch's new **Tile panel** select entity in an automation with `select.select_option`. Its options are `devices` and your stable panel IDs (default `work_morning`). Alternatively call **Fan Control: Set active watch panel** (`fan_control.set_active_panel`) with the Watch ID and Panel ID. `devices` restores the active device controls. The existing **Tile device** selector and `fan_control.set_active_device` also restore device controls when selecting a device.

Panels are stored per watch. Up to eight panels and sixteen total device/panel pages are supported. Their configured roles authorize only the approved state reads and panel actions; the watch cannot substitute another entity or an arbitrary service. Panel ID stays fixed when editing so automations do not break. Changing panel entities invalidates existing tile buttons until refresh. Removing the active panel falls back to device controls. Changes arrive on visible refreshes or the next periodic background configuration check. Background checks read selection/configuration only; they do not read device state or run commands.

## Connections and battery

- Local discovery uses HA's `_home-assistant._tcp.` mDNS advertisement during a bounded 20-second setup scan. The watch needs direct Wi-Fi access and a network allowing discovery traffic. Its multicast lock is released on timeout/pause.
- Discovery and pairing request a saved Wi-Fi network, wait up to ten seconds for it, and release the request on pause, scan completion, or pairing failure/expiry. Normal controls and the tile use Wear OS's default connection, including the phone's Bluetooth network proxy; they do not hold Wi-Fi on.
- Pairing polls every five seconds while its screen is foreground, for up to ten minutes. Leaving cancels the session; return to generate another code.
- The pairing screen stays awake only during that setup window. A successful handoff is read back from encrypted storage, acknowledged, and opens the controls; restored completed setup screens return to controls without starting another pairing session.
- Ordinary tile/resources/prefetch requests render locally. Configuration/state reads occur on tile entry, explicit refresh/tap, or visible settled controls pages.
- While the tile is visible, check HA panel selection independently every two seconds, and refresh device state five seconds after the previous state operation finishes. Publish a changed layout immediately before reading its device state. Leaving the tile or turning the display off cancels visible polling and network calls. Renderer service recreation does not interrupt the visible session. No alarms or idle connection pool are used for passive tile refresh. Explicit vehicle actions use the bounded foreground delivery service described below.
- When no app screen or tile is visible, a persisted Android JobScheduler job checks the HA selected panel/device configuration approximately every fifteen minutes, with a five-minute scheduling window and battery-not-low/network constraints. Every scheduled check is eligible to use the default network, including phone Bluetooth proxy, Wi-Fi, or LTE; there is no hourly LTE restriction, Wi-Fi request, network binding, or radio hold. Android may delay checks during Doze, battery saving, low battery, or unavailable connectivity, so this is not an exact timer. Opening the tile/app cancels an in-progress background check and lets foreground refresh take over. Each endpoint attempt has a four-second total timeout (one-second connect, three-second read); a safe read fallback may make two attempts. Failures wait for the next periodic window without aggressive retry. Changed configuration is saved only if the pairing/configuration has not changed meanwhile; it invalidates device cache when the active definition changes and requests a local tile layout update. Unchanged configuration causes no write/update. Forgetting the connection cancels the job; HA access rejection (401/403) clears only the still-matching connection and cancels future checks. Other HTTP errors and network failures retain pairing. Jobs contain no credentials or URLs in their scheduler metadata. Installation does not clear pairing; saved integration connections schedule the job when the updated app process starts, and new pairing schedules it on save. Force-stopping the app prevents scheduled work until the app is opened again. Real-watch scheduling, LTE reachability, and battery drain still need measurement.
- Integration reads initially try the local address, then HTTPS remote access if the local connection fails. Successful routes are remembered for that configuration during the app process, avoiding repeated attempts at an unreachable local address over Bluetooth. Each transport command uses the endpoint established by a preceding read and is never automatically replayed through another endpoint after an ambiguous failure. Explicit vehicle actions follow the bounded intent-preserving retry policy below.
- Requests have a six-second timeout per endpoint with short connection timeouts; fallback can require two attempts. Fan commands reread the actual state, send once, then check for the requested result up to six times, spaced 350 ms apart. Unconfirmed commands display an error rather than a guessed success. Refreshes cannot cancel an in-progress command.
- The sideload build targets API 35 to retain immediate tile enter/leave callbacks on Wear OS 6. API 36 batches these events and cannot provide reliable immediate visibility for foreground-only polling. Compile SDK remains 36. Historical batched entries and batches ending in leave are ignored as a fallback; no tile freshness interval causes unseen state reads; background configuration checks use the separate periodic job.
- State is a confirmed snapshot, not a live stream. The fan tile shows gray **UNKNOWN** and **?** until an available result is confirmed during the current visible session; saved fan state is never displayed as current, including after failed/unavailable fetches. Other panels retain their existing cached display behavior; refresh failures are shown explicitly. Stale button taps become refreshes if an automation changed the selected device, preventing the action being redirected to a new device.

Remote control needs internet access and remote access already enabled in HA. Changing every reachable HA address at once requires pairing again.

## Security and privacy

Integration pairing uses an ephemeral RSA-2048 key, OAEP-SHA256/MGF1-SHA256 and AES-256-GCM. Verify the fingerprint in the authenticated HA interface. The watch receives an independent revocable key, not an HA bearer token, limited to the integration's approved devices and commands.

Paired messages use AES-256-GCM with fresh IVs and authenticated watch ID, timestamp and nonce. The integration persists consumed nonces before commands and rejects replay. Watch clocks must be within 60 seconds of HA. Local HTTP is permitted only for integration mode on private addresses and `.local` names, with application-level encryption. Remote access requires HTTPS and normal certificate validation. Network observers can see host addresses, opaque watch IDs, message sizes and timing.

Saved addresses, credentials, names and entity IDs are encrypted using Android Keystore. Backups/transfers are disabled; setup screenshots are blocked. Credentials and responses are not logged. Tile caches hold generic states and control labels. **Forget connection** clears watch settings; revoke access in HA as well.

Test values are synthetic. Local configuration, output and tooling are ignored; commits use a generic identity. GitHub ownership/activity remain visible if repositories become public. See [Security reports and publication](SECURITY.md) before sharing source or workspace files; ignored local backups can contain private data.


## Build and validation

Use Android Studio or JDK 17+ with Android SDK 36. Configure the local SDK through Android Studio or ignored `local.properties`.

```sh
./gradlew validateDebug
```

On Windows run `./gradlew.bat validateDebug` from PowerShell. You can also run the root `validateDebug` task from Android Studio's Gradle window.

Validation runs on your computer: it builds the debug APK, runs unit tests and runs Android lint, failing if any task fails. Run it before pushing changes or submitting a pull request. This replaces the GitHub Actions workflow; no hosted runner is used and pushes/pull requests no longer start automatic checks.

Local outputs (ignored by Git):

- APK: `app/build/outputs/apk/debug/app-debug.apk`
- Unit-test report: `app/build/reports/tests/testDebugUnitTest/index.html`
- Lint report: `app/build/reports/lint-results-debug.html`

Outputs remain locally until cleaned or replaced by a later build; there is no GitHub artifact upload or seven-day retention. Share the APK manually when needed. Keep release signing keys outside Git.

Tests cover fan conversions, settings migration, encrypted traffic, tamper rejection, revoked access, endpoint fallback, command non-replay, cancellation, visible-page gating, REST payloads and tile events. Real-watch discovery, layout, platform timing, Keystore behavior and physical control still need a hardware check.

## References

- [HA discovery](https://developers.home-assistant.io/docs/api/instance_discovery/)
- [Tile lifecycle](https://developer.android.com/reference/androidx/wear/tiles/TileService)
- [Fan services](https://www.home-assistant.io/integrations/fan/)
- [Percentage conversion](https://github.com/home-assistant/core/blob/dev/homeassistant/util/percentage.py)

## Gradle security maintenance (October 14, 2026)

Updated the wrapper from Gradle 9.3.1 to 9.8.1 to fix the three high-severity
build-process advisories published October 7. The wrapper verifies the official
SHA-256 checksum before using the downloaded distribution. AGP remains 9.1.0;
Java compilation remains targeted to 17.

Validation: `gradlew.bat validateDebug` passed with Gradle 9.8.1 (debug APK,
unit tests, and Android lint). SDK XML and deprecated API/Gradle feature warnings
remain; no validation task failed. No release or deployment was performed.

Source: https://docs.gradle.org/9.8.1/release-notes.html

## Vehicle button behavior

Vehicle panels send a wake request on visible entry, but **buttons accept taps immediately** using their saved approved roles. Battery/climate readings stay unknown until a current available response arrives. The Work Morning climate/script buttons, Exercise Start/Stop, the separate Exercise tile, and full-screen vehicle pages all use the same bounded delivery path.

A tap stays on the current tile or controls page: its existing button immediately shows the requested state in gray and is disabled until confirmation. No waiting activity is launched. A cancellable foreground notification tracks the pending action even if the display turns off. The watch keeps checking readiness and delivery on its normal connection for up to **one minute**; no Wi-Fi hold is requested. A short, timeout-limited wake lock is used only for this explicit action. Retries back off from two to ten seconds. If the requested result is not confirmed by the deadline, outstanding watch requests are cancelled and a high-priority notification plus vibration alerts the user to check the vehicle. Notification permission is requested for alerts; device notification settings, Do Not Disturb, and OS service restrictions can affect delivery and must be checked on real hardware.

Climate toggles resolve one absolute on/off intent after a fresh ready reading, and keep that intent through retries. Exercise Start retries the idempotent lock action, confirms lock state, and opens Spotify on the watch immediately from the Start tap. Exercise Stop reuses one HA operation ID so already-completed steps are not replayed. At timeout/cancellation it also makes a best-effort HA Stop cancellation request; a disconnected HA or an already in-flight physical action may still finish. A new Start supersedes a pending Stop. Otherwise a second tap reports the existing pending action and offers Cancel. Pairing or configured entity-role changes cancel delivery rather than redirecting it.

Scripts are dispatched at most once. If a script response is lost, the watch keeps checking until the minute expires and reports an unconfirmed request instead of blindly executing the script again. A successful script response acknowledges HA dispatch, not completion of the entire script. Pending actions are not restored after process death or reboot. No Home Assistant configuration or credentials need to be changed for this watch update; existing vehicle panel support in the integration is required.

## Requested-state feedback

This is a required interaction rule for all current and future watch commands;
see [AGENTS.md](AGENTS.md). Pending/requested outcomes use gray text and gray
backgrounds. A matching confirmed result changes to normal state colors, with
mint highlighting for a selected/acknowledged action. Clickability alone is not
confirmation. Panel timeout/cancellation results retain gray requested feedback
with **Not confirmed** until a subsequent state read replaces it; ordinary device
failures return to unknown/error rather than displaying a guessed success.

Power, fan speed, climate, script/scene, and Exercise actions immediately display their requested state in gray. Pending action buttons are disabled until a confirmed response arrives; normal colors return only for a confirmed result. A requested snapshot is never written into the confirmed cache, and failed/cancelled requests do not leave guessed state marked as current. Ordinary power/climate taps resolve an absolute on/off intent from the displayed state so a later server read cannot invert what the watch said it requested. Fan speed drafts remain adjustable during the one-second selection window, with gray requested speed; controls disable when the request is sent.

Panel commands use inline pending labels on their existing buttons in both tiles and app pages, including while the car wakes. Work Morning panels use this path even without optional wake roles. ON/OFF intents are fixed at the tap; tapping unknown climate requests ON. Existing one-minute delivery/alert behavior is retained. Scripts and scenes display REQUESTED, not COMPLETED: the available confirmation is HA dispatch acknowledgment. Exercise setup requires Fan Control HA integration 0.3.0 or later; after an integration update, reload the HA browser page and use Configure → Manage watch panels → choose watch → Add Exercise panel.
Exercise music (watch 1.4.6 / integration 0.3.1): edit the Exercise panel in HA to optionally select a Spotify media player and playlist URL or URI. Sharing parameters are discarded. An optional exact source name is selected only when available; blank uses Spotify's active device and may play elsewhere. Start opens the installed watch Spotify app and sends one separate HA music request, with shuffle disabled before and after playlist playback. Music is never replayed by vehicle retries and failure does not prevent locking. No Spotify credentials are stored on the watch. Opening the watch app does not guarantee that Spotify changes its active output; playback and shuffle still require real-device verification.


## Driving tile (watch 1.5.0 / integration 0.4.0)

In Fan Control's native HA Configure flow, choose Manage watch panels, select
the watch and Add Driving panel. Select distinct garage and trunk `cover`
entities with explicit open/close support, the vehicle's climate entity, wake
button and online binary sensor. Add the separate **Driving** tile on the watch.
It requires exactly one Driving panel; multiple candidates remain disabled.
The panel can be selected in HA as the
main tile's active panel. Entity choices stay in HA; none are compiled in.

Garage and trunk are open/close toggles; Climate ON always requests ON. On each
visible entry the watch requests vehicle wake once; refresh, prefetch, background
configuration checks and hidden rendering never wake a vehicle. Command delivery and retries never send wake; only a currently displayed vehicle page does.

Before a current trunk state is available, the trunk displays **CLOSED in gray**
and is immediately tappable: its first tap fixes an **OPEN** request. This is a
presentation assumption, never a confirmed or cached closed state. A later read
cannot flip that tap into Close. A confirmed OPEN trunk offers Close next; a
confirmed CLOSED trunk offers Open. Moving states remain gray. Garage also begins CLOSED in gray and accepts an immediate explicit Open tap;
it can operate while the vehicle is offline. Vehicle trunk/climate dispatch
waits for the selected online sensor. HA observations can still be cached by
the upstream integration and do not independently prove physical freshness.

Every command immediately displays its requested outcome in gray and disables
conflicting controls. Matching available HA state changes it to confirmed
colors. Delivery is bounded to one minute with progress/Cancel and an unconfirmed
timeout alert. Garage/trunk commands are sent at most once per tap, including
after an ambiguous response; subsequent attempts only read for confirmation.
Climate keeps its absolute ON intent. No `cover.toggle` is used. Cancel cannot
recall an already-dispatched action. Role changes and expired one-use buttons
cannot redirect old commands to another cover or vehicle. No operation resumes
after reboot. Install both updated components before configuring this panel.

## Panel colors and vertical navigation (watch 1.5.1 / integration 0.4.1)

Garage and trunk both start CLOSED in gray when no current state is known;
the first tap fixes an OPEN request immediately. Neither assumption is cached
or treated as a confirmed observation. Select **Car identification color** in
HA when adding/editing Work Morning, Exercise or Driving panels. Each vehicle
panel shows that RGB color in its top bar; it never replaces command feedback
colors. Existing panels use mint until a color is saved.

The color bar identifies the car and has no tap action. Full-screen controls show only the HA-selected device/panel. Watch-side page switching is disabled; change the active selection in HA.

Only a currently displayed, settled vehicle page sends its wake request on
entry. Hidden pages, page prefetch, refreshes, configuration/background reads,
command delivery and screen-off retries never send wake. A previously dispatched
wake cannot be recalled if the user leaves before its network response arrives.


Driving-only identification bars: show the configured colored stripe only for Driving panels, on native tiles and full-screen controls. Fan, Work Morning and Exercise must not display identification bars. HA-only selection remains unchanged.
