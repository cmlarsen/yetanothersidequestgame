extends Screen
## Chunk 15 "Turf brawl": hexB map, boss plate w/ segmented HP, contested-hex
## dashed ring + Gloomling blob, ally pins with HP rings, damage floats, bottom
## gradient scrim and the 5-slot hot bar from GameState.hotbar × Catalog.

# One-off mock colors (not in the token sheet).
const _OVERLAY_DARK := Color("#101622")  # rgba(16,22,34,·) plates/tags
const _SCRIM := Color("#0a0e14")  # bottom gradient rgba(10,14,20,.9)
const _MOB_TAG_BG := Color(20.0 / 255.0, 10.0 / 255.0, 40.0 / 255.0, 0.85)
const _YOU_TAG_BG := Color("#0e2a33")
const _PLATE_SHADOW := Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.5)
const _FLOAT_BIG_SHADOW := Color("#7a4a05")
const _FLOAT_CRIT_SHADOW := Color("#7a1030")

# The mock's slot art diverges from Catalog icons for these two (sword-slash
# and bolt read better at 24px than the literal hammer/scroll glyphs).
const _ICON_OVERRIDE := {"bonk_hammer": "sword_slash", "zap_scroll": "bolt"}
const _ICON_COLOR := {
	"zap_scroll": Tokens.RARITY_LEGENDARY_TOP,
	"fizzy_mender": Tokens.PINK_LIGHT,
}

# Mock hot bar: 52px slots, 8px gap, labels bottom-anchored at 830.
const _SLOT_SIDE := 52.0
const _SLOT_SCALE := _SLOT_SIDE / HotBarSlot.SLOT_SIDE
const _SLOT_TOP := 763.0
const _SLOT_X0 := 55.0
const _SLOT_STEP := 60.0

# Per-kind damage float styling straight from the chunk's absolute divs.
const _FLOAT_STYLE := {
	"big": {"pos": Vector2(246, 352), "size": 26, "rot": -7.0},
	"normal": {"pos": Vector2(118, 410), "size": 18, "rot": 5.0},
	"crit": {"pos": Vector2(86, 300), "size": 30, "rot": -4.0},
}


func build() -> void:
	add_bg(Tokens.MAP_GRASS)
	_add_map()
	_add_mob()
	_add_damage_floats()
	_add_party_pins()
	_add_boss_plate()
	_add_hot_bar()


func _add_map() -> void:
	# Road + tree blobs sit UNDER the hex lines in the mock SVG, so they are a
	# separate decor layer rather than HexGridMap.paths/trees (which draw over).
	var decor := _MapDecor.new()
	decor.road = _bezier(Vector2(-20, 560), Vector2(100, 520), Vector2(220, 500),
		Vector2(420, 470), 26)
	var tree_blobs: Array[Vector3] = [
		Vector3(70, 300, 16), Vector3(105, 270, 20), Vector3(52, 252, 13),
	]
	decor.tree_blobs = tree_blobs
	UI.place(self, decor, Vector2.ZERO, DESIGN_SIZE)
	UI.place(self, HexGridMap.preset_b(), Vector2.ZERO, DESIGN_SIZE)
	var ring := RingPulse.make(73, Tokens.WARNING, 4.0, true)
	UI.place(self, ring, Vector2(201, 430) - ring.size / 2.0)


func _add_mob() -> void:
	var blob := MobBlob.make(84)
	UI.place(self, blob, Vector2(159, 378))
	bob(blob)
	UI.place_centered_x(self, _tag("3D MOB RENDER", Tokens.GLOOM_LIGHT,
		_MOB_TAG_BG), 466)
	# Dev navigation until real combat exists: tapping the mob "wins".
	_nav_button(Rect2(159, 378, 84, 84), "victory")


func _add_damage_floats() -> void:
	for f: Dictionary in GameState.combat.floats:
		var kind := String(f.get("kind", "normal"))
		var style: Dictionary = _FLOAT_STYLE[kind]
		var color := Color.WHITE
		var shadow := Tokens.white(0.0)
		match kind:
			"big":
				color = Tokens.WARNING
				shadow = _FLOAT_BIG_SHADOW
			"normal":
				shadow = Color(0, 0, 0, 0.4)
			"crit":
				color = Tokens.PINK
				shadow = _FLOAT_CRIT_SHADOW
		UI.place(self, DamageFloat.make(String(f.text), color, int(style.size),
			float(style.rot), shadow), Vector2(style.pos))


func _add_party_pins() -> void:
	# Mock pin anchor centers; self is the big bottom-left pin.
	var centers := {"BRITT": Vector2(308, 330), "MAGEMIKE": Vector2(302, 530)}
	for member: Dictionary in GameState.party:
		var is_self := bool(member.get("is_self", false))
		if is_self:
			_pin(Vector2(110, 560), String(member.face), 48.0, 54.0,
				GameState.hp / float(GameState.hp_max), "YOU", true)
		elif centers.has(member.name):
			_pin(centers[member.name], String(member.face), 43.0, 48.0,
				float(member.hp_ratio), String(member.name), false)
	# Dev navigation: tapping your own pin "dies".
	_nav_button(Rect2(83, 523, 54, 60), "death")


## One map pin: HP-ringed face + name tag, centered on the mock's anchor.
func _pin(center: Vector2, face: String, diameter: float, box: float,
		hp: float, tag_text: String, is_self: bool) -> void:
	var top := center.y - (box + 3.0 + 17.0) / 2.0
	var avatar := AvatarFace.make(face, diameter, Color.WHITE, 2.5)
	avatar.set_hp_ring(hp, Tokens.GREEN_GRAD_TOP)
	UI.place(self, avatar, Vector2(center.x - diameter / 2.0,
		top + (box - diameter) / 2.0))
	var tag: Control
	if is_self:
		tag = _tag(tag_text, Tokens.CYAN_LIGHT, _YOU_TAG_BG, Tokens.CYAN, 1.5)
	else:
		tag = _tag(tag_text, Color.WHITE, Color(_OVERLAY_DARK, 0.85))
	UI.place(self, tag, Vector2(center.x - tag.custom_minimum_size.x / 2.0,
		top + box + 3.0))


func _add_boss_plate() -> void:
	var mob: Dictionary = Catalog.mob(String(GameState.combat.mob))
	var plate := Control.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, plate, Vector2(12, 58), Vector2(378, 62))
	var rect := ChunkyRect.panel(Color(_OVERLAY_DARK, 0.9), 16.0,
		Tokens.GLOOM_BORDER_ALT, 2.0, _PLATE_SHADOW)
	UI.fill(plate, rect)
	var pad := UI.margin(14, 10)
	UI.fill(plate, pad)
	var col := UI.vbox(6)
	pad.add_child(col)
	var row := UI.hbox(0)
	col.add_child(row)
	row.add_child(UI.display(String(mob.name), 15, Tokens.GLOOM_LIGHT))
	row.add_child(UI.spacer())
	row.add_child(UI.micro("%s · LV %d" % [mob.title, mob.level], 10, Tokens.white(0.5)))
	var bar := SegmentedBar.make(350, 16, int(mob.hp_segments),
		Tokens.RARITY_EPIC_TOP, Tokens.RARITY_EPIC_BOTTOM)
	bar.set_ratio(float(GameState.combat.boss_hp_ratio))
	col.add_child(bar)


func _add_hot_bar() -> void:
	var scrim := _Scrim.new()
	UI.place(self, scrim, Vector2(0, 704), Vector2(402, 170))
	for i in Rules.HOTBAR_SLOTS:
		var entry: Dictionary = GameState.hotbar[i]
		var x := _SLOT_X0 + i * _SLOT_STEP
		var label_text := "EMPTY"
		var label_color := Tokens.SLOT_BORDER
		var cfg := {}
		if entry.is_empty():
			cfg["state"] = "empty"
		else:
			var id := String(entry.item)
			var item: Dictionary = Catalog.item(id)
			label_text = String(item.name)
			label_color = Tokens.white(0.65)
			cfg["icon"] = _ICON_OVERRIDE.get(id, String(item.icon))
			if _ICON_COLOR.has(id):
				cfg["icon_color"] = _ICON_COLOR[id]
			if entry.get("state", "ready") == "cooldown":
				cfg["state"] = "cooldown"
				cfg["cooldown_left"] = entry.cooldown_left
			if entry.has("charges"):
				cfg["charges"] = entry.charges
			if String(item.slot_type) == "weapon":
				cfg["glow"] = _rarity_color(String(item.rarity))
		var slot := HotBarSlot.make(cfg)
		slot.scale = Vector2(_SLOT_SCALE, _SLOT_SCALE)
		UI.place(self, slot, Vector2(x, _SLOT_TOP))
		var label := _measured(UI.micro(label_text, 8, label_color, 0))
		add_child(label)
		label.position = Vector2(
			x + _SLOT_SIDE / 2.0 - label.get_minimum_size().x / 2.0, 819)
		# Mock gesture is hold-to-swap; the shell simplifies to tap.
		_nav_button(Rect2(x, _SLOT_TOP, _SLOT_SIDE, 68), "equip_drawer")


static func _rarity_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return Tokens.RARITY_RARE
		"epic":
			return Tokens.RARITY_EPIC_TOP
		"legendary":
			return Tokens.RARITY_LEGENDARY_TOP
	return Tokens.RARITY_COMMON


## Font overrides don't refresh a Label's min size until it enters the tree;
## force the theme pass so pre-layout measurements (centering, pill widths)
## use the real 8–9px metrics instead of the default 16px ones.
static func _measured(l: Label) -> Label:
	l.notification(Control.NOTIFICATION_THEME_CHANGED)
	return l


## Mock name-tag pill: micro text, 2px 8px padding, radius 7. Built locally
## because Chip.make bakes the pre-tree (inflated) label width into its size.
static func _tag(text: String, text_color: Color, bg: Color,
		border: Color = Color(0, 0, 0, 0), border_w: float = 0.0) -> Control:
	var label := _measured(UI.micro(text, 9, text_color, 0))
	var tag_size := label.get_minimum_size() + Vector2(16, 4)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = tag_size
	root.size = tag_size
	UI.fill(root, ChunkyRect.panel(bg, 7.0, border, border_w))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(root, label)
	return root


func _nav_button(rect: Rect2, route: String) -> void:
	var b := BaseButton.new()
	UI.place(self, b, rect.position, rect.size)
	b.pressed.connect(func() -> void: Router.go(route))


static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2,
		segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments + 1:
		out.append(p0.bezier_interpolate(p1, p2, p3, float(i) / segments))
	return out


## Road + tree circles drawn beneath the hex grid (mock layer order).
class _MapDecor:
	extends Control

	var road: PackedVector2Array
	var tree_blobs: Array[Vector3] = []  # x, y, radius

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if road.size() >= 2:
			_stroke_round(road, Tokens.MAP_PATH_EDGE, 52.0)
			_stroke_round(road, Tokens.MAP_PATH, 40.0)
		for t in tree_blobs:
			draw_circle(Vector2(t.x, t.y), t.z, Tokens.MAP_TREE)

	func _stroke_round(pts: PackedVector2Array, color: Color, width: float) -> void:
		draw_polyline(pts, color, width, true)
		for pt in pts:
			draw_circle(pt, width / 2.0, color)


## Bottom gradient: transparent → 90% dark at 70% height, then solid.
class _Scrim:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var dark := Color(_SCRIM, 0.9)
		var clear := Color(_SCRIM, 0.0)
		var k := size.y * 0.7
		var quad := PackedVector2Array([
			Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, k), Vector2(0, k)])
		draw_polygon(quad, PackedColorArray([clear, clear, dark, dark]))
		draw_rect(Rect2(0, k, size.x, size.y - k), dark)
