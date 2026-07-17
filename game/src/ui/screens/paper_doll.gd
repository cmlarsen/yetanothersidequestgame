extends Screen
## Paper doll + inventory (chunk 09): header + 5 stat cells with gear deltas,
## 3D character placeholder flanked by 6 gear slots, HAMMER SET bar, filter
## tabs, 5-col inventory grid with rarity borders / E badge / new dots, legend.

# One-off chunk-09 colors (inline CSS only).
const _ATK := Color("#ff8a65")
const _ART_RARE_TEXT := Color("#5d9df0")
const _ART_EPIC := Color("#a678ec")
const _ART_DIM := Color("#4a5570")
const _CAPE_BG := Color(28.0 / 255.0, 36.0 / 255.0, 56.0 / 255.0, 0.5)
const _BOX_GLOW := Color("#22405c")

const _CELL := 69.0
const _CELL_GAP := 7.25
const _GRID_Y := 681.0
const _GRID_SLOTS := 10

var _cell_rects: Array[ChunkyRect] = []
var _base_glow: Dictionary = {}  # ChunkyRect → [color, size] before selection
var _grid: Control
var _selected_rect: ChunkyRect = null


class RenderBox:
	extends Control
	## Radial glow (circle at 50%/25%) + ground-shadow ellipse for the
	## character render region; the rounded fill/border are ChunkyRects.

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, size.y * 0.25)
		for i in 14:
			var t := float(i) / 13.0
			var r := lerpf(150.0, 10.0, t)
			draw_circle(center, r, Color(Color("#22405c"), 0.10))
		var shadow_c := Vector2(size.x * 0.5, size.y - 17.0)
		var pts := PackedVector2Array()
		for i in 28:
			var a := TAU * float(i) / 28.0
			pts.append(shadow_c + Vector2(cos(a) * 45.0, sin(a) * 7.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.4))


func build() -> void:
	add_bg(Tokens.BG_SCREEN)
	_build_header()
	_build_stat_cells()
	_build_doll()
	_build_set_bar()
	_build_tabs()
	_grid = Control.new()
	UI.place(self, _grid, Vector2(14, _GRID_Y), Vector2(374, 145))
	_rebuild_grid(0)
	_build_legend()


func _build_header() -> void:
	UI.place(self, UI.display(GameState.player_name, 20, Color.WHITE), Vector2(16, 66))
	UI.place(self, UI.micro("%s · LV %d" % [GameState.player_epithet, GameState.level],
		10, Tokens.CYAN), Vector2(16, 93))


func _build_stat_cells() -> void:
	# Order/colors per the chunk: HP white, ATK salmon, DEF green, SPD cyan, CRIT gold.
	var cells: Array[Array] = [
		["hp", "HP", Color.WHITE], ["atk", "ATK", _ATK],
		["def", "DEF", Tokens.GREEN_GRAD_TOP], ["spd", "SPD", Tokens.CYAN_LIGHT],
		["crit", "CRIT", Tokens.GOLD_GRAD_TOP],
	]
	var cell_w := (374.0 - 4.0 * 5.0) / 5.0
	for i in cells.size():
		var key := String(cells[i][0])
		var stat: Dictionary = GameState.stats[key]
		var pct := "%" if key == "crit" else ""
		var cell := Control.new()
		UI.place(self, cell, Vector2(14.0 + i * (cell_w + 5.0), 118), Vector2(cell_w, 48))
		UI.fill(cell, ChunkyRect.panel(Tokens.BG_CARD, 10.0, Tokens.BORDER, 2.0))
		var col := UI.vbox(0, BoxContainer.ALIGNMENT_CENTER)
		UI.fill(cell, col)
		col.add_child(UI.centered(UI.display(
			"%d%s" % [int(stat["total"]), pct], 14, cells[i][2])))
		col.add_child(UI.centered(UI.micro(String(cells[i][1]), 8, Tokens.white(0.45))))
		col.add_child(UI.centered(UI.micro(
			"+%d%s" % [int(stat["gear"]), pct], 8, Tokens.GREEN_GRAD_TOP)))


func _build_doll() -> void:
	_build_render_box()
	var helm: Dictionary = Catalog.item(GameState.equipment["helm"])
	var main_hand: Dictionary = Catalog.item(GameState.equipment["main_hand"])
	var off_hand: Dictionary = Catalog.item(GameState.equipment["off_hand"])
	var chest: Dictionary = Catalog.item(GameState.equipment["chest"])
	var boots: Dictionary = Catalog.item(GameState.equipment["boots"])
	# Slot chrome mirrors the chunk exactly (helm reads cyan there even though
	# the item is rare-blue; mock pixels win).
	_gear_block(72, 246, {"border": Tokens.CYAN, "glow": true, "art": Tokens.CYAN,
		"art_text": Tokens.CYAN, "label": "HELM", "label_color": Tokens.white(0.55),
		"sub": String(helm["effect_line"])})
	_gear_block(72, 344, {"border": Tokens.RARITY_RARE, "glow": true,
		"art": Tokens.RARITY_RARE, "art_text": _ART_RARE_TEXT, "label": "MAIN HAND",
		"label_color": _ART_RARE_TEXT,
		"sub": "%s +%d ATK" % [String(main_hand["name"]), int(main_hand["stats"]["atk"])]})
	_gear_block(72, 442, {"border": Tokens.SLOT_BORDER, "art": _ART_DIM,
		"art_text": _ART_DIM, "label": "OFF HAND", "label_color": Tokens.white(0.55),
		"sub": "%s +%d ATK" % [String(off_hand["name"]), int(off_hand["stats"]["atk"])]})
	_gear_block(342, 253, {"border": Tokens.RARITY_EPIC_TOP, "glow": true,
		"art": _ART_EPIC, "art_text": _ART_EPIC, "label": "CHEST · EPIC",
		"label_color": Tokens.GLOOM_LIGHT, "sub": String(chest["effect_line"])})
	_gear_block(342, 351, {"border": Tokens.SLOT_BORDER, "art": _ART_DIM,
		"art_text": _ART_DIM, "label": "BOOTS", "label_color": Tokens.white(0.55),
		"sub": String(boots["effect_line"])})
	_gear_block(342, 449, {"locked": true,
		"label": "CAPE · LV %d" % Rules.CAPE_UNLOCK_LEVEL,
		"label_color": Tokens.SLOT_BORDER})


func _build_render_box() -> void:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.clip_contents = true  # keep the radial glow inside the render region
	UI.place(self, box, Vector2(128, 254), Vector2(170, 260))
	UI.fill(box, ChunkyRect.panel(Tokens.BG_PANEL, 18.0))
	UI.fill(box, RenderBox.new())
	var border := ChunkyRect.panel(Color(0, 0, 0, 0), 18.0, Tokens.SLOT_BORDER, 2.5)
	border.dashed = true
	UI.fill(box, border)
	# Placeholder copy for the KayKit render region (not in Catalog).
	var text := UI.centered(UI.body("3D CHARACTER\nRENDER\n(KayKit knight)",
		9, _ART_RARE_TEXT, 800))
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_constant_override("line_spacing", 4)
	UI.fill(box, text)


func _gear_block(center_x: float, y: float, cfg: Dictionary) -> void:
	var slot := BaseButton.new()
	slot.custom_minimum_size = Vector2(56, 56)
	UI.place(self, slot, Vector2(center_x - 28, y), Vector2(56, 56))
	var rect: ChunkyRect
	if cfg.get("locked", false):
		rect = ChunkyRect.panel(_CAPE_BG, 14.0, Tokens.SLOT_BORDER, 2.5)
		rect.dashed = true
		UI.fill(slot, rect)
		var lock := Icons.rect("lock", 20, Tokens.SLOT_BORDER, 2.2)
		UI.place(slot, lock, Vector2(18, 18))
	else:
		rect = ChunkyRect.panel(Tokens.BG_CARD, 14.0, cfg["border"], 2.5)
		if cfg.get("glow", false):
			rect.glow_color = Color(cfg["border"], 0.3)
			rect.glow_size = 7.0
		UI.fill(slot, rect)
		UI.place(slot, _art_box(34.0, cfg["art"], cfg["art_text"], 8.0, 7), Vector2(11, 11))
	_cell_rects.append(rect)
	slot.pressed.connect(_on_cell_pressed.bind(rect))
	var label := UI.centered(UI.micro(String(cfg["label"]), 8, cfg["label_color"]))
	_center_at(label, center_x, y + 59.0)
	if cfg.has("sub"):
		# body, not micro: the chunk keeps item names mixed-case here.
		var sub := UI.centered(UI.body(String(cfg["sub"]), 8, Tokens.white(0.45), 800))
		_center_at(sub, center_x, y + 72.0)


func _center_at(label: Label, center_x: float, y: float) -> void:
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, wrapper, Vector2(center_x - 70, y), Vector2(140, 12))
	UI.fill(wrapper, label)


func _build_set_bar() -> void:
	var set_info: Dictionary = Catalog.SETS["hammer"]
	var equipped := GameState.set_pieces_equipped("hammer")
	var bar := Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, bar, Vector2(14, 606), Vector2(374, 31))
	UI.fill(bar, ChunkyRect.panel(Tokens.BG_CARD, 12.0, Tokens.BORDER, 2.0))
	var row := UI.hbox(7, BoxContainer.ALIGNMENT_CENTER)
	UI.fill(bar, row)
	row.add_child(Icons.rect("sword_slash", 14, Tokens.GOLD_GRAD_TOP))
	var text := UI.hbox(0)
	row.add_child(text)
	var gold := UI.body("%s %d/%d" % [String(set_info["name"]), equipped,
		int(set_info["pieces_total"])], 10, Tokens.GOLD_GRAD_TOP, 800)
	gold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_child(gold)
	var rest := UI.body(" — " + String(set_info["bonus_line"]), 10, Tokens.white(0.7), 700)
	rest.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_child(rest)


func _build_tabs() -> void:
	var tabs: Array[String] = ["ALL", "WEAPONS", "ARMOR", "POTIONS"]
	var tab_row := TabRow.make(tabs, 0)
	UI.place(self, tab_row, Vector2(14, 637))
	tab_row.tab_changed.connect(_rebuild_grid)


# Filter → slot_type subsets (spells appear under ALL only; the chunk has no
# SPELLS tab).
const _FILTER_SLOTS: Dictionary = {
	1: ["weapon"],
	2: ["helm", "chest", "boots", "off_hand", "cape"],
	3: ["consumable"],
}


func _rebuild_grid(tab: int) -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cell_rects = _cell_rects.slice(0, 6)  # keep the 6 gear-slot rects
	_selected_rect = null
	var entries: Array[Dictionary] = []
	for entry in GameState.inventory:
		var item: Dictionary = Catalog.item(entry["item"])
		if tab == 0 or String(item["slot_type"]) in _FILTER_SLOTS[tab]:
			entries.append(entry)
	for i in _GRID_SLOTS:
		var pos := Vector2(
			fmod(float(i), 5.0) * (_CELL + _CELL_GAP),
			floorf(float(i) / 5.0) * (_CELL + 7.0))
		if i < entries.size():
			_item_cell(entries[i], pos)
		elif tab == 0 and i == _GRID_SLOTS - 1:
			_empty_cell(pos, "+%d" % GameState.inventory_overflow)
		else:
			_empty_cell(pos, "")


func _item_cell(entry: Dictionary, pos: Vector2) -> void:
	var item: Dictionary = Catalog.item(entry["item"])
	var equipped := bool(entry.get("equipped", false))
	var border := Tokens.CYAN if equipped else _rarity_border(String(item["rarity"]))
	var art_border := border
	var art_text := border
	match String(item["rarity"]):
		"epic":
			art_border = _ART_EPIC
			art_text = _ART_EPIC
		"rare":
			art_text = _ART_RARE_TEXT
	if equipped:
		art_border = Tokens.CYAN
		art_text = Tokens.CYAN
	elif String(item["rarity"]) == "common":
		art_border = _ART_DIM
		art_text = _ART_DIM
	var cell := BaseButton.new()
	UI.place(_grid, cell, pos, Vector2(_CELL, _CELL))
	var rect := ChunkyRect.panel(Tokens.BG_CARD, 12.0, border, 2.0)
	UI.fill(cell, rect)
	_cell_rects.append(rect)
	cell.pressed.connect(_on_cell_pressed.bind(rect))
	UI.place(cell, _art_box(41.0, art_border, art_text, 7.0, 6), Vector2(14, 14))
	if equipped:
		UI.place(cell, UI.micro("E", 7, Tokens.CYAN), Vector2(_CELL - 11, _CELL - 14))
	if entry.get("is_new", false):
		var dot := ChunkyRect.panel(Tokens.GOLD_GRAD_TOP, 7.0, Tokens.BG_SCREEN, 2.0)
		UI.place(cell, dot, Vector2(_CELL - 9, -5), Vector2(14, 14))


func _empty_cell(pos: Vector2, overflow: String) -> void:
	var cell := Control.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(_grid, cell, pos, Vector2(_CELL, _CELL))
	var rect := ChunkyRect.panel(Color(Tokens.BG_CARD, 0.5), 12.0, Tokens.BORDER, 2.0)
	rect.dashed = true
	UI.fill(cell, rect)
	if overflow != "":
		var label := UI.centered(UI.micro(overflow, 8, Tokens.SLOT_BORDER, 0))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UI.fill(cell, label)


## Selection feedback only (equip/unequip is out of shell scope): white glow on
## the tapped slot/cell, restoring the previous one's chrome.
func _on_cell_pressed(rect: ChunkyRect) -> void:
	if _selected_rect != null and is_instance_valid(_selected_rect) \
			and _base_glow.has(_selected_rect):
		var base: Array = _base_glow[_selected_rect]
		_selected_rect.glow_color = base[0]
		_selected_rect.glow_size = base[1]
		_selected_rect.queue_redraw()
	if not _base_glow.has(rect):
		_base_glow[rect] = [rect.glow_color, rect.glow_size]
	_selected_rect = rect
	rect.glow_color = Tokens.white(0.5)
	rect.glow_size = 6.0
	rect.queue_redraw()


func _build_legend() -> void:
	# Copy from Catalog.COPY.inventory_legend, with the chunk's colored prefixes.
	var items: Array = Catalog.COPY["inventory_legend"]
	var row := UI.hbox(14, BoxContainer.ALIGNMENT_CENTER)
	var e_entry := UI.hbox(3)
	e_entry.add_child(UI.body("E", 9, Tokens.CYAN, 800))
	e_entry.add_child(UI.body(String(items[0]).trim_prefix("E "), 9, Tokens.white(0.4), 800))
	row.add_child(e_entry)
	var new_entry := UI.hbox(4, BoxContainer.ALIGNMENT_CENTER)
	var dot := ChunkyRect.panel(Tokens.GOLD_GRAD_TOP, 3.5)
	dot.custom_minimum_size = Vector2(7, 7)
	var dot_wrap := UI.vbox(0, BoxContainer.ALIGNMENT_CENTER)
	dot_wrap.add_child(dot)
	new_entry.add_child(dot_wrap)
	new_entry.add_child(UI.body(String(items[1]).trim_prefix("● "), 9, Tokens.white(0.4), 800))
	row.add_child(new_entry)
	row.add_child(UI.body(String(items[2]), 9, Tokens.white(0.4), 800))
	UI.place_centered_x(self, row, 838)


func _art_box(side: float, border: Color, text_color: Color, radius: float,
		font_size: int) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(side, side)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := ChunkyRect.panel(Color(0, 0, 0, 0), radius, border, 2.0)
	rect.dashed = true
	rect.dash_length = 5.0
	rect.gap_length = 4.0
	UI.fill(box, rect)
	var label := UI.centered(UI.micro("ART", font_size, text_color, 0))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(box, label)
	return box


static func _rarity_border(rarity: String) -> Color:
	match rarity:
		"epic":
			return Tokens.RARITY_EPIC_TOP
		"rare":
			return Tokens.RARITY_RARE
		"legendary":
			return Tokens.RARITY_LEGENDARY_TOP
	return Tokens.BORDER
