"""Ensure the complication has an App Store bundle ID using existing CI auth.

JWT credentials remain in memory; no tokens, key material or profiles are logged.
"""
import base64
import json
import os
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

def b64(value):
    return base64.urlsafe_b64encode(value).decode().rstrip("=")

header = b64(json.dumps({"alg":"ES256", "kid":os.environ["ASC_KEY_ID"], "typ":"JWT"}).encode())
now = int(time.time())
payload = b64(json.dumps({"iss":os.environ["ASC_ISSUER_ID"], "iat":now, "exp":now+600, "aud":"appstoreconnect-v1"}).encode())
signing_input = (header+"."+payload).encode()
signature = subprocess.run(["openssl", "dgst", "-sha256", "-sign", os.environ["ASC_KEY_PATH"]], input=signing_input, capture_output=True, check=True).stdout
# OpenSSL emits ASN.1 DER; ES256 JWT uses two fixed-width 32-byte integers.
assert signature[0] == 0x30 and signature[1] < 128
offset = 2
parts = []
for _ in range(2):
    assert signature[offset] == 2
    size = signature[offset+1]
    integer = int.from_bytes(signature[offset+2:offset+2+size], "big")
    parts.append(integer.to_bytes(32, "big"))
    offset += 2+size
token = header+"."+payload+"."+b64(b"".join(parts))

def request(path, body=None):
    req = urllib.request.Request("https://api.appstoreconnect.apple.com/v1/"+path,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization":"Bearer "+token, "Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        # Apple error codes/details identify account/provisioning blockers, not auth.
        result = json.load(error)
        print(json.dumps({"status":error.code, "errors":[{k:v for k,v in item.items() if k in ("code","title","detail")} for item in result.get("errors",[])]}))
        raise SystemExit(1) from None

identifier = "dev.fancontrol.watch.watchkitapp.activepanel"
result = request("bundleIds?"+urllib.parse.urlencode({"filter[identifier]":identifier}))
if not result["data"]:
    result = request("bundleIds", {"data":{"type":"bundleIds", "attributes":{"identifier":identifier,"name":"Fan Control Active Panel Complication","platform":"IOS"}}})
    print("Registered active-panel complication bundle ID")
else:
    print("Active-panel complication bundle ID already registered")

# Existing phone and watch identities require independent APNs capabilities.
for identifier in ("dev.fancontrol.watch", "dev.fancontrol.watch.watchkitapp"):
    result = request("bundleIds?"+urllib.parse.urlencode({"filter[identifier]":identifier}))
    matches = [item for item in result["data"] if item["attributes"]["identifier"] == identifier]
    assert len(matches) == 1, "Exact bundle ID missing or ambiguous"
    bundle = matches[0]["id"]
    capabilities = request("bundleIds/"+bundle+"/bundleIdCapabilities")
    if not any(item["attributes"]["capabilityType"] == "PUSH_NOTIFICATIONS" for item in capabilities["data"]):
        request("bundleIdCapabilities", {"data":{"type":"bundleIdCapabilities",
            "attributes":{"capabilityType":"PUSH_NOTIFICATIONS"},
            "relationships":{"bundleId":{"data":{"type":"bundleIds","id":bundle}}}}})
        print("Enabled Push Notifications: " + identifier)
    else:
        print("Push Notifications already enabled: " + identifier)
