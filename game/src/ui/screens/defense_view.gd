extends Screen
## Screen 25 — defense view (remote). Mock chunk 25: dark fog map (hexC) at
## 90% opacity, tower pins with durability conic rings, bobbing GLOOM PUSH
## marker, header + front meter, overnight digest, REPAIR ALL / FRONTS row.

# One-off mock colors (not in Tokens).
const SCREEN_BG := Color("#0e1420")
const HEADER_BG := Color("#101622eb")  # rgba(16,22,34,.92)
const DIGEST_BG := Color("#101622f0")  # rgba(16,22,34,.94)
const CYAN_BAR_BOTTOM := Color("#2bb8d8")  # front-meter cyan gradient bottom
const GLOOM_LABEL_BG := Color("#140a28d9")  # rgba(20,10,40,.85)

# Pin anchors are mock layout, not game data (one per GameState.towers entry).
const PIN_POINTS: Array[Vector2] = [Vector2(150, 540), Vector2(262, 600), Vector2(168, 652)]
const GLOOM_POINT := Vector2(238, 430)


func build() -> void:
	add_bg(SCREEN_BG)
	_build_map()
	_build_pins()
	_build_gloom_marker()
	_build_header()
	_build_bottom()


func _build_map() -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.modulate.a = 0.9
	UI.place(self, holder, Vector2.ZERO, DESIGN_SIZE)
	var panel_bg := ColorRect.new()
	panel_bg.color = Tokens.BG_PANEL
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(holder, panel_bg)
	UI.place(holder, HexGridMap.preset_c(), Vector2.ZERO)


func _build_pins() -> void:
	for i in GameState.towers.size():
		var tower: Dictionary = GameState.towers[i]
		var warning := bool(tower.get("warning", false))
		var pct := int(tower["durability_pct"])

		var b := BaseButton.new()
		UI.place(self, b, PIN_POINTS[i] - Vector2(65, 38), Vector2(130, 76))
		b.pressed.connect(func() -> void: Router.go("tower_manage"))
		var col := UI.vbox(3, BoxContainer.ALIGNMENT_CENTER)
		UI.fill(b, col)

		var ring := _DurabilityRing.new()
		ring.ratio = pct / 100.0
		ring.color = Tokens.WARNING if warning else Tokens.GREEN_GRAD_TOP
		ring.emoji = String(Catalog.tower(String(tower["type"]))["emoji"])
		ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(ring)

		var badge: Control
		if warning:
			badge = Chip.make("⚠️ %d%% — REPAIR" % pct, {
				"font": "body", "font_size": 9, "text_color": Color.WHITE,
				"bg": Tokens.RED_GRAD_BOTTOM, "border_w": 0.0,
				"radius": 8.0, "pad_h": 8.0, "pad_v": 2.0,
			})
		else:
			badge = Chip.make("%d%%" % pct, {
				"font": "body", "font_size": 9, "text_color": Tokens.GREEN_GRAD_TOP,
				"bg": HEADER_BG, "border_w": 0.0,
				"radius": 8.0, "pad_h": 8.0, "pad_v": 2.0,
			})
		_fit_chip(badge, 8.0, 2.0)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(badge)


func _build_gloom_marker() -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, holder, GLOOM_POINT - Vector2(45, 29), Vector2(90, 58))
	var col := UI.vbox(2, BoxContainer.ALIGNMENT_CENTER)
	UI.fill(holder, col)
	var blob := _GloomBlob.new()
	blob.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var e := UI.centered(UI.body("👾", 16, Color.WHITE))
	e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(blob, e)
	col.add_child(blob)
	var label := Chip.make("GLOOM PUSH", {
		"font": "body", "font_size": 8, "text_color": Tokens.GLOOM_LIGHT,
		"bg": GLOOM_LABEL_BG, "border_w": 0.0,
		"radius": 7.0, "pad_h": 7.0, "pad_v": 2.0,
	})
	_fit_chip(label, 7.0, 2.0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(label)
	bob(holder, 6.0, 2.0)


func _build_header() -> void:
	var front := GameState.front(String(GameState.towers[0]["front_id"]))

	var row := UI.hbox(0)
	UI.place(self, row, Vector2(12, 58), Vector2(378, 0))
	var title := Chip.make("DEFENSE — %s" % String(front["name"]).to_upper(), {
		"font": "display", "font_size": 13, "bg": HEADER_BG,
		"border": Tokens.BORDER, "border_w": 2.0, "radius": 14.0,
		"pad_h": 13.0, "pad_v": 7.0,
	})
	_fit_chip(title, 13.0, 7.0)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	row.add_child(UI.spacer())
	var remote := Chip.make(String(Catalog.COPY["remote_chip"]), {
		"emoji": "🛋️", "font": "body", "font_size": 9,
		"text_color": Tokens.CYAN_LIGHT, "bg": HEADER_BG,
		"border": Tokens.BORDER, "border_w": 2.0, "radius": 30.0,
		"pad_h": 12.0, "pad_v": 6.0,
	})
	_fit_chip(remote, 12.0, 6.0)
	remote.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(remote)

	_build_front_meter(front)


func _build_front_meter(front: Dictionary) -> void:
	var pct_player := int(front["pct_player"])
	var pct_gloom := int(front["pct_gloom"])

	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, panel, Vector2(12, 101), Vector2(378, 52))
	UI.fill(panel, ChunkyRect.panel(HEADER_BG, 14.0, Tokens.BORDER, 2.0))
	var pad := UI.margin(12, 8)
	UI.fill(panel, pad)
	var col := UI.vbox(5)
	pad.add_child(col)

	var labels := UI.hbox(0)
	labels.add_child(UI.body("CYAN %d%%" % pct_player, 9, Tokens.CYAN_LIGHT, 800))
	labels.add_child(UI.spacer())
	labels.add_child(UI.body("TERRITORY", 9, Tokens.white(0.4), 800))
	labels.add_child(UI.spacer())
	labels.add_child(UI.body("GLOOM %d%%" % pct_gloom, 9, Tokens.GLOOM_LIGHT_ALT, 800))
	col.add_child(labels)

	var bar := Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(0, 12)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI.fill(bar, ChunkyRect.panel(Tokens.BG_INSET, 7.0))
	var cyan := ChunkyRect.new().with_gradient(Tokens.CYAN_GRAD_TOP, CYAN_BAR_BOTTOM)
	cyan.corner_radii = Vector4(7, 0, 0, 7)
	UI.fill(bar, cyan)
	cyan.anchor_right = pct_player / 100.0
	var gloom := ChunkyRect.new().with_gradient(Color("#a678ec"), Tokens.RARITY_EPIC_BOTTOM)
	gloom.corner_radii = Vector4(0, 7, 7, 0)
	UI.fill(bar, gloom)
	gloom.anchor_left = 1.0 - pct_gloom / 100.0
	col.add_child(bar)


func _build_bottom() -> void:
	var digest := Control.new()
	digest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, digest, Vector2(12, 718), Vector2(378, 54))
	UI.fill(digest, ChunkyRect.panel(DIGEST_BG, 13.0, Tokens.GREEN_GRAD_TOP, 2.0))
	var pad := UI.margin(12, 9)
	UI.fill(digest, pad)
	var row := UI.hbox(9)
	pad.add_child(row)
	var moon := UI.body("🌙", 15)
	moon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(moon)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rt.add_theme_font_override("normal_font", Tokens.body_font(700))
	rt.add_theme_font_size_override("normal_font_size", 10)
	rt.add_theme_color_override("default_color", Tokens.white(0.8))
	var digest_data: Dictionary = GameState.defense_digest
	var hl := "%d Gloomlings" % int(digest_data["repelled"])
	rt.text = String(digest_data["line"]).replace(hl,
		"[color=#%s]%s[/color]" % [Tokens.GREEN_GRAD_TOP.to_html(false), hl])
	row.add_child(rt)

	var buttons := UI.hbox(8)
	UI.place(self, buttons, Vector2(12, 780), Vector2(378, 46))
	var repair := ChunkyButton.make("REPAIR ALL · 🪵 %d" % GameState.repair_all_cost,
		"cta_cyan", Vector2(0, 46), 13)
	repair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(repair)
	var fronts := ChunkyButton.make("FRONTS ▾", "secondary", Vector2(0, 46), 13)
	fronts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(fronts)


## Chip.make bakes its min size from a pre-tree measure, where the label's
## theme overrides don't resolve yet (falls back to the 16px default font), so
## chips come out too wide. Remeasure the content row once the tree settles.
static func _fit_chip(chip: Control, pad_h: float, pad_v: float) -> void:
	var row := chip.get_child(1).get_child(0) as Control
	(func() -> void:
		chip.custom_minimum_size = row.get_combined_minimum_size() \
			+ Vector2(pad_h, pad_v) * 2.0).call_deferred()


class _DurabilityRing:
	extends Control
	## Mock conic-gradient durability ring: colored wedge from 12 o'clock over a
	## depleted track, dark inner disc + border, centered tower emoji.

	const REST := Color("#26232f")

	var ratio := 1.0
	var color := Tokens.GREEN_GRAD_TOP
	var emoji := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(52, 52)

	func _ready() -> void:
		var e := UI.centered(UI.body(emoji, 18, Color.WHITE))
		e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UI.fill(self, e)

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, 26.0, REST)
		if ratio > 0.0:
			var steps := maxi(10, int(64.0 * ratio))
			var pts := PackedVector2Array([c])
			for s in steps + 1:
				var a := -PI / 2.0 + TAU * ratio * float(s) / steps
				pts.append(c + Vector2(cos(a), sin(a)) * 26.0)
			draw_colored_polygon(pts, color)
		draw_circle(c, 21.5, Tokens.BG_PANEL)
		draw_arc(c, 20.5, 0.0, TAU, 64, Tokens.BORDER, 2.0, true)


class _GloomBlob:
	extends Control
	## 40px Gloom marker: radial purple gradient + 2.5px border (MobBlob has a
	## fixed 4px border, shadow, and icon set — the mock marker differs).

	const LAYERS := 16

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(40, 40)

	func _draw() -> void:
		var r := size.x / 2.0
		var c := size / 2.0
		var highlight := Vector2(size.x * 0.35, size.y * 0.30)
		for i in LAYERS:
			var t := float(i) / float(LAYERS - 1)
			var col := Tokens.GLOOM_GRAD_BOTTOM.lerp(Tokens.GLOOM_GRAD_TOP, t)
			draw_circle(c.lerp(highlight, t * 0.8), r * (1.0 - t * 0.85), col)
		draw_arc(c, r - 1.25, 0.0, TAU, 64, Tokens.GLOOM_BORDER, 2.5, true)
