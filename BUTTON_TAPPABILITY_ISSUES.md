# Button tappability review — October 20, 2026

Initial status: recorded and inspected only. The Apple Watch and shared HA items were subsequently authorized for implementation; current status follows.

## Implementation status — October 20

- Apple Watch 0.5.2 (14): gray readiness gates removed, displayed-state toggle reversal preserved, stale/initial fan speed drafts enabled with existing timing, connection accessibility migrated for locked background refresh, and local selection reloaded before presenting controls. Button catalog and remaining legitimate restrictions are committed in apple-watch/ISSUES.md.
- Push tracing: bounded HA attempts and relay/APNs results correlate with persistent watch receipts, refresh/save outcomes and first app selection. Watch Settings diagnostics and HA Download diagnostics expose the evidence. Unreported receipt remains unknown.
- HA 0.6.3: test harness uses uv 0.13.4/Pillow 13.0.0 overrides with real HA 2026.10.2 runtime validation. 205 integration/relay tests passed; signed Apple build passed 36 Swift tests and archive/export checks. Source committed and pushed to each project's existing codex/push-refresh branch.
- Wear OS remains paused and unchanged. No Wear OS builds, tests, lint or validation were run for this work.
- Physical-watch/car checks, live HA/relay deployment and TestFlight submission remain outstanding. Successful background persistence is implemented; actual silent push delivery is not established by automated tests. See apple-watch/BUILD-14.md and ha-integration/PUSH-DIAGNOSTICS.md for build evidence.

## Required design

A configured control should generally accept a tap as soon as its panel is displayed. Gray communicates unconfirmed evidence, not lack of interactivity. Toggle taps request the opposite of the displayed state, as one absolute intent; a late read must not invert it. Initial gray CLOSED garage/trunk presentation must accept OPEN immediately. Requested presentation stays separate from confirmed observations.

## Reported issue

Driving trunk was gray and could not be tapped until state confirmation. Preserve this as an unresolved physical-watch report. Current Apple Watch source enables an unknown cover displayed CLOSED, so static inspection does not establish the cause or installed-build behavior. Check cold entry, unavailable reads, pending unrelated commands, transitional cover states and installed version before declaring resolved.

## Apple Watch catalog

Source: apple-watch/WatchApp/ControlsView.swift and FanControlApp.swift.

| Control | Blocking condition | Finding |
| --- | --- | --- |
| Driving garage and trunk | Observed opening/closing; unrelated command busy | Unknown CLOSED is currently enabled; transitional states still block taps. Review against displayed-state reversal rule. |
| Driving and Work Morning climate | No climate availability, no Boolean climate reading and no matching pending feedback | Initial display says OFF but can be disabled. Direct violation of immediate displayed-state interaction. |
| Fan/light/switch/input_boolean power | No known on/off observation and no pending power feedback | Cold/unknown state disables power. Cached known state is tappable even before freshness. Define initial presentation/intent without inventing confirmed state. |
| Fan slower/faster | State not fresh, percentage missing, invalid power state, or conflicting busy command | Speed draft cannot be adjusted immediately from stale cached speed. Pending ON is an explicit allowed exception. |
| Script/scene Run | Missing/unknown/unavailable state, stale observation, or busy command | Dispatch action unnecessarily depends on observed readiness/freshness. |
| Start/Stop Exercise, Leave for Work, Honk Horn, Podcast | Any busy command | No initial freshness gate; cataloged pending-conflict restriction. |
| Sync exercise music | Sync already running; settings entry also requires connection | Setup/dependency restriction; not a vehicle state-confirmation gate. |

Pair watch, connection settings, forget connection, pair/cancel pairing and watch-speaker action have no explicit disabled modifier in the inspected views. Gray alone does not disable a button. A visible/valid session and matching approved target are still required by command handling.

## Wear OS catalog (development paused)

Read-only inspection; no Wear OS changes or validation performed.

| Control/surface | Blocking condition | Finding |
| --- | --- | --- |
| Driving garage/trunk: main tile, dedicated tile, full-screen page | Opening/closing; known state without action availability; pending vehicle command | Shared DrivingState enables unknown assumed CLOSED, but other observation/capability conditions disable it. Failed feedback retries the same intent rather than reversing its displayed requested state: also review against the stated rule. |
| Driving climate ON, Exercise Start/Stop, Work Morning climate/script | Pending vehicle command; missing configured target; full-screen also requires settled visible page | Configured initial controls generally bypass state readiness. Preserve target/session checks separately from observation gates. |
| Fan power: main tile | Missing available snapshot or command busy | Initial unavailable/unknown control disabled. |
| Fan slower/faster: main tile | Missing available speed control/current speed, busy command; speed bounds | Initial read required. Bounds are a separate legitimate restriction. |
| Generic power/action: main tile | Unavailable snapshot or busy command | Empty snapshot renders Refresh rather than the command. |
| Fan and generic controls: full-screen | Missing snapshot (buttons absent), loading, disabled controller capability, pending request | Initial commands absent or blocked until read completes. |
| Refresh: full-screen | Already loading or page not selected | Utility restriction, not command confirmation. |

Tile refresh, More controls and setup launch remain clickable in their inspected layouts. Full-screen controls also require the selected, resumed, settled page. Identification stripes are decorative, not buttons.

## Implementation acceptance checks (not run)

- Cold display with delayed, failed, unknown or unavailable reads still accepts the configured intended action.
- Gray CLOSED first tap sends OPEN immediately; a late CLOSED/OPEN read cannot reinterpret that tap.
- Toggle taps reverse displayed intent, including unconfirmed presentation; define treatment of OPENING/CLOSING explicitly.
- Immediate gray projection precedes network completion; matching observations alone grant confirmed colors.
- Rapid taps, pending conflicts, timeouts, cancellation, target/config changes and stale callbacks preserve the newest absolute intent.
- Verify on physical watch; static source review cannot establish rendering, tap delivery or car behavior.

## Active-panel push visibility and reconciliation — recorded October 20

Status: unresolved; diagnostics proposed only, no implementation authorized in this recording pass.

Reported behavior: user changed the active panel in HA, waited two minutes, then opened the Apple Watch app. The old panel appeared first and changed only after the foreground refresh. Successful background selection persistence should allow the new panel to be the first panel displayed on next opening. Push delivery, background refresh and local persistence have not been established for this report.

Required diagnostics:

- HA logs every push attempt with a unique update ID, watch identity, intended panel/configuration revision, timestamp and send result, including failures.
- Record relay submission and Apple's acceptance/rejection with available reason and APNs request ID. Acceptance is not proof of watch receipt.
- Watch persistently records the same update ID and original receipt timestamp as soon as its push callback runs.
- Watch reports receipts to HA when connectivity permits; distinguish original event time from reporting time and reconcile delayed or duplicate reports by ID.
- Trace background refresh start/skip/failure, fetched panel/revision and successful local selection save. Keep receipt and application as separate evidence.
- Record the first displayed panel/revision on opening before foreground refresh, so saved-selection and presentation failures can be distinguished.
- HA provides a history reconciling attempts, service acceptance/rejection, watch receipt and selection application. An attempt without a receipt remains receipt unknown, not proven undelivered. Preserve local watch history for cases where receipt reporting fails.
- Diagnostic work must not send vehicle wake or physical control commands.

Verification scenario: change panel in HA, leave app inactive for two minutes, open it, then reconcile that update's complete trace and first displayed panel. No diagnostic implementation or tests have been performed for this issue.

## FanControlHA CI dependency advisories — recorded October 20

Status: reported alert, queued for investigation and remediation; no dependency edits or validation performed.

The supplied alert reports affected uv 0.12.23 and Pillow 12.3.0 packages in FanControlHA's Home Assistant test environment, with high-severity advisories. Requested remediation is to update the Home Assistant test harness to compatible patched dependencies: uv >=0.13.4 and Pillow 13.0.0.

- [uv advisory GHSA-hq85-5cpj-mr62](https://github.com/astral-sh/uv/security/advisories/GHSA-hq85-5cpj-mr62)
- [Pillow advisory GHSA-q45j-58j2-45rg](https://github.com/python-pillow/Pillow/security/advisories/GHSA-q45j-58j2-45rg)

Scope reported: CI/test environment. An exploitable path or affected deployed version has not been established. Versions, advisory applicability and patched-version compatibility remain to be independently verified before implementation. Locate harness pins/lockfiles and workflow setup, update the applicable dependencies, and validate the HA test harness when remediation is authorized. This shared HA integration work is outside the Wear OS development pause.
