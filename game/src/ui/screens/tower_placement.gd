extends Screen
## Screen 24 — tower placement (in person). Mock chunk 24: grass map (hexB) +
## sand road, dashed range preview ring + tower ghost, YOU pin, standing-on-hex
## confirmation chip, bottom sheet with 3 tower cards + BUILD CTA.

# One-off mock colors (not in Tokens).
const HEADER_BG := Color("#101622e6")  # rgba(16,22,34,.9) header chips
const STANDING_BG := Color("#101622eb")  # rgba(16,22,34,.92)
const GHOST_TEXT := Color("#0e5a6e")
const TAG_BG := Color("#0e2a33")
const CARD_SELECTED_BG := Color("#232c42")
const MEDAL_SHADOW := Color("#080c1480")  # rgba(8,12,20,.5) hard medallion shadow
const CHILL_GRAD_TOP := Color("#a678ec")  # chill-bell medallion top

const MEDAL_GRADS: Dictionary = {
	"bonk_turret": [Tokens.CYAN_GRAD_TOP, Tokens.CYAN_GRAD_BOTTOM],
	"chill_bell": [CHILL_GRAD_TOP, Tokens.RARITY_EPIC_BOTTOM],
	"bastion_post": [Tokens.GOLD_GRAD_TOP, Tokens.GOLD_GRAD_BOTTOM],
}
const TOWER_ORDER: Array[String] = ["bonk_turret", "chill_bell", "bastion_post"]

const SHEET_H := 280.0
const RANGE_CENTER := Vector2(110, 430)
const PLAYER_CENTER := Vector2(196, 495)

var _selected: String = String(GameState.tower_placement["selected"])
var _card_rects: Dictionary = {}
var _cta: ChunkyButton


func build() -> void:
	add_bg(Tokens.MAP_GRASS)
	_build_map()
	_build_range_and_ghost()
	_build_player_pin()
	_build_header()
	_build_standing_chip()
	_build_sheet()


func _build_map() -> void:
	# Mock draws the sand road under the hex overlay (road path precedes hexB).
	var road := _Road.new()
	road.points = _bezier(Vector2(-20, 560), Vector2(100, 520), Vector2(220, 500),
		Vector2(420, 470), 28)
	UI.place(self, road, Vector2.ZERO, DESIGN_SIZE)
	UI.place(self, HexGridMap.preset_b(), Vector2.ZERO)


func _build_range_and_ghost() -> void:
	var ring := _RangeRing.new()
	UI.place(self, ring, RANGE_CENTER - Vector2(145, 145), Vector2(290, 290))

	var col := UI.vbox(4, BoxContainer.ALIGNMENT_CENTER)
	var ghost := Control.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.custom_minimum_size = Vector2(74, 86)
	ghost.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := ChunkyRect.new()
	box.fill_top = Color(Tokens.CYAN, 0.18)
	box.border_color = Tokens.CYAN
	box.border_width = 3.0
	box.corner_radius = 14.0
	box.dashed = true
	UI.fill(ghost, box)
	var ghost_label := UI.centered(UI.body("3D TOWER\nGHOST\n(preview)", 8, GHOST_TEXT, 800))
	ghost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(ghost, ghost_label)
	col.add_child(ghost)

	var radius_hexes := int(Catalog.tower(_selected)["radius_hexes"])
	var tag := Chip.make("RANGE: %d HEXES" % radius_hexes, {
		"font": "body", "font_size": 9, "text_color": Tokens.CYAN_LIGHT,
		"bg": TAG_BG, "border": Tokens.CYAN, "border_w": 1.5,
		"radius": 7.0, "pad_h": 9.0, "pad_v": 2.0,
	})
	_fit_chip(tag, 9.0, 2.0)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(tag)
	UI.place(self, col, RANGE_CENTER - Vector2(60, 54), Vector2(120, 108))


func _build_player_pin() -> void:
	var col := UI.vbox(3, BoxContainer.ALIGNMENT_CENTER)
	var face_wrap := Control.new()
	face_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_wrap.custom_minimum_size = Vector2(54, 54)
	face_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Mock: 48px face, white 3px border, outer cyan 3px ring (box-shadow).
	var outer_ring := ChunkyRect.panel(Color(0, 0, 0, 0), 27.0, Tokens.CYAN, 3.0)
	UI.fill(face_wrap, outer_ring)
	UI.place(face_wrap, AvatarFace.make(GameState.character_id, 48, Color.WHITE, 3.0),
		Vector2(3, 3))
	col.add_child(face_wrap)
	var tag := Chip.make("YOU", {
		"font": "body", "font_size": 9, "text_color": Tokens.CYAN_LIGHT,
		"bg": TAG_BG, "border": Tokens.CYAN, "border_w": 1.5,
		"radius": 7.0, "pad_h": 8.0, "pad_v": 2.0,
	})
	_fit_chip(tag, 8.0, 2.0)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(tag)
	UI.place(self, col, PLAYER_CENTER - Vector2(40, 37), Vector2(80, 74))


func _build_header() -> void:
	var row := UI.hbox(0)
	UI.place(self, row, Vector2(12, 58), Vector2(378, 0))
	var title := Chip.make("PLACE A TOWER", {
		"font": "display", "font_size": 13, "bg": HEADER_BG,
		"border": Tokens.BORDER, "border_w": 2.0, "radius": 14.0,
		"pad_h": 13.0, "pad_v": 7.0,
	})
	_fit_chip(title, 13.0, 7.0)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	row.add_child(UI.spacer())
	var pill := Chip.make(str(GameState.materials), {
		"emoji": "🪵", "font": "display", "font_size": 12,
		"text_color": Tokens.GREEN_GRAD_TOP, "bg": HEADER_BG,
		"border": Tokens.BORDER, "border_w": 2.0, "radius": 30.0,
		"pad_h": 12.0, "pad_v": 6.0,
	})
	_fit_chip(pill, 12.0, 6.0)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pill)


func _build_standing_chip() -> void:
	if not bool(GameState.tower_placement["standing_ok"]):
		return
	var chip := Chip.make(String(Catalog.COPY["tower_standing_ok"]), {
		"icon": "check", "icon_color": Tokens.GREEN_GRAD_TOP,
		"font": "body", "font_size": 10, "text_color": Color.WHITE,
		"bg": STANDING_BG, "border": Tokens.GREEN_GRAD_TOP, "border_w": 2.0,
		"radius": 12.0, "pad_h": 13.0, "pad_v": 6.0,
	})
	_fit_chip(chip, 13.0, 6.0)
	UI.place_centered_x(self, chip, 130)


func _build_sheet() -> void:
	var sheet := SheetPanel.make(Tokens.BORDER, SHEET_H)
	UI.place(self, sheet, Vector2(0, DESIGN_SIZE.y - SHEET_H))
	# Chunk 24's sheet has no drag handle (unlike the manage sheet).
	var handle := sheet.get_child(1).get_child(0).get_child(0) as Control
	handle.visible = false

	var head := UI.hbox(0)
	head.add_child(UI.display("CHOOSE A TOWER", 15))
	head.add_child(UI.spacer())
	var cap := UI.micro("%d / %d PLACED · %d PER HEX" % [GameState.towers_placed,
		GameState.tower_cap, Rules.TOWERS_PER_HEX], 9, Tokens.white(0.45))
	cap.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(cap)
	sheet.content.add_child(head)

	var cards := UI.hbox(8)
	for id in TOWER_ORDER:
		cards.add_child(_tower_card(id))
	sheet.content.add_child(cards)

	_cta = ChunkyButton.make(_cta_text(), "cta_cyan", Vector2(0, 52), 15)
	_cta.pressed.connect(func() -> void: Router.go("defense_view"))
	sheet.content.add_child(_cta)

	sheet.content.add_child(UI.centered(UI.body(
		String(Catalog.COPY["tower_placement_footnote"]), 9, Tokens.white(0.4), 800)))


func _tower_card(id: String) -> BaseButton:
	var t := Catalog.tower(id)
	var cost := int(t["cost"])
	var affordable := GameState.materials >= cost

	var b := BaseButton.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Filled children don't drive a BaseButton's min size; pin the mock height
	# (44 medallion + 3 text lines + 10px pads + 5px gaps).
	b.custom_minimum_size = Vector2(0, 118)
	var rect := ChunkyRect.new()
	rect.corner_radius = 14.0
	UI.fill(b, rect)
	var pad := UI.margin(6, 10)
	UI.fill(b, pad)
	var col := UI.vbox(5, BoxContainer.ALIGNMENT_CENTER)
	pad.add_child(col)

	var medal := _medallion(id, 44.0, 12.0, 20)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(medal)
	var name_l := UI.body(String(t["name"]), 10, Color.WHITE, 800)
	name_l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(name_l)
	var tag_l := UI.centered(UI.body(String(t["tagline"]), 8, Tokens.white(0.5), 700))
	tag_l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(tag_l)
	var cost_l: Label
	if affordable:
		cost_l = UI.body("🪵 %d" % cost, 9, Tokens.GREEN_GRAD_TOP, 800)
	else:
		cost_l = UI.body("🪵 %d — NOT ENOUGH" % cost, 9, Tokens.PINK, 800)
	cost_l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(cost_l)

	if affordable:
		b.pressed.connect(_select.bind(id))
	else:
		b.modulate.a = 0.6
	_card_rects[id] = rect
	_style_card(id)
	return b


func _medallion(id: String, side: float, radius: float, emoji_px: int) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(side, side)
	var r := ChunkyRect.new()
	var grads: Array = MEDAL_GRADS[id]
	r.with_gradient(grads[0], grads[1])
	r.corner_radius = radius
	r.border_color = Color.WHITE
	r.border_width = 2.5
	r.shadow_color = MEDAL_SHADOW
	r.shadow_offset = Vector2(0, 4)
	UI.fill(c, r)
	var e := UI.centered(UI.body(String(Catalog.tower(id)["emoji"]), emoji_px, Color.WHITE, 800))
	e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(c, e)
	return c


func _style_card(id: String) -> void:
	var rect: ChunkyRect = _card_rects[id]
	var on := id == _selected
	rect.fill_top = CARD_SELECTED_BG if on else Tokens.BG_CARD
	rect.border_color = Tokens.CYAN if on else Tokens.BORDER
	rect.border_width = 2.5 if on else 2.0
	rect.glow_color = Color(Tokens.CYAN, 0.35) if on else Color(0, 0, 0, 0)
	rect.glow_size = 9.0 if on else 0.0
	rect.queue_redraw()


func _select(id: String) -> void:
	if id == _selected:
		return
	_selected = id
	for k: String in _card_rects:
		_style_card(k)
	# ChunkyButton has no text setter; its content is rect → margin → row → label.
	var label := _cta.get_child(1).get_child(0).get_child(0) as Label
	label.text = _cta_text()


func _cta_text() -> String:
	var t := Catalog.tower(_selected)
	return "BUILD %s · 🪵 %d" % [String(t["name"]).to_upper(), int(t["cost"])]


## Chip.make bakes its min size from a pre-tree measure, where the label's
## theme overrides don't resolve yet (falls back to the 16px default font), so
## chips come out too wide. Remeasure the content row once the tree settles.
static func _fit_chip(chip: Control, pad_h: float, pad_v: float) -> void:
	var row := chip.get_child(1).get_child(0) as Control
	(func() -> void:
		chip.custom_minimum_size = row.get_combined_minimum_size() \
			+ Vector2(pad_h, pad_v) * 2.0).call_deferred()


static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2,
		segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments + 1:
		out.append(p0.bezier_interpolate(p1, p2, p3, float(i) / segments))
	return out


class _Road:
	extends Control
	## Sand road stroke under the hex overlay (mock: 40px round-cap path).

	var points := PackedVector2Array()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if points.size() < 2:
			return
		draw_polyline(points, Tokens.MAP_PATH, 40.0, true)
		draw_circle(points[0], 20.0, Tokens.MAP_PATH)
		draw_circle(points[points.size() - 1], 20.0, Tokens.MAP_PATH)


class _RangeRing:
	extends Control
	## Static range preview: radial cyan fade + dashed 3px circle (the mock ring
	## is not a RingPulse — it doesn't animate).

	const R := 145.0
	const FILL_LAYERS := 14
	const DASHES := 45

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		# Stacked translucent discs ≈ radial-gradient(.14 → transparent at edge).
		for i in range(FILL_LAYERS, 0, -1):
			draw_circle(c, R * float(i) / FILL_LAYERS, Color(Tokens.CYAN, 0.14 / FILL_LAYERS))
		var seg := TAU / DASHES
		for i in DASHES:
			draw_arc(c, R - 1.5, seg * i, seg * (float(i) + 0.6), 5,
				Color(Tokens.CYAN, 0.75), 3.0, true)
