extends Screen
## Notification pre-prompt (chunk 03): bell medallion, "KNOW WHEN IT MATTERS",
## three value rows, ALLOW NOTIFICATIONS + MAYBE LATER (both → tutorial).

# One-off mock colors: chest-icon stroke on the gold tile.
const _CHEST_STROKE := Color("#6b4508")
# Mock single-person invite icon (Icons "party" draws two people).
const _PERSON_SVG := '<circle cx="9" cy="8" r="3.4"/><path d="M2.5 20c.8-3.4 3.4-5 6.5-5s5.7 1.6 6.5 5"/>'


func build() -> void:
	add_bg(Tokens.BG_SCREEN)

	_add_medallion()

	var title := UI.centered(UI.display(Catalog.COPY["notif_title"], 26))
	# Godot's Lilita line box is ~9px taller than the mock's line-height.
	title.add_theme_constant_override("line_spacing", -9)
	UI.place_centered_x(self, title, 244)

	var body := UI.centered(UI.wrap(UI.body(Catalog.COPY["notif_body"], 12,
		Tokens.white(0.6))))
	body.add_theme_constant_override("line_spacing", 3)
	# 260 wide so the wrap lands after "looking." like the mock.
	UI.place(self, body, Vector2(71, 318), Vector2(260, 42))

	var rows: Array = Catalog.COPY["notif_rows"]
	_add_row(String(rows[0]), 376.0, _tile_icon_shroom())
	_add_row(String(rows[1]), 438.0, _tile_icon_chest())
	_add_row(String(rows[2]), 500.0, _tile_icon_person())

	var allow := ChunkyButton.make(Catalog.COPY["notif_allow"], "cta_cyan",
		Vector2(300, 50), 15)
	UI.place_centered_x(self, allow, 719)
	allow.pressed.connect(func() -> void: Router.go("tutorial"))

	var later := ChunkyButton.make(Catalog.COPY["notif_later"], "secondary",
		Vector2(300, 46), 13)
	UI.place_centered_x(self, later, 778)
	later.pressed.connect(func() -> void: Router.go("tutorial"))


func _add_medallion() -> void:
	var medallion := Control.new()
	medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, medallion, Vector2(141, 100), Vector2(120, 120))
	UI.fill(medallion, ChunkyRect.panel(Tokens.BG_CARD, 60.0, Tokens.BORDER, 3.0))
	UI.place(medallion, Icons.rect("bell", 50, Tokens.GOLD_GRAD_TOP, 2.0),
		Vector2(35, 35))


func _add_row(text: String, y: float, tile: Control) -> void:
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, row, Vector2(51, y), Vector2(300, 54))
	UI.fill(row, ChunkyRect.panel(Tokens.BG_CARD, 12.0, Tokens.BORDER, 2.0))
	var inner := UI.margin(12, 10)
	UI.fill(row, inner)
	var h := UI.hbox(10)
	inner.add_child(h)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tile)
	var label := UI.body(text, 11, Tokens.white(0.75))
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(label)


func _tile(rect: ChunkyRect, icon: Control) -> Control:
	var t := Control.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.custom_minimum_size = Vector2(30, 30)
	rect.corner_radius = 9.0
	UI.fill(t, rect)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	t.add_child(icon)
	return t


func _tile_icon_shroom() -> Control:
	return _tile(ChunkyRect.panel(Tokens.RARITY_EPIC_BOTTOM, 9.0),
		Icons.rect("shroom_plain", 16, Color.WHITE))


func _tile_icon_chest() -> Control:
	var rect := ChunkyRect.new().with_gradient(Tokens.GOLD_GRAD_TOP,
		Tokens.GOLD_GRAD_BOTTOM)
	return _tile(rect, Icons.rect("chest", 16, _CHEST_STROKE, 2.4))


func _tile_icon_person() -> Control:
	var rect := ChunkyRect.new().with_gradient(Tokens.CYAN_GRAD_TOP,
		Tokens.CYAN_GRAD_BOTTOM)
	return _tile(rect, _svg_rect(_PERSON_SVG, 15, Tokens.ON_CYAN, 2.4))


## Mini clone of Icons.tex for a mock-exact path the registry lacks.
static func _svg_rect(inner_markup: String, px: int, color: Color, sw: float) -> TextureRect:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#%s" stroke-width="%.2f" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [
		color.to_html(false), sw, inner_markup]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, float(px) / 24.0)
	assert(err == OK, "svg rasterize failed")
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
