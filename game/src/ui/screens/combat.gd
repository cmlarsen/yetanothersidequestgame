extends Screen
## SCREENS.md §15 "Real-time combat (Turf brawl)". The map is now a real 3D
## KayKit arena (BattleMap3D) the HUD draws over: boss plate + segmented HP top,
## bottom scrim + 5-slot hot bar, FLEE. Tap a slot to USE it (lunge + damage
## float, ticks the boss bar); HOLD a slot opens the Equip drawer — the mock had
## these swapped, so every action was opening the wrong menu.

const _OVERLAY_DARK := Color("#101622")
const _SCRIM := Color("#0a0e14")
const _PLATE_SHADOW := Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.5)
const _FLOAT_BIG_SHADOW := Color("#7a4a05")
const _FLOAT_CRIT_SHADOW := Color("#7a1030")
const _HEAL_SHADOW := Color("#1c5a2a")

# The mock's slot art diverges from Catalog icons for these two.
const _ICON_OVERRIDE := {"bonk_hammer": "sword_slash", "zap_scroll": "bolt"}
const _ICON_COLOR := {
	"zap_scroll": Tokens.RARITY_LEGENDARY_TOP,
	"fizzy_mender": Tokens.PINK_LIGHT,
}

# Hot bar: native 60px slots, FLEE round button bottom-left.
const _SLOT_TOP := 770.0
const _SLOT_X0 := 78.0
const _SLOT_STEP := 61.0
const _HOLD_S := 0.35
const _BOSS_HIT := 0.05  # boss HP ratio removed per damaging tap

var _map: BattleMap3D
var _boss_bar: SegmentedBar
var _boss_ratio := 0.58


func build() -> void:
	add_bg(Tokens.MAP_GRASS)
	_add_map()
	_add_scrim()
	_add_boss_plate()
	_add_hot_bar()
	_add_flee()


func _add_map() -> void:
	_boss_ratio = float(GameState.combat.get("boss_hp_ratio", 0.58))
	_map = BattleMap3D.new()
	_map.configure(GameState.character_id, String(GameState.combat.get("mob", "grumbleshroom")))
	UI.place(self, _map, Vector2.ZERO, DESIGN_SIZE)


func _add_scrim() -> void:
	var scrim := _Scrim.new()
	UI.place(self, scrim, Vector2(0, 704), Vector2(DESIGN_SIZE.x, 170))


func _add_boss_plate() -> void:
	var mob: Dictionary = Catalog.mob(String(GameState.combat.get("mob", "grumbleshroom")))
	if mob.is_empty():
		return
	var plate := Control.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, plate, Vector2(12, 58), Vector2(378, 62))
	UI.fill(plate, ChunkyRect.panel(Color(_OVERLAY_DARK, 0.9), 16.0,
		Tokens.GLOOM_BORDER_ALT, 2.0, _PLATE_SHADOW))
	var pad := UI.margin(14, 10)
	UI.fill(plate, pad)
	var col := UI.vbox(6)
	pad.add_child(col)
	var row := UI.hbox(0)
	col.add_child(row)
	row.add_child(UI.display(String(mob.name), 15, Tokens.GLOOM_LIGHT))
	row.add_child(UI.spacer())
	row.add_child(UI.micro("%s · LV %d" % [mob.title, mob.level], 10, Tokens.white(0.5)))
	_boss_bar = SegmentedBar.make(350, 16, int(mob.hp_segments),
		Tokens.RARITY_EPIC_TOP, Tokens.RARITY_EPIC_BOTTOM)
	_boss_bar.set_ratio(_boss_ratio)
	col.add_child(_boss_bar)


func _add_hot_bar() -> void:
	for i in Rules.HOTBAR_SLOTS:
		var entry: Dictionary = GameState.hotbar[i]
		var x := _SLOT_X0 + i * _SLOT_STEP
		var cfg := {}
		if entry.is_empty():
			cfg["state"] = "empty"
		else:
			var id := String(entry.item)
			var item: Dictionary = Catalog.item(id)
			cfg["label"] = String(item.name)
			cfg["icon"] = _ICON_OVERRIDE.get(id, String(item.icon))
			if _ICON_COLOR.has(id):
				cfg["icon_color"] = _ICON_COLOR[id]
			if entry.get("state", "ready") == "cooldown":
				cfg["state"] = "cooldown"
				cfg["cooldown_left"] = entry.cooldown_left
			if entry.has("charges"):
				cfg["charges"] = entry.charges
			if String(item.slot_type) == "weapon":
				cfg["glow"] = _rarity_color(String(item.rarity))
		var slot := HotBarSlot.make(cfg)
		UI.place(self, slot, Vector2(x, _SLOT_TOP))
		var btn := _SlotButton.new()
		UI.place(self, btn, Vector2(x, _SLOT_TOP), Vector2(HotBarSlot.SLOT_SIDE, 78.0))
		var idx := i
		btn.tapped.connect(func() -> void: _use_slot(idx))
		btn.held.connect(func() -> void: _open_equip(idx))


func _add_flee() -> void:
	var btn := BaseButton.new()
	UI.place(self, btn, Vector2(14, 772), Vector2(54, 54))
	var ring := ChunkyRect.panel(Color(_OVERLAY_DARK, 0.92), 27.0, Tokens.PINK, 2.0,
		_PLATE_SHADOW)
	UI.fill(btn, ring)
	var label := UI.micro("FLEE", 9, Tokens.PINK_LIGHT, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(btn, label)
	btn.pressed.connect(func() -> void: Router.back())


# ── Actions ──────────────────────────────────────────────────────────────────

## Tap: use the slot. Empty → open the drawer to fill it; weapon/spell → strike
## (lunge + damage float + boss-bar tick); consumable → heal float.
func _use_slot(i: int) -> void:
	var entry: Dictionary = GameState.hotbar[i]
	if entry.is_empty():
		_open_equip(i)
		return
	var item: Dictionary = Catalog.item(String(entry.item))
	var kind := String(item.get("slot_type", "weapon"))
	if kind == "consumable":
		_spawn_float("+HEAL", Tokens.GREEN_GRAD_TOP, 18, 5.0, _HEAL_SHADOW,
			Vector2(_map.size.x * 0.24, 560.0))
		return
	if _map != null:
		_map.player_attack()
	var crit := i % 3 == 2
	var dmg := 30 + i * 9 + (47 if crit else 0)
	var text := ("CRIT -%d!" % dmg) if crit else ("-%d" % dmg)
	var color := Tokens.PINK if crit else Tokens.WARNING
	var shadow := _FLOAT_CRIT_SHADOW if crit else _FLOAT_BIG_SHADOW
	_spawn_float(text, color, 26 if crit else 22, -6.0 if crit else -4.0, shadow,
		_map.mob_screen_pos() if _map != null else Vector2(200, 320))
	_damage_boss()


## Hold: open the Equip drawer for this slot (the mock's "hold any slot" gesture).
func _open_equip(i: int) -> void:
	GameState.equip_drawer["slot"] = i + 1
	Router.go("equip_drawer")


func _damage_boss() -> void:
	_boss_ratio = maxf(_boss_ratio - _BOSS_HIT, 0.0)
	if _boss_bar != null:
		_boss_bar.set_ratio(_boss_ratio)
	if _boss_ratio <= 0.0:
		Router.go("victory")


func _spawn_float(text: String, color: Color, font_size: int, rot: float,
		shadow: Color, at: Vector2) -> void:
	var f := DamageFloat.make(text, color, font_size, rot, shadow)
	add_child(f)
	f.position = at
	if AppMode.freeze_motion:
		return
	f.pivot_offset = Vector2(20, 10)
	f.scale = Vector2.ZERO
	var tw := f.create_tween()
	tw.tween_property(f, "scale", Vector2(1.15, 1.15), 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "scale", Vector2.ONE, 0.08)
	tw.parallel().tween_property(f, "position:y", at.y - 46.0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "modulate:a", 0.0, 0.28)
	tw.tween_callback(f.queue_free)


static func _rarity_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return Tokens.RARITY_RARE
		"epic":
			return Tokens.RARITY_EPIC_TOP
		"legendary":
			return Tokens.RARITY_LEGENDARY_TOP
	return Tokens.RARITY_COMMON


## Distinguishes a tap from a press-and-hold so tap uses the action while hold
## opens the equip drawer (SCREENS.md §15 "Hold any slot → Equip drawer").
class _SlotButton:
	extends BaseButton

	signal tapped
	signal held

	var _consumed := false
	var _gen := 0  # press generation, so a prior tap's timer can't fire a hold

	func _init() -> void:
		button_down.connect(_on_down)
		button_up.connect(_on_up)

	func _on_down() -> void:
		_consumed = false
		_gen += 1
		var g := _gen
		get_tree().create_timer(_HOLD_S).timeout.connect(
			func() -> void: _on_hold_elapsed(g))

	func _on_hold_elapsed(g: int) -> void:
		if g == _gen and is_inside_tree() and button_pressed and not _consumed:
			_consumed = true
			held.emit()

	func _on_up() -> void:
		if not _consumed:
			_consumed = true
			tapped.emit()


## Bottom gradient: transparent → 90% dark at 70% height, then solid.
class _Scrim:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var dark := Color(_SCRIM, 0.9)
		var clear := Color(_SCRIM, 0.0)
		var k := size.y * 0.7
		var quad := PackedVector2Array([
			Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, k), Vector2(0, k)])
		draw_polygon(quad, PackedColorArray([clear, clear, dark, dark]))
		draw_rect(Rect2(0, k, size.x, size.y - k), dark)
