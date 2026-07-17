# Yet Another SIDEQUEST — "Glory" Design System

A jewel-toned, hand-set fantasy UI system for a mobile RPG. The north star: **furniture, not flat cards.** Every surface is a made *object* — carved brass, oiled wood, unfurled parchment — pressed with chamfered corners and a fine hairline. Inspired by Sierra's *Quest for Glory* (VGA era), with *For the King* banners/hex pips and *Minecraft Dungeons* blocky loot slots. It is **not** pixel art, and **not** a webpage in a costume — it is illustrated chrome with opinions.

---

## 1. Principles

1. **Objects, not surfaces.** A panel is a carved thing with edge light, an inset face, and a shadow that follows its cut — never a plain rounded rectangle.
2. **One panel language everywhere.** The chamfered plate (angled corners + gold/purple hairline) is the single container primitive — status scrolls, menus, buttons, the tab bar. Consistency is the point.
3. **Personality from bevels, not roundness.** Radii stay modest (5–12px). Depth and character come from chamfers, edge highlights, and inset carving.
4. **Restrained magic.** The palette is warm jewel tones (brass, parchment, royal purple, oxblood, forest). The one modern intrusion is **arcane teal** — held back so it reads as genuinely otherworldly only when the veil tears.
5. **Hand-set type.** Inscriptional caps (Cinzel) over a literary serif (Alegreya). It should look typeset in a tome, never sans-slick.
6. **The hero is a character, not a portrait chip.** Real standing sprite art steps *free* of the chrome — unframed, feet on the floor — rather than boxed in a slot.

---

## 2. Design tokens

Drop this `:root` block in verbatim. All component recipes below reference these.

```css
:root{
  /* stone / night base */
  --stone-950:#0f0e15; --stone-900:#161520; --stone-850:#1d1c29; --stone-800:#252336; --stone-line:#3a3550;
  /* wood */
  --wood-900:#241408; --wood-700:#43290f; --wood-600:#5a3a1a; --wood-500:#6f4a26;
  /* brass / gold */
  --brass-hi:#f6dc92; --brass:#c9932f; --brass-lo:#8a5f1e; --brass-edge:#5e3f10;
  /* parchment */
  --parch-hi:#f5e7c2; --parch:#e6cd9c; --parch-lo:#cdad78; --parch-edge:#b58e52;
  --ink:#2c1c0c; --ink-soft:#5a4327; --ink-faint:#8a6c42;
  /* royal purple (frame lacquer) */
  --royal:#3b2c72; --royal-lt:#6350ad; --royal-deep:#241a49;
  /* jewel states */
  --ox:#b23a34; --ox-deep:#5a1714;              /* HP  */
  --moss:#6a9440; --moss-deep:#2c4118;          /* SP / good */
  --sapphire:#3b6fc0; --sapphire-deep:#182f5c;  /* MP */
  --arcane:#34c2d0; --arcane-hi:#7ff0fb; --arcane-deep:#0e5560; /* the veil rift — used sparingly */
  /* rarity gems: common → legendary */
  --gem-common:#9aa1b0; --gem-uncommon:#6a9440; --gem-rare:#3b6fc0; --gem-epic:#8455c0; --gem-legendary:#e0a93a;

  /* type */
  --font-crest:'Cinzel Decorative', serif;      /* logo + hero numerals */
  --font-title:'Cinzel', serif;                 /* panel titles, buttons */
  --font-body:'Alegreya', Georgia, serif;       /* reading copy */
  --font-label:'Barlow Semi Condensed', 'Arial Narrow', sans-serif; /* HUD / labels */
  --fs-display:36px; --fs-h1:27px; --fs-h2:21px; --fs-h3:17px; --fs-body:16px; --fs-small:13px; --fs-micro:11px;

  /* spacing — 4px base */
  --s1:4px; --s2:8px; --s3:12px; --s4:16px; --s5:24px; --s6:32px; --s7:48px; --s8:64px;
  /* radius — modest; personality comes from bevels */
  --r-btn:5px; --r-sm:6px; --r-md:9px; --r-lg:12px; --r-pill:999px;

  /* material recipes */
  --g-brass:linear-gradient(155deg,#e6c266,#c9932f 50%,#a2751f);
  --g-brass-diag:linear-gradient(155deg,#eccb78,#c9932f 48%,#9a6a20);
  --g-wood:linear-gradient(155deg,#6f4a26,#3c2410);
  --g-boss:radial-gradient(circle at 34% 30%,#f2d585,#c9932f 60%,#8a5f1e);
  --g-parch:radial-gradient(135% 115% at 28% 6%, #f6e9c6, #e2c791 66%, #cdad78);
  --sh-plate:inset 0 1px 0 rgba(255,244,214,.24), inset 0 -3px 0 rgba(74,32,10,.5), 0 3px 0 #4a2f18, 0 7px 12px rgba(0,0,0,.5);
  --sh-plate-sm:inset 0 1px 0 rgba(255,244,214,.2), inset 0 -2px 0 rgba(74,32,10,.5), 0 2px 0 #4a2f18, 0 4px 7px rgba(0,0,0,.45);
  --sh-carve:inset 0 2px 5px rgba(0,0,0,.6), inset 0 -1px 0 rgba(255,255,255,.06);
  --sh-frame:0 0 0 2px var(--brass-edge), 0 8px 20px rgba(0,0,0,.55);

  --ease:cubic-bezier(.2,.8,.2,1); --t-tap:90ms; --t-base:200ms;

  /* frame language */
  --hairline:#6a6480; --gold-line:#e6cf95; --panel:rgba(22,18,30,.92);
  --hex:polygon(50% 0,100% 27%,100% 73%,50% 100%,0 73%,0 27%);
  --ribbon:polygon(0 50%,11px 0,calc(100% - 11px) 0,100% 50%,calc(100% - 11px) 100%,11px 100%);
  --chamfer:polygon(9px 0,calc(100% - 9px) 0,100% 9px,100% calc(100% - 9px),calc(100% - 9px) 100%,9px 100%,0 calc(100% - 9px),0 9px);
  --chamfer-lg:polygon(15px 0,calc(100% - 15px) 0,100% 15px,100% calc(100% - 15px),calc(100% - 15px) 100%,15px 100%,0 calc(100% - 15px),0 15px);
  --chamfer-sm:polygon(6px 0,calc(100% - 6px) 0,100% 6px,100% calc(100% - 6px),calc(100% - 6px) 100%,6px 100%,0 calc(100% - 6px),0 6px);
}
```

### Fonts (Google Fonts)

```html
<link href="https://fonts.googleapis.com/css2?family=Cinzel+Decorative:wght@700;900&family=Cinzel:wght@500;600;700&family=Alegreya:ital,wght@0,400;0,500;0,700;1,400;1,500&family=Alegreya+SC:wght@500;700&display=swap" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@20..48,500,0..1,0" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=Barlow+Semi+Condensed:wght@500;600;700&display=swap" rel="stylesheet">
```

### App background

```css
background:
  radial-gradient(1100px 620px at 50% -8%, #2b2540 0%, transparent 58%),
  linear-gradient(180deg,#14131c,#100e15);
color:#efe3cd;
```

---

## 3. Color usage

| Role | Token(s) | Notes |
|---|---|---|
| App base / night | `--stone-950 … --stone-800` | Deep desaturated indigo-black. Panels sit on this. |
| Container faces | `--stone-850`, `--panel` | Inset panel interiors. |
| Primary metal / CTA | `--brass*`, `--g-brass` | The hero material. Gold hairline = `--gold-line`. |
| Parchment (reading) | `--parch*` + `--ink*` for text | Warm scrolls; **ink** colors are the text-on-parchment palette. |
| Secondary frame lacquer | `--royal*` | Dialog/menu accents; hairline in purple. |
| **HP** | `--ox` / `--ox-deep` | Oxblood red. |
| **SP / positive** | `--moss` / `--moss-deep` | Forest green. |
| **MP** | `--sapphire` / `--sapphire-deep` | Blue. |
| **The rift / magic** | `--arcane`, `--arcane-hi` | Teal. **Sparingly** — reserve for veil/breach/enchant moments. |
| Rarity | `--gem-common → --gem-legendary` | grey → green → blue → purple → gold. Used for loot slot borders + gem chips. |

**Rule:** never introduce a new hue. If you need a tint, derive it from an existing token with `oklch()` or by adjusting the gradient stops. Teal is a privilege, not a default.

---

## 4. Type system

- **`--font-crest` (Cinzel Decorative)** — the SIDEQUEST logo and large hero numerals only. Heavy, ceremonial.
- **`--font-title` (Cinzel)** — panel titles, button labels, nameplates. Inscriptional caps, letter-spacing ~.04–.08em.
- **`--font-body` (Alegreya)** — all reading copy, NPC dialog (use *italic* for asides/murmurs). Warm calligraphic serif.
- **`--font-label` (Barlow Semi Condensed)** — HUD, stat labels, tiny caps, meter labels. Sturdy and legible at small sizes; use uppercase + tracking for labels.

Type scale is `--fs-*` (36 → 11px). Minimum on-screen label size ~11px; body 16px.

---

## 5. Material recipes

Six shadow/gradient "materials" do the heavy lifting:

- **Brass plate** — `--g-brass` fill, `2px solid var(--brass-edge)` border, `--sh-plate` shadow. Text is dark ink (`#3a2409`) with a top white text-shadow (embossed). This is the **primary CTA**.
- **Wood plate** — `--g-wood` fill, `--wood-900` border, parchment text. Secondary/neutral actions.
- **Oxblood plate** — `linear-gradient(155deg,#b0433c,#8a2723 55%,#661a16)`, border `#4a1512`, light text. Destructive actions ("Abandon Quest").
- **Parchment** — `--g-parch` face for reading surfaces; text in `--ink`/`--ink-soft`.
- **Carved (inset)** — `--sh-carve` for recessed wells (meter tracks, sprite slots).
- **Frame** — `--sh-frame` = 2px brass-edge ring + drop shadow, wraps important panels.

Tap feedback on all plates: `style-active="transform:translateY(2px)"`, transition `--t-tap`.

---

## 6. The chamfered panel (core primitive)

Every container is one of these. Pattern: an outer element clipped to a chamfer holds the hairline color; a `::before` inset by ~1.5–3px, clipped to the same chamfer, holds the face. Content sits at `z-index:1`.

```css
.cpanel{ position:relative; clip-path:var(--chamfer-lg); background:var(--hairline);
         filter:drop-shadow(0 6px 16px rgba(0,0,0,.5)); }
.cpanel::before{ content:""; position:absolute; inset:1.5px; clip-path:var(--chamfer-lg);
                 background:var(--stone-850); z-index:0; pointer-events:none; }
.cpanel > *{ position:relative; z-index:1; }
```

Named variants (all same construction, different fill + hairline):

| Class | Hairline | Face | Use |
|---|---|---|---|
| `.cpanel` | `--hairline` (purple-grey) | `--stone-850` | Default dark showcase / section container |
| `.dpanel` | `--hairline` | `--stone-850` (thinner inset) | HUD readout wells |
| `.ppanel` | `--brass` | `--g-parch` | Parchment scroll (gold hairline) |
| `.prpanel` | `--royal-lt` | `--g-parch` | Parchment with royal-purple hairline (dialog/menu) |
| `.wpanel` | `--wood-500` | `--g-wood` | Wood plate (toasts, small bars) |

Use `--chamfer-lg` for large panels, `--chamfer` for standard, `--chamfer-sm` for chips/buttons.

---

## 7. Component kit

### Buttons — carved plates (min 50px tall, 44px hit target floor)
Three tiers: **brass** (primary), **wood** (secondary/retreat), **oxblood** (destructive). Cinzel label, embossed text-shadow, `--sh-plate`, `translateY(2px)` on active.

### Status readout (`.dpanel`)
Titled dark well. Rows of labeled meters: label (`--font-label`, uppercase), then a carved track (`background:#0e0c14; inset shadow; padding:2px`) with a rounded fill gradient `linear-gradient(180deg, hi, base)` + top highlight. HP=ox, MP=sapphire, SP=moss. Combat status panel is labeled **"You"** (personal, not "Hero Status").

### List menu (`.prpanel`)
Quest-for-Glory dialog menu: rows with a small **ink diamond bullet** (`8px` square rotated 45°, `--ink-soft`) + Cinzel label. Active row gets a subtle bg wash. No shiny studs.

### Toast (`.wpanel`)
Wood bar: Material Symbol icon (brass-hi) + Alegreya message with a brass-hi keyword.

### Ribbon nameplate
Pointed-end banner via `--ribbon` clip. Outer holds hairline (1.5px), inner holds fill (dark or `--g-brass`), Cinzel uppercase label. Used for names/tags ("Hunter", class badges).

### Hex badge / stat pip
`--hex` clip, hairline outer + gradient inner. Two-line: tiny label (LEVEL/POWER/STR…) over a Cinzel numeral. Stat pips (STR/AGI/MAG/DEF/LCK) use faceted jewel gradients.

### Blocky loot slot (Minecraft Dungeons)
Square, `aspect-ratio:1`, `border-radius:5px`, dark diagonal fill. Rarity via **layered inset ring**: `inset 0 0 0 2px var(--gem-X), inset 0 0 0 4px rgba(0,0,0,.5)`. Rare+ adds an outer glow. Corner triangle flag for top-tier; small count numeral bottom-right; empty slot = dashed border + faint `close` glyph. Enchant sockets = small diamonds (`polygon(50% 0,100% 50%,50% 100%,0 50%)`).

### Command panel (combat)
Chamfered bar of ability buttons (replaces the old radial dial). Each button: filled Material Symbol icon, Cinzel uppercase name, damage value with a small type icon, a sub-label, and a row of **diamond cost pips**. This is the primary combat input.

### Portrait / hero art
**Do not box the hero.** Render real standing sprite art (PNG with transparent bg, `.pixel` class for `image-rendering:pixelated`) placed free — feet on the floor, drop shadow beneath, stepping past any frame edge. Small framed portrait chips (brass-diag frame + inset) are only for NPCs/dialog (e.g. Marrak). A red health **gem** may ride the hero's nameplate (a *For the King* touch).

### Gem chip
Pill (`--wood-900` bg, brass-edge border) with a radial-gradient rarity gem + uppercase rarity name.

### Rarity gem (animated)
Circle with `radial-gradient(circle at 35% 30%, #fff8, color 55%, dark)`, brass inset ring; legendary/arcane may pulse via `g-gem`.

---

## 8. Iconography

Material Symbols Rounded (`.msym { font-family:'Material Symbols Rounded'; }`). Use `font-variation-settings:'FILL' 1` for active/emphasis states. No hand-drawn SVG icons; no emoji.

---

## 9. Motion

Defined keyframes (respect `prefers-reduced-motion`, which kills all animation/transition):

- `g-gem` — arcane drop-shadow pulse (legendary/magic gems).
- `g-rift` — expanding teal ring (breach/veil markers).
- `g-crit` — scale+rotate pop-in for crit numbers.
- `g-float` — floating combat damage numbers rising + fading.
- `g-glow` — brass drop-shadow pulse (hero/CTA emphasis moments).

Interaction timing: `--t-tap` 90ms for taps, `--t-base` 200ms for state changes, all on `--ease` `cubic-bezier(.2,.8,.2,1)`.

---

## 10. Layout & spacing

- 4px spacing scale (`--s1…--s8`). Section rhythm at `--s6` (32px).
- Content max-width ~1180px on the showcase; the app itself is a **mobile RPG** — design screens portrait-first with a chamfered wood tab bar (Map / Camp / Hero / Party) using Material Symbol icons + labels, active tab = mini brass plate.
- Section headers: a small roman-numeral pill (`--wood-700` bg, `--sh-plate-sm`) + Cinzel title.

---

## 11. Do / Don't

**Do**
- Make every container a chamfered plate with a hairline.
- Keep teal rare and meaningful.
- Let the hero sprite break out of its frame.
- Use ink diamond bullets, hex pips, ribbon nameplates, blocky rarity slots.
- Emboss brass button text; sink meter tracks.

**Don't**
- Plain rounded cards, flat drop-shadow "web" panels, or big border-radius.
- Gradient-wash backgrounds beyond the defined app base.
- Emoji, hand-drawn SVG icons, or sans-serif body copy.
- Rosette/boss corner ornaments (retired) or shiny stud bullets (retired).
- New hues outside the token set.
- Boxing the hero portrait in a slot.
