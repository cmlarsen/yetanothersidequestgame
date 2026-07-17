# UI kit — API contract

Shared components for the 28-screen shell. Screens build UI in GDScript
(no per-screen .tscn) from these pieces + `UI` (labels/layout), `Icons`
(runtime SVG), `Tokens` (colors/fonts), against `GameState`/`Catalog`/`Rules`
data. Never re-declare hex colors in screens; add missing tokens to Tokens.

Design language (docs/design/yas-v1/README.md): chunky "toy" — 2–3px borders,
8–26px radii, HARD offset shadows (no blur), gradients on CTAs/chips, playful
−2°..+2° rotations on celebratory headlines, min hit target 44px, 402×874.

## Existing (spine)

- `Tokens` — every color/f​ont token. `Tokens.body_font(weight, letter_spacing)`,
  `Tokens.display_font()`, `Tokens.white(a)`.
- `UI` — `display/body/micro` labels, `shadowed`, `wrap`, `centered`,
  `vbox/hbox/spacer/margin`, `place(parent, child, pos, size?)`,
  `place_centered_x(parent, child, y)`, `fill(parent, child)`.
- `Icons.tex(name, px, color, stroke_width?)` / `Icons.rect(...)` — runtime
  SVG set; add icons to `_ICONS` (24×24 viewBox) as needed.
- `ChunkyRect` — gradient fill + border (solid/dashed) + hard shadow + glow.
  `ChunkyRect.panel(top, radius, border?, border_w?, shadow?)`,
  `.with_gradient(top, bottom)`. Put it as the first child of a sized Control,
  `UI.fill`-ed.
- `Screen` — base class: override `build()`; helpers `add_bg(color)`,
  `bob(node)`, `pop_in(node, delay)`. `AppMode.freeze_motion` guards all loops.
- `Router.go(id)` / `Router.back()` — ids in `Router.ORDER`.

## Components (this directory)

All constructors are static `make(...)` returning a ready-to-place Control;
sizes are fixed by args or content. Signals only where noted.

- `ChunkyButton.make(text, kind, min_size := Vector2(0, 52), font_size := 17,
  icon := "") -> ChunkyButton` (extends BaseButton) — kinds: `cta_cyan`,
  `cta_green`, `cta_gold`, `cta_red`, `secondary` (card bg + border),
  `tertiary` (dim, borderless). Big CTAs: white 3px border + gradient + hard
  shadow + display-font uppercase. Pressed: content shifts down by the shadow
  offset, shadow hidden. Disabled: 55% modulate (callers add reason badges).
- `Chip.make(text, opts := {}) -> Control` — pill/chip: keys `icon` (Icons
  name), `icon_color`, `emoji` (leading emoji text), `bg`, `border`,
  `border_w`, `text_color`, `font` ("micro"|"body"|"display"), `font_size`,
  `radius`, `pad_h`, `pad_v`, `shadow`. Default: inset dark chip w/ border.
- `CurrencyPill.gold(amount) / materials(amount) -> Control` — header pills,
  gold first then materials (mock: 💰 1,240 / 🪵 14).
- `StatBarChunky.make(width, height, from, to, bg := Tokens.BG_INSET,
  radius := 8.0) -> StatBarChunky` — `set_ratio(r)`; rounded inset track +
  gradient fill (XP, HP, durability, quest progress).
- `SegmentedBar.make(width, height, segments, from, to) -> SegmentedBar` —
  `set_ratio(r)`; tyrant HP ×4 with gaps.
- `TabRow.make(tabs: Array[String], active := 0) -> TabRow` — signal
  `tab_changed(i)`; active pill cyan, inactive dim.
- `ChunkyToggle.make(on := true) -> ChunkyToggle` — 44×26 pill, signal
  `toggled_changed(on)`.
- `SheetPanel.make(accent: Color, height: float) -> SheetPanel` — bottom
  sheet: BG_PANEL, top radius 26, 3px accent border, drag handle; content goes
  in `.content` (VBox inside margins). Anchored to bottom by caller via
  `UI.place`.
- `ModalPanel.make(accent: Color, width: float) -> ModalPanel` — centered
  card radius 22, 3px accent border; `.content` VBox.
- `BottomNav.make(active: String, with_center_button := false) -> BottomNav`
  — 5 tabs HOME/MAP/PARTY/ITEMS/MORE (icons home/map/party/bag/dots), active
  cyan; optional big center run button; signals `tab_selected(id)`,
  `center_pressed`. 84px tall, full width, panel bg + top border.
- `AvatarFace.make(face_id, diameter, ring_color := Color.WHITE,
  ring_width := 3.0) -> AvatarFace` — circle-cropped
  `assets/ui/faces/face-<id>.png` + ring; `set_hp_ring(ratio, color)` adds a
  conic HP arc; `add_status_dot(color)`.
- `HexGridMap` — the mock map backgrounds, port of the dc.html DCLogic:
  `HexGridMap.preset_a()` (exploration r=34: contested ring, player turf,
  gloom spread), `preset_b()` (combat r=72), `preset_c()` (fog map r=34),
  each returning a configured full-screen Control; or construct and set
  `hex_radius`, `zones` (Array of `{center: Vector2, radius: float,
  fill: Color, stroke: Color, width: float, dashed: bool}` — first zone whose
  center distance < radius classifies the hex), `default_fill`,
  `default_stroke`, `default_width`, plus `paths`
  (`{points: PackedVector2Array, width: float}` sand roads w/ edge color),
  `trees` (positions), `water` (`{center, radius}` blobs). Background grass is
  the caller's `add_bg(Tokens.MAP_GRASS)`.
- `MobBlob.make(diameter := 96, icon := "shroom") -> Control` — the purple
  radial Gloomling: radial-ish gradient, 4px GLOOM_BORDER, hard shadow,
  white icon. Bob via `Screen.bob`.
- `RingPulse.make(radius, color, width := 4.0, dashed := false) -> Control` —
  attention ring; animates scale 1→1.25 fade loop (frozen mid-state when
  `AppMode.freeze_motion`).
- `HotBarSlot.make(cfg: Dictionary) -> HotBarSlot` — 60×60 radius 16 slot.
  cfg keys: `emoji` or `icon`, `label` (name under, micro 8.5), `state`
  ("ready"|"cooldown"|"empty"|"locked"), `cooldown_left` (sec, conic sweep +
  seconds), `charges` (×N badge), `glow` (Color for rare/active glow border),
  `border` (Color override), `badge` (top text badge e.g. "×½ RESISTED",
  with `badge_bg`/`badge_color`).
- `DamageFloat.make(text, color, font_size, rot_deg, shadow: Color)
  -> Label` — rotated display-font float w/ hard text shadow.
- `Parchment.make(radius := 14.0) -> ChunkyRect` — quest-card/speech paper
  (PARCHMENT fill, MAP_PATH_EDGE border, ON_PARCHMENT text by caller).
- `Placeholder3D.make(size: Vector2, label: String) -> Control` — dashed
  border box + centered micro label; marks every KayKit render region
  ("3D KEY ART RENDER", "3D MOB RENDER", …).

## Verification loop

- `tools/dev/check.sh` — headless smoke (all routes must instantiate clean).
- `tools/dev/shoot.sh <dir> [ids]` — windowed screenshots; READ the PNGs and
  compare against the mock chunk before calling a screen done.
- Component galleries: `_gallery_core.gd` / `_gallery_map.gd` in
  `src/ui/screens/` render the kit for review (off-registry routes).
