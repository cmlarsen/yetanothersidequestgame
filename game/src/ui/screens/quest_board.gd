extends Screen
## Quest board (mock 13): rotated header, DAILY/STORY/TERRITORY tabs,
## parchment quest cards (pin dot, progress bar, gold reward, DONE! stamp on
## the claimable one), dashed reset slot, CLAIM REWARD CTA.

# Mock-only colors (not tokens).
const _TITLE_SHADOW := Color("#1a5a6e")
const _TAG_TEXT := Color("#8a6b1a")
const _REWARD_TEXT := Color("#8a5a08")
const _PIN_BLUE_BORDER := Color("#1a5a8e")
const _PIN_GREEN_BORDER := Color("#3a7a28")

const _CARD_X := 14.0
const _CARD_W := 374.0
const _CARD_H := 84.0
const _CARD_H_CLAIMABLE := 78.0

var _holder: Control
var _progress: Dictionary = {}


func build() -> void:
	add_bg(Tokens.BG_SCREEN)
	for q: Dictionary in GameState.quests:
		_progress[q["id"]] = q

	var title := UI.shadowed(UI.display("QUEST BOARD", 28), _TITLE_SHADOW, 3)
	add_child(title)
	var ms := title.get_combined_minimum_size()
	title.position = Vector2(201.0 - ms.x / 2.0, 76.0)
	title.pivot_offset = ms * 0.5
	title.rotation_degrees = -1.0
	# Screen-chrome subtitle; not in Catalog copy tables.
	UI.place_centered_x(self,
		UI.body("Daily, story, and territory quests", 10, Tokens.white(0.5), 700), 112.0)

	var tab_names: Array[String] = ["DAILY", "STORY", "TERRITORY"]
	var tabs := TabRow.make(tab_names, 0)
	UI.place_centered_x(self, tabs, 133.0)
	tabs.tab_changed.connect(_rebuild)

	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(self, _holder)
	_rebuild(0)

	var claim_gold := 0
	for q: Dictionary in GameState.quests:
		if q["state"] == "claimable":
			claim_gold = Catalog.quest(q["id"])["reward_gold"]
	var claim := ChunkyButton.make("CLAIM REWARD · %d GOLD" % claim_gold, "cta_green",
		Vector2(_CARD_W, 50), 16)
	UI.place(self, claim, Vector2(_CARD_X, 797))
	claim.pressed.connect(func() -> void:
		if not GameState.is_live:
			return
		for q: Dictionary in GameState.quests:
			if String(q.get("state", "")) == "claimable":
				NetClient.send_op(int(ServerProtocol.OP.QUEST_CLAIM),
					{"questId": String(q["id"])}))


func _rebuild(tab: int) -> void:
	for c in _holder.get_children():
		c.queue_free()
	match tab:
		0:
			_add_card("daily_walk", 312.0, -1.0, "center")
			_add_card("daily_defeat", 411.0, 0.8, "left")
			_add_reset_slot(510.0)
			_add_card("territory_elm", 575.0, -0.6, "right")
		1:
			_add_card("story_grumble_park", 312.0, -1.0, "center")
		2:
			_add_card("territory_elm", 312.0, -0.6, "right")


func _add_card(quest_id: String, y: float, rot_deg: float, pin_align: String) -> void:
	var quest := Catalog.quest(quest_id)
	var entry: Dictionary = _progress.get(quest_id, {})
	var claimable: bool = entry.get("state", "") == "claimable"
	# Story quest has no GameState.quests entry yet — renders at 0 progress.
	var progress: int = entry.get("progress", 0)
	var target: int = quest["target"]
	var h := _CARD_H_CLAIMABLE if claimable else _CARD_H

	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(_holder, card, Vector2(_CARD_X, y), Vector2(_CARD_W, h))
	card.pivot_offset = Vector2(_CARD_W, h) * 0.5
	card.rotation_degrees = rot_deg
	if claimable:
		card.modulate.a = 0.92
	UI.fill(card, Parchment.make())

	var pin_x := _CARD_W / 2.0 - 7.0
	match pin_align:
		"left":
			pin_x = 26.0
		"right":
			pin_x = _CARD_W - 30.0 - 14.0
	card.add_child(_pin(quest["pin"], Vector2(pin_x, -6.0)))

	var top := 10.0 if claimable else 13.0
	UI.place(card, UI.display(quest["title"], 15, Tokens.ON_PARCHMENT), Vector2(14, top))
	var tag := UI.micro(quest["tab"], 9, _TAG_TEXT)
	card.add_child(tag)
	tag.position = Vector2(_CARD_W - 14.0 - tag.get_combined_minimum_size().x, top + 6.0)
	UI.place(card, UI.body(quest["flavor"], 10, Tokens.ON_PARCHMENT_MUTED, 700),
		Vector2(14, top + 21.0))

	var bar_y := top + 45.0
	var bar := StatBarChunky.make(110, 9, Tokens.GREEN_GRAD_BOTTOM, Tokens.GREEN_GRAD_BOTTOM,
		Color(Tokens.ON_PARCHMENT, 0.25), 6.0)
	bar.set_ratio(float(progress) / float(target))
	UI.place(card, bar, Vector2(14, bar_y))
	var fraction := UI.hbox(4)
	fraction.add_child(UI.body("%s / %s" % [Rules.fmt_thousands(progress),
		Rules.fmt_thousands(target)], 9,
		Tokens.GREEN_GRAD_BOTTOM if claimable else Tokens.ON_PARCHMENT_MUTED, 800))
	if claimable:
		# "✓" glyph via icon (parchment text fonts lack it).
		var check := Icons.rect("check", 10, Tokens.GREEN_GRAD_BOTTOM)
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fraction.add_child(check)
	UI.place(card, fraction, Vector2(132, bar_y - 3.0))

	if claimable:
		_add_stamp(card)
	else:
		var reward := UI.hbox(4)
		var coin := _coin(11.0, 1.5)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		reward.add_child(coin)
		reward.add_child(UI.display(str(quest["reward_gold"]), 11, _REWARD_TEXT))
		card.add_child(reward)
		var rw := reward.get_combined_minimum_size()
		reward.position = Vector2(_CARD_W - 14.0 - rw.x, bar_y - 4.0)


func _pin(kind: String, pos: Vector2) -> Control:
	var fill := Tokens.RED_GRAD_BOTTOM
	var border := Tokens.RED_SHADOW
	match kind:
		"blue":
			fill = Tokens.MAP_WATER
			border = _PIN_BLUE_BORDER
		"green":
			fill = Tokens.GREEN_GRAD_TOP
			border = _PIN_GREEN_BORDER
		"gold":
			fill = Tokens.GOLD_GRAD_TOP
			border = Tokens.GOLD_BORDER
	var dot := Control.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.position = pos
	dot.size = Vector2(14, 14)
	UI.fill(dot, ChunkyRect.panel(fill, 7.0, border, 2.0))
	return dot


func _add_stamp(card: Control) -> void:
	# Attach before measuring: detached labels resolve the default theme font.
	var stamp := Control.new()
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(stamp)
	var label := UI.display("DONE!", 14, Tokens.GREEN_GRAD_BOTTOM)
	stamp.add_child(label)
	var ms := label.get_combined_minimum_size()
	stamp.size = ms + Vector2(26, 10)
	label.position = (stamp.size - ms) * 0.5
	var box := ChunkyRect.new()
	box.fill_top = Color(0, 0, 0, 0)
	box.border_color = Tokens.GREEN_GRAD_BOTTOM
	box.border_width = 3.0
	box.corner_radius = 8.0
	UI.fill(stamp, box)
	stamp.move_child(box, 0)
	stamp.position = Vector2(_CARD_W - 12.0 - stamp.size.x, 34.0)
	stamp.pivot_offset = stamp.size * 0.5
	stamp.rotation_degrees = -12.0
	stamp.modulate.a = 0.9


func _add_reset_slot(y: float) -> void:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(_holder, slot, Vector2(_CARD_X, y), Vector2(_CARD_W, 49))
	var box := ChunkyRect.new()
	box.fill_top = Color(0, 0, 0, 0)
	box.border_color = Tokens.BORDER
	box.border_width = 2.0
	box.corner_radius = 14.0
	box.dashed = true
	UI.fill(slot, box)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(slot, center)
	var row := UI.hbox(8)
	center.add_child(row)
	var clock := Icons.rect("clock", 15, Tokens.SLOT_BORDER)
	clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(clock)
	row.add_child(UI.body("New quests in %s" % GameState.quest_reset_label, 10,
		Tokens.SLOT_BORDER, 800))


static func _coin(d: float, border_w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(d, d)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := ChunkyRect.new()
	r.with_gradient(Tokens.RARITY_LEGENDARY_TOP, Tokens.GOLD_GRAD_BOTTOM)
	r.corner_radius = d / 2.0
	r.border_color = Tokens.GOLD_BORDER
	r.border_width = border_w
	UI.fill(c, r)
	return c
