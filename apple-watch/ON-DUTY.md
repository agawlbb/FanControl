## Exclusive flight swipe/tap and Close-only crew — November 24, 2026

Source `698a6cf644a31416ed711602c02523b23407cd45` is prepared and
verified by core regression tests and watch/iPhone SDK typechecks:
https://github.com/agawlbb/FanControl/actions/runs/45418031437
A new app build/release is required; this follow-up did not request one.
No server deployment or crew data/cache changes are needed.

The flight page no longer nests a Button tap recognizer under its drag gesture.
A single native exclusive DragGesture-before-TapGesture arbitrates each touch:
recognized drags can only navigate or be ignored, never open crew on release.
Only the successful tap branch (or accessibility activation) opens crew.
Flight-specific swipe routing uses radial minimum travel and the dominant axis,
with vertical priority on exact diagonals. This removes the previous gap between
the two 1.5x direction thresholds. Shared gestures on other panels are unchanged.
Each swipe still steps one flight, boundaries do not wrap, and Crown selection
is unchanged. Returning a recognized drag to its starting point does not open crew.

Crew presentation retains the native sheet Close button and removes the custom
return icon. Native dismissal continues to restore flight Crown focus and the
selected flight. The flight number, crew list and missing-data state remain.
Regression coverage includes diagonal routing, radial threshold, zero/short
drag rejection, directional page stepping and preserved unrelated tile gestures.
Native arbitration, quick/curved/reversed swipes over text and empty space,
true taps, long-press Settings, VoiceOver activation and Close/Crown restoration
remain simulator/paired-watch interaction checks. No simulator/distributable
build was dispatched and no task artifact was created.

## Tap a flight for crew — November 24, 2026

Prepared in app source `fe18fefde4a54854bfa6234c486dfa87769078e3` and
FlightSync source `e1a4f1b`; explicitly authorized server deployment and
coordinated 0.13.4 (44) release are finished and verified.
This includes the earlier prepared discrete flight pages and IATA labels.

Tap a flight page to open its crew names and employee numbers. A fixed
`arrow.uturn.backward` return button dismisses the crew screen and restores
pager Crown focus without changing the selected flight. The crew list can scroll
independently; the underlying flight Crown handler is disabled during presentation.
Details stay tied to the tapped flight identity, with current same-flight metadata
when available and captured details if the trip removes that flight. Missing
crew displays No crew information. Partial names remain usable and employee
numbers remain strings, preserving leading zeros. No role/seniority/tail/notes
fields are added to the screen or private crew payload.

FlightSync reads its existing durable flight metadata within the same scoped
snapshot transaction, adding optional per-flight `crew` with `first_name`,
`last_name`, `employee_number`. This remains behind the existing separate phone
pairing secret and participates in the existing change-hint digest. The phone
retains crew in the whole-trip offline snapshot and WatchConnectivity envelope.
Old caches/servers without crew remain compatible and show the missing-data state.
No database schema, HA, credentials or public endpoint changes are required.

69 relevant server tests and Python compilation passed, including crew isolation
between flights, completed-flight retention and crew-only hint changes.
Core cache/leading-zero tests and both Apple SDK typechecks passed:
https://github.com/agawlbb/FanControl/actions/runs/45409169757
FlightSync `vm-e1a4f1b` is deployed and fresh. Signed app source
`43d3c0b9b950c2a67b950681b741a7dc8dd92b56` passed core/SDK checks
(run 45410648912) and release run 45411690814. Apple build
`aefb2ec5-bf60-4e2b-8fdd-3177f8b9337e` is VALID and IN_BETA_TESTING;
existing Internal-group access and signing cleanup passed. No new simulator
run was requested or dispatched. Physical checks
remain for tile tap versus swipe, native crew Crown scrolling, return-to-same-flight,
missing crew, and live updates while details are open. No task artifact retained.

## Discrete flight pages and IATA labels — November 24, 2026

Source `354fbbec52e57295d3bdbad765ddd07ea49e92d5` is prepared and verified
by core tests and watch/iPhone SDK typechecks:
https://github.com/agawlbb/FanControl/actions/runs/45407258778
Released in Internal TestFlight 0.13.4 (44) with the crew feature after the
owner explicitly requested coordinated delivery.
No server deployment, schema or credential change is needed.

One flight is rendered at a time, without a ScrollView or neighboring partial
rows. One dominant upward swipe selects the following flight; downward selects
the previous flight. Crown positions use discrete one-flight detents, with no
wrapping beyond the first/last flight. Horizontal swipes retain main-tile
navigation. Entry still uses the existing opening index and 40-minute rule.
Passive updates retain the selected flight when its number/scheduled-departure
identity remains present, even if earlier legs disappear or indices change.
An empty trip clears selection; a different trip uses its opening focus.

Labels normalize cached and live mixed ICAO/IATA routes using FlightSync's
existing supported-airport registry: KCLT/KBOS become CLT/BOS, CYVR becomes YVR,
and supported Caribbean codes retain their explicit mappings. Unknown four-letter
identifiers show a dash instead of being guessed or displayed as ICAO.
Existing three-letter codes are uppercase. Raw trip data and timezone metadata
remain unchanged. Completed/arrival presentation, compact text and departure-airport
local times are preserved.

Regression coverage includes opening focus, single-swipe stepping, horizontal/
diagonal discrimination, bounded Crown positions, empty/late trips, passive
selection retention/reordering, and mixed US/Canadian/Caribbean code labels.
Actual swipe/Crown focus, haptics and direction remain simulator/paired-watch
checks; the signed 0.13.4 (44) release is published, with no new simulator run.
The old scrolling-layout screenshot was superseded and removed from
`build/flight-preview-53d20bf/`; no task artifact is retained.

## Ultra 4 flight opening and Completed size — November 24, 2026

Source `53d20bfc948b7e2126168f5eba0e210e6b11bf3f` is prepared and verified;
released in Internal TestFlight 0.13.3 (43). No server deployment is required or performed.
Each flight now has one scroll target, including its trailing divider. Entry
positioning waits for real eager-row layout dimensions rather than a single
task yield or estimated lazy positions. The scroll area clips content to its
viewport so the previous row does not show above the selected flight.
Positioning remains once per entry; later phone updates do not reset scrolling.
The existing shared focus and local 40-minute rule are unchanged.
Completed uses caption size; tighter field spacing keeps the full countdown
inside the Ultra 4 viewport.

Core tests and watch/iPhone SDK typechecks passed:
https://github.com/agawlbb/FanControl/actions/runs/45321364847
Unsigned compilation and visual capture passed on **Apple Watch Ultra 4 (49mm),
watchOS 27.2**:
https://github.com/agawlbb/FanControl/actions/runs/45321364665
Inspected focused AA105, completed AA104, and initially empty/late-data AA105
screenshots: each expected flight starts at the top without the preceding row;
all requested fields and the complete countdown fit. Synthetic simulator-only
fixtures do not pair or fetch flight data. The capture requires the actual Ultra 4
model and all three screenshot files. The script shuts down the selected existing
simulator; it deletes only a simulator it created.
The first capture script's macOS Bash empty-array error was corrected; subsequent
visual checks caught the initial positioning and countdown clipping before the
final passing run. Real-device Crown/touch scrolling and live phone-update
behavior remain physical checks.

Only the completed-row screenshot is offered for user review at ignored
`build/flight-preview-53d20bf/watch-flight-completed.png`; retain until retrieved
or superseded. Downloaded ZIPs, extracted app bundles and superseded/intermediate
screenshots are absent. The owner subsequently explicitly requested release.
Signed source `f77e1b33fcf0e17b1b56e4dabc5a975361f942d2` passed core/SDK
checks (run 45322303495) and release run 45322303385. Apple build
`c88ccb03-f251-46db-b850-6eba816222d9` is VALID and IN_BETA_TESTING;
existing Internal-group access and signing cleanup passed. Update both apps.

## Previous flights in the selected trip — November 24, 2026

Released in Internal TestFlight 0.13.2 (42); FlightSync deployment verified. FlightSync retains the whole selected trip
in source order and sends optional `focused_flight_index` from its existing
current/next selector. The watch starts there and applies the unchanged 40-minute
departure cutoff, retaining the final flight when no next flight exists.
Rows above that opening focus show Arrival and Completed instead of Departure
and Time to go. Arrival is formatted in the departure airport's timezone, as
requested for all flight times. This is presentation only, not a new flight
completion signal. Focused/following rows retain departure and countdown.
Phone updates do not reposition an already scrolling view. Old cached payloads
without the focus field default to zero. Server image `vm-4757709` is deployed and healthy. Update both apps.
Paired-device touch/Crown scrolling, foreground updates and offline reopening
remain physical checks. The owner explicitly authorized server deployment and app release.
Exact source `921e0ab3746d08c9135df15d90b85f7e2fb51ff0` passed core/SDK
checks (run 45313971443); release run 45314451669 passed Apple processing
and existing Internal-group access. Apple build `59e1c65a-35cb-4f5e-9e70-60350e0a78e2`
is VALID and IN_BETA_TESTING.

# Direct FlightSync flight tile — Apple 0.13.1 (41), November 23, 2026

## Released 0.13.1 (41) correction — November 23, 2026

Limit the visible flight fields to flight number, city pair, departure time in
the departure airport's timezone, and time to go. Remove the unrequested arrival time,
departure date, and provider status (including predeparture). The retained trip
data and the 40-minute opening-position rule are unchanged.

The flight tile now observes horizontal swipes simultaneously with native
vertical scrolling. Its former high-priority drag could capture vertical touch
movement before checking the direction on release. Keep the existing horizontal
direction threshold and other tiles' command/control gesture handling unchanged.
The opening position is still applied once per visible entry; phone updates
must not reposition a user who is scrolling. FlightSync supplies optional IANA
`departure_timezone` metadata for each leg using its existing airport map. The
app formats that flight's departure in the airport zone, preserving locale and
daylight-saving rules independently of the phone/watch timezone. Unknown or
missing timezone metadata shows a dash rather than a device-local time. Both
apps must be updated so phone/offline/watch snapshots retain this metadata.
Countdown and opening cutoffs continue to use absolute instants. The user
authorized the needed server update and the app release after this change.
Apple processing and existing Internal TestFlight access passed in run
https://github.com/agawlbb/FanControl/actions/runs/45261321460 .
Signed source: `fb3aeef9d97516d2af508a6103b9d3a9b47338d8`.
Paired-watch touch/Crown checks remain
for scrolling in both directions, including over text/dividers, horizontal
navigation, and returning to the skipped flight above the opening position.

The iPhone pairs directly with FlightSync in Settings → FlightSync using its
separate server secret. It is validated against the fixed HTTPS FlightSync
endpoint and saved only in the iPhone Keychain. HA never receives this secret,
selects these flights, or transports this flight snapshot. Existing HA sensors,
automations, and older clients retain their behavior.

FlightSync API version 1 owns current/next selection through the shared progress
tracker. Its snapshot contains the present flight, or the next flight when none
is active, followed by every remaining flight in that trip's source order.
Flight number, city pair, departure/arrival, scheduled/actual times, status, route
and delay are retained together. Authoritative empty trips clear the old list.

FlightSync sends silent APNs change hints directly to the iPhone topic
`dev.fancontrol.watch`; the phone fetches and persists a whole trip, then publishes
it through WatchConnectivity. On watch foreground entry, the watch asks the phone
once: the phone returns the cached trip promptly and starts one direct FlightSync
refresh. Foreground phone refresh and OS background refresh recover missed hints.
No direct watch network read or HA flight read is involved. On the existing tile,
scroll down to see each following flight and its flight number. Saved data is
gray when FlightSync's source observation is stale.

The watch chooses its opening scroll position locally. At 40 minutes after a
flight's latest received departure estimate, it assumes that flight has begun
for display purposes and opens on the following flight when one exists. It
skips consecutive elapsed flights but keeps the final flight visible if there
is no next flight. All skipped rows remain above the opening position for
scrolling up; no flight is removed, marked as actually departed, or written back
to FlightSync. A later estimate replaces the old cutoff. The position is
recalculated on each visible tile entry, including reopening offline with saved
data. Phone updates during an open session do not override manual scrolling.
This presentation change requires an app build only, with no server change.

Server setup requires `FLIGHTSYNC_FANCONTROL_TOKEN_FILE`,
`FLIGHTSYNC_FANCONTROL_APNS_CONFIG_FILE`, its existing Apple provider signing key,
and `app/fancontrol_schema.sql`. The JSON APNs configuration has `team_id`,
`key_id`, `key_file`. Registrations survive restart; unchanged digests do not
resend. Secret rotation excludes old registrations. Unlinking clears phone
credentials/cache and asks FlightSync to unregister this phone. The server secret
and APNs tokens are absent from watch snapshots and diagnostics. APNs acceptance
is not device receipt, and iOS may defer background delivery.

Released in FanControl 0.13.1 (41) for iPhone/watch, using the FlightSync direct
API. No HA update is required. FlightSync image `vm-b9802b2` is deployed with the privately installed existing
APNs provider key; the app release is published in Internal TestFlight. Paired-device checks remain for secure pairing, real silent
push delivery, immediate foreground cache retrieval, offline/stale display,
scrolling, empty trips and unlink/relink.
Also verify on a paired watch that opening at the 40-minute boundary positions
the next flight at the top, skipped flights remain accessible above, the last
flight can align at the top, and updates do not jump while scrolling.

The notes below describe historical released HA-backed behavior.

> Message behavior below describes the original release. It is superseded by
> phone-only storage and 12-hour/manual dismissal with HA 0.14.0 and the next
> iPhone build. Arrival no longer clears messages; HA no longer retains them.

# On Duty tile and readable iPhone messages

Task `feature/on-duty`, based on canonical main
`d21ffd123048f34547e5ccaab7af12aecbe2a025`. Requires FanControl HA 0.12.0.

The read-only tile shows city pair, departure time in the watch's local timezone,
and time to go. No flight number. FlightSync owns flight selection. Stored
observations display gray at entry; fresh available observations turn teal.
Existing HA hints, iPhone snapshots, watch transfer and bounded entry reads are
reused. A received On Duty snapshot refreshes only passive flight presentation;
it cannot confirm commands. The countdown runs locally and stops at zero.

The iPhone Messages section keeps the title and full body of automation alerts.
Tapping a banner opens a scrollable message with selectable text and a Done button,
including when the app starts from closed. Messages persist locally for offline
reading. HA snapshots reconcile the full list. On `flight_arrived`, the prepared
HA automation clears all messages; the next successful snapshot removes them
from view, including an open message. Notification Center is unchanged.
Unlinking or replacing the pairing clears private local messages.

The On Duty panel is configured and these two HA automations are enabled:
`automation.joe_watch_on_duty_tile` and
`automation.joe_watch_flightsync_messages`. See the HA repository's ON-DUTY.md.
No FlightSync or relay change is required. Version 0.10.0 (24) is published to the
existing Internal TestFlight group;
HA 0.12.0 is deployed and loaded after one validated restart. Phone/watch app
installation and remaining physical checks are user/device actions.

Validation: all 78 Swift core tests and iPhone/watch source typechecks passed on
[Mac core-tests run 42040629167](https://github.com/agawlbb/FanControlWatch/actions/runs/42040629167),
commit `ce2db5ee20b0541808afc2cdf50104df83033b7c`. Release/device checks still needed: stored gray → updated teal,
local countdown and timezone rendering, notifications tapped with phone app cold
and warm, and arrival clearing on refresh after phone suspension.

## Gray opening display correction — 0.10.1 (25)

The original On Duty implementation omitted its fields from ObservationCache,
so a live flight could be displayed but was not saved for the next opening.
The correction retains one complete valid city-pair/departure observation from
entry reads and phone snapshots. Saved data contains no availability/freshness
flag; opening still starts gray. An incoming available snapshot supplies the
actual live state for teal presentation. Unavailable/partial updates preserve
the saved pair and departure together, gray. Existing credential/watch/role scope
is retained. No HA or automation changes are needed.

All 80 Swift tests and iPhone/watch source typechecks passed on
https://github.com/agawlbb/FanControlWatch/actions/runs/42054731006.
After upgrading, one successful update seeds the cache if no earlier flight data
was saved by the previous build. Paired-watch opening/rendering checks remain.

The correction is published as 0.10.1 (25) to the existing Internal TestFlight group.
Apple processing and assignment passed in run
https://github.com/agawlbb/FanControlWatch/actions/runs/42055189243.
