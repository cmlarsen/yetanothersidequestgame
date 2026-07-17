extends Screen
## Exploration map (chunk 08): fog hex map (preset C) over grass with a sand
## road and trees, fog "?" markers, NEW AREA toast, steps/compass pills, the
## quest chest chip, and the player avatar with pulse ring + YOU tag.

# One-off chunk-08 colors (inline CSS only; everything else is in Tokens).
const _PILL_BG := Color(16.0 / 255.0, 22.0 / 255.0, 34.0 / 255.0, 0.88)
const _TOAST_BG := Color(16.0 / 255.0, 22.0 / 255.0, 34.0 / 255.0, 0.92)
const _CHIP_BG := Color(16.0 / 255.0, 22.0 / 255.0, 34.0 / 255.0, 0.90)
const _HARD_SHADOW := Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.5)
const _YOU_BG := Color("#0e2a33")
const _Q_SHADOW := Color(90.0 / 255.0, 60.0 / 255.0, 0.0, 0.5)
const _CHEST_ICON := Color("#6b4508")

# Chunk-08 inline SVGs with no Icons-registry equivalent (24×24 viewBox).
const _SVG_STEPS_CHEVRONS := '<path d="M13 5l7 7-7 7M4 5l7 7-7 7"/>'
const _SVG_ARROW_UP := '<path d="M12 19V5M6 11l6-6 6 6"/>'


class MapDecor:
	extends Control
	## Sand road + tree blobs drawn UNDER the fog hexes — the chunk draws its
	## decorations before {{ hexC }}, unlike HexGridMap's paths-on-top order.
	var road: PackedVector2Array
	var road_width: float = 22.0
	var edge_extra: float = 8.0
	var tree_spots: Array[Vector3] = []  # (x, y, radius)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if road.size() >= 2:
			_stroke(road, Tokens.MAP_PATH_EDGE, road_width + edge_extra)
			_stroke(road, Tokens.MAP_PATH, road_width)
		for t in tree_spots:
			draw_circle(Vector2(t.x, t.y), t.z, Tokens.MAP_TREE)

	## Round caps/joints via circles at every sample (Godot polylines are butt-capped).
	func _stroke(pts: PackedVector2Array, color: Color, width: float) -> void:
		draw_polyline(pts, color, width, true)
		for p in pts:
			draw_circle(p, width / 2.0, color)


func build() -> void:
	add_bg(Tokens.MAP_GRASS)
	_build_map()
	_build_tap_region()
	_build_markers()
	_build_player()
	_build_toast()
	_build_top_pills()
	_build_chest_chip()


func _build_map() -> void:
	var decor := MapDecor.new()
	# Chunk road: M 160 874 C 172 700 150 560 190 420 C 220 320 300 260 420 230.
	var pts := _bezier(Vector2(160, 874), Vector2(172, 700), Vector2(150, 560),
		Vector2(190, 420), 24)
	pts.append_array(_bezier(Vector2(190, 420), Vector2(220, 320), Vector2(300, 260),
		Vector2(420, 230), 24))
	decor.road = pts
	decor.road_width = 22.0
	decor.edge_extra = 8.0
	var trees: Array[Vector3] = [
		Vector3(110, 700, 11), Vector3(86, 722, 9), Vector3(290, 680, 10),
	]
	decor.tree_spots = trees
	UI.place(self, decor, Vector2.ZERO, DESIGN_SIZE)
	UI.place(self, HexGridMap.preset_c(), Vector2.ZERO, DESIGN_SIZE)


## Generous central tap target: any marked map element opens the info popover.
func _build_tap_region() -> void:
	var tap := BaseButton.new()
	UI.place(self, tap, Vector2(0, 170), Vector2(DESIGN_SIZE.x, 570))
	tap.pressed.connect(func() -> void: Router.go("info_popover"))


func _build_markers() -> void:
	var gold := Control.new()
	gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, gold, Vector2(270 - 15, 415 - 15), Vector2(30, 30))
	var gq := UI.shadowed(UI.display("?", 22, Tokens.GOLD_GRAD_TOP), _Q_SHADOW, 2)
	gq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gq.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(gold, gq)
	UI.place(self, UI.display("?", 18, Tokens.white(0.35)), Vector2(110, 390))


func _build_player() -> void:
	var center := Vector2(201, 620)
	var ring := RingPulse.make(34.0, Tokens.CYAN, 3.0)
	UI.place(self, ring, center - ring.size / 2.0)
	var avatar := AvatarFace.make(GameState.character_id, 56.0, Color.WHITE, 3.5)
	UI.place(self, avatar, center - Vector2(28, 28))
	# box-shadow 0 0 0 3px cyan → a second ring hugging the white one.
	var halo := ChunkyRect.panel(Color(0, 0, 0, 0), 31.0, Tokens.CYAN, 3.0)
	UI.place(self, halo, center - Vector2(31, 31), Vector2(62, 62))
	var tag := Chip.make("YOU", {
		"bg": _YOU_BG, "border": Tokens.CYAN, "border_w": 1.5, "radius": 8.0,
		"text_color": Tokens.CYAN_LIGHT, "font": "micro", "font_size": 10,
		"pad_h": 9.0, "pad_v": 2.0,
	})
	UI.place_centered_x(self, tag, 651)


func _build_toast() -> void:
	var area: Dictionary = GameState.exploration["new_area"]
	var row := UI.hbox(8, BoxContainer.ALIGNMENT_CENTER)
	row.add_child(Icons.rect("pin", 16, Tokens.GREEN_GRAD_TOP, 2.5))
	row.add_child(_valigned(UI.display("NEW AREA", 13, Tokens.GREEN_GRAD_TOP)))
	row.add_child(_valigned(UI.body("%s · +%d XP" % [area["name"], int(area["xp"])],
		11, Color.WHITE, 700)))
	var toast := _pill(row, _TOAST_BG, Tokens.GREEN_GRAD_TOP, 14.0, 14.0, 8.0)
	UI.place_centered_x(self, toast, 130)


func _build_top_pills() -> void:
	var steps_row := UI.hbox(7, BoxContainer.ALIGNMENT_CENTER)
	steps_row.add_child(_svg_rect(_SVG_STEPS_CHEVRONS, 15, Tokens.CYAN, 2.4))
	steps_row.add_child(_valigned(UI.display(
		Rules.fmt_thousands(GameState.steps_today), 12, Color.WHITE)))
	steps_row.add_child(_valigned(UI.micro("STEPS", 9, Tokens.white(0.45))))
	var steps := _pill(steps_row, _PILL_BG, Tokens.BORDER, 30.0, 12.0, 6.0)
	UI.place(self, steps, Vector2(12, 58))

	var compass_row := UI.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	compass_row.add_child(_valigned(UI.display(
		String(GameState.exploration["compass"]), 12, Tokens.GOLD_GRAD_TOP)))
	compass_row.add_child(_svg_rect(_SVG_ARROW_UP, 14, Tokens.GOLD_GRAD_TOP, 2.6))
	var compass := _pill(compass_row, _PILL_BG, Tokens.BORDER, 30.0, 12.0, 6.0)
	UI.place(self, compass,
		Vector2(DESIGN_SIZE.x - 12 - compass.custom_minimum_size.x, 58))


func _build_chest_chip() -> void:
	var chip_data: Dictionary = GameState.exploration["quest_chip"]
	var row := UI.hbox(9, BoxContainer.ALIGNMENT_CENTER)
	var box := Control.new()
	box.custom_minimum_size = Vector2(26, 26)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box_rect := ChunkyRect.panel(Tokens.GOLD_GRAD_TOP, 8.0, Tokens.GOLD_BORDER, 2.0)
	box_rect.with_gradient(Tokens.GOLD_GRAD_TOP, Tokens.GOLD_GRAD_BOTTOM)
	UI.fill(box, box_rect)
	var chest_icon := Icons.rect("chest", 14, _CHEST_ICON)
	UI.place(box, chest_icon, Vector2(6, 6))
	row.add_child(box)
	var text := UI.hbox(0)
	text.add_child(_valigned(UI.body("%s — " % String(chip_data["text"]), 12, Color.WHITE, 700)))
	text.add_child(_valigned(UI.body(String(chip_data["hint"]), 12, Tokens.GOLD_GRAD_TOP, 700)))
	row.add_child(text)
	var chip := _pill(row, _CHIP_BG, Tokens.BORDER, 14.0, 14.0, 8.0, true)
	UI.place_centered_x(self, chip, DESIGN_SIZE.y - 52 - chip.custom_minimum_size.y)
	(chip as BaseButton).pressed.connect(func() -> void: Router.go("quest_board"))


## Dark HUD pill sized to its row (chunk: dark bg, 2px border, hard 4px shadow).
func _pill(row: HBoxContainer, bg: Color, border: Color, radius: float,
		pad_h: float, pad_v: float, interactive: bool = false) -> Control:
	var root: Control
	if interactive:
		root = BaseButton.new()
	else:
		root = Control.new()
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := ChunkyRect.panel(bg, radius, border, 2.0, _HARD_SHADOW)
	rect.shadow_offset = Vector2(0, 4)
	UI.fill(root, rect)
	var content := UI.margin(int(pad_h), int(pad_v))
	UI.fill(root, content)
	content.add_child(row)
	root.custom_minimum_size = row.get_combined_minimum_size() + Vector2(pad_h, pad_v) * 2.0
	return root


static func _valigned(l: Label) -> Label:
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func _svg_rect(body: String, px: int, color: Color, stroke_width: float) -> TextureRect:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#%s" stroke-width="%.2f" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [
		color.to_html(false), stroke_width, body]
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
