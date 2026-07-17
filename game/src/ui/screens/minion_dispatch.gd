extends Screen
## Screen 27 — minion dispatch. Mock chunk 27: MINIONS header + gold pill,
## rule line, roster rows (selected / on-job / dashed hire slot), job rows
## from Catalog.JOBS, SEND CTA + wall-clock footnote.

# One-off mock colors (not in Tokens).
const SELECT_BG := Color("#232c42")
const HIRE_BG := Color("#1b213080")  # rgba(27,33,48,.5)
const HIRE_PRICE := Color("#8a97b3")

const JOB_ORDER: Array[String] = ["gather_lumber", "scout_front", "scavenge"]

var _selected_minion := ""
var _selected_job: String = GameState.selected_job
var _job_rects: Dictionary = {}
var _minion_rects: Dictionary = {}
var _minion_tags: Dictionary = {}
var _send_label: Label
var _cta: ChunkyButton


func build() -> void:
	add_bg(Tokens.BG_SCREEN)
	for m in GameState.minions:
		if bool(m.get("selected", false)):
			_selected_minion = String(m["id"])

	var pad := UI.margin(14, 64, 14, 24)
	UI.fill(self, pad)
	var col := UI.vbox(9)
	pad.add_child(col)

	var head := UI.hbox(0)
	head.add_child(UI.display("MINIONS", 24))
	head.add_child(UI.spacer())
	var pill := _gold_pill(GameState.gold)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(pill)
	col.add_child(head)

	col.add_child(UI.wrap(UI.body(String(Catalog.COPY["minion_rule_line"]), 10,
		Tokens.white(0.5), 700)))

	for m in GameState.minions:
		col.add_child(_minion_row(m))
	col.add_child(_hire_row())

	_send_label = UI.micro(_send_on_text(), 9, Tokens.white(0.4))
	col.add_child(_send_label)

	for id in JOB_ORDER:
		col.add_child(_job_row(id))

	col.add_child(UI.spacer())

	var bottom := UI.vbox(7)
	_cta = ChunkyButton.make(_cta_text(), "cta_cyan", Vector2(0, 52), 15)
	# Dev shortcut: real jobs run on wall-clock time (~30 min); the shell jumps
	# straight to the return report.
	_cta.pressed.connect(func() -> void: Router.go("minion_report"))
	_cta.disabled = _selected_minion == "" or _selected_job == ""
	bottom.add_child(_cta)
	bottom.add_child(UI.centered(UI.body(String(Catalog.COPY["minion_footnote"]), 9,
		Tokens.white(0.4), 800)))
	col.add_child(bottom)


func _minion_row(m: Dictionary) -> Control:
	var id := String(m["id"])
	var info := Catalog.minion(id)
	var on_job := String(m["state"]) == "on_job"
	var selected := id == _selected_minion

	var b := BaseButton.new()
	b.custom_minimum_size = Vector2(0, 64)
	var rect := ChunkyRect.new()
	rect.corner_radius = 14.0
	rect.fill_top = Tokens.BG_CARD
	rect.border_width = 2.0
	if selected:
		rect.border_color = Tokens.CYAN
		rect.glow_color = Color(Tokens.CYAN, 0.3)
		rect.glow_size = 9.0
	else:
		rect.border_color = Tokens.BORDER
	UI.fill(b, rect)
	if not on_job:
		_minion_rects[id] = rect
		b.pressed.connect(_select_minion.bind(id))
	var pad := UI.margin(11, 9)
	UI.fill(b, pad)
	var row := UI.hbox(10)
	pad.add_child(row)

	var ring := Tokens.CYAN if selected else Tokens.SLOT_BORDER
	var face := AvatarFace.make(String(info["face"]), 44, ring, 2.5)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)

	var mid := UI.vbox(1)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(UI.body(String(info["name"]), 11, Color.WHITE, 700))
	mid.add_child(UI.wrap(UI.body(String(info["bio"]), 9, Tokens.white(0.45), 700)))
	row.add_child(mid)

	if on_job:
		var right := UI.vbox(4, BoxContainer.ALIGNMENT_CENTER)
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var status := UI.body("ON JOB · %s" % String(m["time_left"]), 9,
			Tokens.GOLD_GRAD_TOP, 800)
		status.size_flags_horizontal = Control.SIZE_SHRINK_END
		right.add_child(status)
		var bar := StatBarChunky.make(70, 6, Tokens.RARITY_LEGENDARY_TOP,
			Tokens.GOLD_GRAD_BOTTOM, Tokens.BG_INSET, 4.0)
		bar.set_ratio(float(m["progress"]))
		bar.size_flags_horizontal = Control.SIZE_SHRINK_END
		right.add_child(bar)
		row.add_child(right)
	elif selected:
		var tag := UI.body("SELECTED", 9, Tokens.CYAN, 800)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
		_minion_tags[id] = tag
	return b


func _hire_row() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(0, 64)
	var rect := ChunkyRect.new()
	rect.corner_radius = 14.0
	rect.fill_top = HIRE_BG
	rect.border_color = Tokens.SLOT_BORDER
	rect.border_width = 2.0
	rect.dashed = true
	UI.fill(root, rect)
	var pad := UI.margin(11, 9)
	UI.fill(root, pad)
	var row := UI.hbox(10)
	pad.add_child(row)

	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2(44, 44)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var circle := ChunkyRect.panel(Color(0, 0, 0, 0), 22.0, Tokens.SLOT_BORDER, 2.5)
	circle.dashed = true
	UI.fill(slot, circle)
	var plus := UI.centered(UI.display("+", 18, Tokens.SLOT_BORDER))
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(slot, plus)
	row.add_child(slot)

	var mid := UI.vbox(1)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(UI.body("Third roster slot", 11, Tokens.SLOT_BORDER, 700))
	mid.add_child(UI.body("Hire at the merchant", 9, Tokens.white(0.3), 700))
	row.add_child(mid)

	var price := UI.hbox(5)
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price.add_child(_Coin.new())
	price.add_child(UI.display(str(Rules.MINION_HIRE_COST), 11, HIRE_PRICE))
	row.add_child(price)
	return root


func _job_row(id: String) -> BaseButton:
	var j := Catalog.job(id)
	var b := BaseButton.new()
	b.custom_minimum_size = Vector2(0, 48)
	var rect := ChunkyRect.new()
	rect.corner_radius = 13.0
	UI.fill(b, rect)
	var pad := UI.margin(11, 9)
	UI.fill(b, pad)
	var row := UI.hbox(10)
	pad.add_child(row)

	var emoji := UI.body(String(j["emoji"]), 18)
	emoji.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(emoji)

	var mid := UI.vbox(1)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title := UI.hbox(4)
	title.add_child(UI.body(String(j["name"]), 11, Color.WHITE, 700))
	title.add_child(UI.body("· %s" % String(j["duration_label"]), 11, Tokens.white(0.4), 700))
	mid.add_child(title)
	mid.add_child(UI.body(String(j["output_line"]), 9, Tokens.white(0.5), 800))
	row.add_child(mid)

	if int(j.get("injury_pct", 0)) > 0:
		var risk := UI.body(String(j["risk_line"]), 8, Tokens.PINK_LIGHT, 800)
		risk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(risk)

	b.pressed.connect(_select_job.bind(id))
	_job_rects[id] = rect
	_style_job(id)
	return b


func _style_job(id: String) -> void:
	var rect: ChunkyRect = _job_rects[id]
	var on := id == _selected_job
	rect.fill_top = SELECT_BG if on else Tokens.BG_CARD
	rect.border_color = Tokens.CYAN if on else Tokens.BORDER
	rect.queue_redraw()


func _select_minion(id: String) -> void:
	if id == _selected_minion:
		return
	_selected_minion = id
	for k: String in _minion_rects:
		var rect: ChunkyRect = _minion_rects[k]
		var on := k == id
		rect.border_color = Tokens.CYAN if on else Tokens.BORDER
		rect.glow_color = Color(Tokens.CYAN, 0.3) if on else Color(0, 0, 0, 0)
		rect.glow_size = 9.0 if on else 0.0
		rect.queue_redraw()
		if _minion_tags.has(k):
			(_minion_tags[k] as Label).visible = on
	_send_label.text = _send_on_text()
	var label := _cta.get_child(1).get_child(0).get_child(0) as Label
	label.text = _cta_text()
	_cta.disabled = _selected_minion == "" or _selected_job == ""


func _select_job(id: String) -> void:
	if id == _selected_job:
		return
	_selected_job = id
	for k: String in _job_rects:
		_style_job(k)
	_send_label.text = _send_on_text()
	# ChunkyButton has no text setter; its content is rect → margin → row → label.
	var label := _cta.get_child(1).get_child(0).get_child(0) as Label
	label.text = _cta_text()


func _send_on_text() -> String:
	return "SEND %s ON…" % String(Catalog.minion(_selected_minion)["name"]).to_upper()


func _cta_text() -> String:
	return "SEND %s — %s" % [String(Catalog.minion(_selected_minion)["name"]).to_upper(),
		String(Catalog.job(_selected_job)["name"]).to_upper()]


func _gold_pill(amount: int) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(root, ChunkyRect.panel(Tokens.BG_CARD, 30.0, Tokens.BORDER, 2.0))
	var content := UI.margin(11, 5)
	UI.fill(root, content)
	var row := UI.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	content.add_child(row)
	row.add_child(_Coin.new())
	row.add_child(UI.display(Rules.fmt_thousands(amount), 12, Tokens.GOLD_GRAD_TOP))
	# Pre-tree label measures use the 16px default font (theme overrides don't
	# resolve outside the tree); remeasure once the tree settles.
	(func() -> void:
		root.custom_minimum_size = row.get_combined_minimum_size() + Vector2(22, 10)
	).call_deferred()
	return root


class _Coin:
	extends Control
	## 13px gold coin (mock: radial #ffe27a → #f2a92e disc, 1.5px #9c6b12 rim).

	const LAYERS := 10

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(13, 13)

	func _draw() -> void:
		var r := size.x / 2.0
		var c := size / 2.0
		var highlight := Vector2(size.x * 0.35, size.y * 0.30)
		for i in LAYERS:
			var t := float(i) / float(LAYERS - 1)
			var col := Tokens.GOLD_GRAD_BOTTOM.lerp(Tokens.RARITY_LEGENDARY_TOP, t)
			draw_circle(c.lerp(highlight, t * 0.7), r * (1.0 - t * 0.8), col)
		draw_arc(c, r - 0.75, 0.0, TAU, 32, Tokens.GOLD_BORDER, 1.5, true)
