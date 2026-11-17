# Build and publish from the unified FanControl repository

All new builds and releases use `agawlbb/FanControl`. The original Apple release records are preserved in `agawlbb/FanControl-Apple-history`. The same five existing signing credentials were securely copied into the unified repository with explicit user approval; app identifiers and the Apple team are unchanged. Apple source lives in `apple-watch/`; the workflow files live in the repository root under `.github/workflows/`. Run local Apple checks from `apple-watch/`.

## Test and build without Apple credentials

Open https://github.com/agawlbb/FanControl/actions/workflows/watchos.yml.
Select **Run workflow**, select the branch you want to test, select
**validation_only**, and select the green **Run workflow** button.
This runs the Swift regression tests and compiles the iPhone and Apple Watch
simulator applications on a GitHub-hosted Mac. It does not sign or upload an app.
The cloud editing environment runs Linux; Xcode and Apple framework tests run
on GitHub's Mac runner instead.

## Add signing credentials once

Open https://github.com/agawlbb/FanControl/settings/secrets/actions.
Select **New repository secret** for each name in the table below. Enter its
value in GitHub's secret field, then select **Add secret**. Never send these
values in chat or commit them to the repository.

| Secret name | Value to enter |
| --- | --- |
| `ASC_KEY_ID` | The key identifier for an existing App Store Connect API key. |
| `ASC_ISSUER_ID` | The issuer identifier displayed in App Store Connect for that key's team. |
| `ASC_PRIVATE_KEY` | The complete contents of its original Apple `.p8` private-key file, including its BEGIN and END lines. |
| `IOS_DEVELOPMENT_CERT_P12` | The base64-encoded contents of the existing Apple development signing certificate export, including its private key, in `.p12` format. |
| `IOS_DEVELOPMENT_CERT_PASSWORD` | The password used when that `.p12` file was exported. |

Use credentials belonging to Apple team `FKR675M7PM`, which owns this app.
The App Store Connect key must have access to Fan Control and permission to
upload builds, manage its existing internal TestFlight group, and perform the
certificate, identifier, capability, and provisioning operations used by Xcode.
An account administrator should confirm the appropriate role and access to
Certificates, Identifiers & Profiles. Active Apple Developer membership and any
required Apple agreements must also be in place.

If these credentials already exist as organization secrets, their owner can
grant this repository access instead of adding duplicate repository secrets.
GitHub does not let anyone retrieve a saved secret's value. If the only saved
copy is in another repository, use the original private files or ask the person
who manages them. Do not print secrets through an Actions job to recover them.
Apple normally allows a private API key to be downloaded only once. If the
original file is unavailable, an account administrator must arrange a replacement
credential; do not revoke working credentials as part of this setup.

For a `.p12` file already available on your computer, create its base64 text
locally. On macOS, run `base64 -i /path/to/development.p12 | pbcopy` to copy it
directly to the clipboard, then paste it into GitHub's secret field. On Windows,
run the following in PowerShell, using the actual path to the file:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\development.p12')) | Set-Clipboard
```

Do not create or export a new certificate if you already have the valid export
and password used for the previous releases.

## Verify a signed build without uploading

Open https://github.com/agawlbb/FanControl/actions/workflows/testflight.yml.
Select **Run workflow** and select the intended branch. Enter a positive build
number and leave **Upload signed build to TestFlight** unchecked. Select the
green **Run workflow** button.

The workflow first checks which credential names are missing, without displaying
their values or starting a Mac runner. Once those checks pass, it runs the Swift
tests, builds and signs the app, verifies the exported signatures and production
push-notification entitlements, and saves a signed application package as an
artifact for seven days. A green result verifies the signing path. Xcode can
create or update provisioning profiles, and the signing script ensures the
existing app identifiers have their required push capabilities. This mode does
not upload a build or assign it to testers.

## Upload to internal TestFlight

After a signed build succeeds and the owner authorizes the release, run the same
workflow with **Upload signed build to TestFlight** checked. Choose a build number
greater than every number already uploaded for the current app version. The last
documented upload was version 0.12.9, build 37; check App Store Connect before choosing
the next number because other releases may have occurred.

The release job checks uploaded build numbers directly with App Store Connect
before creating an archive. If the requested number was already used, it stops
and reports the next available number without uploading anything.

The workflow rebuilds and signs the selected source, uploads it to Apple, waits
for Apple's processing, and verifies or assigns it to the existing internal
testing group. It saves Apple's processing result as a separate artifact. It
does not create external testers or submit an App Store release. If processing
or group verification fails after upload, inspect the build in App Store Connect
before retrying; do not upload a duplicate build number.

Temporary signing files and the runner keychain are deleted at job cleanup.
Signing credentials stay in GitHub and are not needed in the Linux cloud editor.

## GitHub access

The person or connection editing this repository needs permission to push code
and update workflow files. The connection starting builds needs Actions write
permission. Someone with permission to manage repository secrets must perform
the one-time credential setup above. Repository administrators should also check
that GitHub Actions and GitHub-hosted Mac runner usage are enabled and have
available capacity or billing allowance.
