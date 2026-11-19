# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users
The owner and their household. Household members open `http://tazer` mainly to control the smart bulb, so every control must be obvious to non-technical people. Guests never see the control pages; they only meet the Wi-Fi welcome page (captive portal) when their device first joins.

## Product Purpose
A home control panel that runs on the household's ISP fibre router (EARTH-4222) itself, with no extra hardware, app or cloud service. It controls a WiZ smart bulb, shows which devices are on the Wi-Fi and how much they use, and reports the fibre signal's health. Success: anyone at home can switch, dim or recolour the light in a couple of taps, and the owner can tell at a glance whether the internet, the Wi-Fi and the fibre line are healthy.

## Positioning
It lives on the router everyone already has: an unlocked ISP box serving pages from its own shell and netcat, reachable at `http://tazer`. Nothing to install on phones, no account, nothing outside the house.

## Operating Context
Used at any time of day, on iPhones and a Mac on the home Wi-Fi, often one-handed. Opened from Safari or a Home Screen icon. The internet-down alarm turns the bulb red during outages, so the panel is also checked when something feels off.

## Capabilities and Constraints
- Bulb: on/off/toggle, brightness 10–100 %, white 2200–6500 K, RGB colour, WiZ scenes with speed, sleep timer.
- Devices: per-device Wi-Fi band, signal, live down/up speed and data since connecting; wired devices listed without usage. Names come only from what devices report (no hand-set nicknames: phones rotate private addresses).
- Fibre: received/transmitted optical power, module temperature, voltage, laser bias, with a healthy/weak/critical verdict.
- Welcome page: captive-portal sheet for chosen devices on their next join.
- Server: one request at a time from a shell script; every page must stay small, avoid polling when hidden, and retry briefly when a request is refused. All files live in router RAM and are redeployed after a router reboot.
- No external assets at runtime (no CDNs, web fonts or images from the internet); everything is served by the router.

## Brand Commitments
Name: "tazer" (lowercase), reached at `http://tazer`.

## Evidence on Hand
Live readings only (bulb state, device list, fibre values). No photos, logos or other assets exist; do not invent any.

## Product Principles
- The light comes first: bulb control is one tap from opening the panel.
- Readable at a glance: health states are plain words (healthy, weak, offline), not raw numbers alone.
- Gentle on the router: fetch only what a page shows, only while it is visible.
- Familiar over clever: controls behave like the phone's own switches and sliders.

## Accessibility & Inclusion
Household members of any technical level; controls need clear labels, large touch targets and sufficient contrast in both light and dark system themes.
