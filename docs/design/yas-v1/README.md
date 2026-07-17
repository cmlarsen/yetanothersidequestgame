# Handoff: Yet Another Sidequest (YAS) — v1.0 Game UI

## Overview
YAS is a location-based mobile RPG: hexes overlay the real-world GPS map; walking claims
territory for your side while an AI faction (the Gloomlings) claims it back. Combat is
real-time on the map with an equippable cooldown hot bar and drop-in co-op. A tower-defense
layer lets players physically place defenses and manage them remotely; hired minions run
timed gathering jobs. Sessions are 5–15 minute "runs."

This package contains everything needed to build the v1.0 game shell: the design reference,
per-screen specs, the authoritative rules, and the data model.

## About the Design Files
The HTML files in this bundle are **design references created in HTML** — prototypes showing
intended look, layout, and behavior. They are NOT production code. The task is to **recreate
these designs in the target codebase** (per docs/RN-CONVERSION-PLAN.md in the game repo, the
target is React Native; if that changes, use the project's chosen stack) using its established
patterns. The 3D map/characters are KayKit-model renders in the real app; the mockups mark
every 3D region with a dashed "3D RENDER" placeholder.

## Fidelity
**High-fidelity visuals**: colors, typography, spacing, radii, copy, and component states are
final intent — recreate closely (exact tokens below and in SCREENS.md).
**Medium-fidelity motion/3D**: animations are indicative (bob, pulse rings, pop-ins);
3D content is placeholder. Numbers shown in mocks (damage, costs, %s) are real v1 tuning
defaults — see GAME-RULES.md.

## Reading order
1. **GAME-RULES.md** — authoritative mechanics. Every system has concrete v1 numbers;
   items marked DEFAULT are decided-but-tunable. Build to this; do not guess.
2. **SCREENS.md** — all 28 screens: purpose, elements, interactions, states, navigation.
3. **DATA-MODEL.md** — entities, fields, client/server split, notification triggers.
4. **YAS v1.0.dc.html** — the flow map: open in a browser; columns are app areas, arrows are
   navigation. Screens are pixel-accurate 402×874 (iPhone) frames.
5. **YAS UI Board.dc.html** — earlier exploration board; canonical only where v1.0 lacks a
   screen (hot-bar option studies). **YAS Combat Lab.dc.html** — four optional combat
   deepenings, NOT in v1 scope; kept for context.

## Design Tokens
Fonts (Google Fonts): **Lilita One** (display/headings/buttons/numbers, always uppercase for
labels) · **Nunito** 600–900 (body, micro-labels; micro-labels are 800 weight, 8–10px,
letter-spaced, uppercase).

Colors:
- Canvas/dark bg: #101319 · screen bg #151a26 · panel #141a28 · card #1b2130 · inset #0b0f18
- Border: #2c3852 (2–3px solid, everywhere) · muted text rgba(255,255,255,.4–.75)
- Primary cyan: #45d6f4 (accents), gradient CTA #63e2f8→#1fa9cc, text-on-cyan #083240,
  hard shadow #12586b · light cyan #7ee7fb
- Success green: #7ce843→#3aa74e, text-on-green #0e2a10, shadow #2a6a1e
- Gold: #ffd75e→#f2a92e, border #9c6b12, text-on-gold #4a3305/#5c3f06, shadow #b8891a ·
  warning chip #ffc93c
- Danger red: #ff7a5c→#e0342e, shadow #8a1a16 · pink accents #ff5f8a/#ff8fb0
- Gloomling purple: #9a63f0→#5c26b8, borders #3c1685/#4a2591, light #d9b8ff/#c9a2ff,
  hex tint #a163ff
- Rarity: Common #9aa5ba · Rare #3f8ee8 · Epic #c85cf0→#7a3fe0 · Legendary #ffe27a→#f2a92e
- Map: grass #a4c53c (variant #8fb332), path fill #f0dda6, path edge #d8bd80, trees #2f8f4e,
  water #3aa7ee, paper/parchment #f0dda6 (quest cards, speech bubbles, text #3a2c08/#6b5518)
- Player turf tint: #27d3f5 at 24–30% opacity (tweakable) · Gloom turf: rgba(150,80,255,.28)

Shape language: chunky "toy" style — 2–3px borders, 8–26px radii, HARD drop shadows
(box-shadow: 0 4px 0 <darker>, no blur) on cards/buttons, playful −2°..+2° rotations on
celebratory headlines/badges. Big CTAs: white 3px border + gradient + hard shadow.
Overlap treatments that are INTENTIONAL: stacked two-line display headlines, rotated "DONE!"
stamps over quest cards.

Minimum hit target 44px. Portrait only, 402×874 design frame.

## Assets
- assets/face-*.png — character faces cropped from the KayKit Adventurers pack art
  (barbarian, dwarf, mage, knight, huntress, beardruid, archer, druid). Stand-ins for live
  3D renders.
- All icons are inline SVG (stroke 2.2–2.6, round caps) — recreate with any icon lib or copy
  the paths. Resource glyphs use emoji in mocks (💰🪵🧪); replace with game icons in prod.
- Every dashed-border box labeled "ART" or "3D … RENDER" is a placeholder for KayKit renders.

## Files
- YAS v1.0.dc.html — canonical flow map (28 screens, all columns + nav arrows)
- YAS UI Board.dc.html — exploration board (hot-bar studies, earlier iterations)
- YAS Combat Lab.dc.html — combat variants, out of v1 scope
- GAME-RULES.md, SCREENS.md, DATA-MODEL.md — specs
- YAS-MECHANICS-EXTRAPOLATED.md — design rationale doc the rules grew from (background)
- assets/, ios-frame.jsx, support.js — needed for the HTML files to render
- Excluded on purpose: "YAS Mechanics Flow" (a superseded camp/turn-based direction)

## Out of scope for v1 (do not build)
Combat Lab variants (weakness-swap/timed-guard/smash/positioning), any camp/turn-based
system, aura/survivor combat, PvP between player factions.
