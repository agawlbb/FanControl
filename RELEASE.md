# Live music sync handshake — 0.12.2 (30), November 15, 2026

Continues the user's instruction to complete music sync, merge to main, remove
completed task branches and release the app. Task `fix/music-sync-readiness`
starts at main `f2fc515bb821c3ba5a83b31ae33aea559ad39c4d`.

The user confirmed both apps were on 0.12.1 (29) and Podcast live controls work.
Music now uses that same activated/reachable channel without an extra companion
installation hint blocking submission. The phone returns a matching single-song
manifest directly in its reply. Sync can wait up to 15 seconds for initial
readiness and submit once. Readiness changes republish/resume pending transfers.
Unsolicited old manifests cannot clear an outstanding live request. Unlinked or
mismatched watches, preparation failures, invalid replies, timeouts and numeric
WatchConnectivity errors remain distinct. Context publication failure does not
prevent live publication. Hash verification, atomic replacement, active playback
preservation and screen-off background file handling remain unchanged.

Core tests, SDK typechecks and TestFlight publication are pending.
Physical-device checks remain for the reported 0% failure, late readiness,
single-song transfer, wrist-down completion and offline playback. Working Podcast
controls establish a live channel, but automated validation alone cannot establish
why music failed on the paired devices or guarantee the fix resolves that failure.
Both apps need updating after publication. No HA deployment is needed.

---

# Exercise music sync — 0.12.1 (29), November 15, 2026

User authorized merge, task-branch cleanup and app release on November 15, 2026.
Prepared on `fix/iphone-music-sync`, containing implementation source
`5c8f767c1021ba004e98aadd3edd09be07234f92`.

- Both watch Sync controls request the iPhone's imported playlist instead of the
  separate legacy HA playlist, fixing mismatched song totals.
- A visible watch can receive verified music chunks directly from the iPhone,
  with transfer progress and immediate saved receipts.
- Screen-off WatchConnectivity wake tasks remain alive until session activation,
  incoming delivery and file persistence finish; background file transfers remain
  available after wrist-down.
- Partial or corrupt replacements never replace the installed library, and
  currently playing music is retained until the next session.

Published to the existing **Internal** TestFlight group. Apple build
`4d9d0d06-e5c7-478f-8579-6937e04790ae` is `VALID`, not expired and
`IN_BETA_TESTING`, marketing version 0.12.1, without non-exempt encryption.
Update both the iPhone and watch apps through TestFlight.

Signed source, merged into main: `83e80b2401a72e8ea0c6edf73ce02860f899a32e`.
All **101 Swift core tests** and iPhone/watch SDK source typechecks passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/43661749003
Signed iPhone/watch archive/export, signatures and production APNs entitlement
checks, upload, Apple processing and Internal-group assignment passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/43661897402
Immutable release tag: `v0.12.1-build29` at the signed source. Processing evidence
is retained in the release workflow artifact and this record. The user authorized
removing the merged task branch. No HA deployment is needed.

Paired-device checks remain for a one-song playlist, wrist-down during transfer,
background completion receipts, interrupted transfer and offline playback.
Automated tests and builds do not establish physical-device transfer or playback.

---

# Mission Log phone player — 0.12.0 (28), November 15, 2026

Release authorized by the user. Prepared on `feature/iphone-podcast-player`,
containing implementation source `60943d0ca77aaad2cffaf1d1736abd9166267f2f`.
Published to the existing **Internal** TestFlight group. Apple build
`9538ea76-35ec-4baa-81a8-48601303a147` is `VALID`, not expired and
`IN_BETA_TESTING`, marketing version 0.12.0, without non-exempt encryption.
Update Fan Control in TestFlight to install it.

Signed source: `f5d1262d4ba09be3c192b0c784f9964704a3cb9c`.
All 95 Swift tests, signed iPhone/watch archive/export, signature and production
APNs entitlement checks, upload, Apple processing and Internal-group assignment
passed: https://github.com/agawlbb/FanControlWatch/actions/runs/43655966382
Release-source core tests and both SDK typechecks also passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/43655966169
Immutable release tag: `v0.12.0-build28` at the signed source.
Processing evidence is retained in the release workflow artifact and recorded here.
No external testing submission or App Store release was performed.

- iPhone-owned offline podcast playback and saved progress/completion history.
- Episode picker grouped by Star Trek series/season, with films and played indicators.
- Five-episode Wi-Fi download window; starting the last downloaded episode allows
  its immediate successor to download over cellular.
- Permanent watch Podcast tile with Play/Pause, ±15 seconds and Mark Complete.
  Driving's Podcast button opens the tile and starts/resumes phone playback.
- Natural/manual completion stops playback and prepares the next regular episode
  without autoplay. Supplementals and unrelated specials are excluded.

The implementation passed 95 Swift core tests and phone/watch SDK source typechecks:
https://github.com/agawlbb/FanControlWatch/actions/runs/43650303565
No HA update is needed. Paired-device checks remain for locked-phone startup,
background downloads, car Bluetooth output, interruptions and watch rendering.
Automated validation does not prove audible playback or physical-device behavior.
The user approved merging this release into main and removing its task branch on
November 15, 2026. The immutable release tag preserves the signed source.

---

# Tap Delete after swiping — 0.11.1 (27), November 6, 2026

Swipe left on an iPhone message to reveal the native red **Delete** action.
Only tapping Delete removes it. Full-swipe deletion is disabled and no
confirmation dialog is shown. The message still opens on a normal tap.
The list starts outside edit mode so native swipe actions work; **Edit/Done**
retains tile and exercise-music reordering and music removal.
Deletion remains local, with the existing notification cleanup and 12-hour expiry.

Published to the existing **Internal** TestFlight group. Apple build
`6a469e30-a709-4a43-914d-6deb639213c1` is `VALID`, not expired,
`IN_BETA_TESTING`, marketing version 0.11.1, without non-exempt encryption.
Update Fan Control in TestFlight to install it.

Signed source: `ef28cc744395fb46aeada90f63016f343d322c9a`.
Task `fix/message-delete-button` started from canonical main
`b22cce0558726df7d0fcd7beb8fa935f244a58c8`.
All **85 Swift core tests**, signed iPhone/watch archive/export,
signature and production APNs entitlement checks, upload, Apple processing
and existing internal-group assignment passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/42248342302
Release tag: `v0.11.1-build27` at the signed source.
The one-time release-branch trigger was removed afterward.
No HA update or restart was needed; deployed HA 0.14.0 remains compatible.

On-device checks remain: a partial or full left swipe leaves the message visible
with Delete revealed; tapping Delete removes it and its delivered notification;
tapping elsewhere closes the action without deletion; normal taps still show full
text; Edit/Done allows tile/music rearrangement. Automated builds do not verify
physical iPhone gesture rendering or notification receipt.

---

# Phone-only messages — 0.11.0 (26), November 6, 2026

Published to the existing **Internal** TestFlight group. Apple build
`cb11ec93-582a-4610-aa1e-311e44e9f2f3` is `VALID`, not expired and
`IN_BETA_TESTING`, with marketing version 0.11.0 and no non-exempt encryption.
Install the update through TestFlight on iPhone; publication does not remotely
install it.

Messages are retained only on the iPhone. Swipe left to dismiss immediately,
including offline, with no confirmation. List and full-text views use adaptive
black/white text. Messages expire after 12 hours; cleanup runs when the app opens
and while active, and removes matching delivered notifications. Notification
Center imports preserve original age and do not restore dismissed/expired items.
There is no arrival clearing or HA message-history recovery.

Signed source: `296388dc5af76e286034ac9c1e50e86242e63ef2`.
Release task `release/phone-messages-26` started from canonical main
`fa8b78aa8694be44b99540ef129de52e72172560`.
All **85 Swift tests** and iPhone/watch source typechecks passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/42241396154
Signed archive/export, signature and production APNs entitlement checks, upload,
Apple processing and existing internal-group assignment passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/42241396000
Immutable release tag: `v0.11.0-build26` at the signed source commit.

HA **0.14.0** is deployed and loaded; its old live message copy was removed
without changing pairing. Direct APNs remains enabled. The flight-alert automation
retains delay, schedule-attention and route-change alerts, without arrival clearing.
See [HA deployment evidence](https://github.com/agawlbb/FanControlHA/blob/main/DEPLOYMENT-PHONE-MESSAGES.md).

The one-time release-branch trigger was removed after the successful release;
normal TestFlight publication remains manual. Physical checks remain for swipe
handling, adaptive text, full-text notification taps, expiry and Notification
Center cleanup on the installed iPhone build. Automated checks do not establish
on-device rendering or APNs receipt.

---

# On Duty last-known flight cache — 0.10.1 (25), November 5, 2026

Fix task `fix/on-duty-cache` starts at fetched canonical main
`d572d6fe14338c47d083ac98cef627bcda16a2ae`.

On Duty previously opened with placeholders because the shared observation cache
never retained its city-pair and departure fields. It now saves one complete valid
flight observation from entry reads and phone snapshots, and reopens with that
last-known flight in gray. Invalid, unavailable or partial updates do not erase it
or combine different flights. Fresh phone snapshots pass their actual observation
to the visible tile, so availability is taken from the update rather than inferred
from saved data. Cached values never carry freshness; watch/roles/credential scope
remains unchanged. No HA, relay or automation changes are required.

Regression checks cover cache recreation, gray saved data, complete replacement,
unavailable/partial updates, and watch/role isolation. All **80 Swift tests** and
watch/iPhone source typechecks passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/42054731006

Signed source: `2f837fb8e7d655da29a8af0aea50b8b1746bb1f1`.
Signed archive/export, signature/APNs entitlement checks, upload, Apple processing
and assignment to the existing **Internal** TestFlight group passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/42055189243
Apple build `f3242c18-023a-48af-8bb5-9b822904f959` is `VALID`, not expired,
`IN_BETA_TESTING`, with marketing version 0.10.1 and no non-exempt encryption.
Immutable tag: `v0.10.1-build25` at the signed source commit.

No HA deployment or automation changes were made for this fix. After upgrading,
one successful refresh seeds the previously missing flight cache; subsequent
openings retain that flight in gray until fresh data arrives. Physical checks
remain for gray opening and teal update rendering on the paired watch.

---

# On Duty tile and readable messages — 0.10.0 (24), November 5, 2026

Release task `release/on-duty` starts at canonical main
`22491332d579e154cc74045ae25d3dd9cef17537`. Requires HA 0.12.0.
Phone, watch and complication use version **0.10.0**, build **24**.

- On Duty displays FlightSync's city pair, departure time and local countdown;
  no flight number. Existing snapshots and entry reads preserve gray stored data
  and teal fresh data.
- The iPhone stores full automation messages and opens their text on notification
  taps, including cold launch and taps while Settings or a refresh is active.
- FlightSync arrival clears all messages from view in the iPhone app via HA.
  Notification Center is unchanged.

Pre-release checks: 78 Swift tests and iPhone/watch source typechecks passed on
Mac run https://github.com/agawlbb/FanControlWatch/actions/runs/42040629167.
297 HA integration tests and eight relay tests passed; Python compilation passed.
Signed source: `e70abe5fb451daa86a35729ab91e53f37dd11585`.
Signed archive/export, signature and production APNs entitlement checks, upload,
Apple processing and assignment to the existing **Internal** group passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/42042238583
Apple build `28b6c495-b6b1-4d38-a274-860da576692b` is `VALID`, not expired,
`IN_BETA_TESTING`, with no non-exempt encryption. Marketing version is 0.10.0.
The immutable release tag is `v0.10.0-build24` at the signed source commit.

HA 0.12.0 source `f4bff5e215f83e2912029cee9019c25d7f4bc96e` was deployed
through File editor after all ten changed existing files matched installed 0.11.0.
All eleven updated/new source files read back exactly. HA configuration validation
passed and one Core restart loaded 0.12.0. Pairing, credentials, existing panels
and prior active selection were preserved. The On Duty panel uses FlightSync's
Flight airports and Flight start sensors. Both prepared automations are enabled;
no physical command or synthetic flight notification was sent as validation.

Remaining physical checks: background updates; gray → teal rendering; departure
and countdown timezone display; full text on cold/warm notification taps; and
arrival clearing after phone suspension. Automated checks do not prove device
rendering, APNs receipt or OS background scheduling.

---

# Foreground command handoff — 0.9.4 (23), November 1, 2026

Published to the existing **Internal** TestFlight group. Apple build
`9548c7c5-bbb9-44a3-95a3-e088ca7ac721` is `VALID`, not expired and
`IN_BETA_TESTING`, with no non-exempt encryption.

Signed source: `675b6ce8e81deccb29611c7f5546f0b8dca8754e`.
Phone, watch and complication use version **0.9.4**, build **23**.
The fix was merged through https://github.com/agawlbb/FanControlWatch/pull/5;
the explicitly approved release bridge through pull request 6.

## Changes and validation

Commands persist their absolute intent, then submit immediately using reusable
foreground HTTPS. App inactivity or foreground failure permits one background
continuation with the same operation ID, intent and original ten-second deadline,
but fresh authentication. HA deduplicates submissions and retains execution
ownership. Navigation alone does not cancel delivery. Existing remote-only routing,
receipt colors, five-second action feedback and one-shot dispatch protections remain.
Numeric transport error codes are retained in local diagnostics.

All **75 Swift tests** and watchOS SDK typechecking passed. Both simulator builds
passed on the merged app source. **33 HA tests** covering durable operations,
duplicate submissions, restart recovery and command feedback passed locally.
Signed archive/export, signature and APNs entitlement checks, upload, Apple
processing and existing internal-group assignment passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/41334139980

Core tests and source typechecking:
https://github.com/agawlbb/FanControlWatch/actions/runs/41333665556
Simulator validation:
https://github.com/agawlbb/FanControlWatch/actions/runs/41333933966

No HA deployment or physical command was performed. Remaining paired-watch checks:
repeat park/cellular commands while active, immediate taps after opening, wrist-down
during handoff, lost responses and opposite intents during an older request.
Automation does not establish actual watch routing, rendering or vehicle behavior.
The release bridge and merged temporary branches are removed after publication.

---
# Stale handoff alerts and accessible diagnostics — 0.9.3 (22), October 31, 2026

Published to the existing **Internal** TestFlight group. Apple build
`208acc40-6749-43bb-937d-1041b20afb4f` is `VALID`, not expired and
`IN_BETA_TESTING`, with no non-exempt encryption. No external testers, beta
review submission or App Store release were created.

Signed source: `4e4b920853740bad20ad73976be0e9c589a9e799`.
Phone, watch and complication use version **0.9.3**, build **22**. Later removal
of the one-use release workflow and these release notes do not alter app code.

## Changes

- Save authenticated late HA receipts for the original pairing and configured
  target, clearing obsolete local handoff failures without reviving Activated UI.
- Reconcile local notifications on foreground entry and after asynchronous
  submission. An old callback cannot clear a newer submission.
- Add **Diagnostics** to the existing long-press connection settings screen.
  Show installed version/build, saved receipt and alert timings, OS notification
  delivery timestamps and local refresh. Diagnostics refresh sends no vehicle
  command, wake or operation-status poll.
- Preserve the ten-second handoff, one upload, no reopening replay, no execution
  polling and the five-second timely action receipt display.

## Validation and evidence

All **73 Swift core tests**, watchOS SDK typechecking, iPhone/watch simulator
builds, screenshot runs and unsigned archive passed on the final task head:
https://github.com/agawlbb/FanControlWatch/actions/runs/41226980465
https://github.com/agawlbb/FanControlWatch/actions/runs/41226984263

The merged source repeated all 73 tests and passed signed archive/export, deep
signature verification, production APNs entitlement checks, bundle/build metadata
checks, upload, Apple processing and existing internal-group assignment:
https://github.com/agawlbb/FanControlWatch/actions/runs/41227745700

Apple build-number preflight verified 21 was the highest uploaded build and 22
was available. Processing evidence is preserved in that run's
`FanControlWatch-TestFlight-processing` artifact.

Merged through https://github.com/agawlbb/FanControlWatch/pull/4. The task branch
was removed locally and remotely. The one-use release dispatch workflow was
removed after dispatch; no release helper remains. No HA deployment was required.

Remaining paired-device checks: navigate/wrist-down during Start handoff, reopen
after 25 minutes, late receipt clearing, actual notifications, diagnostics
navigation and a newer command or changed pairing during an old callback. The
historical notification was not reproduced on a physical watch; automation
does not prove actual watchOS notification presentation or vehicle behavior.

---
# Remote HA handoff and action reset - 0.9.2 (21), October 30, 2026

Published to the existing **Internal** TestFlight group. Apple build
`67ead92c-811d-4f52-aa23-7e60958e88a7` is `VALID`, not expired and
`IN_BETA_TESTING`, with no non-exempt encryption. No external testers, beta
review submission or App Store release were created.

Signed source: `717ab49ada4212fb0633243fa29a7086cab433c0`.
The release task starts from canonical `main` commit
`1f88b87f024f6d00f8b1a2448870fe3c17c79fae`. The signed iPhone, watch and
complication package uses version 0.9.2, build 21. Later documentation and the
project's default build-number update do not change the signed application code;
the release workflow explicitly supplied build 21 during archive/export.

## Changes

- Use the saved remote HTTPS HA address exclusively, with no hardcoded domain
  or local fallback. Require remote HTTPS for initial watch pairing too.
- Long-press a FanControl page to see the saved remote address on the existing
  connection screen and run an authenticated read-only remote connection test.
- End the watch's command handoff after ten seconds or an earlier response.
  Send once; do not retry, replay on reopening, or poll execution after HA
  acknowledges ownership. HA retains execution, wake, retries and failure alerts.
- Action buttons show gray Activated during handoff, restore their command name
  on failure, and show teal Activated for five seconds after acknowledgment before
  restoring the normal appearance. Stale callbacks/timers cannot clear newer taps.
- Register HA failure notifications independently on watch entry. Retire the
  previous multi-minute local handoff timers.
- Check Apple's uploaded build numbers before archiving. The check found build
  20 already uploaded and stopped before building; build 21 was verified unused.

## Validation and evidence

The signed release passed all 69 Swift core tests, signed archive/export, deep
signature verification, production APNs entitlement checks, all three bundle/build
metadata checks, upload, Apple processing and existing internal-group assignment:
https://github.com/agawlbb/FanControlWatch/actions/runs/41124053197

The application source also passed watchOS SDK typechecking:
https://github.com/agawlbb/FanControlWatch/actions/runs/41122623379

Apple processing evidence is preserved locally in
`build/remote-ha-021/testflight-processing.json` and in the release run's
`FanControlWatch-TestFlight-processing` artifact. Signing material remains outside
Git. HA and relay deployment were not required for this release.

Remaining physical checks: install build 21 on phone/watch, long-press to confirm
and test the actual saved remote URL, test disconnected-phone/cellular access,
network failure timing, navigation/wrist-down during handoff, five-second button
reset and a newer tap while an old timer exists, and HA failure-notification
receipt. Automated checks do not establish physical connectivity, watchOS
scheduling, actual device rendering, notification delivery or vehicle behavior.

---
# Fan refresh and local alert safeguards - 0.9.1 (19), October 25, 2026

Published to the existing **Internal** TestFlight group. Apple build
`0adcd073-353c-49d5-89ad-1b4bdca0c20f` is `VALID`, not expired and
`IN_BETA_TESTING`, with no non-exempt encryption. No external testers, review
submission or App Store release were created.

Signed source: `845d408a95d5236ef028b4608d57016560e24670`.
Phone, watch and complication all report 0.9.1 (19). Later documentation changes
do not alter that signed source. HA 0.10.0 and its relay remain unchanged.

## Changes

- Restore one bounded authenticated state read when a nonvehicle control becomes
  visible, without a phone or command tap. Available fan power/speed and other
  device states can turn teal. Saved/unknown/unavailable state stays gray.
  Late entry responses cannot replace a later command, pairing or target.
- The regression originated in the earlier companion-refresh change `ff56000`,
  which removed nonvehicle direct reads; vehicle entry work retained that gap.
  Vehicle wake/readiness and shared command delivery remain separate.
- Reconcile OS-owned local notification timers against current saved commands,
  pairing, target roles, acknowledgment and original issue time after relaunch.
  Remove orphaned/obsolete timers and legacy Exercise alerts. Never recreate an
  overdue timer or replay historical terminal failures. Local notification
  relevance ends five minutes after the original tap; the fallback's original
  trigger remains 195 seconds plus 30 seconds of transport grace.
- Suppress stale callbacks and duplicate local fallback/terminal alerts. Recheck
  after asynchronous permission/notification work so a newly received HA
  acknowledgment cancels older alert work. Recovery may read command status;
  it does not submit a command or wake a vehicle.
- Add bounded correlated alert scheduling, presentation, suppression and recovery
  events to existing diagnostics. Ordinary controls have no added status text.
  The exact source of the reported unsolicited alerts was not proven; these
  changes close concrete stale-timer/callback paths found during investigation.

## Validation and evidence

63 Swift regression tests and unsigned iPhone/watch simulator builds passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/40261522318

The signed release repeated 63 tests and passed archive/export, deep signature
verification, production APNs entitlements, three bundle/version checks, upload,
Apple processing and existing Internal group access:
https://github.com/agawlbb/coffey-table-recipes/actions/runs/40261830834

IPA SHA256: `2e7d14319de38c467e9eec45dd931e842cefa0d2cfc9a1da67eb5f1deac5adce`.
Signed IPA, processing record, logs and verified branch recovery are preserved
under `build/alerts019/`. The isolated temporary signing branch was retired using
its exact-head lease; CTR main's independent owner changes were preserved.

Remaining physical checks: open the bedroom fan without issuing a command, with
and without the phone; unavailable fan; switch targets during a delayed read;
relaunch with acknowledged/expired timers; real notification permission, deferred
watchOS delivery and immediate navigation/wrist-down after commands. Automated
checks do not establish paired-watch rendering or actual notification delivery.

---

# Command feedback and reliability release - 0.9.0 (18), October 25, 2026

Published to the existing **Internal** TestFlight group. Apple build
`59d77956-c358-4b1a-b0d4-1c0ce47b933f` is `VALID`, not expired and
`IN_BETA_TESTING`, with no non-exempt encryption. No external testers, beta review
submission or App Store release were created.

Signed source: `a1161318e91ea0c54c956ecd963a09b4a8321aae`.
Phone, watch and complication all report 0.9.0 (18). Later documentation commits
do not change that signed source. HA 0.10.0 and the matching outcome relay are
installed and verified; both existing pairings were preserved.

## Changes

- Every control immediately projects the requested outcome in gray and turns teal
  on authenticated HA ownership, including Climate. HA execution and observation
  continue independently after leaving the watch screen. Terminal failures return
  gray. Existing controls have no separate command status messages.
- Foreground/background acknowledgment and reopening share persisted receipts;
  stale snapshots/callbacks cannot overwrite newer requests. Visible vehicle entry
  performs bounded wake/readiness refresh. Cold climate presents gray OFF so the
  first tap remains absolute ON despite stale cached ON.
- Generic command failures use a dedicated watch notification destination, separate
  from phone snapshots. Expected wake/retry delays remain silent; missing handoff
  has a local not-confirmed notification fallback after 195 seconds plus 30 seconds
  transport grace. Notification wording is separate from control presentation.
- Bounded diagnostics correlate tap, upload, HA arrival/acceptance, wake, dispatch,
  observed outcome, feedback display and notification transport. Future-command
  requirements are recorded in both repositories' AGENTS.md.

## Validation and evidence

50 Swift tests and unsigned iPhone/watch simulator builds passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/40199880630

The release repeated 50 Swift tests and passed signed archive/export, deep
signature verification, production APNs entitlements, three bundle/version checks,
upload, Apple processing and existing internal group access:
https://github.com/agawlbb/coffey-table-recipes/actions/runs/40242439379

257 HA/relay/deployment regression tests passed locally. Matching runtime sources
passed real-HA, PHP, compilation and package checks:
https://github.com/agawlbb/FanControlHA/actions/runs/40242073803
Relay deployment/readback passed:
https://github.com/agawlbb/coffey-table-recipes/actions/runs/40242258723
Live HA source hashes, loaded version and pairing preservation passed after restart.
See FanControlHA `DEPLOYMENT-0.10.0.md` for backups and rollback.

IPA SHA256: `61271a1f6dc98d1d7d4bf7935f5f8ba821128796ae6023b9f776b4cb07edd1c2`.
Local signed IPA, Apple processing record, logs and branch recovery are preserved
under `build/corrections-release/`. The temporary signing/relay branch was retired
with an exact-head lease after recovery verification. CTR main advanced under its
owner and was not changed by this release.

Physical watch/car checks remain: cellular-only swipe/tap/immediate exit,
sleeping-car wake/climate, notification permission and delivery, opposite intents,
HA restart and observed-state freshness. Automated checks do not prove paired
watch rendering, OS scheduling, actual notifications or physical car outcomes.

---

# Durable command delivery release - 0.8.0 (17), October 24, 2026

Published to the existing **Internal** TestFlight group. Apple build
`235e769a-793d-4406-a96c-ca0fd44c7b66` is `VALID`, not expired and
`IN_BETA_TESTING`, with no non-exempt encryption. No external testers, beta review
submission or App Store release were created.

Signed source: `aff112a6b1b2a5ed7e2017e83495b4efccd9fa73`.
Phone, watch and complication all report 0.8.0 (17). The released binary remains pinned to that source.
Newer unshipped work is documented in [UNRELEASED-CORRECTIONS.md](UNRELEASED-CORRECTIONS.md).
HA 0.9.0 was deployed and loaded; both existing pairings were preserved.

## Changes

- Every HA control now saves one absolute intent in the watch keychain outbox and
  schedules background submission before monitoring. Navigation and wrist-down
  cancel UI observation only; accepted commands remain HA-owned.
- HA persists acceptance and dispatch boundaries, resumes operations after restart
  within the original deadline, retries safe desired states and never blindly
  replays ambiguous cover/horn/script/scene actions.
- Fixed the first-tap audit gaps: transient reads no longer gate dispatch, unrelated
  configuration does not block a valid captured target, generic services do not
  block operation acceptance, and battery telemetry cannot block healthy controls.
  Trunk and climate-OFF confirmation, legacy Exercise configuration, shared wake
  cancellation/restart and stale upload outcomes are covered by regressions.
- Fan-speed debounce remains one second and is now HA-owned. Normal wake/retry
  delays stay silent through 180 seconds plus 15 seconds of final confirmation.
  Requested/unconfirmed feedback remains gray; receipts do not imply playback or
  physical completion. Swipe-selected default persistence is retained.

## Validation and evidence

42 Swift core tests and unsigned iPhone/watch simulator builds passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/40128116674

The release repeated core tests and passed signed archive/export, deep signature,
production APNs entitlements, bundle/version checks, upload, Apple processing and
existing internal TestFlight access:
https://github.com/agawlbb/coffey-table-recipes/actions/runs/40128954393

HA passed 242 regression tests, compilation/package/PHP checks and real Home
Assistant durable-storage/reload checks:
https://github.com/agawlbb/FanControlHA/actions/runs/40128342770
Live deployment and rollback: FanControlHA `DEPLOYMENT-0.9.0.md`.

IPA SHA256: `4d46d373bc43c2b725726c0ec648f1d7b661d8586b4bee80cc3b6f7a75dc4a03`.
Local signed IPA, Apple processing record, logs and signing-branch recovery:
`build/commands080/`. The temporary signing branch was retired with an exact-head
lease after preserving recovery evidence; the signing host's main was unchanged.

Remaining physical checks: cellular-only handoff, immediate swipe/wrist-down after
all watch actions, sleeping-car response, opposite intents/cancellation, HA restart
during delivery and local audio/headset behavior. Automated checks do not establish
physical delivery or watchOS background scheduling; ambiguous one-shots can remain
unconfirmed when the target supplies no deduplication or definitive acknowledgment.

---

# Vehicle reliability release — 0.7.0 (16), October 24, 2026

Uploaded and available to the existing **Internal** TestFlight group. Apple build
`4fa19c25-a9b5-4250-8654-03edac7b5f80` is `VALID`, not expired, and
`IN_BETA_TESTING`, with no non-exempt encryption. No external testing group,
new tester, beta review submission or App Store release was created.

Signed application source: `e9e1e54da2288bc0736865d6093340d5b9756152`.
Later changes affect release verification/documentation only; application sources
and project settings are identical. Phone, watch and complication all report
0.7.0 (16). Paired hardware behavior has not been tested.

## Changes

- Explicit vehicle taps coordinate one wake/readiness attempt through HA 0.8.0.
  Operations preserve absolute intent, deduplicate submissions, avoid holding
  the shared HA lock during slow services, and never blindly replay one-shots.
- Delivery lasts up to 180 seconds plus 15 seconds of read-only confirmation.
  Normal wake/retry delays remain silent; missing evidence is not confirmed.
  Definitive rejection can report failure immediately.
- Exercise selection follows the person's morning arrival at either exercise
  location without waiting for car GPS. HA 0.8.0 is deployed and loaded;
  both existing pairings were preserved. Stop still selects a uniquely matching
  Driving panel once after the required outcomes are observed.

## Validation and evidence

38 Swift tests passed. iPhone/watch simulator builds, 13 synthetic captures and
unsigned archive passed; captures were visually reviewed. Signed archive/export,
deep signature, APNs entitlements, bundle versions and upload checks passed.
223 HA regression scenarios, Python compilation, package generation and real HA
runtime checks passed. Installed HA 2026.10.3 loaded the deployed integration.

- Simulator/core validation: https://github.com/agawlbb/FanControlWatch/actions/runs/40097060261
- Signed archive/upload: https://github.com/agawlbb/coffey-table-recipes/actions/runs/40097426044
- Final processing/internal access: https://github.com/agawlbb/coffey-table-recipes/actions/runs/40098120807
- HA final-source CI: https://github.com/agawlbb/FanControlHA/actions/runs/40097430298

The signing run's post-upload metadata verifier failed; the corrected standalone
verification above confirmed the same uploaded binary without rebuilding/reuploading.
The verifier has an isolated mocked Apple-response test. Private credentials stayed
in the existing runner and were removed at job cleanup.

IPA SHA256: `169353e4df9b7b7aa6613ace37d673936a66ffc0639173279eb81020c14b3e46`.
Local signed package, simulator captures and processing JSON: `build/vehicle070/`.
HA deployment and rollback details: the integration repository's `DEPLOYMENT-0.8.0.md`.

Remaining physical checks: asleep-car first tap, immediate gray feedback, delayed
confirmation, opposite intent/cancellation, offline phone, screen-off Stop,
actual morning arrival and notification suppression during normal delays.
Automated tests do not prove physical vehicle outcomes or paired-watch behavior.

---

# iPhone companion and Apple Watch — 0.6.0 (15)

Source: `3adaed3e3ad538ddd9fd097920cbab2ac6afdc65`.
Tested HA 0.7.0 source: `c40f5b9eae7f30bb32862c8fa9f66ef3431f2d23`.

## Behavior

- Minimal iPhone list: reorder approved tiles, import/reorder/remove audio, Sync.
  A separate gear button opens Settings independently of list reorder mode.
  Settings contains headset preference, connection status, refresh/relink/unlink
  and a separate diagnostics view. No explanatory notes in ordinary controls.
- Tile ordering is fixed, saved per watch through revision-checked HA preferences.
  Opening watch selection still comes from HA; swiping never changes HA selection.
- The phone owns routine APNs/background refresh and visible-phone refresh.
  Watch background tasks do no network refresh. The watch renders its saved panel
  immediately, asks the phone once on visible entry, and accepts passive snapshots.
- Direct watch commands, bounded validation/confirmation and settled visible
  vehicle entry remain independent of the phone. Cached states stay gray and
  tappable; requested intents never enter the observed cache. New phone snapshots
  cannot overwrite command feedback or that foreground session's intent target.
- Phone snapshots contain no credential. Watch/phone use independent Keychain
  keys; HA refuses commands from the companion. Watch revocation revokes both;
  phone self-unlink revokes only the companion key.
- Exercise imports MP3/M4A/AAC files (25 tracks, 30 MB each, 200 MB total), queues
  WatchConnectivity file transfers, checks size/SHA256 and atomically replaces
  the playlist only after all tracks arrive. Empty playlists and reordered lists
  work independently from snapshot sequence. A playing library remains available
  until the next playback session; an older receipt cannot label an edited draft
  as installed. Failed/interrupted transfers keep the previous playable library.
- Settings is no longer a swipe page. Hold a watch page for setup/recovery.
- Diagnostics separate HA attempt/APNs outcome, phone receipt/save, watch save,
  and the watch's first displayed panel. Missing evidence remains unknown.

## Validation

HA checks passed: 209 tests, Python compilation, package generation, PHP syntax,
real Home Assistant 2026.10.2 runtime, uv 0.13.4/Pillow 13.0.0 security overrides.
https://github.com/agawlbb/FanControlHA/actions/runs/39645595614

Local synthetic relay migration check passed: legacy SQLite registrations retain
watch destination, phone registration persists, arbitrary topics/destinations
are rejected. No APNs requests were sent by this check.

Apple final-source validation and signed package verification:
https://github.com/agawlbb/FanControlWatch/actions/runs/39652643037
https://github.com/agawlbb/coffey-table-recipes/actions/runs/39652653308

Apple checks passed: 37 Swift tests, iPhone and watch simulator builds/captures,
unsigned archive, signed archive/export, deep signature verification and production
APNs entitlement checks for both phone and watch. Bundle metadata confirms 0.6.0
(15) for phone/watch/complication, a launchable full-screen iPhone app and independent
watch operation. Main, first-launch and Settings captures were visually reviewed.
These are synthetic simulator rendering checks, not paired-device interaction tests.

- Signed IPA: `build/companion060/final/signed/FanControl.ipa`
- IPA SHA256: `fd2f34fa8ad1c314815d7b217ef48ab07864561bff26408a329f9b8a5df75257`
- CI HA package: `../ha-integration/dist/companion070/fan_control-0.7.0.zip`
- HA ZIP SHA256: `bb00f888d9e37614f0fa9187f0c4a9bcf891d2298e9ccdd1e0e5d2e615823e95`
- Captures: `build/companion060/final/screens/`

Only documentation changes follow the tested source commit. The existing HA CI
workflow was restored to its previous disabled state after successful validation.

## Deployment and physical checks

Install HA 0.7.0 and deploy its updated `relay/public/index.php` before companion
linking. Preserve the existing private relay configuration/key/database; the
public entry migrates legacy registration rows and uses the fixed phone APNs
topic `dev.fancontrol.watch`. The relay APNs key must authorize the phone topic and selected environment.
A team-scoped key can serve both apps; verify any topic-specific restrictions.
The phone receives no Apple private key or HA admin token.

Install the iPhone/watch package, open both apps and use Link watch if needed.
Existing watch pairing is retained.

### October 21 deployment and TestFlight upload

HA 0.7.0 and the pinned relay entry were deployed, backed up and verified.
Both existing HA watch identities and pairing secrets were preserved. The existing
production APNs key now authorizes both phone and watch topics, saved with the
user's explicit approval. HA recorded a post-deployment hint as accepted by APNs
(HTTP 202); device receipt remains unknown. See the integration repository's
`DEPLOYMENT-0.7.0.md` for deployment evidence and rollback locations.

The existing signing runner rebuilt the unchanged tested source commit, passed
all 37 Swift tests and signature/APNs entitlement checks, and uploaded 0.6.0 (15):
https://github.com/agawlbb/coffey-table-recipes/actions/runs/39655941241

Apple reported upload success at 18:58:13 UTC and processing `VALID` at
19:00:37 UTC on October 21. The build is not expired and declares no non-exempt
encryption. It was assigned to the existing Internal testing group; no new
testers, external review submission or App Store release was created.
App Store Connect build ID: `c359b4c2-e92b-4827-8108-b2d923e83674`.

The earlier IPA hash above describes the pre-upload signed verification package.
This upload was freshly signed from the same pinned source; it is a separate
signing output. Local upload logs and browser evidence are under
`build/companion060/` and are excluded from Git.

Paired hardware must still verify locked-phone APNs/background execution,
WatchConnectivity latency, first displayed panel, disconnected-phone commands,
request/confirmation colors, vehicle wake timing and offline headset playback.
Simulator captures are synthetic rendering checks; automated tests do not prove
physical delivery, playback or vehicle behavior. iOS background work remains
opportunistic, including when Background App Refresh is disabled or an app is
force-quit. Wear OS development/build/test/lint remains paused and untouched.
