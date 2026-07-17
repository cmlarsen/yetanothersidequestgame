extends Screen
## Character selection (mock chunk 05). Tapping a face in the swipe row swaps
## the featured card; the locked Grumbeard entry is not selectable.

# Mock swipe-row order (chunk 05 shows this 5-face window of the 8).
const _ROW: Array[String] = ["barbarian", "mage", "knight", "huntress", "dwarf"]

# One-off chunk-05 colors with no token.
const _BG_TOP := Color("#22405c")
const _TITLE_SHADOW := Color("#1a5a6e")
const _ATK_BAR_TOP := Color("#ff8a65")
const _LOCK_GRAY := Color("#8a97b3")
const _CARD_SHADOW := Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.6)

var _selected: String = GameState.character_id

var _badge: Control
var _face_holder: Control
var _name_label: Label
var _epithet_label: Label
var _flavor_label: Label
var _bars: Dictionary = {}
var _row: Control


func build() -> void:
	clip_contents = true
	add_bg(Tokens.BG_SCREEN)
	# radial-gradient(circle at 50% 20%, #22405c, #151a26 60%) → 436px radius.
	UI.place(self, _radial_layer(_BG_TOP, Tokens.BG_SCREEN, 1.0),
		Vector2(-235, -261), Vector2(872, 872))

	var title := UI.display(Catalog.COPY["select_title"], 32)
	UI.shadowed(title, _TITLE_SHADOW, 3)
	UI.wrap(title)
	# Lilita's tall line metrics leave ~55px strides; the mock wraps at ~35px.
	title.add_theme_constant_override("line_spacing", -20)
	UI.place(self, title, Vector2(20, 136), Vector2(362, 80))
	title.pivot_offset = Vector2(181, 40)
	title.rotation_degrees = -1.5

	UI.place_centered_x(self, UI.body(Catalog.COPY["select_subtitle"], 11,
		Tokens.white(0.5), 700), 216)

	_build_card()
	_row = Control.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, _row, Vector2(0, 608), Vector2(DESIGN_SIZE.x, 56))
	_build_hint()

	var confirm := ChunkyButton.make(Catalog.COPY["select_cta"], "cta_cyan",
		Vector2(306, 52), 17)
	UI.place_centered_x(self, confirm, 717)
	confirm.pressed.connect(func() -> void: Router.go("home"))

	_refresh()


func _build_card() -> void:
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, card, Vector2(18, 247), Vector2(366, 336))
	var rect := ChunkyRect.panel(Tokens.BG_CARD, 24.0, Tokens.CYAN, 3.0, _CARD_SHADOW)
	rect.shadow_offset = Vector2(0, 8)
	rect.glow_color = Color(Tokens.CYAN, 0.25)
	rect.glow_size = 18.0
	UI.fill(card, rect)

	# "MOST PLAYED" chip copy is not in Catalog.COPY (chunk 05 only).
	_badge = Chip.make("MOST PLAYED", {
		"font": "display", "font_size": 11, "text_color": Tokens.ON_GOLD,
		"bg": Tokens.WARNING, "border_w": 0.0, "radius": 9.0,
		"pad_h": 13.0, "pad_v": 4.0, "shadow": Tokens.GOLD_SHADOW,
	})
	UI.place_centered_x(card, _badge, -13)
	_badge.pivot_offset = _badge.custom_minimum_size * 0.5
	_badge.rotation_degrees = -2.0

	var pad := UI.margin(23, 25, 23, 21)
	UI.fill(card, pad)
	var col := UI.vbox(10)
	pad.add_child(col)

	_face_holder = Control.new()
	_face_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_holder.custom_minimum_size = Vector2(126, 126)
	_face_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_face_holder)

	var names := UI.vbox(0)
	names.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(names)
	_name_label = UI.centered(UI.display("", 22))
	names.add_child(_name_label)
	_epithet_label = UI.centered(UI.micro("", 10, Tokens.CYAN))
	names.add_child(_epithet_label)

	_flavor_label = UI.centered(UI.wrap(UI.body("", 11, Tokens.white(0.6), 700)))
	_flavor_label.custom_minimum_size = Vector2(320, 0)
	_flavor_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_flavor_label)

	var bars := UI.vbox(6)
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(bars)
	bars.add_child(_stat_row("ATK", _ATK_BAR_TOP, Tokens.RED_GRAD_BOTTOM))
	bars.add_child(_stat_row("DEF", Tokens.GREEN_GRAD_TOP, Tokens.GREEN_GRAD_BOTTOM))
	bars.add_child(_stat_row("SPD", Tokens.CYAN_GRAD_TOP, Tokens.CYAN_GRAD_BOTTOM))


func _stat_row(stat: String, from: Color, to: Color) -> Control:
	var row := UI.hbox(8)
	var label := UI.micro(stat, 9, Tokens.white(0.5))
	label.custom_minimum_size = Vector2(38, 0)
	row.add_child(label)
	var bar := HBar.bar(0, 9, from, to, 6.0, 0.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	_bars[stat.to_lower()] = bar
	return row


func _build_hint() -> void:
	var hint := UI.hbox(0)
	hint.add_child(UI.body(String(Catalog.COPY["select_swipe_hint"]) + " · ", 9,
		Tokens.white(0.4), 800))
	hint.add_child(UI.body(String(Catalog.character("dwarf")["unlock_hint"]), 9,
		Tokens.GOLD_GRAD_TOP, 800))
	UI.place_centered_x(self, hint, 670)


func _refresh() -> void:
	var ch := Catalog.character(_selected)
	_badge.visible = bool(ch.get("most_played", false))
	_name_label.text = String(ch["name"])
	_epithet_label.text = String(ch["epithet"])
	_flavor_label.text = String(ch["flavor"])
	var stat_bars: Dictionary = ch["bars"]
	for stat: String in _bars:
		var bar: HBar = _bars[stat]
		bar.ratio = float(stat_bars[stat])
		bar.queue_redraw()

	for c in _face_holder.get_children():
		c.queue_free()
	var ring := ChunkyRect.new()
	ring.fill_top = Color(0, 0, 0, 0)
	ring.border_color = Tokens.CYAN
	ring.border_width = 4.0
	ring.corner_radius = 67.0
	UI.place(_face_holder, ring, Vector2(-4, -4), Vector2(134, 134))
	UI.place(_face_holder, AvatarFace.make(_selected, 126, Color.WHITE, 4.0), Vector2.ZERO)

	for c in _row.get_children():
		c.queue_free()
	var x := 61.0
	for id in _ROW:
		var d := 52.0 if id == _selected else 48.0
		_add_face_button(id, Vector2(x, 28.0 - d / 2.0), d)
		x += d + 9.0


func _add_face_button(id: String, pos: Vector2, d: float) -> void:
	var ch := Catalog.character(id)
	var locked := int(ch.get("unlock_level", 1)) > GameState.level
	var active := id == _selected
	var b := BaseButton.new()
	UI.place(_row, b, pos, Vector2(d, d))
	if active:
		var glow := ChunkyRect.new()
		glow.fill_top = Color(0, 0, 0, 0)
		glow.corner_radius = d / 2.0
		glow.glow_color = Color(Tokens.CYAN, 0.5)
		glow.glow_size = 8.0
		UI.fill(b, glow)
	var ring_color := Tokens.CYAN if active else Tokens.SLOT_BORDER
	var ring_width := 3.0 if active else 2.5
	UI.fill(b, AvatarFace.make(id, d, ring_color, ring_width))
	if locked:
		# Mock dims the locked face itself (brightness .4) and overlays a lock.
		var scrim := ChunkyRect.panel(Color(0, 0, 0, 0.55), d / 2.0)
		UI.fill(b, scrim)
		UI.place(b, Icons.rect("lock", 16, _LOCK_GRAY),
			Vector2((d - 16.0) / 2.0, (d - 16.0) / 2.0))
	if not active:
		b.modulate = Tokens.white(0.65)
	if not locked:
		b.pressed.connect(_on_face_pressed.bind(id))


func _on_face_pressed(id: String) -> void:
	if id == _selected:
		return
	_selected = id
	_refresh()


static func _radial_layer(center: Color, edge: Color, edge_stop: float) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, edge_stop, 1.0])
	g.colors = PackedColorArray([center, edge, edge])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 512
	t.height = 512
	var tr := TextureRect.new()
	tr.texture = t
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Rounded inset track + HORIZONTAL gradient fill (the kit's StatBarChunky
## gradient is vertical; chunk 05/06 bars sweep left→right).
class HBar:
	extends Control

	var ratio: float = 1.0
	var color_from: Color
	var color_to: Color
	var bg: Color = Tokens.BG_INSET
	var radius: float = 6.0

	static func bar(w: float, h: float, from: Color, to: Color, r: float,
			p_ratio: float) -> HBar:
		var b := HBar.new()
		b.custom_minimum_size = Vector2(w, h)
		b.color_from = from
		b.color_to = to
		b.radius = r
		b.ratio = p_ratio
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.resized.connect(b.queue_redraw)
		return b

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var r4 := Vector4(radius, radius, radius, radius)
		draw_colored_polygon(ChunkyRect.rounded_points(Rect2(Vector2.ZERO, size), r4), bg)
		if ratio <= 0.01:
			return
		var w := size.x * clampf(ratio, 0.0, 1.0)
		var right_r := radius if ratio >= 0.99 else 0.0
		var pts := ChunkyRect.rounded_points(Rect2(Vector2.ZERO, Vector2(w, size.y)),
			Vector4(radius, right_r, right_r, radius))
		var cols := PackedColorArray()
		for p in pts:
			cols.append(color_from.lerp(color_to, clampf(p.x / w, 0.0, 1.0)))
		draw_polygon(pts, cols)
