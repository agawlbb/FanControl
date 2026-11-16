#!/bin/bash
set -euo pipefail
: "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_PATH:?}" "${IOS_TEAM_ID:?}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]{0,8}$ ]]
[[ "$IOS_TEAM_ID" == FKR675M7PM ]]
auth=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
python3 scripts/register_bundle.py
swift test
xcodegen generate
mkdir -p build
xcodebuild -project FanControlWatch.xcodeproj -scheme FanControl -configuration Release \
  -jobs 2 -destination 'generic/platform=iOS' -archivePath build/FanControlWatch.xcarchive \
  DEVELOPMENT_TEAM="$IOS_TEAM_ID" CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" -allowProvisioningUpdates "${auth[@]}" archive
python3 - <<'PY'
import os, plistlib
from pathlib import Path
archive=Path('build/FanControlWatch.xcarchive/Products/Applications')
apps=list(archive.glob('*.app'))
assert len(apps)==1, 'Missing distribution container'
watch=list((apps[0]/'Watch').glob('*.app'))
assert len(watch)==1, 'Missing embedded watch app'
for bundle, expected in [(apps[0],'dev.fancontrol.watch'),(watch[0],'dev.fancontrol.watch.watchkitapp')]:
    info=plistlib.loads((bundle/'Info.plist').read_bytes())
    assert info['CFBundleIdentifier']==expected
    assert info['CFBundleVersion']==os.environ.get('BUILD_NUMBER','1')
assert plistlib.loads((watch[0]/'Info.plist').read_bytes())['WKRunsIndependentlyOfCompanionApp']
assert not plistlib.loads((apps[0]/'Info.plist').read_bytes()).get('LSApplicationLaunchProhibited', False)
extensions=list((watch[0]/'PlugIns').glob('*.appex'))
assert len(extensions)==1, 'Missing active-panel complication'
info=plistlib.loads((extensions[0]/'Info.plist').read_bytes())
assert info['CFBundleIdentifier']=='dev.fancontrol.watch.watchkitapp.activepanel'
assert info['CFBundleVersion']==os.environ.get('BUILD_NUMBER','2')
assert info['NSExtension']['NSExtensionPointIdentifier']=='com.apple.widgetkit-extension'
Path('build/ExportOptions.plist').write_bytes(plistlib.dumps({
    'method':'app-store-connect','teamID':os.environ['IOS_TEAM_ID'],
    'signingStyle':'automatic','manageAppVersionAndBuildNumber':False,'destination':'export'}))
PY

xcodebuild -exportArchive -archivePath build/FanControlWatch.xcarchive -exportPath build/signed \
  -exportOptionsPlist build/ExportOptions.plist -allowProvisioningUpdates "${auth[@]}"
# Archive with the existing imported identity; distribution signing happens at export.
python3 - <<'PY'
import plistlib, subprocess, tempfile, zipfile
from pathlib import Path
packages=list(Path('build/signed').glob('*.ipa'))
assert len(packages)==1, 'Expected one signed package'
with tempfile.TemporaryDirectory() as temp:
    with zipfile.ZipFile(packages[0]) as archive: archive.extractall(temp)
    app=next((Path(temp)/'Payload').glob('*.app'))
    subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
    watch=next((app/'Watch').glob('*.app'))
    phone_entitlements=plistlib.loads(subprocess.run(['codesign','-d','--entitlements',':-',str(app)],capture_output=True,check=True).stdout)
    assert phone_entitlements.get('aps-environment')=='production', 'Phone distribution push entitlement missing'
    entitlements=plistlib.loads(subprocess.run(['codesign','-d','--entitlements',':-',str(watch)],capture_output=True,check=True).stdout)
    assert entitlements.get('aps-environment')=='production', 'Watch distribution push entitlement missing'
    assert plistlib.loads((watch/'Info.plist').read_bytes())['FanControlAPNSEnvironment']=='production', 'Watch APNs environment mismatch'
    for bundle in [app,watch,*list((watch/'PlugIns').glob('*.appex'))]:
        info=plistlib.loads((bundle/'Info.plist').read_bytes())
        assert info['CFBundleIdentifier'] in ['dev.fancontrol.watch','dev.fancontrol.watch.watchkitapp','dev.fancontrol.watch.watchkitapp.activepanel']
        assert info['CFBundlePackageType']==('XPC!' if bundle.suffix=='.appex' else 'APPL')
        signature=subprocess.run(['codesign','-d','--verbose=4',str(bundle)],capture_output=True,text=True,check=True).stderr
        assert 'Identifier='+info['CFBundleIdentifier']+'\n' in signature, 'Signature identifier mismatch'
        assert 'TeamIdentifier=FKR675M7PM' in signature, 'Signature team mismatch'
        assert (bundle/'embedded.mobileprovision').is_file(), 'Distribution profile missing'
PY
if [[ "${UPLOAD:-false}" == true ]]; then
  python3 - <<'PY'
import plistlib
from pathlib import Path
p=Path('build/ExportOptions.plist'); options=plistlib.loads(p.read_bytes())
options['destination']='upload'; Path('build/UploadOptions.plist').write_bytes(plistlib.dumps(options))
PY
  xcodebuild -exportArchive -archivePath build/FanControlWatch.xcarchive -exportPath build/upload \
    -exportOptionsPlist build/UploadOptions.plist -allowProvisioningUpdates "${auth[@]}"
fi



