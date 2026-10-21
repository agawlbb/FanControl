# Watch command feedback review

Reviewed against local app 1.4.6 sources, October 18, 2026. This review covers
source paths and automated behavior; physical-watch rendering, timing and device
outcomes still require hardware checks. The permanent interaction requirements
are in [AGENTS.md](AGENTS.md).

| Command | Watch surfaces | Immediate requested display | Confirmation evidence |
| --- | --- | --- | --- |
| Fan ON/OFF | Main tile, full-screen page | Gray ON/OFF; conflicting controls disabled | Available observed power matches the absolute request |
| Fan speed 1–6 | Main tile +/−, full-screen speed buttons | Gray requested speed; tile drafts remain adjustable for one second | Available observed power/speed match; dispatch occurs once |
| Light, switch, input boolean power | Main tile, full-screen page | Gray requested ON/OFF | Available observed power matches, not merely service acknowledgment |
| Script/scene Run | Main tile, full-screen page | Gray REQUESTED | HA dispatch acknowledgment changes action to mint; never means COMPLETED |
| Work Morning climate ON/OFF | Main tile, full-screen panel | Gray requested climate state, including while waking | Available climate matches fixed ON/OFF intent |
| Work Morning script | Main tile, full-screen panel | Gray REQUESTED | Mint REQUESTED means dispatch acknowledged only |
| Exercise Start | Main tile panel, separate Exercise tile, full-screen panel | Gray LOCKED on originating control; existing Spotify handoff preserved | Lock observed as locked after the requested action |
| Exercise Stop | Main tile panel, separate Exercise tile, full-screen panel, legacy action screen | Gray UNLOCKED / Climate 63°F | HA operation confirms required unlock/climate-on/temperature steps |

Vehicle wake is automatic entry/action preparation, not a standalone result
button. It never makes the requested climate/lock outcome confirmed. Optional
Spotify launch, music and pause accompany Exercise but have separate evidence:
vehicle confirmation does not confirm playback, source selection or pause. Music
and pause retain their existing one-shot semantics.

## Gaps corrected

- Both Exercise tile layouts and full-screen Exercise buttons previously used
  pending status alone. Completion discarded the requested label without an
  explicit confirmed highlight. They now retain the result label and use mint
  only for the matching confirmed action.
- Work Morning script acknowledgment and generic script/scene acknowledgment
  now get a confirmed action highlight without claiming execution completed.
- Failed/cancelled panel actions retain gray requested feedback and a
  Not confirmed label, independently of whether retry is available. A later
  successful state read can replace that presentation with actual state. Older
  in-flight reads cannot clear newer feedback.
- Panel climate confirmation now rejects unavailable climate readings even if
  their boolean happens to equal the requested OFF state.
- Ordinary pending status text is gray as well as its control. Swiping away
  clears canceled ordinary projections rather than leaving them on a later visit.
- Shared color rules and regression tests cover pending, confirmed and failed
  presentation, all six speeds, fixed power intentions, scripts/scenes and panel
  commands. Existing transport/session tests cover non-replay and cancellation.

## Hardware verification

For each row above, start with the opposite observed state where applicable,
tap once and verify the requested label appears gray before the network finishes.
Delay/disconnect HA and verify no successful color appears. Restore connectivity
and check that only matching evidence changes the color. Exercise timeout and
Cancel must remain unconfirmed; ordinary failures must show unknown/error.
Repeat on all listed surfaces, with the screen off during a pending panel action,
after swiping away/back, and after changing the approved target in HA. Check
that long Stop/error labels fit and that Spotify handoffs preserve feedback on
return. No live commands were sent during this review.

## Automated validation

The final local app 1.4.6 debug build passed gradlew.bat validateDebug:
APK assembly succeeded; all 142 unit tests passed with zero failures/errors;
lint passed with 40 warnings. No APK was installed and no live HA or vehicle
commands were sent. The generated APK is app/build/outputs/apk/debug/app-debug.apk.

## Driving extension (app 1.5.0 / HA 0.4.0)

Driving adds garage open/close, trunk open/close and Climate ON to a separate
tile, active main-tile panel and full-screen page. All share DrivingState and
CommandFeedback colors. Initial trunk CLOSED is gray and immediately issues
absolute OPEN when tapped; later reads cannot reverse the intent. Covers send
once and only poll after an ambiguous result. Matching available HA state
confirms the outcome. Native HA selectors configure all roles. Visible entry
requests wake; passive reads never do. Final validation passed APK assembly,
158 Android tests, lint (40 warnings), 122 HA tests and Python compilation.
The APK was installed and version-checked; no live garage/trunk/climate action
was used to test the feature. Updated HA source was uploaded and read back.
Home Assistant restarted with user approval; Fan Control loaded successfully, and the live Add Driving form was verified with all five role selectors. No panel selections were saved and no vehicle commands were sent.

## Display and navigation update (app 1.5.1 / HA 0.4.1)
Garage and trunk share initial gray CLOSED with absolute OPEN intent. RGB
identification bars are HA configurable and separate from confirmation colors.
Tap the bar to enter the vertical pager; all configured pages are available,
with the HA-selected initial default. Native tile gestures are system-owned.
Wake is confined to visible settled vehicle entry. Activity-covered tiles,
hidden pages, background/prefetch and command retries do not send wake.
Validated: 165 Android tests, APK assembly and lint; 150 HA tests and Python
compilation. HA source uploaded/read-back verified; approved restart scheduled.
Watch APK installed successfully. No physical vehicle/garage commands sent.
Physical layout and device behavior still require user verification.
Activation verified: HA restarted, Fan Control loaded, and live Driving setup exposes the native color_rgb selector. Watch reports version 1.5.1/code 21. No panel selections saved during form verification.


Version 1.5.2 removes watch-side panel switching at user request. Color bars are decorative; the app exposes only the HA-selected first device, disables pager gestures, ignores restored page selection and removes page counters. Full Android validation passed. No HA runtime change or physical commands.


Driving-only identification bars: show the configured colored stripe only for Driving panels, on native tiles and full-screen controls. Fan, Work Morning and Exercise must not display identification bars. HA-only selection remains unchanged.


Confirmed Stop Exercise selects Driving (HA 0.4.2): after the authenticated
Stop operation confirms unlock, climate on and target temperature, HA selects
this watch's unique Driving panel matching climate, wake and online roles.
This works on the immediate response or background continuation and does not
depend on location. Pending, failed, expired, cancelled, stale and ambiguous
operations must not select another car. Duplicate completed polls must not
reapply selection over a later manual choice. Selection sends no vehicle wake
or other physical command. All watch surfaces share the HA completion path.
Deployment validation: 163 integration tests and Python compilation passed.
