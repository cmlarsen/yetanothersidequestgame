extends Screen
## Location pre-prompt (chunk 02): pin medallion, "YOUR LEGS ARE THE JOYSTICK",
## rationale copy, two reassurance chips, mocked OS dialog. The dialog's Allow
## row is the primary CTA → notification permission; Don't Allow stays visual.

# One-off mock colors for the light OS dialog.
const _OS_BG := Color(240.0 / 255.0, 244.0 / 255.0, 250.0 / 255.0, 0.97)
const _OS_TEXT := Color("#1a2130")
const _OS_MUTED := Color("#6b7688")
const _OS_LINK := Color("#2a7de1")
const _OS_DIVIDER := Color(0, 0, 0, 0.12)


func build() -> void:
	add_bg(Tokens.BG_SCREEN)

	_add_medallion()

	var title := UI.centered(UI.display(Catalog.COPY["location_title"], 26))
	# Godot's Lilita line box is ~9px taller than the mock's line-height.
	title.add_theme_constant_override("line_spacing", -9)
	UI.place_centered_x(self, title, 244)

	var body := UI.centered(UI.wrap(UI.body(Catalog.COPY["location_body"], 12,
		Tokens.white(0.6))))
	body.add_theme_constant_override("line_spacing", 3)
	UI.place(self, body, Vector2(56, 318), Vector2(290, 62))

	var chips: Array = Catalog.COPY["location_chips"]
	_add_chip(String(chips[0]), Vector2(51, 396), 36.0)
	_add_chip(String(chips[1]), Vector2(51, 440), 50.0)

	_add_os_dialog()


func _add_medallion() -> void:
	var medallion := Control.new()
	medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, medallion, Vector2(141, 100), Vector2(120, 120))
	var circle := ChunkyRect.panel(Tokens.BG_CARD, 60.0, Tokens.BORDER, 3.0)
	UI.fill(medallion, circle)
	var icon := Icons.rect("pin", 52, Tokens.CYAN, 2.0)
	UI.place(medallion, icon, Vector2(34, 34))


func _add_chip(text: String, pos: Vector2, height: float) -> void:
	var chip := Control.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, chip, pos, Vector2(300, height))
	UI.fill(chip, ChunkyRect.panel(Tokens.BG_CARD, 12.0, Tokens.BORDER, 2.0))
	var inner := UI.margin(12, 9)
	UI.fill(chip, inner)
	var row := UI.hbox(9)
	inner.add_child(row)
	var check := Icons.rect("check", 15, Tokens.GREEN_GRAD_TOP, 2.6)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(check)
	var label := UI.wrap(UI.body(text, 10, Tokens.white(0.7)))
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.custom_minimum_size = Vector2(252, 0)
	row.add_child(label)


func _add_os_dialog() -> void:
	var dialog := Control.new()
	UI.place(self, dialog, Vector2(66, 512), Vector2(270, 152))
	var card := ChunkyRect.panel(_OS_BG, 16.0)
	# Approximates the mock's soft drop shadow (0 12px 30px black .5).
	card.glow_color = Color(0, 0, 0, 0.4)
	card.glow_size = 14.0
	UI.fill(dialog, card)

	var title := UI.centered(UI.wrap(UI.body(Catalog.COPY["location_os_title"],
		12, _OS_TEXT, 800)))
	UI.place(dialog, title, Vector2(14, 14), Vector2(242, 34))

	var sub := UI.centered(UI.body(Catalog.COPY["location_os_body"], 10,
		_OS_MUTED, 600))
	UI.place(dialog, sub, Vector2(14, 53), Vector2(242, 14))

	_add_divider(dialog, 79.0)
	var allow := BaseButton.new()
	UI.place(dialog, allow, Vector2(14, 80), Vector2(242, 33))
	var allow_label := UI.centered(UI.body(Catalog.COPY["location_os_allow"],
		12, _OS_LINK))
	allow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(allow, allow_label)
	allow.pressed.connect(func() -> void: Router.go("notification_permission"))

	_add_divider(dialog, 113.0)
	var deny := UI.centered(UI.body(Catalog.COPY["location_os_deny"], 12,
		_OS_LINK, 600))
	deny.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.place(dialog, deny, Vector2(14, 114), Vector2(242, 29))


func _add_divider(dialog: Control, y: float) -> void:
	var line := ColorRect.new()
	line.color = _OS_DIVIDER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(dialog, line, Vector2(14, y), Vector2(242, 1))
