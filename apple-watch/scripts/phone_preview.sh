#!/bin/bash
set -euo pipefail
mkdir -p build
xcrun simctl list devices available --json > build/phone-simulators.json
udid=$(python3 - <<'PY'
import json
for runtime, entries in json.load(open('build/phone-simulators.json'))['devices'].items():
    for device in entries:
        if 'iOS' in runtime and device['name'].startswith('iPhone'):
            print(device['udid']); raise SystemExit
raise SystemExit('No iPhone simulator runtime installed')
PY
)
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b
xcrun simctl install "$udid" build-phone/Build/Products/Debug-iphonesimulator/FanControl.app
xcrun simctl launch "$udid" dev.fancontrol.watch
sleep 3
xcrun simctl io "$udid" screenshot build/phone-first-launch.png
xcrun simctl terminate "$udid" dev.fancontrol.watch
xcrun simctl launch "$udid" dev.fancontrol.watch --preview-companion
sleep 3
xcrun simctl io "$udid" screenshot build/phone-companion.png
xcrun simctl terminate "$udid" dev.fancontrol.watch
xcrun simctl launch "$udid" dev.fancontrol.watch --preview-companion --preview-settings
sleep 3
xcrun simctl io "$udid" screenshot build/phone-settings.png
xcrun simctl shutdown "$udid"
