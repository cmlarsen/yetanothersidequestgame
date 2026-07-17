extends Screen
## Level up + skill unlock (mock chunk 07): radial celebration bg, LEVEL UP!
## + big number, stat-bump pills, NEW SKILL card, next-unlock tease, CONTINUE.
## Pop-in stagger: title → pills → card → tease (SCREENS.md §7).

# Chunk-07 one-off colors.
const _BG_CENTER := Color("#1e4a3a")
const _BG_EDGE := Color("#12151f")
const _GLOW_GREEN := Color(124.0 / 255.0, 232.0 / 255.0, 67.0 / 255.0, 0.18)
const _NUM_SHADOW := Color("#1a4a10")
const _ATK_PILL := Color("#ff8a65")
const _TEASE_GRAY := Color("#8a97b3")
const _TILE_GRAD_TOP := Color("#1e4a5c")
const _TILE_GRAD_BOTTOM := Color("#123240")
const _CARD_SHADOW := Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.6)


func build() -> void:
	clip_contents = true
	add_bg(_BG_EDGE)
	# radial-gradient(circle at 50% 32%, #1e4a3a, #12151f 65%) → 408px radius.
	UI.place(self, _radial_layer(_BG_CENTER, _BG_EDGE, 1.0),
		Vector2(-207, -128), Vector2(816, 816))
	var glow_edge := Color(_GLOW_GREEN, 0.0)
	UI.place(self, _radial_layer(_GLOW_GREEN, glow_edge, 0.6),
		Vector2(-39, 60), Vector2(480, 480))

	_build_title()
	_build_pills()
	_build_card()
	_build_tease()

	var cont := ChunkyButton.make("CONTINUE", "cta_cyan", Vector2(306, 50), 15)
	UI.place_centered_x(self, cont, 776)
	cont.pressed.connect(func() -> void: Router.go("home"))


func _build_title() -> void:
	var block := Control.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place_centered_x(self, block, 80, Vector2(240, 100))
	block.pivot_offset = Vector2(120, 50)
	block.rotation_degrees = -2.0
	# Negative gap tucks the big number against the headline (mock margin -8px
	# plus Lilita's tall line metrics).
	var col := UI.vbox(-22, BoxContainer.ALIGNMENT_BEGIN)
	UI.fill(block, col)
	# "LEVEL UP!" headline copy is not in Catalog (chunk 07 only).
	var head := UI.centered(UI.display("LEVEL UP!", 20, Tokens.white(0.6)))
	col.add_child(head)
	var num := UI.centered(UI.display(str(int(GameState.level_up["level"])), 64,
		Tokens.GREEN_GRAD_TOP))
	UI.shadowed(num, _NUM_SHADOW, 5)
	col.add_child(num)
	pop_in(block)


func _build_pills() -> void:
	var row := UI.hbox(9)
	row.add_child(_pill("ATK +%d" % int(GameState.level_up["atk"]), _ATK_PILL))
	row.add_child(_pill("DEF +%d" % int(GameState.level_up["def"]), Tokens.GREEN_GRAD_TOP))
	row.add_child(_pill("HP +%d" % int(GameState.level_up["hp"]), Tokens.CYAN_LIGHT))
	UI.place_centered_x(self, row, 186)
	pop_in(row, 0.2)


func _pill(text: String, color: Color) -> Control:
	return Chip.make(text, {
		"font": "display", "font_size": 12, "text_color": color,
		"bg": Tokens.BG_CARD, "border": Tokens.BORDER, "border_w": 2.0,
		"radius": 30.0, "pad_h": 13.0, "pad_v": 6.0,
	})


func _build_card() -> void:
	var skill := Catalog.item(String(GameState.level_up["new_skill"]))
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, card, Vector2(27, 238), Vector2(348, 220))
	var rect := ChunkyRect.panel(Tokens.BG_CARD, 20.0, Tokens.CYAN, 3.0, _CARD_SHADOW)
	rect.shadow_offset = Vector2(0, 6)
	rect.glow_color = Color(Tokens.CYAN, 0.3)
	rect.glow_size = 15.0
	UI.fill(card, rect)

	var pad := UI.margin(19, 16)
	UI.fill(card, pad)
	var col := UI.vbox(9)
	pad.add_child(col)
	# Card frame copy ("NEW SKILL UNLOCKED", "ADD TO HOT BAR") is chunk-07 only.
	var head := UI.micro("NEW SKILL UNLOCKED", 9, Tokens.CYAN)
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(head)

	var tile := Control.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.custom_minimum_size = Vector2(66, 66)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(tile)
	var tile_rect := ChunkyRect.panel(_TILE_GRAD_TOP, 18.0, Tokens.CYAN, 3.0) \
		.with_gradient(_TILE_GRAD_TOP, _TILE_GRAD_BOTTOM)
	UI.fill(tile, tile_rect)
	UI.place(tile, Icons.rect(String(skill["icon"]), 30, Tokens.CYAN_LIGHT, 2.3),
		Vector2(18, 18))

	var name_l := UI.display(String(skill["name"]).to_upper(), 17)
	name_l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(name_l)
	var effect := UI.centered(UI.wrap(UI.body(String(skill["effect_line"]), 11,
		Tokens.white(0.6), 700)))
	effect.custom_minimum_size = Vector2(300, 0)
	effect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(effect)

	var add_btn := _mini_button("ADD TO HOT BAR")
	add_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(add_btn)
	pop_in(card, 0.45)


## Small cyan CTA (mock: padding 8/24, radius 12) — below ChunkyButton's 44px
## floor, so built locally with the same pressed-onto-shadow feedback.
func _mini_button(text: String) -> BaseButton:
	var b := BaseButton.new()
	var rect := ChunkyRect.new()
	rect.with_gradient(Tokens.CYAN_GRAD_TOP, Tokens.CYAN_GRAD_BOTTOM)
	rect.border_color = Color.WHITE
	rect.border_width = 2.0
	rect.corner_radius = 12.0
	rect.shadow_color = Tokens.CYAN_SHADOW
	rect.shadow_offset = Vector2(0, 3)
	UI.fill(b, rect)
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(b, wrap)
	var label := UI.display(text, 12, Tokens.ON_CYAN)
	wrap.add_child(label)
	b.custom_minimum_size = Vector2(label.get_minimum_size().x + 48.0, 31)
	b.button_down.connect(func() -> void: _mini_press(rect, wrap, true))
	b.button_up.connect(func() -> void: _mini_press(rect, wrap, false))
	return b


func _mini_press(rect: ChunkyRect, wrap: Control, down: bool) -> void:
	var dy := 3.0 if down else 0.0
	for c: Control in [rect, wrap]:
		c.offset_top = dy
		c.offset_bottom = dy
	rect.shadow_color = Color(Tokens.CYAN_SHADOW, 0.0 if down else 1.0)
	rect.queue_redraw()


func _build_tease() -> void:
	var chip := Control.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := ChunkyRect.panel(Color(Tokens.BG_CARD, 0.7), 14.0,
		Tokens.SLOT_BORDER, 2.0)
	rect.dashed = true
	UI.fill(chip, rect)
	var row := UI.hbox(9, BoxContainer.ALIGNMENT_CENTER)
	row.add_child(Icons.rect("lock", 16, Tokens.SLOT_BORDER, 2.2))
	var text := UI.hbox(0)
	# "Next at LV N" template is chunk-07 copy; the level/label are GameState.
	text.add_child(UI.body("Next at LV %d — " % int(GameState.level_up["tease_level"]),
		10, Tokens.white(0.5), 700))
	text.add_child(UI.body(String(GameState.level_up["tease_label"]), 10,
		_TEASE_GRAY, 700))
	row.add_child(text)
	var content := UI.margin(14, 9)
	UI.fill(chip, content)
	content.add_child(row)
	chip.custom_minimum_size = row.get_combined_minimum_size() + Vector2(28, 18)
	UI.place_centered_x(self, chip, 487)
	pop_in(chip, 0.65)


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
