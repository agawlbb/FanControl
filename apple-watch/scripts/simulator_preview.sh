#!/bin/bash
set -euo pipefail
xcrun simctl list devices available --json > build/simulators.json
udid=$(python3 - <<'PY'
import json
with open('build/simulators.json') as f: devices=json.load(f)['devices']
for runtime, entries in devices.items():
    if 'watchOS' in runtime and entries:
        print(entries[0]['udid']); break
else: raise SystemExit('No watchOS simulator runtime installed')
PY
)
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b
xcrun simctl install "$udid" build/Build/Products/Debug-watchsimulator/FanControlWatch.app
xcrun simctl launch "$udid" dev.fancontrol.watch.watchkitapp
sleep 3
xcrun simctl io "$udid" screenshot build/watch-first-launch.png
for mode in driving exercise; do
    xcrun simctl terminate "$udid" dev.fancontrol.watch.watchkitapp
    xcrun simctl launch "$udid" dev.fancontrol.watch.watchkitapp "--preview-$mode"
    sleep 2
    xcrun simctl io "$udid" screenshot "build/watch-$mode.png"
done
xcrun simctl terminate "$udid" dev.fancontrol.watch.watchkitapp
xcrun simctl launch "$udid" dev.fancontrol.watch.watchkitapp --preview-exercise --preview-playing
sleep 2
xcrun simctl io "$udid" screenshot build/watch-exercise-playing.png
xcrun simctl terminate "$udid" dev.fancontrol.watch.watchkitapp
xcrun simctl launch "$udid" dev.fancontrol.watch.watchkitapp --preview-exercise --preview-settings
sleep 2
xcrun simctl io "$udid" screenshot build/watch-settings.png
xcrun simctl terminate "$udid" dev.fancontrol.watch.watchkitapp
xcrun simctl launch "$udid" dev.fancontrol.watch.watchkitapp --preview-driving --preview-pending
sleep 2
xcrun simctl io "$udid" screenshot build/watch-driving-pending.png
for mode in driving exercise; do
    for phase in pending accepted; do
        xcrun simctl terminate "$udid" dev.fancontrol.watch.watchkitapp
        xcrun simctl launch "$udid" dev.fancontrol.watch.watchkitapp "--preview-$mode" "--preview-action-$phase"
        sleep 2
        xcrun simctl io "$udid" screenshot "build/watch-$mode-action-$phase.png"
    done
done
xcrun simctl shutdown "$udid"
