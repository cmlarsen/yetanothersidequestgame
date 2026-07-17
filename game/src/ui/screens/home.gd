extends Screen
## Home / pre-run (mock chunk 06): header, live map preview card, START RUN,
## daily quests, party row, bottom nav.

# Chunk-06 one-off colors.
const _CHIP_SCRIM := Color(16.0 / 255.0, 22.0 / 255.0, 34.0 / 255.0, 0.9)
const _MOB_CHIP_BG := Color(Tokens.RARITY_EPIC_BOTTOM, 0.92)

const _MAP_POS := Vector2(14, 129)
const _MAP_SIZE := Vector2(374, 155)


func build() -> void:
	add_bg(Tokens.BG_SCREEN)
	_build_header()
	_build_map_card()

	var start := ChunkyButton.make("START RUN", "cta_cyan", Vector2(374, 54), 18)
	UI.place(self, start, Vector2(14, 296))
	start.pressed.connect(func() -> void: Router.go("exploration"))

	_build_quests()
	_build_party()

	var nav := BottomNav.make("home")
	UI.place(self, nav, Vector2(0, DESIGN_SIZE.y - BottomNav.HEIGHT))
	nav.tab_selected.connect(_on_tab)


func _build_header() -> void:
	UI.place(self, AvatarFace.make(GameState.character_id, 49, Tokens.CYAN, 2.5),
		Vector2(16, 66))
	var name_row := UI.hbox(5)
	name_row.add_child(UI.display(GameState.player_name, 14))
	name_row.add_child(UI.display("LV %d" % GameState.level, 14, Tokens.CYAN))
	UI.place(self, name_row, Vector2(74, 76))
	var xp := HBar.bar(110, 6, Tokens.CYAN, Tokens.GREEN_GRAD_TOP, 4.0,
		GameState.xp / GameState.xp_next)
	UI.place(self, xp, Vector2(74, 99))

	var gold := CurrencyPill.gold(GameState.gold)
	UI.place(self, gold,
		Vector2(386.0 - gold.custom_minimum_size.x,
			66.0 + (49.0 - gold.custom_minimum_size.y) / 2.0))


func _build_map_card() -> void:
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, card, _MAP_POS, _MAP_SIZE)

	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(card, clip, Vector2(3, 3), _MAP_SIZE - Vector2(6, 6))
	var grass := ColorRect.new()
	grass.color = Tokens.MAP_GRASS
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(clip, grass)
	# Live-ish neighborhood peek: preset A cropped to the band around the
	# contested ring / gloom edge (map coords ~y 265–420).
	var map := HexGridMap.preset_a()
	var road: Array[Dictionary] = [{
		"points": PackedVector2Array([Vector2(60, 430), Vector2(140, 380),
			Vector2(230, 360), Vector2(330, 300), Vector2(420, 280)]),
		"width": 20.0,
	}]
	map.paths = road
	var tree_spots: Array[Vector2] = [Vector2(70, 300), Vector2(320, 400)]
	map.trees = tree_spots
	UI.place(clip, map, Vector2(-16, -265), Screen.DESIGN_SIZE)

	# clip_contents is rectangular; patch the corners back to the screen bg so
	# the map respects the card's 20px radius.
	var mask := CornerMask.new()
	mask.radius = 20.0
	mask.color = Tokens.BG_SCREEN
	UI.fill(card, mask)
	var border := ChunkyRect.new()
	border.fill_top = Color(0, 0, 0, 0)
	border.border_color = Tokens.BORDER
	border.border_width = 2.5
	border.corner_radius = 20.0
	UI.fill(card, border)

	var front: Dictionary = GameState.fronts[0]
	var front_chip := Chip.make("%s · %d%% YOURS" % [String(front["name"]).to_upper(),
		int(front["pct_player"])], {
		"text_color": Tokens.CYAN_LIGHT, "bg": _CHIP_SCRIM, "border_w": 0.0,
		"radius": 9.0, "pad_h": 9.0, "pad_v": 4.0,
	})
	UI.place(card, front_chip, Vector2(12, 12))
	var mob_chip := Chip.make("%d MOBS ACTIVE" % GameState.mobs_active, {
		"bg": _MOB_CHIP_BG, "border_w": 0.0, "radius": 9.0, "pad_h": 9.0, "pad_v": 4.0,
	})
	UI.place(card, mob_chip,
		Vector2(_MAP_SIZE.x - 12.0 - mob_chip.custom_minimum_size.x, 12))


func _build_quests() -> void:
	var daily: Array[Dictionary] = []
	var active := 0
	for q in GameState.quests:
		var cat := Catalog.quest(String(q["id"]))
		if String(cat.get("tab", "")) != "daily":
			continue
		daily.append(q)
		if String(q.get("state", "")) == "active":
			active += 1
	UI.place(self, UI.micro("DAILY QUESTS · %d ACTIVE" % active, 9, Tokens.white(0.4)),
		Vector2(16, 370))
	var y := 390.0
	for q in daily:
		_quest_row(q, y)
		y += 55.0


func _quest_row(q: Dictionary, y: float) -> void:
	var cat := Catalog.quest(String(q["id"]))
	var btn := BaseButton.new()
	UI.place(self, btn, Vector2(14, y), Vector2(374, 48))
	UI.fill(btn, ChunkyRect.panel(Tokens.BG_CARD, 12.0, Tokens.BORDER, 2.0))
	UI.place(btn, UI.body(String(cat["objective"]), 11, Color.WHITE, 700), Vector2(12, 7))
	var progress := int(q["progress"])
	var target := int(cat["target"])
	var counter := UI.micro("%s / %s" % [Rules.fmt_thousands(progress),
		Rules.fmt_thousands(target)], 9, Tokens.white(0.5))
	btn.add_child(counter)
	counter.position = Vector2(362.0 - counter.get_minimum_size().x,
		(48.0 - counter.get_minimum_size().y) / 2.0)
	var bar := StatBarChunky.make(270, 7, Tokens.GREEN_GRAD_BOTTOM,
		Tokens.GREEN_GRAD_BOTTOM, Tokens.BG_INSET, 3.5)
	bar.set_ratio(float(progress) / float(target))
	UI.place(btn, bar, Vector2(12, 28))
	btn.pressed.connect(func() -> void: Router.go("quest_board"))


func _build_party() -> void:
	UI.place(self, UI.micro("PARTY", 9, Tokens.white(0.4)), Vector2(16, 511))
	var btn := BaseButton.new()
	UI.place(self, btn, Vector2(14, 531), Vector2(374, 56))
	UI.fill(btn, ChunkyRect.panel(Tokens.BG_CARD, 12.0, Tokens.BORDER, 2.0))
	var others: Array[Dictionary] = []
	for m in GameState.party:
		if not bool(m.get("is_self", false)):
			others.append(m)
	var x := 12.0
	for m in others:
		UI.place(btn, AvatarFace.make(String(m["face"]), 38, Tokens.BG_CARD, 2.0),
			Vector2(x, 9))
		x += 28.0
	# Mixed-case display names + the "is online" phrasing aren't derivable from
	# GameState.party (uppercase names, in_combat status) — chunk 06 copy.
	var status := UI.hbox(0)
	status.add_child(UI.body("Britt is online", 11, Tokens.GREEN_GRAD_TOP, 700))
	status.add_child(UI.body(" · MageMike offline", 11, Tokens.white(0.7), 700))
	btn.add_child(status)
	status.position = Vector2(x + 20.0, 20.0)
	var view := UI.micro("VIEW", 9, Tokens.CYAN)
	btn.add_child(view)
	view.position = Vector2(362.0 - view.get_minimum_size().x,
		(56.0 - view.get_minimum_size().y) / 2.0)
	btn.pressed.connect(func() -> void: Router.go("party"))


func _on_tab(id: String) -> void:
	match id:
		"map":
			Router.go("exploration")
		"party":
			Router.go("party")
		"items":
			Router.go("paper_doll")
		"more":
			Router.go("settings")


## Horizontal-gradient XP bar (kit StatBarChunky gradients run vertically).
class HBar:
	extends Control

	var ratio: float = 1.0
	var color_from: Color
	var color_to: Color
	var bg: Color = Tokens.BG_INSET
	var radius: float = 4.0

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


## Paints the four corner slivers outside a rounded rect (rectangular
## clip_contents can't round the live-map crop).
class CornerMask:
	extends Control

	var radius: float = 20.0
	var color: Color = Tokens.BG_SCREEN

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var r := radius
		var corners: Array[Array] = [
			[Vector2(0, 0), Vector2(r, r), PI],
			[Vector2(size.x, 0), Vector2(size.x - r, r), PI * 1.5],
			[Vector2(size.x, size.y), Vector2(size.x - r, size.y - r), 0.0],
			[Vector2(0, size.y), Vector2(r, size.y - r), PI * 0.5],
		]
		for c in corners:
			var pts := PackedVector2Array()
			pts.append(c[0])
			for i in 9:
				var a: float = float(c[2]) + (PI / 2.0) * (float(i) / 8.0)
				pts.append((c[1] as Vector2) + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, color)
