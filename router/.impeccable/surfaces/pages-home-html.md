---
version: 1
slug: "pages-home-html"
primary_target: "pages/home.html"
related_targets: ["pages/bulb.html","pages/devices.html","pages/fibre.html"]
---

# tazer control pages

Scope: home (pages/home.html), bulb, devices, fibre; shared pages/style.css. Visitor mode: Operate.
Audience: owner and household, any time of day, iPhone one-handed or Mac. Job: switch/dim/recolour the light fast; read internet, Wi-Fi and fibre health in plain words.
Constraints: one-request-at-a-time shell server; no external fonts or assets; pages stay small; no polling while hidden.

## Direction contract

THESIS: tazer is a warm household app where the light is the one big friendly control on every screen. It refuses the category default of a dark dashboard of tiles and the settings-list clone.

OWN-WORLD: warm cream ground (light #FFF4E6, dark warm charcoal #1C1714), white cards (dark #29221D) with 22px radii and a 1px warm border, warm brown text, one action orange #FF6A3D reserved for things you can press and the active tab. Rounded system sans (ui-rounded). Line icons, 1.75 stroke, in tinted round wells. Green, amber and red appear only on health words.

STORY: open tazer, see whether the light is on and flip it with a thumb; read internet, devices and fibre health as words; tap through for detail and fine control.

FIRST VIEWPORT: home at 390 wide: "tazer" title with a status line (internet latency, time); a large Bulb card with state words, a round orange power button at right and a brightness slider; two half-width cards, Devices (count, live speed) and Fibre (verdict word in its state colour, dBm); a persistent bottom bar Home, Bulb, Devices, Fibre with the active tab in orange. Primary action: the power button.

FORM: dealt challenger digital-design-canon-warm-consumer-app-surface, chosen by the user over the assigned direction (assigned was candidate 7 of 7). seed:d4535f755586e457. Signature interaction: the bulb card's light swatch re-tints live while you drag brightness or white. Motion: press feedback scale .97 over 160ms, no entrance animation.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
