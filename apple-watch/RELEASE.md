# Ultra 4 flight opening and compact Completed — 0.13.3 (43), November 24, 2026

The owner explicitly requested release of all completed changes. This coordinated
iPhone/watch release preserves current flight selection and the 40-minute rule.
The flight tile opens on its intended row without the preceding flight above it.
Each row is a single scroll target; initial positioning waits for real eager
layout, and later updates do not reset manual scrolling. Completed uses caption
size; compact field spacing keeps the full countdown inside the Ultra 4 viewport.
No server deployment or database/credential change is needed.

UI source `53d20bfc948b7e2126168f5eba0e210e6b11bf3f` passed core tests
and watch/iPhone SDK typechecks:
https://github.com/agawlbb/FanControl/actions/runs/45321364847
Ultra 4 (49mm), watchOS 27.2 compilation and focused/completed/late-data captures
passed and were visually inspected:
https://github.com/agawlbb/FanControl/actions/runs/45321364665
App Store Connect highest uploaded build was 42; build 43 was unused.
Published to the existing **Internal** TestFlight group. Apple build
`c88ccb03-f251-46db-b850-6eba816222d9` is `VALID`, not expired,
`IN_BETA_TESTING`, marketing version 0.13.3, without non-exempt encryption.
Exact signed source: `f77e1b33fcf0e17b1b56e4dabc5a975361f942d2`.
Exact-source core tests and both SDK typechecks passed:
https://github.com/agawlbb/FanControl/actions/runs/45322303495
Signed archive/export, production APNs entitlements, upload, Apple processing,
existing Internal-group access and temporary signing cleanup passed:
https://github.com/agawlbb/FanControl/actions/runs/45322303385
Release tag: `v0.13.3-build43`, pointing to the exact signed source.
No local app archive or raw release report was downloaded. The existing Ultra 4
completed-row preview remains for user retrieval under its recorded condition.
Update both iPhone and watch.
Real-device Crown/touch scrolling and live phone-update behavior remain checks.

# Previous trip flights — 0.13.2 (42), November 24, 2026

The owner explicitly authorized server deployment and app release after the
change. The selected trip retains earlier flights above the unchanged focused
flight. FlightSync sends its shared current/next focus separately; the watch
still applies the existing 40-minute rule and retains the final flight if no
next flight exists. Earlier rows show Arrival and Completed, with arrival time
in the departure airport's timezone. Focused/following rows retain departure
and countdown. Completed is presentation only, not a new progress signal.
Manual scrolling is not reset by phone updates.

Exact release source: `921e0ab3746d08c9135df15d90b85f7e2fb51ff0`.
Core tests and both SDK typechecks passed:
https://github.com/agawlbb/FanControl/actions/runs/45313971443
67 relevant server tests and Python compilation passed. FlightSync image
`vm-4757709` is deployed, healthy and serving fresh full-trip snapshots.
App Store Connect highest uploaded build was 41; build 42 was unused.
Published to the existing **Internal** TestFlight group. Apple build
`59e1c65a-35cb-4f5e-9e70-60350e0a78e2` is `VALID`, not expired,
`IN_BETA_TESTING`, marketing version 0.13.2, without non-exempt encryption.
Signed archive/export, production APNs entitlements, upload, Apple processing,
existing Internal-group access and temporary signing cleanup passed.
Release tag: `v0.13.2-build42`, pointing to the exact signed source above.
Verified release:
https://github.com/agawlbb/FanControl/actions/runs/45314451669
Update both apps. Paired-watch scrolling, foreground updates and offline
reopening remain physical checks. No local archive/report has been downloaded.

# Flight tile display, scrolling and airport time — 0.13.1 (41), November 23, 2026

The user authorized release after changing flight times to the departure airport's
local timezone, and authorized the needed server deployment. This release keeps
only flight number, city pair, departure time and countdown. Unrequested arrival,
date and provider-status display are removed. Horizontal swipes observe alongside
native vertical scrolling instead of capturing vertical drags at high priority.
The existing 40-minute opening rule and upward access to skipped flights remain.

FlightSync adds each leg's IANA `departure_timezone` from its existing airport
map, without a schema or progress-selection change. The phone retains it in the
trip snapshot; the watch explicitly formats departure in that zone with the
user's locale and daylight-saving rules. Missing/unknown metadata shows a dash,
never a fallback to the device timezone. Countdown and the 40-minute rule still
compare absolute instants. Update both iPhone and watch apps.

Corrected display/gesture source `e56a1d8` passed core tests and both SDK typechecks:
https://github.com/agawlbb/FanControl/actions/runs/45258910328
App Store Connect preflight found 40 as the highest uploaded build and 41 unused.
Timezone source `fb3aeef9d97516d2af508a6103b9d3a9b47338d8` passed core tests
and watch/iPhone SDK typechecks:
https://github.com/agawlbb/FanControl/actions/runs/45260299883
Published to the existing **Internal** TestFlight group. Apple build
`d3629abc-24ec-4b9a-9e30-082771441b6a` is `VALID`, not expired,
`IN_BETA_TESTING`, marketing version 0.13.1, without non-exempt encryption.
Signed archive/export, production APNs entitlements, upload, Apple processing,
Internal-group access and temporary signing cleanup passed on retry attempt 2:
https://github.com/agawlbb/FanControl/actions/runs/45261321460
The first attempt stopped before upload after an Apple provisioning connection
loss. Release tag: `v0.13.1-build41`, pointing to the signed source above.
FlightSync `vm-b9802b2` is deployed, healthy and serving fresh authenticated
snapshots with airport timezones; 67 relevant server tests passed.
Deployment staging, image exports and the superseded image were removed.
No local app archive or raw release report was downloaded.
Paired-device checks remain for touch/Crown scrolling, horizontal navigation,
local airport times when traveling, skipped flights above and OS push delivery.

# Direct FlightSync flight tile — 0.13.0 (40), November 23, 2026

Release explicitly authorized by the user. The iPhone pairs directly with
FlightSync in Settings → FlightSync using the private server secret. FlightSync
owns flight selection and sends direct silent iPhone APNs hints. The phone stores
the full current/next flight and following trip legs and supplies them promptly
to the watch on foreground entry. No HA update is required.

The flight tile includes flight number, city pair, departure/arrival and status.
At 40 minutes after the latest received departure estimate, the watch opens on
the next retained flight if one exists. Skipped flights remain above for scrolling
up; a delayed estimate updates the cutoff, and the final flight remains visible.
This is a local presentation assumption and never changes FlightSync progress.

Source validation passed for `e8faf79`:
https://github.com/agawlbb/FanControl/actions/runs/45251602796
App Store Connect preflight found 39 as the highest uploaded build and 40 available.
Published to the existing **Internal** TestFlight group. Apple build
`189ca4c8-a91e-4709-9273-dbf54c8ecd80` is `VALID`, not expired, and
`IN_BETA_TESTING`, marketing version 0.13.0, without non-exempt encryption.
Signed source: `ad72194b4ed16399989be700360b11a3dff619b9` on `main`.
Signed archive/export, signatures, production APNs entitlements, Apple processing
and existing Internal-group access passed:
https://github.com/agawlbb/FanControl/actions/runs/45252744328
Release tag: `v0.13.0-build40`. Workflow artifacts retain processing evidence;
no local app archive or raw release report was downloaded. Update both apps in
TestFlight. FlightSync image `vm-f9b5f62` is deployed and healthy, with authenticated fresh
flight snapshots and missing/wrong-secret rejection verified. The existing HA
APNs key was copied privately to the VPS after the owner explicitly approved
that source; HA configuration stayed unchanged. Provider ES256 signing passed
an offline check; real iPhone APNs receipt remains a paired-device check.

Paired-device checks remain for secret pairing,
silent-push/background execution, foreground cache retrieval, opening scroll
position, upward access to skipped flights, and scrolling during fresh updates.

# Podcast series and episode title — 0.12.11 (39), November 22, 2026

Split the watch title into two single-line fields: series without the Star Trek
prefix plus abbreviated season/episode (for example, Voyager S4 E8&9), followed
by the episode name. Keep full source titles in accessibility labels. Parsing
handles single episodes, paired episodes, ranges, quoted names and film/fallback
titles without changing feed data or command payloads.

Use available width with smaller side margins and let the playback buttons
expand into remaining vertical room. Keep progress on one line and Mark Complete
on the left/native volume on the right of the bottom 44-point row; no scrolling.
The simulator preview now prefers Ultra 4, otherwise another available Ultra,
and records the actual model/runtime in its artifact. Temporary simulators
created for the preview are shut down and deleted afterward.

Core title tests and both Apple SDK source typechecks passed for source
`fda5faffc3e07c92732e4eb054106dc14fd25305`:
https://github.com/agawlbb/FanControl/actions/runs/45040236984
Unsigned simulator compilation and screenshot capture passed on **Apple Watch
Ultra 4 (49mm), watchOS 27.2**. The long-title screenshot shows both title lines,
progress, playback and the completion/volume row together without scrolling:
https://github.com/agawlbb/FanControl/actions/runs/45040236872
The selected simulator was already installed; the capture script shut it down.
Only the requested screenshot is retained locally at ignored
`build/podcast-preview/watch-podcast-compact-title.png` for user retrieval until
superseded or no longer needed. No app bundle, downloaded ZIP or temporary report
was retained. Physical Crown/paired-iPhone volume and touch responsiveness still
need device checks.

Published at the user's explicit request to the existing **Internal** TestFlight
group. Apple build `0ddea83c-c55f-4b89-88e0-1b23546a6f4e` is `VALID`, not
expired, and `IN_BETA_TESTING`, marketing version 0.12.11, without non-exempt
encryption. Update both iPhone and watch apps through TestFlight.

Signed source: `2b0c358833f0877da79824858b7644195bfaa463` on `main`.
Core tests and both Apple SDK source typechecks passed for that source:
https://github.com/agawlbb/FanControl/actions/runs/45041604461
Signed archive/export, signature and production APNs entitlement checks, upload,
Apple processing and Internal TestFlight access passed:
https://github.com/agawlbb/FanControl/actions/runs/45041604161
Release tag: `v0.12.11-build39`. Processing evidence remains in the workflow
artifact. No local release archive or evidence report was retained. No HA
deployment was needed. Native volume requests Crown focus on active tile entry;
this release does not claim verified physical focus or paired-iPhone volume
response.

## Included compact Podcast layout

Use the requested four-row layout without a ScrollView: a title capped at two
lines (truncating longer titles), one progress line, the existing playback row,
and Mark Complete on the left with native paired-iPhone volume on the right.
Keep volume visible at 44 by 44 points and preserve its existing active-scene
Crown-focus lifecycle. Completion remains disabled while a command is pending;
volume stays enabled. Error/Refresh and nonredundant provider status remain bounded
below the controls when needed; routine Playing/Paused/Ready status is omitted
because the playback control already shows the relevant state.

The long-title simulator fixture now matches the length seen in the user's photo.
The user reported that released 0.12.10 did not show Mark Complete or give volume
Crown focus on an Ultra 4; its single short-title simulator screenshot did not
establish those physical behaviors. This change removes that offscreen design.
Remaining checks: normal/larger text on the Ultra, title truncation, visible
completion and volume, playback taps, horizontal swipes without activation,
pending/error states, Crown volume on entry and after wrist-down/up. Core tests
and SDK typechecks cannot prove paired-iPhone volume response. These layout
changes are included in the user-authorized 0.12.11 release above. No HA change
or deployment is required.

# Podcast completion access — 0.12.10 (38), November 22, 2026

Show episode details, playback buttons and Mark Complete on the first screen.
Place native paired-iPhone volume underneath that viewport, reachable by touch
scrolling. Keep it mounted in a non-lazy stack and retain the existing active-scene
Crown focus, so moving it below the fold does not remove its focus coordinator.
Compact 36-point playback/completion rows preserve room for the title and progress.
Error/status details follow volume. Horizontal navigation observes the full tile
alongside native scroll. No extra volume screen or speaker shortcut is added.
The existing completion action, pending-command protection and feedback remain.
No HA API changes or deployment are required.

Paired-watch checks remain: the bottom completion row is visible on small and
large displays, including larger text and long episode/error content; completion
stays disabled during pending commands; vertical scrolling, horizontal navigation,
ordinary playback taps and paired-iPhone volume still work without accidental
completion. In particular, confirm Crown volume works immediately while its
control is below the fold, after scrolling and after wrist-down/up. A simulator
preview checks layout only, not paired-iPhone Crown behavior. The user explicitly
authorized this release.

Published to the existing **Internal** TestFlight group. Apple build
`d9b561df-a63b-4aa8-8592-498b7d12b52c` is `VALID`, not expired, and
`IN_BETA_TESTING`, marketing version 0.12.10, without non-exempt encryption.
Update both iPhone and watch apps through TestFlight.

Signed source: `ea145e8b4310b3d35003f5f275c7f045ca7e2641` on `main`.
Core tests and watch/iPhone SDK source typechecks passed:
https://github.com/agawlbb/FanControl/actions/runs/45032298991
The final simulator screenshot verifies that volume is fully below the initial
viewport while title, progress, playback and Mark Complete remain visible:
https://github.com/agawlbb/FanControl/actions/runs/45031192542
Signed archive/export, signature and production APNs entitlement checks, upload,
Apple processing and Internal TestFlight access passed:
https://github.com/agawlbb/FanControl/actions/runs/45032298801
Release tag: `v0.12.10-build38`. Processing evidence remains in the workflow
artifact; no local release archive or evidence report was retained. The requested
simulator image remains at ignored
`build/podcast-preview/watch-podcast-volume-offscreen.png` for user retrieval
until it is superseded or no longer needed. No HA deployment was needed.

# Podcast volume and scrolling — 0.12.9 (37), November 17, 2026

The podcast tile uses the native paired-iPhone volume control with Digital Crown
focus while active. Exercise keeps its watch-local volume control. Podcast
vertical scrolling now recognizes alongside horizontal tile navigation, retaining
the existing navigation thresholds. Scrolling, navigation and volume remain
available during pending playback commands; playback buttons stay disabled.
Other tiles retain their existing gesture handling. No HA update is required.

Core tests, watch/iPhone SDK source typechecks, and unsigned watch simulator
compilation and screenshot capture passed. Simulator evidence:
https://github.com/agawlbb/FanControl/actions/runs/44171921667

Signed source: `1a66b3ee39ac9e273dc21473f61812d814139f12` on `main`.
Published to the existing **Internal** TestFlight group. Apple build
`66927559-4292-4c1a-880e-97f2b7cec092` is `VALID`, not expired, and
`IN_BETA_TESTING`, marketing version 0.12.9, without non-exempt encryption.
Signed archive/export, signature and production APNs entitlement checks, upload,
Apple processing and internal access passed:
https://github.com/agawlbb/FanControl/actions/runs/44173284698
Release tag: `v0.12.9-build37`. Processing evidence is retained in the workflow
artifact. Update both iPhone and watch apps through TestFlight.

Remaining paired-watch checks: slow/fast vertical drags, diagonal gestures,
horizontal navigation once per swipe, gestures over buttons without activation,
long titles/error content, pending commands, and iPhone volume after entry and
wrist-down/up. Confirm Exercise still adjusts watch volume. Simulator screenshots
do not establish physical gesture responsiveness or audio volume behavior.

# Tile swipe touch handling — 0.12.8 (36), November 17, 2026

Horizontal tile navigation recognizes 12-point drags on tile content, including
over buttons, instead of waiting for a 35-point drag outside the scroll view.
The high-priority gesture cancels child button touches before navigating; it is
not simultaneous with command taps. Empty tile space is also swipeable. Driving,
Exercise, Podcast and generic device tiles share the same gesture policy.
No HA API or command delivery changes are required.

Core regression coverage checks short left/right drags and rejects tap jitter,
vertical movement and diagonal movement as navigation. The macOS core workflow
also typechecks the watch UI without an app build.
Remaining paired-watch checks: swipe starting on every command/playback button
without activating it, swipe at either end of the tile order without activation,
tap each control normally, scroll tall tiles vertically, use the Exercise native
volume control/Crown, and long-press for Settings. Check small and large displays.
Published at the user's explicit request to the existing **Internal** TestFlight
group. Apple build `68d479af-748d-4d60-a64f-ebeab662405c` is `VALID`, not
expired, and `IN_BETA_TESTING`, marketing version 0.12.8, without non-exempt
encryption. Update both iPhone and watch apps through TestFlight.

Signed source: `cd3da56d9f2f3a74bdd14f33f1161d0c380367e3` on `main`.
Core tests and both Apple SDK source typechecks passed:
https://github.com/agawlbb/FanControl/actions/runs/44074529517
Signed archive/export, signature and production APNs entitlement checks, upload,
Apple processing and Internal TestFlight access passed:
https://github.com/agawlbb/FanControl/actions/runs/44074529759
Release tag: `v0.12.8-build36`. Processing evidence is retained in the workflow
artifact and locally under ignored `build/release36-evidence/`.
No HA deployment was needed. Paired-watch touch checks above remain physical
verification; automated checks do not establish actual touch recognition.

# Background music delivery — 0.12.7 (35), November 15, 2026

Published at the user's explicit request to the existing **Internal** TestFlight
group. Apple build `5b0031ec-d8e1-4163-b522-aa0aef2cdb8a` is `VALID`, not
expired, and `IN_BETA_TESTING`, marketing version 0.12.7, without non-exempt
encryption. Update both iPhone and watch apps through TestFlight.

- Persist background audio and its playlist metadata before WCSession's file
  callback returns; recover the delivery inbox after interruption/relaunch.
- Install local deliveries during background wakes and session activation without
  requiring an active screen or live phone reachability. Keep failed installs
  queued, and preserve the old library until the replacement fully verifies.
- Preserve incoming, installed and playing generations by directory name, avoiding
  URL-form differences that allowed cleanup to delete required files.
- Verify installed bytes after cleanup before sending the saved receipt. Reserve
  phone 100% completion for that receipt, rather than an empty outgoing queue.

Signed source: `d7d924d92a5a7733062714b578f4cdf781a6ee72` on existing branch
`fix/music-sync-and-settings`. All **133 core tests** and both app SDK typechecks
passed for that exact source:
https://github.com/agawlbb/FanControlWatch/actions/runs/43739230927
Signed archive/export, signatures, production APNs entitlement checks, upload,
Apple processing and Internal TestFlight access passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/43739230864
Release tag: `v0.12.7-build35`. Processing evidence is retained in the workflow
artifact and locally under ignored `build/release35-evidence/`.

Actual paired-watch screen-off transfer, installation and speaker playback remain
physical checks; automation does not prove OS scheduling or playback. No HA
change or deployment was needed. Main remains unchanged and the fix branch
awaits merge approval. No new branch, tester group or external/App Store release
was created.

---

# Offline MP3 playback checks — 0.12.6 (34), November 15, 2026

The user explicitly requested this release. Related work continues on the same
claimed `fix/music-sync-and-settings` branch. Implementation source:
`980948333ab0c5675e243f96bf10afdb8525ff05`.

- Verify the actual saved audio size and SHA-256 before opening the decoder.
- Supply explicit MP3/M4A format hints to AVAudioPlayer.
- Preserve native read, decoder, audio-session and asynchronous decoding errors
  rather than replacing every failure with Track could not play.
- Stop automatic playback reattempts after a failure until explicit user action,
  and show playback failures on the existing playback controls only.

The user's supplied MP3 was decoded and inspected locally without errors. Only
a generated tone with matching MP3 encoding characteristics is stored in Git/CI.
All 125 implementation tests and both app SDK typechecks passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/43729965607
The generated tone initializes AVAudioPlayer and decodes PCM through AVAudioFile
on macOS without playing sound. The user's specific watch failure remains
unconfirmed; this release improves file preparation and preserves native evidence.

Published to the existing **Internal** TestFlight group. Apple build
`1fccc5ea-55a1-4aaf-95e2-ab88977b4e81` is `VALID`, not expired and
`IN_BETA_TESTING`, marketing version 0.12.6, without non-exempt encryption.
Update both the iPhone and watch apps through TestFlight.

Signed source: `cf93d19e18236e20423715f1452d6e99874384db` on the existing
`fix/music-sync-and-settings` branch. All **125 core tests** and both app SDK
source typechecks passed for the exact release source:
https://github.com/agawlbb/FanControlWatch/actions/runs/43730563882
Signed archive/export, signatures and production APNs entitlement checks, upload,
Apple processing and Internal TestFlight access passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/43730564602
Immutable release tag: `v0.12.6-build34` at the signed source. Apple processing
evidence is retained in the release artifact and this record. The branch and its
checkout claim remain available for related follow-ups. Main remains unchanged
pending explicit merge approval. No HA deployment is needed. Physical-watch checks remain
for the supplied MP3 on the speaker/headphones, interruptions and offline playback.
Both apps need updating after publication. This authorization is for this release.

---

# Interrupted music recovery — 0.12.5 (33), November 15, 2026

The user explicitly requested this release. Work continues on the existing claimed
`fix/music-sync-and-settings` branch; implementation source is
`c3acc406e96b2199856ad9564171c27448da8408`.

- A live WatchConnectivity notReachable/session-inactive error pauses music sync
  instead of marking it permanently failed or deleting downloaded chunks.
- Existing visible-entry/reachability handling resumes the manifest-scoped partial
  file at its saved chunk boundary. The regression test resumes at the photographed
  688128-byte offset and verifies the complete file. Invalid or corrupt prefixes
  cannot be installed; full SHA-256 verification remains required.
- Background audio verifies its content and creates the destination directory at
  the actual write boundary before atomic saving. Diagnostics distinguish reading,
  saving and installing background audio. Late live replies safely defer to a
  background delivery that has already installed a verified track.

All 121 implementation core tests and both SDK typechecks passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/43720023118
Published to the existing **Internal** TestFlight group. Apple build
`feee7f07-e34e-4ca4-a3fb-77cceaa95c62` is `VALID`, not expired and
`IN_BETA_TESTING`, marketing version 0.12.5, without non-exempt encryption.
Update both the iPhone and watch apps through TestFlight.

Signed source: `b602e7a65acd73c0f2b41c4dd9e2d4cede4a9ff8` on
`fix/music-sync-and-settings`. All **121 Swift core tests** and both app SDK
source typechecks passed for this release source:
https://github.com/agawlbb/FanControlWatch/actions/runs/43723468186
Signed archive/export, signature and production APNs entitlement checks, upload,
Apple processing and Internal TestFlight access passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/43723468369
Immutable release tag: `v0.12.5-build33` at the signed source. Apple processing
evidence is retained in the workflow artifact and this record. Main remains
unchanged pending explicit merge approval; the existing branch/checkout claim
are retained for related follow-ups.
No HA deployment is needed. Physical-watch checks remain for link loss/recovery,
screen-off background completion, one-song sync and playback. Automated tests do
not establish real-device delivery or playback. Both apps need updating after
publication. Authorization applies to this release only.

---

# Music storage fix and watch settings — 0.12.4 (32), November 15, 2026

The user explicitly requested consolidating both fix branches, deleting the old
branches and releasing the combined app. The single ongoing working branch is
`fix/music-sync-and-settings`, based on main
`dcd045a8ede6d515f3d8815735a88af7103a24fd`. It preserves all commits from
`fix/music-first-chunk` (`d653465f4941b670eb163b26f64c6b260be58a7f`) and
`fix/watch-settings-cleanup` (`599850a4a6f12dc2eb71b3aaad16b3079eccfcad`).

- The first audio-chunk write creates its staging directory at the write boundary
  and saves real data directly. Missing-staging regression tests reproduced the
  photographed NSCocoaErrorDomain 4 with the old writer. Later chunks still
  require the correct existing prefix; whole-file SHA-256 remains mandatory.
- One native watch settings menu replaces the duplicated layouts. Routine setup
  instructions are removed. Watch ID/server are available only on the Connection
  details page, and sync status appears only beside Sync music.
- Diagnostics shows recorded activity without static timing explanations or
  duplicated music errors. Forget connection requires a destructive confirmation.

Published to the existing **Internal** TestFlight group. Apple build
`c9a81f2c-ccce-4d72-bc66-82916c36273d` is `VALID`, not expired and
`IN_BETA_TESTING`, marketing version 0.12.4, without non-exempt encryption.
Update both the iPhone and watch apps through TestFlight.

Signed source: `e4147ea11e55590ec1f716dbf7fc8551d3d095fe` on
`fix/music-sync-and-settings`. All **115 Swift core tests** and both app SDK
source typechecks passed together:
https://github.com/agawlbb/FanControlWatch/actions/runs/43717925835
Signed archive/export, signatures and production APNs entitlement checks, upload,
Apple processing and Internal TestFlight access passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/43718143480
Immutable release tag: `v0.12.4-build32` at the signed source. Apple processing
evidence is retained in the release workflow artifact and this record.
The old fix branches were removed locally/remotely after both original heads were
verified as ancestors of the pushed combined branch. Main remains unchanged;
merging to main was not requested. The combined branch and its checkout claim
remain available for related follow-ups. No HA deployment is needed. Physical checks remain for one-song transfer, wrist-down/background
completion, offline playback, and settings layout/navigation. Automated checks do
not establish physical-watch behavior. This request authorizes this release only.

---

# Readable music sync failures — 0.12.3 (31), November 15, 2026

The user explicitly authorized finishing this already-started release. There is
no standing authorization for subsequent releases; each needs a new explicit
request. Task `fix/music-sync-feedback` starts at main
`6ae6cffe31d7df59c77a2f2c848cad2a4af13f75`.

- Sync progress and errors are separate from playback and appear by the existing
  sync controls, never on the Exercise panel.
- The first failure remains readable across repeated phone updates, navigation,
  playback events and app restarts. Passive updates do not restart that failed
  attempt. A new explicit sync can retry; verified background installation can
  complete an interrupted live transfer.
- Existing Diagnostics retain a bounded sync history. A matched watch failure
  is also retained in the phone's existing music error area.
- Errors identify requesting, saving or installing audio and preserve sanitized
  domain/code. Chunk length, offset, reply mismatch and checksum failures have
  distinct wording. Screen sleep or a lost live link pauses foreground work
  without treating it as an unexplained transfer failure.

Published to the existing **Internal** TestFlight group. Apple build
`409315da-8af9-487a-972b-4aff3107bda6` is `VALID`, not expired and
`IN_BETA_TESTING`, marketing version 0.12.3, without non-exempt encryption.

Signed source, merged to main: `dc95fffc26053d8001ab07a6fc1dfdd8e8e5180b`.
All **112 Swift core tests** and both app SDK typechecks passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/43713182207
Signed iPhone/watch archive/export, signatures and production APNs entitlement
checks, upload, Apple processing and Internal-group assignment passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/43713373876
Immutable release tag: `v0.12.3-build31` at the signed source. Apple processing
evidence is retained in the release workflow artifact and this record.
This corrects the reported error placement, flashing and erased failure evidence.
The underlying device audio-transfer failure is not yet established; the retained
stage/code is needed to diagnose it. Physical checks remain for settings-only
feedback, persistence, one-song delivery, wrist-down and offline playback.
Both apps need updating after publication. No HA deployment is needed.

---

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

Published to the existing **Internal** TestFlight group. Apple build
`212dfd32-0dc9-4ab9-961e-a2fb7d95b326` is `VALID`, not expired and
`IN_BETA_TESTING`, marketing version 0.12.2, without non-exempt encryption.

Signed source, merged to main: `6bcbe32746a0cda8fffa2365e184dcb156af1daf`.
All **106 Swift core tests** and both app SDK typechecks passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/43663475154
Signed iPhone/watch archive/export, signatures and production APNs entitlement
checks, upload, Apple processing and Internal-group assignment passed:
https://github.com/agawlbb/FanControlWatch/actions/runs/43663628978
Immutable release tag: `v0.12.2-build30` at the signed source. Apple processing
evidence is retained in the release workflow artifact and this record.
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
See [HA deployment evidence](https://github.com/agawlbb/FanControl/blob/main/DEPLOYMENT-PHONE-MESSAGES.md).

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
