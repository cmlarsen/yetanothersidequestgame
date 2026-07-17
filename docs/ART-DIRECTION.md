# Art Direction — Yet Another SIDEQUEST (Claude Code brief)

You are building the UI for **Yet Another SIDEQUEST**, a mobile fantasy RPG. This brief tells you how it must look and feel. The full spec (tokens, component recipes, material formulas) lives in **`DESIGN-SYSTEM.md`** — read it and treat its `:root` token block and panel classes as the source of truth. This file is the *taste* layer: the intent behind the tokens.

---

## The one-line brief

> **Illustrated chrome with opinions.** A jewel-toned fantasy interface where every surface is a hand-crafted *object* — carved brass, oiled wood, unfurled parchment — not a flat card. Think Sierra's *Quest for Glory* (VGA), with *For the King*'s banners and hex pips and *Minecraft Dungeons*' blocky loot slots. Modern in polish, old-world in soul.

It is **not** pixel-art UI, and it is **not** a web app in a fantasy skin. If a screen could pass for a generic mobile app with the colors swapped, it's wrong.

---

## Seven commandments

1. **Furniture, not flat cards.** Every container is a *made thing*: a chamfered plate with a fine gold or purple hairline, an inset face, and a shadow that follows its cut. Reach for the `.cpanel / .ppanel / .prpanel / .wpanel / .dpanel` primitives — never a plain `border-radius` div.

2. **One panel language everywhere.** The chamfered plate is the only container. Status scrolls, menus, buttons, the tab bar — all the same vocabulary. Do not invent a second card style.

3. **Personality from bevels, not roundness.** Keep radii modest (5–12px). Character comes from chamfered corners, edge highlights, embossed text, and carved wells — not from soft rounding or big shadows.

4. **Teal is sacred.** The palette is warm — brass, parchment, royal purple, oxblood, forest. **Arcane teal (`--arcane`)** is the single cold accent and it means *magic / the veil / the rift*. Use it rarely so it lands hard when the veil tears. Never as a default UI accent.

5. **Type is hand-set.** Cinzel (inscriptional caps) for titles, logo, numerals; Alegreya (literary serif) for all reading copy and NPC dialog (italic for murmured asides); Barlow Semi Condensed for HUD labels only. No sans-serif body. No system fonts.

6. **The hero is a character.** Render real standing sprite art that steps *free* of the chrome — unframed, feet on the floor, with a drop shadow. Do not box the hero in a portrait slot (framed chips are for NPCs only).

7. **Restraint is the aesthetic.** No gradient-wash backgrounds, no emoji, no hand-drawn SVG icons (use Material Symbols Rounded), no rosette corner ornaments, no shiny stud bullets. When a screen feels empty, solve it with layout and material — never with filler stats, badges, or decoration.

---

## Voice & copy

Warm, wry, second-person, lightly heroic. The tagline is *"So you want to be a hero."* NPCs speak in italic Alegreya. Labels are terse and inscriptional ("Enter the Breach", "Retreat", "Abandon Quest"). Combat status is labeled **"You"**, not "Hero Status" — keep it personal. Avoid corporate microcopy.

---

## How to build a screen

1. Start from the app background (defined base gradient) and lay panels on it.
2. Choose the right plate for each surface:
   - **Reading / scroll content →** `.ppanel` (gold hairline) or `.prpanel` (royal hairline for dialog/menus).
   - **HUD readouts (meters, stats) →** `.dpanel` dark well.
   - **Toasts / small bars →** `.wpanel` wood.
   - **General dark containers →** `.cpanel`.
3. Actions are **carved plates**: brass = primary, wood = secondary, oxblood = destructive. Min 50px tall, embossed Cinzel label, `translateY(2px)` on tap.
4. Meters: sink the track (`--sh-carve`, near-black bg), fill with the state color (HP ox / MP sapphire / SP moss) + top highlight.
5. Loot & stats: blocky rarity slots (layered inset rings colored by `--gem-*`), hex pips for stats, ribbon nameplates for names/classes, ink diamond bullets for lists.
6. Combat input is the **command panel** (chamfered ability bar with icon + name + damage + cost pips) — not a radial dial.
7. Navigation is a chamfered wood tab bar (Map / Camp / Hero / Party), Material Symbol icons + labels, active tab as a mini brass plate.
8. Animate with the defined keyframes only; always honor `prefers-reduced-motion`.

---

## Acceptance checklist (self-review before shipping any screen)

- [ ] Every container is a chamfered plate with a hairline — zero plain rounded cards.
- [ ] Only one card/panel language is in use.
- [ ] Teal appears only on magic/veil/enchant elements (or not at all).
- [ ] All type is Cinzel / Alegreya / Barlow — no sans body, no system fonts.
- [ ] The hero (if present) is a free-standing sprite, not a boxed portrait.
- [ ] Buttons are carved brass/wood/oxblood plates ≥44px hit target with tap feedback.
- [ ] No emoji, no SVG-drawn icons, no gradient-wash backgrounds, no filler content.
- [ ] Colors come only from the token set; new tints derived via `oklch()` from existing tokens.
- [ ] Icons are Material Symbols Rounded; `FILL 1` on active states.
- [ ] Reduced-motion is respected.

If any box is unchecked, the screen isn't done.

---

## Reference implementation

`YAS Quest-for-Glory Direction.dc.html` is the living style guide — it renders the full token set, the component kit, the frame language, and example screens (combat, inventory, hero moment). When in doubt, match it. When extending, extend *its* vocabulary rather than inventing new patterns.
