# Unified FanControl repository

Home Assistant lives at the root. Apple apps live under `apple-watch/`; apply
that directory's AGENTS.md for Apple work. Never reintroduce Wear OS source.
Run tools from each component's directory. Root `.github/workflows/` owns all
workflows; builds and releases require explicit user authorization. The canonical
checkout is `/home/dev/projects/FanControl` after migration acceptance.

# Home Assistant integration development

## Repository workflow

Canonical repository: `agawlbb/FanControl`; default branch: `main`.
Follow the VM-wide working procedure in `/home/dev/projects/AGENTS.md`.
Use the existing checkout on `main`, one task at a time; no routine task
branches, extra worktrees or ownership claims. Complete the requested outcome,
including deployment when applicable, then commit and push to `main`.
Use only relevant checks; do not repeat passing checks without a concrete reason.
Questions and status checks are read-only. Preserve unrelated work and credentials.

Inspect push workflows first. Do not trigger releases, deployment, device installation
or distributable builds without authorization. Never change branch protections
without specific approval. Back up before deletion/history rewrite, exclude ignored
credentials/runtime/signing material, preserve release tags, and use exact-SHA
force-with-lease for authorized rewrites. Never purge recovery archives.

## Required design for future commands

Every new or changed Apple watch HA action must use the shared durable operation
pipeline, including generic devices and new panel types. First-tap completion is
the design goal for valid, authorized targets; ordinary wake and transient delivery
delays must recover without another watch tap. Follow
[COMMAND-OPERATIONS.md](COMMAND-OPERATIONS.md) and the watch repository's
`COMMAND-DELIVERY.md`; do not add a synchronous watch-dependent command path.

- Validate the captured watch/owner/credential, target roles and absolute intent.
  Persist the operation before acknowledging acceptance or starting physical work.
  The same ID and payload return the same operation; reject changed payloads and
  stale/conflicting intents. Selection and unrelated configuration edits must not
  redirect or block a still-valid approved target.
- After durable acceptance, HA owns readiness, bounded wake, delivery, retry and
  confirmation independently of watch connectivity, navigation and polling. Save
  enough state to recover after HA restart within the original deadline. Preserve
  explicit cancellation (including cancellation arriving before submission),
  supersession and credential/role revocation across recovery.
- Classify every command as a retryable desired state or an at-most-once action.
  Persist the dispatch boundary before calling one-shot services. Never replay an
  ambiguous cover, horn, script, scene or equivalent action after a lost response
  or restart. Preserve shared wake ownership and fan-speed debounce across both
  cancellation and restart. Service/provider waits must not hold the global lock
  and prevent other commands from being accepted.
- Keep durable queue acceptance, dispatch acknowledgment and observed completion
  distinct in API results. ALL watch command controls turn their requested state
  teal on authenticated durable HA ownership; this is not physical confirmation.
  HA must still confirm desired states from fresh matching observations and send
  final failures to the dedicated watch outcome route. Scripts/scenes acknowledge dispatch unless
  separately configured completion evidence exists. Vehicle state cannot confirm
  independent music playback. Report ambiguous outcomes as unconfirmed.
- Use the shared 180-second delivery deadline plus 15-second read-only grace;
  retries and duplicate requests must not extend it. Expected wake, retry, rate-
  limit and temporary provider delays stay silent. Reconcile final evidence before
  failure notifications; avoid duplicate/stale alerts and never promote timeout,
  cancellation or unknown state into success. Do not add passive/background wakes.

For each new action, add meaningful regression coverage for durable acceptance,
lost responses and duplicate IDs, retryable delays, observed confirmation,
unavailable/mismatched evidence, expiry, explicit cancellation, supersession,
target/revocation changes, restart recovery and one-shot ambiguity. Exercise its
watch surfaces too, including immediate navigation/wrist-down and stale callbacks.
Document required API capabilities, compatible app/integration versions and
remaining physical checks. Do not claim guaranteed exactly-once physical completion
without target-side support. Deployment needed for the requested fix is part of completion. Physical vehicle
actions remain subject to explicit user authorization.

## Integration invariants

Keep approval, credentials, entities, panel roles and operations scoped to the
same watch/owner/configuration. Companion keys authorize observations/preferences,
never physical commands. Unlink phone revokes only that companion; watch revocation
revokes both. Revision-check preference writes and keep selection independent of
swipe order. Configuration, snapshots, push and diagnostics never wake vehicles.
Explicit settled visible watch entry and a user-tapped vehicle command may request or join one bounded wake attempt. Passive updates and command retries never initiate additional wakes. Apple command operations expire after 180 seconds plus a 15-second read-only confirmation grace period; expected delays do not trigger one-minute alerts.

All new Apple commands use durable HA-owned operations: persist before acceptance,
continue independently of watch navigation, and restore after restart within the
original deadline. Persist one-shot dispatch boundaries before service calls;
never replay ambiguous horn/cover/script/scene actions. The watch owns durable
handoff until HA accepts; no preflight reads are required for command submission.
Fan speed requests debounce for one second on HA, so wrist-down cannot lose drafts.
Preserve at-most-once one-shot dispatch and bounded Stop continuation. Completed
Stop selects a uniquely matching Driving panel once, without physical commands;
duplicate polls cannot overwrite later manual selection. Local music Stop confirms
available unlocked/climate-on evidence and treats temperature as best effort.
Do not change legacy client semantics incidentally. An HA observation is not
independent physical vehicle proof; APNs acceptance is not device receipt.

Keep private HA storage, relay config/database/APNs keys, diagnostics and music
out of Git and backups of tracked source. Use synthetic test credentials. Preserve
all integration and relay regression tests. Run pytest and Python compilation for
code changes; PHP checks require a supported runtime. Deploy to HA/hosting when needed for the requested outcome; do not send physical
commands as validation without explicit authorization.

## Required entry, notification and timing contract

Visible settled vehicle entry submits a single role-scoped wake and performs a
bounded readiness/state refresh. Passive snapshots and cosmetic panel changes must
not cancel it, and passive/offscreen updates must never initiate a wake. Treat
stale online/climate observations as unknown; use HA last_reported/last_updated
freshness, not cached values, for wake suppression and outcome confirmation. This
is HA evidence, not independent proof of physical state.

All user commands, including Work Morning climate, require terminal outcome alert
handling independent of watch screen lifetime. The command APNs destination is
watch-only and separate from phone snapshot registration. Keep normal delays
silent; deduplicate retries by operation/outcome and suppress stale/superseded
failures. Entry-only wake trouble is diagnostic, not an extra command alert.
Preserve bounded retry/recovery and record whether APNs accepted a notification;
never equate APNs acceptance with watch receipt. Notification permission and direct APNs signing credentials remain prerequisites.
HA 0.13.0 sends pushes directly to Apple; no hosted relay fallback is permitted.
The signing key stays in /config/fancontrol-apns.p8, outside source and diagnostics.
Preserve fixed phone/watch topics, token isolation and bounded outcome handling.

Keep server timing/events bounded and correlated by operation ID: request arrival,
authenticated registration, durable acceptance, wake dispatch/online observation,
command dispatch/return, terminal result and notification result. Do not accept
client-supplied server timestamps. Duplicate requests preserve the original times;
no credentials, tokens, URLs or full request bodies belong in these diagnostics.
