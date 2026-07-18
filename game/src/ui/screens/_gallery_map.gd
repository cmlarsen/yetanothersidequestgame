extends Screen
## Off-registry component gallery for the map/combat kit: HexGridMap preset A
## with decorations up top; avatar faces, mob blob, ring pulses, and every
## hot-bar slot state below. Shoot route "_gallery_map" to review.


func build() -> void:
	add_bg(Tokens.BG_SCREEN)
	_build_map_half()
	_build_kit_half()


func _build_map_half() -> void:
	var holder := Control.new()
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, holder, Vector2.ZERO, Vector2(402, 437))
	var grass := ColorRect.new()
	grass.color = Tokens.MAP_GRASS
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(holder, grass)
	var map := HexGridMap.preset_a()
	var road: Array[Dictionary] = [
		{"points": _bezier(Vector2(150, 470), Vector2(130, 330), Vector2(240, 250),
			Vector2(430, 170), 26), "width": 22.0},
	]
	map.paths = road
	var tree_spots: Array[Vector2] = [
		Vector2(58, 330), Vector2(84, 352), Vector2(300, 120), Vector2(330, 96),
	]
	map.trees = tree_spots
	var ponds: Array[Dictionary] = [{"center": Vector2(340, 370), "radius": 44.0}]
	map.water = ponds
	UI.place(holder, map, Vector2.ZERO, Screen.DESIGN_SIZE)


func _build_kit_half() -> void:
	UI.place(self, UI.micro("AVATAR FACE — RING · HP RING · STATUS DOT", 9,
		Tokens.white(0.4)), Vector2(16, 448))
	var plain := AvatarFace.make("knight", 56, Color.WHITE, 3.5)
	UI.place(self, plain, Vector2(20, 470))
	var hp_high := AvatarFace.make("huntress", 56, Color.WHITE, 2.5)
	hp_high.set_hp_ring(0.76, Tokens.GREEN_GRAD_TOP)
	UI.place(self, hp_high, Vector2(96, 470))
	var hp_low := AvatarFace.make("dwarf", 56, Color.WHITE, 2.5)
	hp_low.set_hp_ring(0.34, Tokens.WARNING)
	hp_low.add_status_dot(Tokens.PINK)
	UI.place(self, hp_low, Vector2(172, 470))
	var ringed := AvatarFace.make("mage", 56, Tokens.CYAN, 3.0)
	ringed.add_status_dot(Tokens.GREEN_GRAD_TOP)
	UI.place(self, ringed, Vector2(248, 470))

	UI.place(self, UI.micro("MOB BLOB + RING PULSE", 9, Tokens.white(0.4)),
		Vector2(16, 552))
	var contested := RingPulse.make(56, Tokens.WARNING, 4.0, true)
	UI.place(self, contested, Vector2(90.0 - contested.size.x / 2.0, 630.0 - contested.size.y / 2.0))
	var boss := MobBlob.make(84)
	UI.place(self, boss, Vector2(48, 588))
	var halo := RingPulse.make(46, Color.WHITE, 3.0)
	UI.place(self, halo, Vector2(230.0 - halo.size.x / 2.0, 630.0 - halo.size.y / 2.0))
	var minion := MobBlob.make(56)
	UI.place(self, minion, Vector2(202, 602))
	var cyan_ring := RingPulse.make(30, Tokens.CYAN, 3.0, true)
	UI.place(self, cyan_ring, Vector2(330.0 - cyan_ring.size.x / 2.0, 630.0 - cyan_ring.size.y / 2.0))

	UI.place(self, UI.micro("HOT BAR — READY · COOLDOWN · BADGE · CHARGES · LOCKED · EMPTY",
		8, Tokens.white(0.4)), Vector2(16, 706))
	var row := UI.hbox(6)
	var slots: Array[Dictionary] = [
		{"icon": "sword_slash", "label": "BONK HAMMER", "glow": Tokens.RARITY_RARE},
		{"icon": "bolt", "icon_color": Tokens.RARITY_LEGENDARY_TOP, "label": "ZAP SCROLL",
			"state": "cooldown", "cooldown_left": 4.1},
		{"icon": "shield", "label": "TURTLE UP", "badge": "×2 CRACK!",
			"badge_bg": Tokens.WARNING, "badge_color": Tokens.ON_GOLD},
		{"emoji": "🧪", "label": "FIZZY MENDER", "charges": 3},
		{"icon": "wand", "label": "SEALED", "state": "locked"},
		{"state": "empty", "label": "EMPTY"},
	]
	for cfg in slots:
		row.add_child(HotBarSlot.make(cfg))
	UI.place_centered_x(self, row, 736)


static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2,
		segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments + 1:
		out.append(p0.bezier_interpolate(p1, p2, p3, float(i) / segments))
	return out
