# FanControl

FanControl combines the Home Assistant integration and the iPhone/Apple Watch apps.
The retired Wear OS app is archived separately and is not part of this repository.

- [Home Assistant integration and setup](HOME-ASSISTANT.md): `custom_components/fan_control/`, with `hacs.json` at the repository root for HACS compatibility.
- [iPhone and Apple Watch apps](apple-watch/README.md): `apple-watch/`, including Swift sources, tests and XcodeGen configuration.
- [Apple signing and TestFlight](apple-watch/GITHUB-TESTFLIGHT.md): the existing Apple identifiers and credentials are retained.

Run HA checks from the repository root; run Swift checks from `apple-watch/`.
GitHub checks test source changes. App builds and TestFlight publication require explicit workflow dispatch and separate user authorization.

Both original Git histories and release tags are retained. See [migration details](REPOSITORY-MIGRATION.md).
