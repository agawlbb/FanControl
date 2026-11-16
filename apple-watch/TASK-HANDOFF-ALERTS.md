# Stale handoff alert correction

Purpose: accept authenticated late receipts without replaying UI, reconcile local
notifications on visible entry and after asynchronous submission, and expose
local command/alert diagnostics through the long-press connection settings.

Base: origin/main 60ec51d461b9c3963e8d74200f03aa55f8e20da9, fetched October 31, 2026.

The reported Start → leave → 25-minute exercise → reopen notification has not
been reproduced on a paired watch. The fix addresses concrete late-receipt and
notification-lifecycle defects; it does not claim a proven historical cause.

No command retries, replay, execution polling, HA changes or physical commands.
Remaining paired-device checks: navigate/wrist-down during Start handoff, return
at 25 minutes, late authenticated receipt clearing, real APNs delivery, diagnostics
navigation, and a newer command/changed pairing while an old callback completes.

Validation: 73 Swift core tests, watchOS SDK typechecking, simulator builds and
unsigned archive passed. Signed merged source 4e4b920853740bad20ad73976be0e9c589a9e799
was released as 0.9.3 (22), VALID and IN_BETA_TESTING in Internal. Release evidence:
https://github.com/agawlbb/FanControlWatch/actions/runs/41227745700
