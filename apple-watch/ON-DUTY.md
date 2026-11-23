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
