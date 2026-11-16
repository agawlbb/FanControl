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
