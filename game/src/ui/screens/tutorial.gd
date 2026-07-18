extends Screen
## Tutorial overlay (chunk 04): dimmed first map view (fog hexC variant),
## spotlight ring on the player avatar, SKIP, coach card with 4 steps from
## Catalog.TUTORIAL_STEPS. NEXT advances (dots + copy swap); after step 4 or
## SKIP → character select.

# One-off mock colors: dim veil, card hard shadow, YOU-badge fill, SKIP fill.
const _DIM := Color(10.0 / 255.0, 14.0 / 255.0, 20.0 / 255.0, 0.62)
const _CARD_SHADOW := Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.5)
const _BADGE_BG := Color("#0e2a33")
const _SKIP_BG := Color(16.0 / 255.0, 22.0 / 255.0, 34.0 / 255.0, 0.9)

var _step := 0
var _title: Label
var _body: Label
var _dots: Array[ChunkyRect] = []


func build() -> void:
	add_bg(Tokens.MAP_GRASS)
	# Mock draws the sand road under the hex tiles (fog must cover it), so the
	# path is its own layer below HexGridMap rather than the kit's paths list.
	UI.fill(self, _SandPath.new())
	UI.place(self, HexGridMap.preset_c(), Vector2.ZERO)

	var dim := ColorRect.new()
	dim.color = _DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(self, dim)

	var spotlight := ChunkyRect.new()
	spotlight.fill_top = Color(0, 0, 0, 0)
	spotlight.corner_radius = 75.0
	spotlight.border_color = Tokens.GOLD_GRAD_TOP
	spotlight.border_width = 3.0
	spotlight.dashed = true
	UI.place(self, spotlight, Vector2(126, 545), Vector2(150, 150))

	_add_avatar_cluster()
	_add_skip()
	_add_coach_card()


func _add_avatar_cluster() -> void:
	# box-shadow 0 0 0 3px cyan → a ring just outside the white avatar border.
	var cyan_ring := ChunkyRect.new()
	cyan_ring.fill_top = Color(0, 0, 0, 0)
	cyan_ring.corner_radius = 34.5
	cyan_ring.border_color = Tokens.CYAN
	cyan_ring.border_width = 3.0
	UI.place(self, cyan_ring, Vector2(166.5, 573.5), Vector2(69, 69))
	UI.place(self, AvatarFace.make(GameState.character_id, 63, Color.WHITE, 3.5),
		Vector2(169.5, 576.5))
	# "YOU" label is mock-only chrome, not in Catalog.
	var badge := Chip.make("YOU", {
		"font": "body", "font_size": 10, "text_color": Tokens.CYAN_LIGHT,
		"bg": _BADGE_BG, "border": Tokens.CYAN, "border_w": 1.5,
		"radius": 8.0, "pad_h": 9.0, "pad_v": 2.0})
	UI.place_centered_x(self, badge, 645.5)


func _add_skip() -> void:
	var rect := ChunkyRect.panel(_SKIP_BG, 12.0, Tokens.BORDER, 2.0)
	# pad_v 4 (mock 6): Godot's Lilita line box runs taller than the CSS one.
	var skip := _pill_button("SKIP", 11, Tokens.white(0.6), Vector2(13, 4), rect)
	add_child(skip)
	skip.position = Vector2(Screen.DESIGN_SIZE.x - 16.0 - skip.custom_minimum_size.x, 64)
	skip.size = skip.custom_minimum_size
	skip.pressed.connect(func() -> void: Router.go("character_select"))


func _add_coach_card() -> void:
	var card := Control.new()
	UI.place(self, card, Vector2(20, 614), Vector2(362, 150))
	var panel := ChunkyRect.panel(Tokens.BG_PANEL, 20.0, Tokens.GOLD_GRAD_TOP,
		2.5, _CARD_SHADOW)
	panel.shadow_offset = Vector2(0, 8)
	UI.fill(card, panel)
	var inner := UI.margin(17, 16)
	UI.fill(card, inner)
	var v := UI.vbox(10)
	inner.add_child(v)

	var step: Dictionary = Catalog.TUTORIAL_STEPS[0]
	_title = UI.display(step["title"], 16, Tokens.GOLD_GRAD_TOP)
	v.add_child(_title)
	_body = UI.wrap(UI.body(step["body"], 12, Tokens.white(0.75)))
	_body.add_theme_constant_override("line_spacing", 3)
	v.add_child(_body)

	var footer_wrap := UI.margin(0, 2, 0, 0)
	v.add_child(footer_wrap)
	var footer := UI.hbox(0)
	footer_wrap.add_child(footer)
	var dots := UI.hbox(5)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(dots)
	for i in Catalog.TUTORIAL_STEPS.size():
		var dot := Control.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.custom_minimum_size = Vector2(8, 8)
		var dr := ChunkyRect.panel(
			Tokens.GOLD_GRAD_TOP if i == 0 else Tokens.BORDER, 4.0)
		UI.fill(dot, dr)
		dots.add_child(dot)
		_dots.append(dr)
	footer.add_child(UI.spacer())

	var next_rect := ChunkyRect.new().with_gradient(Tokens.CYAN_GRAD_TOP,
		Tokens.CYAN_GRAD_BOTTOM)
	next_rect.corner_radius = 12.0
	next_rect.border_color = Color.WHITE
	next_rect.border_width = 2.0
	next_rect.shadow_color = Tokens.CYAN_SHADOW
	next_rect.shadow_offset = Vector2(0, 3)
	var next := _pill_button("NEXT", 13, Tokens.ON_CYAN, Vector2(22, 6), next_rect)
	footer.add_child(next)
	next.pressed.connect(_on_next)


func _on_next() -> void:
	_step += 1
	if _step >= Catalog.TUTORIAL_STEPS.size():
		Router.go("character_select")
		return
	var step: Dictionary = Catalog.TUTORIAL_STEPS[_step]
	_title.text = step["title"]
	_body.text = step["body"]
	for i in _dots.size():
		_dots[i].fill_top = Tokens.GOLD_GRAD_TOP if i == _step else Tokens.BORDER
		_dots[i].queue_redraw()


## Small chunky pill (the kit's ChunkyButton floors height at 44px; the mock's
## SKIP/NEXT pills are ~27/35px). Caller styles the rect; press shifts content
## onto the hidden shadow like ChunkyButton.
static func _pill_button(text: String, font_size: int, text_color: Color,
		pad: Vector2, rect: ChunkyRect) -> BaseButton:
	var b := BaseButton.new()
	UI.fill(b, rect)
	var content := UI.margin(0)
	UI.fill(b, content)
	var label := UI.display(text, font_size, text_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(label)
	b.custom_minimum_size = label.get_combined_minimum_size() + pad * 2.0 \
		+ Vector2.ONE * rect.border_width * 2.0
	var shadow_h := rect.shadow_offset.y if rect.shadow_color.a > 0.0 else 0.0
	if shadow_h > 0.0:
		var base_shadow := rect.shadow_color
		b.button_down.connect(func() -> void:
			for c: Control in [rect, content]:
				c.offset_top = shadow_h
				c.offset_bottom = shadow_h
			rect.shadow_color = Color(base_shadow, 0.0)
			rect.queue_redraw())
		b.button_up.connect(func() -> void:
			for c: Control in [rect, content]:
				c.offset_top = 0.0
				c.offset_bottom = 0.0
			rect.shadow_color = base_shadow
			rect.queue_redraw())
	return b


## The mock svg's sand road (two cubic segments, round caps, no edge stroke).
class _SandPath:
	extends Control

	const _WIDTH := 22.0
	const _SEGMENTS := 24

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var pts := PackedVector2Array()
		pts.append_array(_cubic(Vector2(160, 874), Vector2(172, 700),
			Vector2(150, 560), Vector2(190, 420)))
		pts.append_array(_cubic(Vector2(190, 420), Vector2(220, 320),
			Vector2(300, 260), Vector2(420, 230)))
		draw_polyline(pts, Tokens.MAP_PATH, _WIDTH, true)
		for p in pts:
			draw_circle(p, _WIDTH / 2.0, Tokens.MAP_PATH)

	static func _cubic(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in _SEGMENTS + 1:
			out.append(p0.bezier_interpolate(p1, p2, p3, float(i) / _SEGMENTS))
		return out
