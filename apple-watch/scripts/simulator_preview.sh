#!/bin/bash
set -euo pipefail
xcrun simctl list devices available --json > build/simulators.json
udid=$(python3 - <<'PY'
import json, os, subprocess, sys
with open('build/simulators.json') as f: devices=json.load(f)['devices']
candidates=[(runtime, device) for runtime, entries in devices.items()
            if 'watchOS' in runtime for device in entries]
if not candidates: raise SystemExit('No watchOS simulator runtime installed')
# Prefer the requested Ultra 4; use another Ultra only when that model is absent.
types=json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devicetypes', '--json']))['devicetypes']
ultras=[device for device in types if 'Apple Watch Ultra' in device['name']]
preferred=max(ultras, key=lambda device: ('Ultra 4' in device['name'], device['name']), default=None)
created_udid=None
if preferred and not any(device['name']==preferred['name'] for _, device in candidates):
    runtime=sorted({runtime for runtime, _ in candidates})[-1]
    result=subprocess.run(['xcrun', 'simctl', 'create', 'FanControl Ultra Preview', preferred['identifier'], runtime],
                          capture_output=True, text=True)
    if result.returncode == 0:
        created_udid=result.stdout.strip()
        candidates.append((runtime, {'name':preferred['name'], 'udid':created_udid}))
    else:
        print('Could not create preferred Ultra simulator; choosing an installed device: '+result.stderr[:500], file=sys.stderr)
def priority(candidate):
    runtime, device=candidate
    name=device['name'].lower()
    return ('ultra 4' in name, 'ultra' in name, runtime, device['name'])
runtime, device=max(candidates, key=priority)
if os.environ.get('FLIGHT_PREVIEW_ONLY') == 'true' and 'Ultra 4' not in device['name']:
    raise SystemExit('Flight regression requires Apple Watch Ultra 4; no substitute model allowed')
selection={'name':device['name'], 'udid':device['udid'], 'runtime':runtime, 'created':device['udid']==created_udid}
print('Selected simulator: '+json.dumps(selection), file=sys.stderr)
with open('build/watch-simulator-selection.json', 'w') as f: json.dump(selection, f)
print(device['udid'])
PY
)
if ! xcrun simctl boot "$udid"; then
    # A selected simulator may already be booted on the Mac runner.
    xcrun simctl bootstatus "$udid" -b
fi
cleanup_simulator() {
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    if python3 -c 'import json; raise SystemExit(not json.load(open("build/watch-simulator-selection.json"))["created"])'; then
        xcrun simctl delete "$udid"
    fi
}
trap cleanup_simulator EXIT
xcrun simctl bootstatus "$udid" -b
xcrun simctl install "$udid" build/Build/Products/Debug-watchsimulator/FanControlWatch.app
if [[ "${FLIGHT_PREVIEW_ONLY:-false}" == true ]]; then
    for mode in focused completed delayed; do
        extra=()
        [[ "$mode" == focused ]] || extra+=("--preview-flight-$mode")
        xcrun simctl launch "$udid" dev.fancontrol.watch.watchkitapp --preview-flight "${extra[@]}"
        sleep 3
        xcrun simctl io "$udid" screenshot "build/watch-flight-$mode.png"
        xcrun simctl terminate "$udid" dev.fancontrol.watch.watchkitapp
    done
    exit 0
fi
xcrun simctl launch "$udid" dev.fancontrol.watch.watchkitapp
sleep 3
xcrun simctl io "$udid" screenshot build/watch-first-launch.png
for mode in driving exercise podcast; do
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
