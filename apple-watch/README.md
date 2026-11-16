# Fan Control for iPhone and Apple Watch

**Current TestFlight release:** 0.11.1 (27), compatible with deployed HA 0.14.0
and direct Apple push delivery. Update Fan Control in TestFlight to activate
phone-only messages, swipe-to-reveal Delete and 12-hour expiry. See [release evidence](RELEASE.md) and
[the implementation record](UNRELEASED-CORRECTIONS.md).

Active watch commands now submit immediately through foreground HTTPS, with one
bounded background continuation when needed. See [release evidence](RELEASE.md).

Opening a nonvehicle control makes one bounded authenticated HA state read,
without a command tap or phone. Local command alerts reconcile saved timers on
recovery, suppress obsolete callbacks and avoid duplicate notifications. The
release passed 85 Swift tests, iPhone/watch source typechecks and signed upload checks.

Independent watchOS 10+ SwiftUI client for the [Fan Control HA integration](https://github.com/agawlbb/FanControlHA), ported from [Android 1.5.3](https://github.com/agawlbb/FanControl/tree/841587d42c391afaac4df77621c7428dd250b2c9).

## Phone-only messages — 0.11.1 (27)

Messages are saved only on the iPhone. Swipe left on a message to reveal Delete, then tap Delete to remove it,
including offline. Swiping alone never deletes a message. The same message is removed from Notification
Center. Use Edit for tile/music reordering. Text uses adaptive black/white system colors in the list and full-text view.
Messages expire after 12 hours; cleanup runs on app opening and while its UI is
active, without waiting for HA. Expired banners are removed when the app can run.
Notifications still in Notification Center are imported at opening with their
original age; dismissed or expired messages do not return. Existing saved phone
messages are preserved until dismissed or expired. Unlinking clears local messages.

HA 0.14.0 no longer stores message bodies or includes them in snapshots. Flight
arrival no longer clears messages. No message history is transferred to the watch.
Missed pushes have no server-side recovery. Install TestFlight 0.11.1 (27) to
activate swipe-to-reveal Delete and expiry.
Task `feature/phone-only-messages`, Apple base
`2aceaaab70d1b5f3a6726b2b72c7b4e260f02777`.
Swift core tests and iPhone/watch source typechecks passed in
[run 42237414837](https://github.com/agawlbb/FanControlWatch/actions/runs/42237414837).
The signed release passed in [run 42248342302](https://github.com/agawlbb/FanControlWatch/actions/runs/42248342302).
Physical swipe handling, readability and Notification Center cleanup remain checks
on the installed iPhone update.

## Home Assistant automation alerts

This source adds **Settings → Notifications → Enable notifications** to the
Fan Control iPhone app. Enable alerts after linking the phone; if permission is
denied, **Notification settings** opens the app's iOS notification settings.
Foreground alerts are also presented for the currently linked watch.

With HA integration 0.13.1 configured for direct APNs delivery, an automation can call
`fan_control.send_notification`, choosing the Fan Control watch device, title and
message. Alerts go directly to **Fan Control on iPhone** (`dev.fancontrol.watch`),
without the Home Assistant Companion app or background app execution. Apple may
present them on the paired watch, subject to normal routing/notification settings.
Watch command failure alerts keep their existing separate destination.

HA holds the APNs signing key privately and sends directly to Apple over HTTP/2.
The old hosted relay is retired. See the
[verified HA deployment](https://github.com/agawlbb/FanControlHA/blob/main/DEPLOYMENT-DIRECT-APNS.md).
This transport migration changes no app payload or pairing contract.

Automation alerts and readable in-app messages are included in 0.10.0 (24).
Paired-device checks remain for notification permission, foreground/background
and locked/unlocked phone/watch behavior, Focus/mirroring, and unlink/revocation.

## iPhone companion — 0.6.0 (15)

The iOS 17+ companion manages fixed watch swipe order, preferred headset, and
imported MP3/M4A/AAC exercise music. Add/reorder/remove tracks, then Sync for
offline watch playback. Files are hash checked and the previous playlist remains
playable until its complete replacement is installed.

Pair the watch with HA as before, then open both apps and Link watch on iPhone.
Requires companion support in HA; current HA 0.13.1 sends pushes directly to Apple.
The phone receives a separate
observation/preferences key; the watch command key stays on the watch. Unlink
phone revokes only that key. HA watch revocation revokes both.

Routine refresh belongs to the phone: APNs, opportunistic background refresh,
and 15-second refresh while the phone app is visible. The watch has no routine
HA polling. It immediately displays its saved panel/states and asks the phone
for its cache on entry. Without the phone, saved controls, direct HA commands,
command-confirmation reads, visible settled-entry wake and offline music remain
available. Cached states stay gray and tappable; snapshots cannot confirm a
watch command. iOS background execution/delivery remains opportunistic.

The Settings swipe page is removed; hold a watch page for setup/recovery. HA
selects the opening panel until a swipe saves a local default. That default survives reopening until another swipe or an HA selection/configuration revision; phone ordering controls swipe order without changing
selection. Phone diagnostics show cache time and watch acknowledgment; HA
retains correlated push attempts, phone receipt/save and watch-save events.

## Pairing and controls

Enter the HA local or HTTPS address on the watch, choose Pair, then approve its
eight-digit code and compare the full fingerprint in HA's native Fan Control
configuration. Configure devices, panels and opening selection in HA. Remote
addresses require HTTPS. Add the Active Panel complication in the watch face editor.

Fans expose power and six speeds; approved lights, switches, booleans, scripts
and scenes retain their controls. Driving has Garage, Trunk, Climate, Horn and
optional Podcast. Exercise uses private offline audio and headset routing. Stop
requests unlock, climate on and 63 F; local-mode completion requires available
unlock/climate evidence, with temperature best effort. HA then selects the unique
matching Driving panel. Receipt colors never prove physical state or playback.

## Development and releases

For instructions to run tests, build on GitHub's Mac runner, configure Apple
signing credentials, and publish to internal TestFlight directly from this
repository, see [GitHub builds and TestFlight setup](GITHUB-TESTFLIGHT.md).

Current version: **0.11.1 (27)**; iOS 17+, watchOS 10+, HA 0.14.0. Published to the existing Internal TestFlight group.
`swift test` runs core regression tests. XcodeGen uses `project.yml` to generate
the iPhone, watch and complication targets. Existing GitHub workflows compile
simulators/archive on main pushes and build/upload TestFlight only by explicit
dispatch. Inspect workflow triggers before pushing; do not run release workflows
for documentation maintenance.

[Release evidence and remaining hardware checks](RELEASE.md),
[privacy](PRIVACY.md), and [signing/encryption policy](SIGNING-REVIEW.md).
Historical release tags and Git history retain earlier release source; old setup
instructions are superseded by this companion workflow. Licensed AGPL-3.0-only;
see LICENSE and NOTICE.md. Never commit keys, certificates, pairing secrets or audio.

## HA-owned commands - 0.8.0 (17)

Requires HA integration 0.9.0. Every HA control saves an absolute intent and schedules
background submission before monitoring. HA durably accepts it and owns readiness,
bounded wake, safe retries and confirmation, including recovery after HA restart.
Leaving the watch screen stops monitoring without cancelling delivery; reopening
reconciles the same operation. Fan-speed debounce is HA-owned. One-shot actions
are never blindly replayed after an ambiguous response.

Delivery allows three minutes plus a 15-second read-only final check. Expected
wake/retry delays do not trigger one-minute Exercise alerts; absent evidence stays
**not confirmed**. Scripts/scenes/music receipts prove dispatch acceptance only.
Local music stays watch-owned; phone snapshots and passive reads never wake cars.
Existing pairings are preserved. See [the delivery contract](COMMAND-DELIVERY.md).

### Watch diagnostics

Long-press any watch control page, then tap **Diagnostics** on the connection
settings screen. It shows the installed version/build, saved command receipt and
alert timestamps, and push history. **Refresh diagnostics** reads local evidence
and removes obsolete local alerts; it sends no command, wake or status poll.
A late authenticated HA receipt clears obsolete handoff failure evidence without
restarting Activated feedback. Receipt does not prove physical completion.

## On Duty tile and readable messages

See [implementation and activation](ON-DUTY.md). Released in 0.10.0 (24), with HA 0.12.0.
Version 0.10.1 (25) fixes the last-known gray flight display on opening.
