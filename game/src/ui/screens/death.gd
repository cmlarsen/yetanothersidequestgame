extends Screen
## Chunk 18 "Death screen": dark red radial bg, stacked YOU WERE / DEFEATED
## display, fallen-character 3D region, tally chips, revive helper chip, and
## WAIT FOR REVIVE (live countdown) / RESPAWN AT HOME. Data: GameState.death.

# One-off mock colors (not in the token sheet).
const _BG_INNER := Color("#3a1a24")
const _BG_OUTER := Color("#12070c")
const _TITLE_SHADOW := Color("#5a0f28")
const _BOX_BORDER := Color("#7a4a58")
const _BOX_TEXT := Color("#b06a80")
const _CHIP_BORDER := Color("#3a2430")

var _wait_label: Label
var _seconds_left: int


func build() -> void:
	var bg := _RadialBg.new()
	UI.place(self, bg, Vector2.ZERO, DESIGN_SIZE)
	move_child(bg, 0)
	_add_headline()
	_add_render_region()
	_add_tally()
	_add_revive_chip()
	_add_buttons()


func _add_headline() -> void:
	# Fixed death copy exists nowhere in Catalog/GameState — pinned here.
	var l1 := DamageFloat.make("YOU WERE", Tokens.PINK, 40, -2.0, _TITLE_SHADOW)
	UI.place_centered_x(self, l1, 168)
	# Mock stacks the second line at margin-top:-8 for a deliberate overlap.
	var l2 := DamageFloat.make("DEFEATED", Color.WHITE, 46, -2.0, _TITLE_SHADOW)
	UI.place_centered_x(self, l2, 208)
	UI.place_centered_x(self, UI.body(String(GameState.death.cause_line), 12,
		Tokens.white(0.55), 700), 266)


func _add_render_region() -> void:
	# Placeholder3D's fixed white dressing doesn't match the mock's pink-tinted
	# box, so the region is rebuilt locally with the chunk's exact colors.
	var region := Control.new()
	region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, region, Vector2(126, 310), Vector2(150, 150))
	region.pivot_offset = Vector2(75, 75)
	region.rotation_degrees = 2.0
	var box := ChunkyRect.new()
	box.fill_top = Color(Tokens.PINK, 0.06)
	box.border_color = _BOX_BORDER
	box.border_width = 3.0
	box.corner_radius = 20.0
	box.dashed = true
	UI.fill(region, box)
	var label := UI.centered(UI.body("3D RENDER\n(knight, dramatically\nface-down)",
		9, _BOX_TEXT, 800))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(region, label)


func _add_tally() -> void:
	var d: Dictionary = GameState.death
	var row := UI.hbox(9)
	row.add_child(_tally_chip("+%d" % int(d.hexes_kept), Tokens.CYAN_LIGHT, "HEXES KEPT"))
	row.add_child(_tally_chip("-%d" % int(d.hexes_lost), Tokens.PINK, "HEXES LOST"))
	row.add_child(_tally_chip("-%d" % int(d.gold_dropped), Tokens.GOLD_GRAD_TOP,
		"GOLD DROPPED"))
	UI.place_centered_x(self, row, 486)


func _tally_chip(value: String, value_color: Color, label_text: String) -> Control:
	var value_label := _measured(UI.centered(UI.display(value, 17, value_color)))
	var micro := _measured(UI.centered(UI.micro(label_text, 8, Tokens.white(0.45), 0)))
	var w := maxf(value_label.get_minimum_size().x, micro.get_minimum_size().x) + 26.0
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(w, 51)
	UI.fill(root, ChunkyRect.panel(Color(Tokens.BG_CARD, 0.8), 13.0, _CHIP_BORDER, 2.0))
	var col := UI.vbox(0, BoxContainer.ALIGNMENT_CENTER)
	UI.fill(root, col)
	col.add_child(value_label)
	col.add_child(micro)
	return root


func _add_revive_chip() -> void:
	var d: Dictionary = GameState.death
	var face := AvatarFace.make(String(d.reviver_face), 30, Tokens.GREEN_GRAD_TOP, 2.0)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lead := _measured(UI.body("%s is %d m away" % [d.reviver, int(d.reviver_distance_m)],
		11, Tokens.GREEN_GRAD_TOP, 700))
	lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rest := _measured(UI.body(" and can revive you", 11, Color.WHITE, 700))
	rest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var text := UI.hbox(0)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_child(lead)
	text.add_child(rest)
	var content := UI.hbox(8)
	content.add_child(face)
	content.add_child(text)
	var min_size := content.get_combined_minimum_size()
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(min_size.x + 28.0, 48)
	UI.fill(root, ChunkyRect.panel(Color(Tokens.BG_CARD, 0.85), 14.0,
		Tokens.GREEN_GRAD_TOP, 2.0))
	var pad := UI.margin(14, 9)
	UI.fill(root, pad)
	pad.add_child(content)
	UI.place_centered_x(self, root, 568)


func _add_buttons() -> void:
	_seconds_left = int(GameState.death.countdown_sec)
	var wait := ChunkyButton.make(_wait_text(), "cta_green", Vector2(300, 47), 15)
	UI.place(self, wait, Vector2(51, 641))
	# The countdown ticks live; frozen shots keep the static GameState value.
	if not AppMode.freeze_motion:
		_wait_label = wait.find_children("", "Label", true, false)[0]
		var timer := Timer.new()
		timer.wait_time = 1.0
		timer.autostart = true
		add_child(timer)
		timer.timeout.connect(_tick)
	_add_respawn_button()


func _wait_text() -> String:
	return "WAIT FOR REVIVE · %s" % Rules.fmt_mmss(_seconds_left)


func _tick() -> void:
	_seconds_left = maxi(_seconds_left - 1, 0)
	_wait_label.text = _wait_text()


func _add_respawn_button() -> void:
	# Two-tone label (dim hex penalty) → local button instead of ChunkyButton.
	var b := BaseButton.new()
	UI.place(self, b, Vector2(51, 698), Vector2(300, 45))
	UI.fill(b, ChunkyRect.panel(Tokens.BG_CARD, 18.0, Tokens.BORDER, 2.0))
	var row := UI.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	UI.fill(b, row)
	var main := UI.display("RESPAWN AT HOME", 13, Tokens.white(0.75))
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(main)
	var penalty := UI.display("(-%d HEXES)" % int(GameState.death.hexes_lost), 13,
		Tokens.white(0.4))
	penalty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(penalty)
	b.pressed.connect(func() -> void:
		if GameState.is_live:
			# The wire RESPAWN carries no fields today; mode rides as a stripped
			# forward-compatible extra.
			NetClient.send_op(int(ServerProtocol.OP.RESPAWN), {"mode": "home"})
		Router.go("home"))


## Font overrides don't refresh a Label's min size until it enters the tree;
## force the theme pass so pre-layout measurements use the real metrics.
static func _measured(l: Label) -> Label:
	l.notification(Control.NOTIFICATION_THEME_CHANGED)
	return l


## Mock bg: radial-gradient(circle at 50% 30%, #3a1a24, #12070c 70%).
class _RadialBg:
	extends Control

	const _LAYERS := 28
	const _REACH := 450.0  # 70% of the farthest-corner distance

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), _BG_OUTER)
		var center := Vector2(size.x * 0.5, size.y * 0.3)
		for i in _LAYERS:
			var t := float(i) / float(_LAYERS - 1)
			draw_circle(center, _REACH * (1.0 - t), _BG_OUTER.lerp(_BG_INNER, t))
