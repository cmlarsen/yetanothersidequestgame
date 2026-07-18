extends Screen
## Chunk 16 "Victory": grayed tipped mob, cyan claim ring, gold VICTORY!
## display + claim chip, staggered +XP/+GOLD floats, ticking front meter,
## CONTINUE back to exploration. Data: GameState.victory / party / front.

# One-off mock colors (not in the token sheet).
const _OVERLAY_DARK := Color("#101622")
const _CHIP_BG := Color("#0e2a33")
const _TITLE_SHADOW := Color("#8a5a08")
const _XP_SHADOW := Color("#1a4a10")
const _GOLD_SHADOW := Color("#7a4a05")
const _CYAN_BAR_BOTTOM := Color("#2bb8d8")
const _GLOOM_BAR_TOP := Color("#a678ec")
const _DEFEATED_TAG_BG := Color(20.0 / 255.0, 20.0 / 255.0, 25.0 / 255.0, 0.7)
const _GRAY_TOP := Color("#8a8a95")
const _GRAY_BOTTOM := Color("#4a4a55")
const _GRAY_BORDER := Color("#333333")
const _GRAY_ICON := Color("#dddddd")


func build() -> void:
	add_bg(Tokens.MAP_GRASS)
	_add_map()
	_add_defeated_mob()
	_add_headline()
	_add_floats()
	_add_front_meter()
	var btn := ChunkyButton.make("CONTINUE", "cta_cyan", Vector2(300, 47), 15)
	UI.place(self, btn, Vector2(51, 767))
	btn.pressed.connect(func() -> void: Router.go("exploration"))


func _add_map() -> void:
	# Mock road here has no dark edge and sits under the hex lines, so it is a
	# local decor layer instead of HexGridMap.paths (which adds an edge, over).
	var decor := _RoadDecor.new()
	decor.road = _bezier(Vector2(-20, 560), Vector2(100, 520), Vector2(220, 500),
		Vector2(420, 470), 26)
	UI.place(self, decor, Vector2.ZERO, DESIGN_SIZE)
	UI.place(self, HexGridMap.preset_b(), Vector2.ZERO, DESIGN_SIZE)


func _add_defeated_mob() -> void:
	var group := Control.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, group, Vector2.ZERO, DESIGN_SIZE)
	group.modulate = Tokens.white(0.55)
	# MobBlob is hardwired to the Gloomling purple; the tipped corpse needs the
	# mock's flat gray ramp, so it's a local redraw of the same shape.
	var blob := _GrayBlob.new()
	blob.pivot_offset = Vector2(42, 42)
	blob.rotation_degrees = 80.0
	UI.place(group, blob, Vector2(159, 391.5), Vector2(84, 84))
	UI.place_centered_x(group, _tag("DEFEATED", Tokens.white(0.6),
		_DEFEATED_TAG_BG), 466)
	var ring := RingPulse.make(88, Tokens.CYAN, 4.0)
	UI.place(self, ring, Vector2(201, 430) - ring.size / 2.0)


func _add_headline() -> void:
	var title := DamageFloat.make("VICTORY!", Tokens.GOLD_GRAD_TOP, 40, -2.0,
		_TITLE_SHADOW)
	UI.place_centered_x(self, title, 230)
	pop_in(title)
	# Claim chip wraps to two lines at the mock's min-content width (~204px).
	var chip := Control.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place_centered_x(self, chip, 286, Vector2(204, 44))
	chip.size = Vector2(204, 44)
	UI.fill(chip, ChunkyRect.panel(_CHIP_BG, 12.0, Tokens.CYAN, 2.0))
	var pad := UI.margin(16, 6)
	UI.fill(chip, pad)
	var line := UI.centered(UI.wrap(UI.display(
		String(GameState.victory.claim_line), 13, Tokens.CYAN_LIGHT)))
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pad.add_child(line)
	pop_in(chip, 0.25)


func _add_floats() -> void:
	var xp := DamageFloat.make("+%d XP" % int(GameState.victory.xp),
		Tokens.GREEN_GRAD_TOP, 22, -7.0, _XP_SHADOW)
	UI.place(self, xp, Vector2(262, 344))
	pop_in(xp, 0.4)
	var gold := DamageFloat.make("+%d GOLD" % int(GameState.victory.gold),
		Tokens.GOLD_GRAD_TOP, 22, 5.0, _GOLD_SHADOW)
	UI.place(self, gold, Vector2(96, 350))
	pop_in(gold, 0.55)


func _add_front_meter() -> void:
	var v: Dictionary = GameState.victory
	var plate := Control.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, plate, Vector2(12, 58), Vector2(378, 46))
	UI.fill(plate, ChunkyRect.panel(Color(_OVERLAY_DARK, 0.88), 14.0,
		Tokens.BORDER, 2.0))
	var pad := UI.margin(12, 8)
	UI.fill(plate, pad)
	var col := UI.vbox(5)
	pad.add_child(col)
	var row := UI.hbox(0)
	col.add_child(row)
	row.add_child(UI.micro("%s %d%% ▲" % [GameState.party_name, v.front_pct_player],
		9, Tokens.CYAN_LIGHT))
	row.add_child(UI.spacer())
	row.add_child(UI.micro(GameState.front_name, 9, Tokens.white(0.4)))
	row.add_child(UI.spacer())
	row.add_child(UI.micro("GLOOM %d%% ▼" % v.front_pct_gloom, 9,
		Tokens.GLOOM_LIGHT_ALT))
	var bar := Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(354, 12)
	col.add_child(bar)
	UI.fill(bar, ChunkyRect.panel(Tokens.BG_INSET, 7.0))
	var left := ChunkyRect.new().with_gradient(Tokens.CYAN_GRAD_TOP, _CYAN_BAR_BOTTOM)
	left.corner_radii = Vector4(7, 0, 0, 7)
	var lw := 354.0 * float(v.front_pct_player) / 100.0
	UI.place(bar, left, Vector2.ZERO, Vector2(lw, 12))
	var right := ChunkyRect.new().with_gradient(_GLOOM_BAR_TOP, Tokens.RARITY_EPIC_BOTTOM)
	right.corner_radii = Vector4(0, 7, 7, 0)
	var rw := 354.0 * float(v.front_pct_gloom) / 100.0
	UI.place(bar, right, Vector2(354.0 - rw, 0), Vector2(rw, 12))


## Mock name-tag pill, sized from true font metrics (see combat.gd:_measured —
## Chip.make bakes the pre-tree inflated label width into its size).
static func _tag(text: String, text_color: Color, bg: Color) -> Control:
	var label := UI.micro(text, 9, text_color, 0)
	label.notification(Control.NOTIFICATION_THEME_CHANGED)
	var tag_size := label.get_minimum_size() + Vector2(16, 4)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = tag_size
	root.size = tag_size
	UI.fill(root, ChunkyRect.panel(bg, 7.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(root, label)
	return root


static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2,
		segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments + 1:
		out.append(p0.bezier_interpolate(p1, p2, p3, float(i) / segments))
	return out


## The defeated mob: MobBlob's radial-ish shading in the mock's gray ramp,
## no drop shadow (the corpse lies flat), #333 ring, pale plain-shroom icon.
class _GrayBlob:
	extends Control

	const _LAYERS := 24

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tr := Icons.rect("shroom_plain", 38, _GRAY_ICON)
		add_child(tr)
		tr.position = Vector2(23, 23)

	func _draw() -> void:
		var r := size.x / 2.0
		var c := size / 2.0
		var highlight := Vector2(size.x * 0.35, size.y * 0.30)
		for i in _LAYERS:
			var t := float(i) / float(_LAYERS - 1)
			draw_circle(c.lerp(highlight, t * 0.8), r * (1.0 - t * 0.85),
				_GRAY_BOTTOM.lerp(_GRAY_TOP, t))
		draw_arc(c, r - 2.0, 0.0, TAU, 64, _GRAY_BORDER, 4.0, true)


## Edge-less sand road drawn beneath the hex grid (mock layer order).
class _RoadDecor:
	extends Control

	var road: PackedVector2Array

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if road.size() < 2:
			return
		draw_polyline(road, Tokens.MAP_PATH, 40.0, true)
		for pt in road:
			draw_circle(pt, 20.0, Tokens.MAP_PATH)
