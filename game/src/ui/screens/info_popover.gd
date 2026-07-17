extends Screen
## Map info popover (chunk 11): dimmed hexB combat map, the tapped mob
## highlighted with a white pulse ring, anchored card with pointer — mob
## name/title/LV, bio, 3 stat chips, weakness line, ATTACK / AVOID.

const _MOB_ID := "grumbleshroom"
# One-off chunk-11 colors (inline CSS only).
const _DIM := Color(10.0 / 255.0, 14.0 / 255.0, 20.0 / 255.0, 0.35)
const _HEXES_VALUE := Color("#a678ec")
const _HINT_SHADOW := Color(0, 0, 0, 0.6)

const _STAR := '<path d="M12 2.5l2.9 5.9 6.5.9-4.7 4.6 1.1 6.5L12 17.3l-5.8 3.1 1.1-6.5L2.6 9.3l6.5-.9z"/>'
const _THREAT_STARS_MAX := 3  # chunk shows a 3-star threat scale (not in Catalog)

var _mob: Dictionary = Catalog.mob(_MOB_ID)


class MapDecor:
	extends Control
	## Sand road drawn UNDER the hexes (the chunk draws it before {{ hexB }}).
	var road: PackedVector2Array
	var road_width: float = 40.0
	var edge_extra: float = 12.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		_stroke(road, Tokens.MAP_PATH_EDGE, road_width + edge_extra)
		_stroke(road, Tokens.MAP_PATH, road_width)

	func _stroke(pts: PackedVector2Array, color: Color, width: float) -> void:
		draw_polyline(pts, color, width, true)
		for p in pts:
			draw_circle(p, width / 2.0, color)


class Halo:
	extends Control
	## Soft white glow around the tapped mob (chunk: 0 0 26px white .35).
	## Drawn as fading arcs — ChunkyRect's polygon glow degenerates on circles.
	var radius := 37.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		for i in 6:
			var t := float(i) / 5.0
			draw_arc(c, radius + 1.0 + t * 10.0, 0.0, TAU, 64,
				Tokens.white(0.28 * (1.0 - t)), 3.0, true)


class Pointer:
	extends Control
	## The card's anchor triangle (border-left/right transparent trick in CSS).

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([
			Vector2(size.x / 2.0, 0), Vector2(size.x, size.y), Vector2(0, size.y),
		]), Tokens.BG_PANEL)


func build() -> void:
	add_bg(Tokens.MAP_GRASS)
	_build_map()
	_build_backdrop()
	_build_mob()
	_build_card()
	# Dismiss hint (COPY.popover_dismiss_hint), lowercase body per the chunk.
	var hint := UI.shadowed(UI.body(String(Catalog.COPY["popover_dismiss_hint"]),
		10, Tokens.white(0.8), 800), _HINT_SHADOW, 1)
	UI.place_centered_x(self, hint, DESIGN_SIZE.y - 60 - 14)


func _build_map() -> void:
	var decor := MapDecor.new()
	# Chunk road: M -20 560 C 100 520 220 500 420 470.
	decor.road = _bezier(Vector2(-20, 560), Vector2(100, 520), Vector2(220, 500),
		Vector2(420, 470), 24)
	UI.place(self, decor, Vector2.ZERO, DESIGN_SIZE)
	UI.place(self, HexGridMap.preset_b(), Vector2.ZERO, DESIGN_SIZE)
	var dim := ColorRect.new()
	dim.color = _DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(self, dim)


func _build_backdrop() -> void:
	var backdrop := BaseButton.new()
	UI.fill(self, backdrop)
	backdrop.pressed.connect(func() -> void: Router.back())


func _build_mob() -> void:
	var center := Vector2(201, 300)
	var ring := RingPulse.make(46.0, Color.WHITE, 3.0)
	UI.place(self, ring, center - ring.size / 2.0)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, holder, center - Vector2(37, 37), Vector2(74, 74))
	holder.add_child(MobBlob.make(74.0))
	# Tapped state: white border + white glow over the blob's purple ring.
	var white_ring := ChunkyRect.panel(Color(0, 0, 0, 0), 37.0, Color.WHITE, 3.5)
	UI.fill(holder, white_ring)
	var halo := Halo.new()
	UI.fill(holder, halo)
	bob(holder)


func _build_card() -> void:
	UI.place(self, Pointer.new(), Vector2(201 - 12, 368), Vector2(24, 13))
	var card := ModalPanel.make(Tokens.GLOOM_BORDER_ALT, 354.0)
	UI.place(self, card, Vector2(24, 380))

	var header := UI.hbox(0)
	card.content.add_child(header)
	header.add_child(UI.display(String(_mob["name"]), 18, Tokens.GLOOM_LIGHT))
	header.add_child(UI.spacer())
	var kind := UI.micro("%s · LV %d" % [String(_mob["title"]), int(_mob["level"])],
		10, Tokens.white(0.5))
	kind.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	header.add_child(kind)

	card.content.add_child(UI.wrap(UI.body(String(_mob["bio"]), 11, Tokens.white(0.6), 700)))

	var chips := UI.hbox(7)
	card.content.add_child(chips)
	chips.add_child(_stat_chip(str(int(_mob["hexes_held"])), _HEXES_VALUE, "HEXES HELD"))
	chips.add_child(_threat_chip(int(_mob["threat_stars"])))
	chips.add_child(_stat_chip(String(_mob["loot_rarity_hint"]), Tokens.GOLD_GRAD_TOP,
		"LOOT DROP"))

	card.content.add_child(_weakness_row())

	var buttons := UI.hbox(8)
	card.content.add_child(buttons)
	var attack := ChunkyButton.make("ATTACK", "cta_red", Vector2(0, 44), 14)
	attack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attack.pressed.connect(func() -> void: Router.go("combat"))
	buttons.add_child(attack)
	var avoid := ChunkyButton.make("AVOID", "secondary", Vector2(0, 44), 13)
	avoid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	avoid.pressed.connect(func() -> void: Router.back())
	buttons.add_child(avoid)


func _stat_chip(value: String, value_color: Color, label: String) -> Control:
	var chip := Control.new()
	chip.custom_minimum_size = Vector2(0, 47)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(chip, ChunkyRect.panel(Tokens.BG_CARD, 11.0, Tokens.BORDER, 2.0))
	var col := UI.vbox(1, BoxContainer.ALIGNMENT_CENTER)
	UI.fill(chip, col)
	col.add_child(UI.centered(UI.display(value, 14, value_color)))
	col.add_child(UI.centered(UI.micro(label, 8, Tokens.white(0.45))))
	return chip


func _threat_chip(stars: int) -> Control:
	var chip := Control.new()
	chip.custom_minimum_size = Vector2(0, 47)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(chip, ChunkyRect.panel(Tokens.BG_CARD, 11.0, Tokens.BORDER, 2.0))
	var col := UI.vbox(2, BoxContainer.ALIGNMENT_CENTER)
	UI.fill(chip, col)
	var star_row := UI.hbox(1, BoxContainer.ALIGNMENT_CENTER)
	for i in _THREAT_STARS_MAX:
		star_row.add_child(_star_rect(13, Tokens.PINK, i < stars))
	col.add_child(star_row)
	col.add_child(UI.centered(UI.micro("THREAT", 8, Tokens.white(0.45))))
	return chip


func _weakness_row() -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0, 33)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(row, ChunkyRect.panel(Tokens.BG_CARD, 11.0, Tokens.BORDER, 2.0))
	var content := UI.hbox(7, BoxContainer.ALIGNMENT_CENTER)
	UI.fill(row, content)
	content.add_child(UI.spacer(11.0))
	content.add_child(Icons.rect("sword_slash", 15, Tokens.GOLD_GRAD_TOP))
	# Tag copy from weak/resist tags (GAME-RULES BONK, not the chunk's "ATK").
	var text := UI.hbox(0)
	content.add_child(text)
	text.add_child(_vcenter(UI.body("Weak to ", 10, Tokens.white(0.7), 700)))
	text.add_child(_vcenter(UI.body(String(_mob["weak_tags"][0]), 10,
		Tokens.GOLD_GRAD_TOP, 800)))
	var resists: Array = _mob["resist_tags"]
	if not resists.is_empty():
		text.add_child(_vcenter(UI.body(" · resists ", 10, Tokens.white(0.7), 700)))
		text.add_child(_vcenter(UI.body(String(resists[0]), 10,
			Tokens.CYAN_LIGHT, 800)))
	content.add_child(UI.spacer())
	return row


static func _vcenter(l: Label) -> Label:
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func _star_rect(px: int, color: Color, filled: bool) -> TextureRect:
	# ★ / ☆ as SVGs — the chunk's star glyphs have no coverage in the bundled fonts.
	var inner: String
	if filled:
		inner = '<g fill="#%s">%s</g>' % [color.to_html(false), _STAR]
	else:
		inner = '<g fill="none" stroke="#%s" stroke-width="2" stroke-linejoin="round">%s</g>' % [
			color.to_html(false), _STAR]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">%s</svg>' % inner
	var img := Image.new()
	var err := img.load_svg_from_string(svg, float(px) / 24.0)
	assert(err == OK, "svg rasterize failed")
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2,
		segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments + 1:
		out.append(p0.bezier_interpolate(p1, p2, p3, float(i) / segments))
	return out
