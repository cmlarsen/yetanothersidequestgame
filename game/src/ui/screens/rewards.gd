extends Screen
## Chunk 20 — Rewards (chest open). Dark radial bg + slow-spinning gold rays +
## confetti ticks, rotated gold title, 3D chest region with pulse ring, three
## loot cards (center = highest rarity, raised + glowed), +gold/+XP chips,
## COLLECT ALL → exploration.

# One-off mock colors (no token equivalents).
const _BG_INNER := Color("#2a3550")
const _BG_OUTER := Color("#12151f")
const _TITLE_SHADOW := Color("#8a5a08")
const _SHADOW_DARK := Color("#080c14", 0.5)
const _RARE_ART_TEXT := Color("#5d9df0")
const _COMMON_ART := Color("#4a5570")
const _COMMON_BADGE_TEXT := Color("#0e1420")

const _CARD_BOTTOM := 592.0


func build() -> void:
	var bg := _RadialBg.new()
	bg.center = Vector2(201, 350)
	bg.inner = _BG_INNER
	bg.outer = _BG_OUTER
	bg.radius = 393.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, bg, Vector2.ZERO, DESIGN_SIZE)
	_build_rays()
	_build_confetti()
	_build_title()
	_build_chest_region()
	_build_cards()
	_build_gain_chips()
	_build_cta()


func _build_rays() -> void:
	var rays := _Rays.new()
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, rays, Vector2(201 - 280, 340 - 280), Vector2(560, 560))
	rays.pivot_offset = rays.size * 0.5
	if not AppMode.freeze_motion:
		var tw := rays.create_tween().set_loops()
		tw.tween_property(rays, "rotation_degrees", 360.0, 14.0).from(0.0)


func _build_confetti() -> void:
	var ticks: Array[Array] = [
		[Vector2(70, 150), Vector2(9, 15), 24.0, Tokens.CYAN],
		[Vector2(320, 140), Vector2(9, 14), -30.0, Tokens.WARNING],
		[Vector2(295, 520), Vector2(8, 13), 40.0, Tokens.PINK],
		[Vector2(85, 490), Vector2(8, 13), -18.0, Tokens.GREEN_GRAD_TOP],
	]
	for t in ticks:
		var tick := ChunkyRect.panel(t[3], 3.0)
		UI.place(self, tick, t[0], t[1])
		tick.pivot_offset = tick.size * 0.5
		tick.rotation_degrees = t[2]


func _build_title() -> void:
	var title := DamageFloat.make(String(GameState.rewards["title"]), Tokens.GOLD_GRAD_TOP,
		32, -2.0, _TITLE_SHADOW)
	UI.shadowed(title, _TITLE_SHADOW, 3)
	UI.place_centered_x(self, title, 164)
	var sub := UI.body(String(GameState.rewards["source_line"]), 11, Tokens.white(0.55))
	UI.place_centered_x(self, sub, 205)


func _build_chest_region() -> void:
	var ring_holder := Control.new()
	ring_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, ring_holder, Vector2(106 - 14, 254.5 - 14), Vector2(218, 193))
	var ring := ChunkyRect.new()
	ring.fill_top = Color(0, 0, 0, 0)
	ring.border_color = Color(Tokens.GOLD_GRAD_TOP, 0.5)
	ring.border_width = 3.0
	ring.corner_radius = 26.0
	UI.fill(ring_holder, ring)
	ring_holder.pivot_offset = ring_holder.size * 0.5
	if not AppMode.freeze_motion:
		var tw := ring_holder.create_tween().set_loops()
		tw.tween_property(ring_holder, "scale", Vector2(1.1, 1.1), 1.5) \
			.from(Vector2.ONE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ring_holder, "modulate:a", 0.0, 1.5).from(0.9)

	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, box, Vector2(106, 254.5), Vector2(190, 165))
	var rect := ChunkyRect.new()
	rect.fill_top = Color(Tokens.GOLD_GRAD_TOP, 0.08)
	rect.border_color = Tokens.GOLD_GRAD_TOP
	rect.border_width = 3.0
	rect.corner_radius = 20.0
	rect.dashed = true
	UI.fill(box, rect)
	box.pivot_offset = box.size * 0.5
	box.rotation_degrees = -2.0
	# Label sits outside the rotated box: 10px text goes mushy under Godot's
	# rotated rasterization, and the 2° tilt is imperceptible on copy this size.
	var label := UI.centered(UI.body("3D CHEST RENDER\n(lid popped)", 10,
		Tokens.GOLD_GRAD_TOP, 800))
	# Same-color outline fakes the mock's 800 weight, which washes out at 10px.
	label.add_theme_color_override("font_outline_color", Tokens.GOLD_GRAD_TOP)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_constant_override("line_spacing", 5)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var label_holder := Control.new()
	label_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, label_holder, Vector2(106, 254.5), Vector2(190, 165))
	UI.fill(label_holder, label)


func _build_cards() -> void:
	var items: Array = GameState.rewards["items"]
	var cards: Array[Control] = [
		_loot_card(String(items[0]), false),
		_loot_card(String(items[1]), true),
		_loot_card(String(items[2]), false),
	]
	var xs: Array[float] = [21.0, 139.0, 272.0]
	var delays: Array[float] = [0.2, 0.45, 0.7]
	for i in 3:
		var card := cards[i]
		var y := _CARD_BOTTOM - card.custom_minimum_size.y - (10.0 if i == 1 else 0.0)
		UI.place(self, card, Vector2(xs[i], y), card.custom_minimum_size)
		pop_in(card, delays[i])


func _loot_card(item_id: String, center: bool) -> Control:
	var item := Catalog.item(item_id)
	var rarity := String(item.get("rarity", "common"))
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(124, 138) if center else Vector2(109, 112)

	var rect := ChunkyRect.panel(Tokens.BG_CARD, 17.0 if center else 15.0)
	rect.border_color = _rarity_border(rarity)
	rect.border_width = 3.0 if center else 2.5
	rect.shadow_color = _SHADOW_DARK
	rect.shadow_offset = Vector2(0, 6.0 if center else 5.0)
	if center:
		rect.glow_color = Color(Tokens.GOLD_GRAD_TOP, 0.45)
		rect.glow_size = 12.0
	UI.fill(card, rect)

	# Center card gets a hair more horizontal inset so long names wrap like the
	# mock's 98px content box.
	var pad := UI.margin(14 if center else 9, 13 if center else 11)
	UI.fill(card, pad)
	var col := UI.vbox(6)
	pad.add_child(col)

	var art_side := 58.0 if center else 50.0
	var art := Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size = Vector2(art_side, art_side)
	var art_rect := ChunkyRect.new()
	art_rect.fill_top = Color(0, 0, 0, 0)
	art_rect.border_color = _art_color(rarity)
	art_rect.border_width = 2.0
	art_rect.corner_radius = 11.0 if center else 10.0
	art_rect.dashed = true
	UI.fill(art, art_rect)
	var art_label := UI.centered(UI.micro("ART", 7, _art_color(rarity)))
	art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(art, art_label)
	var art_wrap := CenterContainer.new()
	art_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_wrap.add_child(art)
	col.add_child(art_wrap)

	var name_label := UI.centered(UI.wrap(UI.body(String(item["name"]),
		11 if center else 10, Color.WHITE)))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(name_label)

	var badge_wrap := CenterContainer.new()
	badge_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_wrap.add_child(_rarity_badge(rarity))
	col.add_child(badge_wrap)
	return card


func _rarity_border(rarity: String) -> Color:
	match rarity:
		"rare":
			return Tokens.RARITY_RARE
		"legendary":
			return Tokens.GOLD_GRAD_TOP
		"epic":
			return Tokens.RARITY_EPIC_BOTTOM
		_:
			return Tokens.BORDER


func _art_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return _RARE_ART_TEXT
		"legendary":
			return Tokens.GOLD_GRAD_TOP
		"epic":
			return Tokens.RARITY_EPIC_TOP
		_:
			return _COMMON_ART


func _rarity_badge(rarity: String) -> Control:
	var opts := {
		"font": "body", "font_size": 8, "border_w": 0.0,
		"radius": 6.0, "pad_h": 8.0, "pad_v": 2.0,
	}
	match rarity:
		"rare":
			opts["bg"] = Tokens.RARITY_RARE
			opts["text_color"] = Color.WHITE
		"legendary":
			opts["bg"] = Tokens.RARITY_LEGENDARY_TOP
			opts["bg_bottom"] = Tokens.RARITY_LEGENDARY_BOTTOM
			opts["text_color"] = Tokens.ON_GOLD
		"epic":
			opts["bg"] = Tokens.RARITY_EPIC_BOTTOM
			opts["text_color"] = Color.WHITE
		_:
			opts["bg"] = Tokens.RARITY_COMMON
			opts["text_color"] = _COMMON_BADGE_TEXT
	var badge := Chip.make(rarity.to_upper(), opts)
	# Chip pins its min size from a pre-tree measurement that ignores font
	# overrides — re-pin from real font metrics.
	badge.custom_minimum_size = Vector2(
		_text_w(Tokens.body_font(800), rarity.to_upper(), 8) + 16.0, 16.0)
	return badge


func _build_gain_chips() -> void:
	var row := UI.hbox(10)
	var gold_chip := _pill()
	var gold_row: HBoxContainer = gold_chip.get_meta("row")
	var coin := ChunkyRect.new()
	coin.with_gradient(Tokens.GOLD_GRAD_TOP, Tokens.GOLD_GRAD_BOTTOM)
	coin.corner_radius = 7.5
	coin.border_color = Tokens.GOLD_BORDER
	coin.border_width = 2.0
	coin.custom_minimum_size = Vector2(15, 15)
	var gold_text := "+%d" % int(GameState.rewards["gold"])
	gold_row.add_child(coin)
	gold_row.add_child(UI.display(gold_text, 14, Tokens.GOLD_GRAD_TOP))
	gold_chip.custom_minimum_size = Vector2(
		15.0 + 6.0 + _text_w(Tokens.display_font(), gold_text, 14) + 28.0, 33.0)
	row.add_child(gold_chip)

	var xp_chip := _pill()
	var xp_row: HBoxContainer = xp_chip.get_meta("row")
	var xp_text := "+%d" % int(GameState.rewards["xp"])
	xp_row.add_child(UI.display("XP", 11, Tokens.GREEN_GRAD_TOP))
	xp_row.add_child(UI.display(xp_text, 14, Tokens.GREEN_GRAD_TOP))
	xp_chip.custom_minimum_size = Vector2(
		_text_w(Tokens.display_font(), "XP", 11) + 6.0
		+ _text_w(Tokens.display_font(), xp_text, 14) + 28.0, 33.0)
	row.add_child(xp_chip)

	UI.place_centered_x(self, row, 616)
	pop_in(row, 0.9)


func _pill() -> Control:
	var chip := Control.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(chip, ChunkyRect.panel(Tokens.BG_CARD, 30.0, Tokens.BORDER, 2.0))
	var pad := UI.margin(14, 7)
	UI.fill(chip, pad)
	var inner := UI.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	pad.add_child(inner)
	chip.set_meta("row", inner)
	return chip


static func _text_w(font: Font, text: String, px: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


func _build_cta() -> void:
	var cta := ChunkyButton.make("COLLECT ALL", "cta_gold", Vector2(290, 52), 18)
	UI.place_centered_x(self, cta, 684, Vector2(290, 52))
	cta.pressed.connect(func() -> void: Router.go("exploration"))


## Opaque radial background (mock: radial-gradient circle) via stacked
## outer→inner circles.
class _RadialBg:
	extends Control

	const _STEPS := 40

	var center := Vector2.ZERO
	var inner := Color.BLACK
	var outer := Color.BLACK
	var radius := 400.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), outer)
		for i in range(_STEPS, 0, -1):
			var t := float(i) / _STEPS
			draw_circle(center, radius * t, inner.lerp(outer, t))


## The 13-wedge gold ray burst (mock: conic-gradient, 14° on / 14° off).
class _Rays:
	extends Control

	const _COLOR := Color("#ffd75e", 0.16)

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		var start := 0.0
		while start < 350.0:
			var wedge := PackedVector2Array()
			wedge.append(c)
			for s in 7:
				var a := deg_to_rad(start + 14.0 * float(s) / 6.0 - 90.0)
				wedge.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(wedge, _COLOR)
			start += 28.0
