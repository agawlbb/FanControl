# Repository consolidation — November 16, 2026

Canonical repository: https://github.com/agawlbb/FanControl (main).

The former FanControlWatch repository is renamed so its Apple signing secrets,
Actions history and release records remain attached. Its source moves to
`apple-watch/`. FanControlHA is imported at the root through a merge retaining
its original commits, preserving HACS custom_components discovery. The retained
FanControlHA repository should redirect users here and be archived only after
the migration is accepted; existing HACS users must update their custom repository URL.

Source bases:
- Apple: 75425f5 (original main).
- HA: 42b4658 (original main).

Original release tags point to their original historical layouts. New releases
must use the unified layout. Historical release evidence remains historical.
No app identifiers, HA domain, pairing credentials or deployed software change.
Migration does not deploy HA or publish an app.

Wear OS source and Git history were verified in the Samba Retired projects folder
before the original FanControl GitHub repository was deleted by the user.

Integration packaging remains available through `python scripts/build_integration.py`; automatic checks do not build distributables. Apple workflow preflight runs at the workspace root before checkout; release commands run in `apple-watch/`.

## Remaining updater migration — November 16, 2026

The live Marketplace still owns the installed `fan_control` directory through
repository ID 1417562588 (`agawlbb/FanControlHA`). The combined repository, ID
1424743760 (`agawlbb/FanControl`), is registered as a custom integration source.
An install pinned to the combined main commit was rejected before installation:
"The fan_control directory belongs to agawlbb/FanControlHA".

Do not delete the configured integration or its pairing data to work around this
ownership check. Keep FanControlHA available until a supported ownership transfer
or an explicitly approved backup/restore migration is established. Registering the
new repository alone does not transfer installed ownership. No HA restart, config
entry deletion, integration uninstall or physical command was performed.

Historical Actions links deliberately retain the original repository name because
those run records were not moved by the Git history import. Current source links
and the legacy relay maintenance fetch now use the unified repository. The relay
is retired; changing its source link does not authorize running its deployment.
