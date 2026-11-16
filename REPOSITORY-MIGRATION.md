# Repository consolidation — November 16, 2026

Canonical repository: https://github.com/agawlbb/FanControl (main).
Canonical local checkout: `/home/dev/projects/FanControl`.

Home Assistant stays at the root for HACS/Marketplace discovery. The iPhone and
Apple Watch apps live in `apple-watch/`. Both original commit histories and
release tags are preserved without rewriting history.

## Preserve the Home Assistant update identity

The final canonical repository retains the original Home Assistant repository ID
1417562588. Marketplace owns the installed `fan_control` directory through that
ID, so renaming this repository preserves the existing update connection without
uninstalling the integration, deleting configuration, or recreating pairings.

The earlier attempt to use Apple repository ID 1424743760 as canonical was
rejected by Marketplace's directory-ownership check. Its uninstalled Marketplace
registration was removed. That repository is retained as `FanControl-Apple-history`
for original Apple release files, Actions runs and pull-request records.

The five existing Apple signing secrets were copied with explicit user approval,
sealed to the destination repository public key. No plaintext secrets were logged
or placed in artifacts; the temporary artifact contained only destination-key
ciphertext, which was deleted after import. An isolated one-job development-container runner completed the transfer after hosted execution stalled; its registration and local files were removed. No new Apple identity was created and no app was built or released.

Original main bases:
- Apple: 75425f5.
- HA: 42b4658.

Original tags retain their historical layouts. New integration updates use the
unified main layout; Apple release tags from before consolidation do not contain
root-level integration source. Historical Actions links retain the repository
identity that actually owns those records.

Wear OS source and Git history were verified on Samba before the user deleted
its original GitHub repository. Redundant local checkouts were preserved outside
the active project directories. A combined Git recovery bundle is in Samba's
`Retired projects/FanControl-consolidation-recovery-20261116/` folder.

The consolidation changes no HA domain, app identifier, pairing, credential,
entity or physical-device behavior. Integration packaging remains available with
`python scripts/build_integration.py`; Apple checks run from `apple-watch/`.
App builds and TestFlight publication require explicit workflow dispatch and
separate user authorization.

## Verified completion

Marketplace lists `agawlbb/FanControl`, ID 1417562588, as the installed update
source. The original config entry `01M4VCVEECE8176WED4BJGGMS8` remained loaded.
Its installed revision stayed `42b4658`; source migration required no deployment,
restart, uninstall, pairing change or physical command.

All five existing Apple signing secret names are present in the final repository.
Encryption-only workflow run 43956293551 succeeded in the preserved Apple history
repository. The temporary transfer branch and ciphertext artifact were removed. The history repository workflow was disabled before archival. GitHub rejected cancellation/deletion of two earlier hosted-run requests while they were awaiting queue admission; those audit records remain in the archived repository. The normal TestFlight workflow on canonical main was not replaced.
Original Apple releases and pull requests (including consolidation PRs 9 and 10)
remain in [FanControl-Apple-history](https://github.com/agawlbb/FanControl-Apple-history).
