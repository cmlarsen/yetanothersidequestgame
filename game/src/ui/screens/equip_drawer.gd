extends Screen
## Chunk 17 "Equip drawer": dimmed combat map, small mob, the hot bar with the
## edited slot highlighted (SLOT 2 tag + pulse), and a bottom sheet with tabs,
## 3×2 item grid and EQUIP CTA. Data: GameState.equip_drawer / hotbar × Catalog.

# One-off mock colors (not in the token sheet).
const _DIM := Color(10.0 / 255.0, 14.0 / 255.0, 20.0 / 255.0, 0.45)
const _ART_RARE_TEXT := Color("#5d9df0")
const _ART_COMMON := Color("#4a5570")
const _COMMON_BADGE_TEXT := Color("#0e1420")
const _LOCKED_BADGE_TEXT := Color("#8a97b3")

const _SHEET_H := 435.0
const _SHEET_TOP := Screen.DESIGN_SIZE.y - _SHEET_H
const _SLOT_SCALE := 52.0 / HotBarSlot.SLOT_SIDE
# Slot bar: 52px slots, 58px selected, 9px gaps, bottoms aligned at 322.
const _BAR_BOTTOM := 322.0
const _CELL_W := 116.0


func build() -> void:
	add_bg(Tokens.MAP_GRASS)
	_add_map()
	var dim := ColorRect.new()
	dim.color = _DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, dim, Vector2.ZERO, DESIGN_SIZE)
	var dismiss := BaseButton.new()
	UI.place(self, dismiss, Vector2.ZERO, Vector2(DESIGN_SIZE.x, _SHEET_TOP))
	dismiss.pressed.connect(func() -> void: Router.back())
	var blob := MobBlob.make(64)
	UI.place(self, blob, Vector2(169, 158))
	bob(blob)
	_add_slot_bar()
	_add_sheet()


func _add_map() -> void:
	# Road sits under the hex lines in the mock SVG → local decor layer.
	var decor := _RoadDecor.new()
	decor.road = _bezier(Vector2(-20, 300), Vector2(100, 260), Vector2(220, 240),
		Vector2(420, 210), 26)
	UI.place(self, decor, Vector2.ZERO, DESIGN_SIZE)
	UI.place(self, HexGridMap.preset_b(), Vector2.ZERO, DESIGN_SIZE)


func _add_slot_bar() -> void:
	# The mock shows only the four filled slots (the empty 5th is omitted).
	var slot_no := int(GameState.equip_drawer.slot)
	var widths: Array[float] = []
	for i in 4:
		widths.append(58.0 if i == slot_no - 1 else 52.0)
	var total := 9.0 * 3.0
	for w in widths:
		total += w
	var x := (DESIGN_SIZE.x - total) / 2.0
	for i in 4:
		var w := widths[i]
		if i == slot_no - 1:
			_add_selected_slot(Vector2(x, _BAR_BOTTOM - w), slot_no)
		elif i == 3:
			_add_round_slot(Vector2(x, _BAR_BOTTOM - w))
		else:
			var id := String(GameState.hotbar[i].item)
			# Same mock art divergence as the combat screen (sword-slash).
			var icon := "sword_slash" if id == "bonk_hammer" else String(Catalog.item(id).icon)
			var slot := HotBarSlot.make({"icon": icon})
			slot.scale = Vector2(_SLOT_SCALE, _SLOT_SCALE)
			UI.place(self, slot, Vector2(x, _BAR_BOTTOM - w))
		x += w + 9.0


func _add_selected_slot(pos: Vector2, slot_no: int) -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, root, pos, Vector2(58, 58))
	var rect := ChunkyRect.panel(Tokens.SLOT_GRAD_TOP, 14.0, Tokens.CYAN, 3.0,
		Tokens.SLOT_SHADOW).with_gradient(Tokens.SLOT_GRAD_TOP, Tokens.SLOT_GRAD_BOTTOM)
	rect.glow_color = Color(Tokens.CYAN, 0.55)
	rect.glow_size = 12.0
	UI.fill(root, rect)
	var q := UI.display("?", 22, Tokens.CYAN)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(root, q)
	var pulse := _RectPulse.new()
	UI.place(root, pulse, Vector2(-9, -9), Vector2(76, 76))
	var tag := _pill("SLOT %d" % slot_no, 9, Tokens.ON_CYAN, Tokens.CYAN,
		Color(0, 0, 0, 0), 6.0, Vector2(8, 2))
	UI.place(self, tag, Vector2(pos.x + 29.0 - tag.custom_minimum_size.x / 2.0,
		pos.y - 26.0))


## The mock renders the consumable slot as a circle (border-radius 50%).
func _add_round_slot(pos: Vector2) -> void:
	var entry: Dictionary = GameState.hotbar[3]
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, root, pos, Vector2(52, 52))
	var rect := ChunkyRect.panel(Tokens.SLOT_GRAD_TOP, 26.0, Tokens.SLOT_BORDER, 2.5,
		Tokens.SLOT_SHADOW).with_gradient(Tokens.SLOT_GRAD_TOP, Tokens.SLOT_GRAD_BOTTOM)
	UI.fill(root, rect)
	UI.place(root, Icons.rect(String(Catalog.item(String(entry.item)).icon), 22,
		Tokens.PINK_LIGHT, 2.3), Vector2(15, 15))
	var badge := Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(root, badge, Vector2(38, -6), Vector2(20, 20))
	UI.fill(badge, ChunkyRect.panel(Tokens.PINK, 10.0, Tokens.BG_PANEL, 2.0))
	var n := UI.body(str(int(entry.charges)), 10, Color.WHITE, 800)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(badge, n)


func _add_sheet() -> void:
	var drawer: Dictionary = GameState.equip_drawer
	var sheet := SheetPanel.make(Tokens.BORDER, _SHEET_H)
	UI.place(self, sheet, Vector2(0, _SHEET_TOP))

	var header := UI.hbox(0)
	sheet.content.add_child(header)
	header.add_child(UI.display("EQUIP · SLOT %d" % int(drawer.slot), 17))
	header.add_child(UI.spacer())
	var hint := UI.micro(String(Catalog.COPY.equip_drawer_hint), 10, Tokens.white(0.4))
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(hint)

	var tabs: Array[String] = ["WEAPONS", "SPELLS", "POTIONS"]
	var active: int = {"weapons": 0, "spells": 1, "potions": 2}[String(drawer.tab)]
	sheet.content.add_child(TabRow.make(tabs, active))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.content.add_child(grid)
	var items: Array = drawer.items
	for i in items.size():
		var id := String(items[i])
		var row_h := 103.0 if i < 3 else 116.0
		grid.add_child(_cell(id, id == String(drawer.selected), row_h))

	var cta := ChunkyButton.make("EQUIP %s" % Catalog.item(String(drawer.selected)).name,
		"cta_cyan", Vector2(366, 50), 16)
	sheet.content.add_child(cta)
	cta.pressed.connect(func() -> void: Router.go("combat"))


func _cell(id: String, selected: bool, row_h: float) -> Control:
	var item: Dictionary = Catalog.item(id)
	var locked := String(item.get("source_hint", "")) != ""
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(_CELL_W, row_h)

	var rect := ChunkyRect.new()
	rect.corner_radius = 14.0
	if locked:
		rect.fill_top = Color(Tokens.BG_CARD, 0.5)
		rect.border_color = Tokens.BORDER
		rect.border_width = 2.0
		rect.dashed = true
	elif selected:
		rect.fill_top = Tokens.BG_CARD
		rect.border_color = Tokens.CYAN
		rect.border_width = 2.5
		rect.glow_color = Color(Tokens.CYAN, 0.35)
		rect.glow_size = 10.0
	else:
		rect.fill_top = Tokens.BG_CARD
		# Mock keeps common cells on the neutral BORDER, rarity colors the rest.
		var rarity := String(item.rarity)
		rect.border_color = Tokens.BORDER if rarity == "common" \
			else (Tokens.RARITY_RARE if rarity == "rare" else Tokens.RARITY_EPIC_TOP)
		rect.border_width = 2.0
	UI.fill(root, rect)

	var pad := UI.margin(6, 10)
	UI.fill(root, pad)
	var col := UI.vbox(5, BoxContainer.ALIGNMENT_CENTER)
	pad.add_child(col)

	var art := Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size = Vector2(44, 44)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(art)
	if locked:
		UI.place(art, Icons.rect("lock", 20, Tokens.SLOT_BORDER, 2.2), Vector2(12, 12))
	else:
		var art_color := _art_color(String(item.rarity))
		var box := ChunkyRect.new()
		box.fill_top = Color(0, 0, 0, 0)
		box.border_color = art_color
		box.border_width = 2.0
		box.corner_radius = 10.0
		box.dashed = true
		UI.fill(art, box)
		var art_label := UI.centered(UI.micro("ART", 7, _art_text_color(String(item.rarity))))
		art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UI.fill(art, art_label)

	var name_text := String(item.source_hint) if locked else String(item.name)
	var name_color := Tokens.SLOT_BORDER if locked else Color.WHITE
	var name := UI.centered(UI.wrap(UI.body(name_text, 10, name_color, 700)))
	col.add_child(name)

	var badge: Control
	if locked:
		badge = _pill("LV %d" % int(item.level_req), 8, _LOCKED_BADGE_TEXT,
			Tokens.BORDER)
	else:
		badge = _rarity_badge(String(item.rarity))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(badge)
	return root


static func _art_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return Tokens.RARITY_RARE
		"epic":
			return Tokens.GLOOM_LIGHT_ALT
	return _ART_COMMON


static func _art_text_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return _ART_RARE_TEXT
		"epic":
			return Tokens.GLOOM_LIGHT_ALT
	return _ART_COMMON


static func _rarity_badge(rarity: String) -> Control:
	match rarity:
		"common":
			return _pill(rarity, 8, _COMMON_BADGE_TEXT, Tokens.RARITY_COMMON)
		"rare":
			return _pill(rarity, 8, Color.WHITE, Tokens.RARITY_RARE)
		"epic":
			return _pill(rarity, 8, Color.WHITE, Tokens.RARITY_EPIC_TOP,
				Tokens.RARITY_EPIC_BOTTOM)
	return _pill(rarity, 8, Tokens.ON_GOLD, Tokens.RARITY_LEGENDARY_TOP)


## Mock badge/tag pill, sized from true font metrics (see combat.gd:_measured —
## Chip.make bakes the pre-tree inflated label width into its size).
static func _pill(text: String, font_size: int, text_color: Color, bg: Color,
		bg_bottom: Color = Color(0, 0, 0, 0), radius: float = 5.0,
		pad: Vector2 = Vector2(7, 1)) -> Control:
	var label := UI.micro(text, font_size, text_color, 0)
	label.notification(Control.NOTIFICATION_THEME_CHANGED)
	var pill_size := label.get_minimum_size() + pad * 2.0
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = pill_size
	root.size = pill_size
	var rect := ChunkyRect.panel(bg, radius)
	if bg_bottom.a > 0.0:
		rect.with_gradient(bg, bg_bottom)
	UI.fill(root, rect)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(root, label)
	return root


static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2,
		segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments + 1:
		out.append(p0.bezier_interpolate(p1, p2, p3, float(i) / segments))
	return out


## Sand road (edge + fill) drawn beneath the hex grid (mock layer order).
class _RoadDecor:
	extends Control

	var road: PackedVector2Array

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if road.size() < 2:
			return
		_stroke_round(road, Tokens.MAP_PATH_EDGE, 52.0)
		_stroke_round(road, Tokens.MAP_PATH, 40.0)

	func _stroke_round(pts: PackedVector2Array, color: Color, width: float) -> void:
		draw_polyline(pts, color, width, true)
		for pt in pts:
			draw_circle(pt, width / 2.0, color)


## Rounded-rect ring pulse around the edited slot (RingPulse is circular).
class _RectPulse:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ring := ChunkyRect.new()
		ring.fill_top = Color(0, 0, 0, 0)
		ring.border_color = Tokens.CYAN
		ring.border_width = 2.5
		ring.corner_radius = 18.0
		UI.fill(self, ring)

	func _ready() -> void:
		pivot_offset = size / 2.0
		if AppMode.freeze_motion:
			scale = Vector2(1.1, 1.1)
			modulate.a = 0.6
			return
		var tw := create_tween().set_loops()
		tw.tween_property(self, "scale", Vector2(1.25, 1.25), 1.4) \
			.from(Vector2.ONE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 1.4).from(0.9)
