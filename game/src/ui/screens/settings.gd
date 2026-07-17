extends Screen
## Chunk 23 — Settings. Section cards: LOCATION & BATTERY (GPS HIGH/SAVER
## segmented + screen-off steps toggle), SAFETY (speed pause, reduced motion),
## NOTIFICATIONS (3 toggles), ACCOUNT (avatar + gamertag + MANAGE), legal
## footer. Toggle state is in-memory only (writes back to GameState.settings).

# One-off mock colors (no token equivalents).
const _ON_SEG := Color("#082530")

const _X := 14.0
const _W := 374.0

var _seg_rects: Array[ChunkyRect] = []
var _seg_labels: Array[Label] = []


func build() -> void:
	add_bg(Tokens.BG_SCREEN)
	# Row copy below is mock-pinned settings text with no Catalog/GameState
	# home (only values like the km/h threshold live in Rules).
	UI.place(self, UI.display("SETTINGS", 24, Color.WHITE), Vector2(_X + 2, 60))

	_section("LOCATION & BATTERY", 106)
	_row("GPS accuracy", "High uses more battery", _gps_segmented(), 128, 56)
	_row("Screen-off step tracking", "Counts steps toward quests while locked",
		_toggle("screen_off_steps"), 191, 56)

	_section("SAFETY", 259)
	_row("Pause when moving fast",
		"Auto-pauses claiming above %d km/h (driving)" % Rules.SPEED_PAUSE_KMH,
		_toggle("speed_pause"), 281, 56)
	_row("Reduced motion", "Calmer combat effects", _toggle("reduced_motion"), 344, 56)

	_section("NOTIFICATIONS", 411)
	_row("Territory under attack", "", _toggle("notif_attack"), 433, 52)
	_row("Chest nearby", "", _toggle("notif_chest"), 492, 52)
	_row("Party invites", "", _toggle("notif_party"), 551, 52)

	_section("ACCOUNT", 614)
	_account_row(636)

	UI.place_centered_x(self, UI.body(String(GameState.settings["footer"]), 9,
		Tokens.white(0.3), 600), 838)


func _section(text: String, y: float) -> void:
	UI.place(self, UI.micro(text, 10, Tokens.white(0.4)), Vector2(_X + 2, y))


func _row(title: String, sub: String, right: Control, y: float, height: float) -> void:
	var card := Control.new()
	UI.place(self, card, Vector2(_X, y), Vector2(_W, height))
	UI.fill(card, ChunkyRect.panel(Tokens.BG_CARD, 14.0, Tokens.BORDER, 2.0))
	var pad := UI.margin(13, 0)
	UI.fill(card, pad)
	var row := UI.hbox(11, BoxContainer.ALIGNMENT_CENTER)
	pad.add_child(row)
	var col := UI.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(UI.body(title, 12, Color.WHITE))
	if sub != "":
		col.add_child(UI.body(sub, 10, Tokens.white(0.45)))
	row.add_child(col)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)


func _toggle(key: String) -> ChunkyToggle:
	var t := ChunkyToggle.make(bool(GameState.settings[key]))
	t.toggled_changed.connect(func(on: bool) -> void: GameState.settings[key] = on)
	return t


func _gps_segmented() -> Control:
	var seg := UI.hbox(4)
	seg.mouse_filter = Control.MOUSE_FILTER_STOP
	var modes: Array[String] = ["high", "saver"]
	for i in 2:
		var b := BaseButton.new()
		var rect := ChunkyRect.new()
		rect.corner_radius = 8.0
		UI.fill(b, rect)
		var label := UI.centered(UI.display(modes[i].to_upper(), 10))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UI.fill(b, label)
		# Sized from real font metrics — pre-tree label measurements ignore
		# font overrides.
		b.custom_minimum_size = Vector2(Tokens.display_font().get_string_size(
			modes[i].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 20.0, 22.0)
		var mode := modes[i]
		b.pressed.connect(func() -> void: _set_gps(mode))
		seg.add_child(b)
		_seg_rects.append(rect)
		_seg_labels.append(label)
	_restyle_gps()
	return seg


func _set_gps(mode: String) -> void:
	GameState.settings["gps_mode"] = mode
	_restyle_gps()


func _restyle_gps() -> void:
	var active := 0 if String(GameState.settings["gps_mode"]) == "high" else 1
	for i in 2:
		var on := i == active
		_seg_rects[i].fill_top = Tokens.CYAN if on else Tokens.BG_INSET
		_seg_rects[i].queue_redraw()
		_seg_labels[i].add_theme_color_override("font_color",
			_ON_SEG if on else Tokens.TEXT_DIM)


func _account_row(y: float) -> void:
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, card, Vector2(_X, y), Vector2(_W, 62))
	UI.fill(card, ChunkyRect.panel(Tokens.BG_CARD, 14.0, Tokens.BORDER, 2.0))
	var pad := UI.margin(13, 0)
	UI.fill(card, pad)
	var row := UI.hbox(11, BoxContainer.ALIGNMENT_CENTER)
	pad.add_child(row)
	var face := AvatarFace.make(GameState.character_id, 36, Tokens.CYAN, 2.0)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)
	var col := UI.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(UI.body(String(GameState.settings["gamertag"]), 12, Color.WHITE))
	col.add_child(UI.body(String(GameState.settings["account_line"]), 10, Tokens.white(0.45)))
	row.add_child(col)
	# MANAGE is visual-only in v1 (no account management flow).
	var manage := UI.micro("MANAGE", 9, Tokens.CYAN)
	manage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(manage)
