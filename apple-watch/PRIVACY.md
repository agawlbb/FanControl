# Privacy

Fan Control sends requests to your configured Home Assistant addresses. It has no advertising, tracking SDK or developer analytics service.

The watch stores an independent revocable command credential in device-only Keychain storage accessible after first unlock. The phone receives a separate revocable companion credential through Apple's paired WatchConnectivity channel. It permits observations, approved preferences, push registration and diagnostics; HA rejects physical commands from it. The watch command key is never copied to the phone. HA watch revocation revokes both keys. Unlink phone revokes only the companion key.

The phone fetches snapshots using APNs, opportunistic background refresh and foreground refresh. It stores approved configuration, observations, tile order and diagnostics locally, and sends credential-free snapshots to the watch. The watch keeps its own key. Background work never wakes vehicles. Watch commands and their validation/confirmation reads go directly to HA.

Optional push goes directly from HA to Apple's APNs service. Refresh payloads contain correlation hints; automation alerts contain their title, full message and send timestamp. The APNs signing key stays privately on HA, never in the app. The old hosted relay is retired. Push handling cannot issue HA or vehicle commands.

Automation message text is saved only on the iPhone from received/opened notifications or Notification Center. Messages expire after 12 hours or are dismissed by swiping. Cleanup removes matching Notification Center entries when the app runs. HA 0.14.0 retains no message history and sends no arrival clear-all instruction. Snapshots carry no message bodies. Unlinking clears phone messages and its delivered notifications. Alert text is not added to diagnostics.

Diagnostics retain up to 120 local events and HA attempts per watch, with correlation IDs, timestamps, panel identifiers and revisions. Review private entity names before sharing. Phone receipt, phone save and watch acknowledgment are separate evidence. APNs acceptance does not prove delivery. Device diagnostics are not sent to the developer.

Imported audio stays in private phone/watch storage and transfers through WatchConnectivity. It is not uploaded to the developer, relay or HA. Legacy explicit HA music download remains available in watch recovery. Headset names and the remembered watch audio-route identifier stay on the devices/paired HA. Removing a phone track takes effect on watch after Sync; ongoing playback can finish its current library. Unlink phone keeps the user's imported library. Forget connection on watch removes watch credentials, music and diagnostics.

Apple may provide TestFlight crash reports, beta feedback and diagnostics under its policies. Do not include private credentials or entity details in public issues. Use private GitHub security reporting when available.
