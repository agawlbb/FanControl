## Product scope

Do not add user-facing features, controls, screens or workflows unless the user
requested them or they are necessary to complete the requested behavior. Ask before
adding optional UI. Keep changes limited to the requested scope.

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

# Apple Watch and iPhone development

## Current command contract — October 30, 2026

This user-approved contract supersedes older watch retry, monitoring and receipt
duration rules below. Use the per-watch configured remote HTTPS URL exclusively;
never hardcode an HA host or fall back to a local address. The watch saves one
absolute intent and schedules one upload, with a ten-second handoff deadline from
the tap. No foreground duplicate submission, delivery retry, reopening replay or
execution polling. Navigation does not cancel the scheduled handoff. On authenticated
ownership HA alone continues execution, wake, retries and failure notification.
HA's 180-second execution window remains independent of the watch's ten seconds.
Action buttons show gray Activated during handoff, restore their command name on
handoff failure, and show teal Activated for five seconds after acknowledgment
before restoring their normal name/appearance. Stale callbacks/timers must not
affect newer taps or other targets. State controls still project absolute intent.
The existing long-press connection screen displays the saved remote URL and offers
a bounded authenticated read-only connection test. It never wakes a vehicle.
Entry wake submits once; there is no watch-side readiness/status polling afterward.

## GitHub, branches and workspaces

- GitHub `agawlbb/FanControlWatch`, default branch `main`, is the canonical copy of accepted code and history. Laptop, VPS and cloud checkouts are working copies. The default branch is for integration of completed work, never a working branch for a task.
- Prefer the VPS for most development. Development may also take place on the laptop or another authorized environment, including emulator, webview and device testing. Independent tasks use separate, clearly named temporary branches and separate working directories (Git worktrees or clones). Do not share a writable checkout between concurrent tasks. There is no permanent designated chat owner or owner-chat approval requirement.
- Before editing, read applicable instructions and inspect current branches, worktrees, local edits, live GitHub heads and active writers/builds. Preserve unrelated and unpushed work; a clean tree alone does not prove inactivity. Coordinate overlapping changes and shared resources with the tasks involved.
- Before starting new work, fetch from GitHub (`git fetch origin`) and create the temporary task branch from the latest fetched remote default (`origin/<default>`, where `<default>` is this repository's `main`, `master` or `work` branch identified above). Record the task's purpose and base commit; do not branch from a stale local default.
- Before resuming existing work, fetch from GitHub and inspect the intended task branch, its upstream and any divergence from the remote task branch and canonical default. Reconcile updates intentionally without overwriting uncommitted, unpushed or unrelated changes. Preserve local work before switching branches or integrating updates, and resolve conflicts without discarding another task's work. Do not blindly run `git pull` in the current branch or pull another task's branch into it.
- To move the same task between machines, commit and push that task branch, then fetch and continue the intended branch on the other machine after coordinating the handoff and following the resumption checks above. Never overwrite another task's work or use recovery archives as active workspaces.
- Before merging, fetch and integrate the latest canonical default into the task branch, resolve conflicts without discarding others' changes, review the diff and rerun relevant checks against the integrated result. Serialize merges into the default branch and recheck its live head before publishing. Respect existing protections; do not bypass them or rewrite published history.
- Commit and push completed work to the existing GitHub origin, merge accepted work into `main`, and verify the remote commit and a clean task working tree before reporting completion. Report blockers or unsynchronized work explicitly. Inspect push triggers before every push; GitHub publication does not itself authorize builds, releases, deployment or installation.
- Temporary task branches must be removed both locally and remotely once their purpose is fulfilled and their changes are merged into the canonical default branch, or their work is explicitly abandoned by the user or the person responsible for that task. Verify the merge or abandonment decision first; preserve commit history, required recovery evidence and recoverable unique work before deletion. Stale or paused work is not abandoned. Never discard unmerged work without that decision, delete another task's branches, or purge recovery archives as routine cleanup.

## Release authorization clarification — November 15, 2026

A completed release request is not standing authorization for later releases.
The user authorized finishing the already-started 0.12.3 (31) release only.
Future releases require a new explicit user request; do not infer permission
from earlier completed release requests or ordinary bug reports.

Inspect push workflows first. Do not trigger releases, deployment, device installation
or distributable builds without authorization. Never change branch protections
without specific approval. Back up before deletion/history rewrite, exclude ignored
credentials/runtime/signing material, preserve release tags, and use exact-SHA
force-with-lease for authorized rewrites. Never purge recovery archives.

## Required design for future controls

Apply these rules to every new or changed HA-controlled action on every watch
surface, including panels, shortcuts and complications. First-tap completion is
the design goal for a valid, authorized target: recover ordinary wake, transport
and provider delays without requiring another tap. Do not add a separate delivery
path for a new control. Use the shared command outbox and HA operation API described
in [COMMAND-DELIVERY.md](COMMAND-DELIVERY.md), with the corresponding server contract
in the HA repository's `COMMAND-OPERATIONS.md`.

- Capture one absolute intent, approved target, unique operation ID and original
  deadline at the tap. Save it securely and schedule background submission before
  monitoring. Retries, endpoint fallback and reopening must use that same intent
  and ID; never recompute a toggle from a later read. No preflight read may gate
  submission. HA remains authoritative for authorization and role validation.
- The watch owns delivery until HA durably acknowledges acceptance; HA then owns
  readiness, bounded wake, execution, retry and confirmation. Screen navigation,
  wrist-down and UI task cancellation must not cancel handoff or accepted work.
  Reopening reconciles the saved operation. Only explicit cancellation, a newer
  conflicting intent, revocation/target invalidation or expiry may stop it.
- Keep queue acceptance, dispatch acknowledgment and confirmed outcome distinct.
  Project the requested outcome immediately in gray. For EVERY command control, teal requested ON/OFF, speed, cover state or Activated means authenticated HA ownership of this exact operation and target, not physical completion. Never put projected state
  in the observed cache. Scripts/scenes/horn/music receipts do not prove physical
  completion or playback. Stale callbacks must not change a newer request.
- Declare whether each new command is a retryable desired state or an at-most-once
  action. Persist one-shot dispatch boundaries on HA; never blindly replay an
  ambiguous action for better feedback. Keep conflicting controls disabled while
  preserving supported opposite-intent supersession and fan-speed adjustment.
- Keep expected wake/retry delays silent through the shared 180-second delivery
  and 15-second read-only grace policy. Treat transient network errors, rate limits
  and temporary server errors as retryable within that deadline. Final failures
  stay gray; never claim an unproven success.
- Local-only actions such as audio and volume remain watch-owned; their feedback
  and evidence must remain independent of HA or vehicle completion. Keep background
  command transfer separate from passive reads; do not add background polling or
  passive vehicle wakes. Clear saved command credentials when forgetting pairing.

Before delivering a new command, cover immediate feedback, early navigation and
wrist-down, lost acceptance responses, same-ID retry/fallback, delayed/unavailable
or mismatched evidence, terminal failure, explicit cancellation, supersession,
stale callbacks, target/revocation changes and restart recovery. Verify the HA
worker and any one-shot recovery behavior as well as the watch path. Add meaningful
regression coverage and record paired-device checks that automation cannot prove.
Do not promise guaranteed OS scheduling or exactly-once physical effects when the
target supplies no deduplication/definitive acknowledgment. Coordinate required HA
capabilities and version compatibility before introducing a dependent app action.

## Current behavior

The iPhone owns routine APNs/background refresh and visible-phone polling. The
watch renders persisted snapshots and asks the phone once on visible entry; do
not add routine watch background polling or an unbounded foreground refresh loop.
Every displayed nonvehicle control also performs one bounded authenticated HA state
read on entry, without requiring a phone or command tap. Available ON/OFF and speed
observations may turn teal; unknown/unavailable data and saved snapshots stay gray.
Keep this separate from command acknowledgment and vehicle report-age checks.
Vehicle changes must preserve this opening-screen behavior for fans, lights,
switches, booleans and nonvehicle panels. Cover opening without issuing a command
when validating refresh changes. Bounded visible-entry wake/readiness confirmation is required. Phone/background
reads never wake vehicles. Direct watch commands remain independent of the phone. Save every absolute intent
in the keychain outbox and schedule its background upload before monitoring.
HA owns durable execution after acceptance, across watch navigation/inactivity and
HA restart. Leaving cancels observation/entry work only, never accepted delivery.
Resume the same operation on return; unrelated selection/config changes must not
block a valid captured target. No command preflight reads or watch background polling.

A swiped tile persists as the local opening tile until another swipe or an HA selection/configuration revision. Saved phone preferences define a fixed swipe order;
swiping never changes HA selection. Settings is reached by holding a watch page,
not by swiping. Keep the phone UI minimal. Only Driving has an identification stripe.
Visible primary vehicle entry wakes after target validation without artificial
delay; swipe entry waits 1.5 seconds continuously visible. Leaving cancels entry
work. Explicit vehicle taps may start or join one bounded wake attempt. Prefetch/configuration/background reads and command retries never initiate additional wake requests. Apple commands allow 180 seconds plus 15 seconds of read-only confirmation; expected wake/retry delays remain silent.

## Command evidence

Immediately project the requested absolute outcome in gray on the originating
control. Never store projection as observed state. Gray toggles remain tappable:
an opposite absolute intent supersedes earlier UI work. Preserve the one-second
fan-speed quiet window on HA; the watch hands off each revised draft immediately. Stale responses cannot recolor another request or target.
Authenticated HA ownership turns every requested command control teal immediately, including Climate. Execution/conflicting-control protection remains pending independently of color. Terminal failed/unconfirmed/cancelled results turn it gray. Observed state and its freshness are tracked separately; unknown observations are never confirmed.
Garage/trunk initial CLOSED is only a gray assumption; its first tap is absolute
OPEN. Dispatch cover/script/scene/music requests at most once per tap.

Command feedback uses color on the existing control, without separate status
messages such as Requested, Waiting for Home Assistant, Request accepted or Not
confirmed. Action buttons intentionally change to Activated after a tap; retain that behavior. Do not use REQUESTED as a generic replacement. State controls immediately show the requested ON/OFF, OPEN/CLOSED
or speed in gray; authenticated ownership promotes their color to teal before physical completion. Failures stay gray.
Setup, pairing and audio-route guidance are separate from command feedback.

Leave for Work, Horn, Start/Stop Exercise and Podcast show gray Activated after a tap. Teal Activated means an authenticated response matching this operation confirms HA has received the command and owns ensuring completion. Active operation statuses acknowledge that handoff before dispatch/completion. It does not prove physical completion or playback. Keep monitoring and conflict protection independent of the receipt color; terminal failures remain gray. Resetting session presentation on
leaving/configuration change must not delete saved operations or prevent
reconciliation on return. Generic script/scene controls preserve their existing
receipt semantics. Pending conflicting actions remain disabled.
Stop continuation must survive accepted dispatch; Driving selection requires HA
operation completion. Local Exercise Stop confirms unlock and climate on; the
63 F temperature request is best effort. Preserve existing legacy-client semantics.

Keep imported audio private and offline on the watch. Verify a whole replacement
before installing it; preserve the playing library until the next session. Phone
snapshots contain no command credential and cannot confirm a watch command.

## Validation

Preserve regression tests and build/release configuration. For command changes,
cover immediate intent, delayed/mismatched/unavailable evidence, confirmation,
failure/cancellation and stale callbacks across exposed surfaces. Run appropriate
core tests; simulator/signing builds require their own authorization. Report exact
source and remaining paired-device checks. Automated checks do not establish real
watch rendering, APNs delivery, playback or vehicle behavior.

## Entry, outcome notifications and timing

Vehicle panels perform one scoped, bounded wake/readiness refresh on visible settled
entry. Passive snapshots cannot cancel that coordinator or initiate an offscreen
wake. Cold/unconfirmed climate presentation assumes OFF in gray, making its first
tap an absolute ON intent; never toggle from stale cached ON. Once tapped, preserve
the captured absolute intent through leaving, retries and configuration refreshes.
Foreground and background authenticated receipts update the same visible control;
reopening reconciles the latest keychain receipt before another network read.

User-command terminal failures use HA-owned APNs to a dedicated watch destination;
phone snapshot registration cannot replace it. No failure alert for ordinary wake
or pending delays. A bounded local not-confirmed fallback covers missing HA
acknowledgment; cancel it when HA ownership is received. Entry-only wake failures
are diagnostic, not extra user-command alerts. HA 0.13.1 sends directly to Apple;
no hosted relay is used. Notification permission, HA-owned APNs signing credentials
and OS delivery remain prerequisites; APNs acceptance is not receipt. Keep signing
keys on HA, never in the phone/watch app or source.
On recovery, reconcile pending/delivered local alerts against the current outbox,
pairing, target roles, acknowledgment and original issue time. Never replay an
overdue timer or notify from an orphaned/obsolete callback. Local alert relevance
is bounded to five minutes from the original tap; native timers still target
195 seconds plus 30 seconds of transport grace. Deduplicate local fallback and
terminal alerts, recheck relevance after asynchronous permission/notification work,
and remove obsolete legacy Exercise timers. Entry reads/wakes never create alerts.
Keep all timing diagnostics bounded and correlated by operation ID. Record tap,
submission, acknowledgment received/displayed and entry wake/state-display timing;
never log credentials, tokens, URL contents or full request bodies. Preserve these
rules and meaningful lifecycle/notification regression coverage for future controls.
