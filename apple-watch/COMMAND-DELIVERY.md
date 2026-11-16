## Foreground command handoff — November 1, 2026

User-authorized task `fix/foreground-command-handoff`, based on canonical main
`56dddf61681811c65d239aab3f426e9384d3bd69`, replaces the background-upload-only rule.
Persist the absolute intent first, then submit immediately through reusable foreground
HTTPS. App inactivity or a foreground transport failure starts at most one background
continuation with the same operation ID, intent and original ten-second deadline,
but a fresh authentication nonce. HA serializes and deduplicates same-ID submissions;
this is not permission to repeat physical actions. Navigation alone does not cancel
handoff. No preflight, local endpoint fallback, polling or reopening replay is added.
Authenticated receipts remain authoritative; a failed continuation cannot reject a
foreground request still in flight. Diagnostics retain numeric transport error codes.

# HA-owned command delivery

## Current behavior — October 30, 2026

Task `fix/remote-ha-handoff` starts from canonical `main` commit
`07bd517653bb074ce6af1e20704d442ed2d2b9e3`.

The watch uses its saved `remote_url` exclusively for authenticated HA requests.
Missing/invalid remote configuration fails without attempting the local URL.
Long-press a FanControl page to open the existing Home Assistant connection screen:
it now displays the saved remote URL and offers Test remote connection, an encrypted
configuration read that sends no physical command or wake.

A tap immediately projects the requested outcome in gray, saves the absolute intent
and schedules one background upload. The handoff budget is ten seconds from the
original tap, including receipt. There is no duplicate foreground sender, endpoint
fallback, retry or status polling. A failed/expired handoff is not proof that HA
did not receive the command: a response can be lost. Reopening never resubmits it.
An authenticated matching acknowledgment ends watch responsibility. HA retains its
existing durable execution/retry/wake/confirmation window and failure notifications.
Push-triggered authenticated result retrieval remains event-driven, not polling.

Action buttons show gray Activated during handoff, restore their normal name on
failure, or show teal Activated for five seconds from acknowledgment before resetting.
Neither duplicate receipts nor stale timers can extend or clear a newer request.
Controls unlock on acknowledgment rather than waiting for HA execution. Visible
vehicle entry sends one wake submission without subsequent watch status polling.

watchOS owns background scheduling and suspension. The ten-second UI deadline is
enforced while running and on recovery, alongside ten-second transport limits;
wall-clock callback/notification delivery while suspended requires physical checks.
Remaining checks: remote-only cellular connectivity; missing/incorrect URL; DNS/TLS,
offline and lost-response cases; early navigation/wrist-down; action acknowledgment
and five-second reset; new taps during an older timer; HA failure push after handoff.
No installation, TestFlight release or HA deployment is included in this change.
The subsequent authorized October 30 TestFlight release is 0.9.2 (21); see
[RELEASE.md](RELEASE.md) for Apple's processing and Internal group evidence.

Validation: source `47ac0d3890283c1d095ef777123aa15357513fdd` (project version
0.9.2/build 20, no new packaged build) passed all 69 Swift core tests and watchOS
SDK source typechecking in [Core tests run 41122623379](https://github.com/agawlbb/FanControlWatch/actions/runs/41122623379).
Coverage includes remote-only transport and no fallback, absent/loopback remote
configuration, ten-second handoff expiry, failure reset, five-second receipt expiry,
duplicate acknowledgments and stale callbacks/timers across targets. Source checking
does not verify physical-watch rendering, OS scheduling or real HA connectivity.
Simulator/signing builds were not run. Documentation and main integration use
`[skip ci]` to avoid the existing main-push app archive/simulator workflow.

The following sections record prior behavior and historical validation.

Every HA control submits an absolute intent with a stable UUID and original issued
time. A keychain outbox records the captured connection, target and body before a
watchOS background URLSession upload is scheduled. Foreground submission and remote
fallback use the same operation ID with independently authenticated fresh envelopes.
No config/state read is required before handoff; HA validates the captured roles.

Leaving or wrist-down cancels UI observation only. HA saves acceptance before its
acknowledgment and before physical dispatch. HA then owns readiness, one bounded
wake, safe desired-state retries and observed confirmation for 180 seconds plus a
15-second read-only grace period. The operation store restores work after restart
without extending that deadline. Fan speed's one-second quiet window is server-owned
and superseded drafts cannot execute later. Reopening resumes the same operation
and its stored result. Unrelated HA selection or other panel edits do not redirect
or block delivery.

HA persists the at-most-once boundary before cover/horn/script/scene delivery.
After an ambiguous call or restart these actions are never replayed. This means an
ambiguous one-shot can remain unconfirmed: no distributed system can guarantee both
physical completion and no duplicate effects without support from the target.
Scripts/scenes/music and horn confirm dispatch acknowledgment, not physical completion.
Local audio/volume remain watch-owned. Explicit cancellation, revoked credentials,
removed/changed roles and expired requests still stop delivery.

Normal wake/retry delays produce no one-minute alerts. Final Exercise alerts come
from HA; the originating controls show pending or unconfirmed outcomes in gray, with no separate command-status text. Action buttons intentionally change to Activated after a tap. Unknown/unavailable observations never confirm a command.

Validation requires core transport/evidence tests, HA regression and real-runtime
checks, and unsigned simulator compilation. Paired-watch cellular, immediate wrist-
down/navigation, force-quit/OS scheduling, sleeping car and physical target behavior
still require device checks. Apple controls background scheduling; a saved upload
cannot guarantee immediate execution, especially after user force-quit. No live
HA commands, deployment or TestFlight upload form part of these automated checks.

## Validation record — October 24, 2026

Application source `7e08fea371dea668703693b24c2ea403b0c6a19e` (0.8.0, build 17)
passed 42 Swift core tests and unsigned iPhone/watch simulator compilation:
https://github.com/agawlbb/FanControlWatch/actions/runs/40128116674
Archive, screenshot-launch and TestFlight steps were skipped. The first run exposed
an outdated progress-text assertion; it was corrected before this final green run.

HA 0.9.0 source `a5514ffeec2d5a331dd88ea6968c13bf519b579c` passed 242 local
regression tests and Python compilation, including the former nine failing audit
scenarios, durable acceptance/reload, storage failure, ambiguous one-shot recovery,
fan debounce and cancellation during wake persistence. Its isolated real-runtime
CI record is maintained in FanControlHA/COMMAND-OPERATIONS.md.

Remaining device checks: tap each fan/device/script/scene control, each Driving
control, Exercise Start/Stop and Work Morning controls; immediately swipe away,
lower the wrist and return. Verify completion stays bound to the tapped target,
normal sleeping-car delays remain silent, unknown/offline observations stay gray,
and local audio evidence remains independent. Also check cellular-only operation,
HA restart during delivery, revoked/changed roles, opposite intents and watchOS
force-quit/background scheduling. Simulator compilation does not prove these effects.
HA 0.9.0 is now deployed and watch 0.8.0/build 17 is signed and published to the
existing Internal TestFlight group. See [RELEASE.md](RELEASE.md) for the Apple build
ID, successful release run, package hash and remaining paired-device checks.

Action buttons initially show their normal name in teal, turn gray Activated on tap,
and turn teal Activated when a matching authenticated operation response confirms
HA ownership. This acknowledges responsibility for completion, not physical completion
or playback. Monitoring and conflicting-command protection continue independently.

# Swipe command isolation

Tile navigation uses a high-priority drag gesture so a recognized swipe cancels
the underlying button press instead of sharing the touch with an HA command.
Entry wake/read work remains separate from the command outbox and its alerts.

Paired-watch regression check: swipe starting on each state/action button and
fan speed control, in both directions and at the first/last tile. Include short
and diagonal drags, vertical scrolling, and the Exercise playback area. Verify
that navigation alone creates no command tap/submission timing events, changes
no command control to Activated, and produces no command alert after five minutes.
Then verify deliberate taps still submit once, long press opens settings, and
vertical scrolling still works. This check requires watchOS; core tests cannot
establish SwiftUI gesture arbitration or notification delivery.
