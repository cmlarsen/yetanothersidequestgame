extends Screen
## Chunk 19 — Loot box found (proximity). hexB map, glowing Grumble Chest with
## gold halo + pulse ring, white path dots toward the player, CHEST NEARBY
## banner, and the out-of-range gate (label + distance bar + disabled CTA).

# One-off mock colors (no token equivalents).
const _CHEST_LABEL := Color("#6b4508")
const _YOU_CHIP_BG := Color("#0e2a33")
const _BANNER_BG := Color("#101622", 0.92)
const _SHADOW_DARK := Color("#080c14", 0.5)
const _CTA_DISABLED_BG := Color(120.0 / 255.0, 130.0 / 255.0, 150.0 / 255.0, 0.75)
# Mock-pinned 45% fill — 18 m out vs the 10 m gate has no defined mapping.
const _GATE_RATIO := 0.45

const _CHEST_CENTER := Vector2(201, 360)


func build() -> void:
	add_bg(Tokens.MAP_GRASS)
	var deco := _RoadLayer.new()
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, deco, Vector2.ZERO, DESIGN_SIZE)
	UI.place(self, HexGridMap.preset_b(), Vector2.ZERO, DESIGN_SIZE)
	_build_halo()
	_build_chest()
	_build_path_dots()
	_build_player()
	_build_banner()
	_build_gate()


func _build_halo() -> void:
	var halo := _RadialGlow.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, halo, _CHEST_CENTER - Vector2(80, 80), Vector2(160, 160))


func _build_chest() -> void:
	# Column (74×64 box + tag) centered on the chest hex; whole group bobs.
	var group := Control.new()
	UI.place(self, group, _CHEST_CENTER - Vector2(37, 44.5), Vector2(74, 89))

	var ring_holder := Control.new()
	ring_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(group, ring_holder, Vector2(-11, -11), Vector2(96, 86))
	var ring := ChunkyRect.new()
	ring.fill_top = Color(0, 0, 0, 0)
	ring.border_color = Color(Tokens.GOLD_GRAD_TOP, 0.7)
	ring.border_width = 3.0
	ring.corner_radius = 18.0
	UI.fill(ring_holder, ring)
	ring_holder.pivot_offset = ring_holder.size * 0.5
	if not AppMode.freeze_motion:
		var tw := ring_holder.create_tween().set_loops()
		tw.tween_property(ring_holder, "scale", Vector2(1.18, 1.18), 1.6) \
			.from(Vector2.ONE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ring_holder, "modulate:a", 0.0, 1.6).from(0.9)

	var box := Control.new()
	UI.place(group, box, Vector2.ZERO, Vector2(74, 64))
	var rect := ChunkyRect.new()
	rect.with_gradient(Tokens.GOLD_GRAD_TOP, Tokens.GOLD_GRAD_BOTTOM)
	rect.border_color = Tokens.GOLD_BORDER
	rect.border_width = 3.0
	rect.corner_radius = 14.0
	rect.dashed = true
	UI.fill(box, rect)
	var render_label := UI.centered(UI.body("3D CHEST\nRENDER", 8, _CHEST_LABEL, 800))
	render_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(box, render_label)

	var tag := Chip.make(String(GameState.chest["name"]), {
		"font": "display", "font_size": 9, "text_color": Tokens.ON_GOLD,
		"bg": Tokens.WARNING, "border_w": 0.0, "radius": 8.0,
		"pad_h": 9.0, "pad_v": 2.0, "shadow": Tokens.GOLD_SHADOW,
	})
	# Chip pins its min size from a pre-tree measurement that ignores font
	# overrides — re-pin from real font metrics.
	tag.custom_minimum_size = Vector2(
		_text_w(Tokens.display_font(), String(GameState.chest["name"]), 9) + 18.0, 17.0)
	tag.rotation_degrees = -2.0
	tag.resized.connect(func() -> void: tag.pivot_offset = tag.size * 0.5)
	UI.place_centered_x(group, tag, 69)

	# Dev navigation: the flow map opens Rewards on chest open; range gating
	# isn't simulated in the shell, so tapping the chest jumps straight there.
	var hit := BaseButton.new()
	UI.place(group, hit, Vector2(-11, -11), Vector2(96, 86))
	hit.pressed.connect(func() -> void: Router.go("rewards"))

	bob(group, 6.0, 2.4)


func _build_path_dots() -> void:
	var dots: Array[Array] = [
		[Vector2(158, 560), 6.0, 0.85],
		[Vector2(172, 512), 7.0, 0.65],
		[Vector2(186, 462), 8.0, 0.45],
	]
	for d in dots:
		var side: float = d[1]
		var dot := ChunkyRect.panel(Tokens.white(d[2]), side * 0.5)
		UI.place(self, dot, d[0], Vector2(side, side))


func _build_player() -> void:
	var group := Control.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, group, Vector2(141 - 33, 620 - 42), Vector2(66, 84))
	var ring := _CircleRing.new()
	ring.ring_color = Tokens.CYAN
	ring.ring_width = 3.0
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(group, ring, Vector2.ZERO, Vector2(66, 66))
	UI.place(group, AvatarFace.make(GameState.character_id, 56, Color.WHITE, 3.5),
		Vector2(5, 5))
	# "YOU" marker copy is fixed map chrome, not in Catalog.
	var you := Chip.make("YOU", {
		"font": "body", "font_size": 10, "text_color": Tokens.CYAN_LIGHT,
		"bg": _YOU_CHIP_BG, "border": Tokens.CYAN, "border_w": 1.5,
		"radius": 8.0, "pad_h": 9.0, "pad_v": 2.0,
	})
	you.custom_minimum_size = Vector2(_text_w(Tokens.body_font(800), "YOU", 10) + 18.0, 19.0)
	UI.place_centered_x(group, you, 69)


func _build_banner() -> void:
	var banner := Control.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := ChunkyRect.panel(_BANNER_BG, 14.0, Tokens.GOLD_GRAD_TOP, 2.0, _SHADOW_DARK)
	rect.shadow_offset = Vector2(0, 4)
	UI.fill(banner, rect)
	var pad := UI.margin(15, 8)
	UI.fill(banner, pad)
	var row := UI.hbox(8, BoxContainer.ALIGNMENT_CENTER)
	pad.add_child(row)
	# "CHEST NEARBY" banner copy is fixed map chrome, not in Catalog.
	var away := "%d m away" % int(GameState.chest["distance_m"])
	row.add_child(UI.display("CHEST NEARBY", 12, Tokens.GOLD_GRAD_TOP))
	row.add_child(UI.body(away, 10, Color.WHITE))
	banner.custom_minimum_size = Vector2(
		_text_w(Tokens.display_font(), "CHEST NEARBY", 12)
		+ _text_w(Tokens.body_font(700), away, 10) + 8.0 + 30.0, 34.0)
	UI.place_centered_x(self, banner, 130)


func _build_gate() -> void:
	var row := UI.hbox(0)
	UI.place(self, row, Vector2(16, 732), Vector2(370, 14))
	var gate := UI.body(String(Catalog.COPY["chest_gate_label"]), 10, Tokens.white(0.85), 800)
	UI.shadowed(gate, Color(0, 0, 0, 0.5), 1)
	row.add_child(gate)
	row.add_child(UI.spacer())
	var dist := UI.body("%d m" % int(GameState.chest["distance_m"]), 10, Tokens.GOLD_GRAD_TOP, 800)
	UI.shadowed(dist, Color(0, 0, 0, 0.5), 1)
	row.add_child(dist)

	var track := ChunkyRect.panel(Color(Tokens.BG_INSET, 0.8), 7.0, Tokens.white(0.25), 1.5)
	UI.place(self, track, Vector2(16, 753), Vector2(370, 12))
	var fill := _HGradBar.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, fill, Vector2(17.5, 754.5), Vector2(367.0 * _GATE_RATIO, 9))

	# Out-of-range CTA: bespoke disabled gray per the mock (enables + goes gold
	# in range — not simulated in the shell, so it stays inert).
	var cta := Control.new()
	cta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, cta, Vector2(16, 773), Vector2(370, 49))
	UI.fill(cta, ChunkyRect.panel(_CTA_DISABLED_BG, 18.0, Tokens.white(0.5), 3.0))
	var label := UI.centered(UI.display(String(Catalog.COPY["chest_out_of_range"]), 16,
		Tokens.white(0.75)))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(cta, label)


static func _text_w(font: Font, text: String, px: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


## Sand road + plain tree circles that sit UNDER the hex grid (the mock draws
## hexB after the road, so hex lines and turf tints overlay it).
class _RoadLayer:
	extends Control

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 29:
			pts.append(Vector2(-20, 560).bezier_interpolate(
				Vector2(100, 520), Vector2(220, 500), Vector2(420, 470), float(i) / 28.0))
		_stroke_round(pts, Tokens.MAP_PATH_EDGE, 52.0)
		_stroke_round(pts, Tokens.MAP_PATH, 40.0)
		draw_circle(Vector2(330, 640), 14.0, Tokens.MAP_TREE)
		draw_circle(Vector2(358, 616), 11.0, Tokens.MAP_TREE)

	func _stroke_round(pts: PackedVector2Array, color: Color, width: float) -> void:
		draw_polyline(pts, color, width, true)
		for pt in pts:
			draw_circle(pt, width / 2.0, color)


## Gold radial halo (mock: radial-gradient .35 → transparent 65%) faked with
## stacked low-alpha circles.
class _RadialGlow:
	extends Control

	const _LAYERS := 14

	func _draw() -> void:
		var c := size * 0.5
		for i in _LAYERS:
			var t := float(i) / float(_LAYERS - 1)
			draw_circle(c, lerpf(78.0, 18.0, t), Color(Tokens.GOLD_GRAD_TOP, 0.055))


## Plain circle outline (the player's outer cyan ring; box-shadow spread in
## the mock).
class _CircleRing:
	extends Control

	var ring_color: Color = Color.WHITE
	var ring_width: float = 3.0

	func _draw() -> void:
		draw_arc(size * 0.5, size.x * 0.5 - ring_width * 0.5, 0.0, TAU, 64,
			ring_color, ring_width, true)


## Horizontal gold gradient fill for the distance bar (ChunkyRect gradients
## are vertical only).
class _HGradBar:
	extends Control

	func _draw() -> void:
		if size.x <= 0.0:
			return
		var pts := ChunkyRect.rounded_points(Rect2(Vector2.ZERO, size),
			Vector4(6, 6, 6, 6))
		var colors := PackedColorArray()
		for p in pts:
			colors.append(Tokens.RARITY_LEGENDARY_TOP.lerp(
				Tokens.RARITY_LEGENDARY_BOTTOM, clampf(p.x / size.x, 0.0, 1.0)))
		draw_polygon(pts, colors)
