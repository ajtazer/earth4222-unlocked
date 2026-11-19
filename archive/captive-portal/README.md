# Archived: Wi-Fi welcome pop-up (captive portal) — failed

**Status: removed from the live router code. Kept here for reference.**

## What it tried
Show a welcome sheet ("Welcome to Tazer's Wi-Fi") on a chosen device the next time it joins Wi-Fi,
the same way hotel Wi-Fi pops up a login page:

1. `/api?a=portal&mac=<mac>` inserted an iptables rule redirecting that device's port-80 traffic to the tazer server.
2. When the device rejoined, iOS/macOS fetched `captive.apple.com/hotspot-detect.html`; the server answered with `portal.html` instead of "Success", which makes the OS open its captive-portal sheet.
3. "Continue" called `/api?a=portaloff`; the server found the caller via the single ESTABLISHED connection on :8080 in `/proc/net/tcp`, mapped its IP to a MAC through ARP, and deleted the rule.

The mechanism itself worked when tested with curl (welcome page while armed, release on Continue, Apple's "Success" afterwards).

## Why it failed
Our own Apple devices use **rotating private Wi-Fi addresses**: the iPhone and the Mac each came back from a Wi-Fi toggle with a
new MAC, so a rule armed for the old MAC never matched. Arming by MAC can't catch a device that changes its MAC exactly when it reconnects.
It was never confirmed whether Apple devices re-check a network they already know.

## If someone revives it
Arm "every device except an allow-list" instead of one MAC, test with a guest device that joins for the first time,
and auto-remove the rule after a few minutes.

Files: `portal.html` (the sheet), `portal-api.sh` (the removed `portal|portaloff` handler from `router/wiz.sh`).
