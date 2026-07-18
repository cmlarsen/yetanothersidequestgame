extends Screen
## Chunk 22 — Notification patterns. The mock is a 430px pattern board;
## recreated as a 402×874 screen: each pattern (in-app banner, success toast,
## OS push rows) stacked on BG_SCREEN under its micro-label. Copy from
## Catalog.ALERTS; every card deep-links to its route.

# One-off mock colors (no token equivalents).
const _CARD_BG := Color("#101622", 0.96)
const _SHADOW_DARK := Color("#080c14", 0.5)
const _PUSH_BG := Color("#f0f4fa", 0.96)
const _PUSH_TITLE := Color("#1a2130")
const _PUSH_TIME := Color("#6b7688")
const _PUSH_BODY := Color("#3a4353")

const _X := 16.0
const _W := 370.0


func build() -> void:
	add_bg(Tokens.BG_SCREEN)
	# Pattern-board annotations from the mock — dev-facing, not in Catalog.
	_label("IN-APP BANNER — drops from the top, auto-dismisses in 6 s", 64)
	_banner(Catalog.alert("territory_attack"), 84)
	_label("SUCCESS TOAST — bottom of screen, tap to view", 172)
	_toast(Catalog.alert("quest_complete"), 192)
	_label("PUSH NOTIFICATION — lock screen, app closed", 274)
	var y := 294.0
	for a in Catalog.ALERTS:
		if String(a["kind"]) == "push":
			_push(a, y)
			y += 76.0


func _label(text: String, y: float) -> void:
	UI.place(self, UI.body(text, 10, Tokens.white(0.4), 800), Vector2(_X, y))


func _card(alert: Dictionary, y: float, height: float) -> BaseButton:
	var b := BaseButton.new()
	UI.place(self, b, Vector2(_X, y), Vector2(_W, height))
	b.pressed.connect(func() -> void: Router.go(String(alert["route"])))
	return b


func _banner(alert: Dictionary, y: float) -> void:
	var card := _card(alert, y, 68.0)
	var rect := ChunkyRect.panel(_CARD_BG, 16.0, Tokens.RARITY_EPIC_BOTTOM, 2.5, _SHADOW_DARK)
	rect.shadow_offset = Vector2(0, 6)
	rect.glow_color = Color(Tokens.RARITY_EPIC_BOTTOM, 0.35)
	rect.glow_size = 9.0
	UI.fill(card, rect)
	var pad := UI.margin(13, 11)
	UI.fill(card, pad)
	var row := UI.hbox(11, BoxContainer.ALIGNMENT_CENTER)
	pad.add_child(row)

	var tile := Control.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.custom_minimum_size = Vector2(42, 42)
	UI.fill(tile, ChunkyRect.panel(Tokens.RARITY_EPIC_BOTTOM, 12.0, Tokens.GLOOM_BORDER, 2.0))
	var shroom := Icons.rect("shroom", 22, Color.WHITE)
	UI.place(tile, shroom, Vector2(10, 10))
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tile)

	var col := UI.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(UI.display(String(alert["title"]), 13, Tokens.GLOOM_LIGHT))
	col.add_child(UI.body(String(alert["body"]), 10, Tokens.white(0.65)))
	row.add_child(col)

	var cta := Control.new()
	cta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cta_label := UI.display(String(alert["cta"]), 11, Color.WHITE)
	# Sized from real font metrics — pre-tree label measurements ignore font
	# overrides.
	cta.custom_minimum_size = Vector2(Tokens.display_font().get_string_size(
		String(alert["cta"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 26.0, 32.0)
	var cta_rect := ChunkyRect.new()
	cta_rect.with_gradient(Tokens.RED_GRAD_TOP, Tokens.RED_GRAD_BOTTOM)
	cta_rect.border_color = Color.WHITE
	cta_rect.border_width = 2.0
	cta_rect.corner_radius = 11.0
	cta_rect.shadow_color = Tokens.RED_SHADOW
	cta_rect.shadow_offset = Vector2(0, 3)
	UI.fill(cta, cta_rect)
	UI.fill(cta, UI.centered(cta_label))
	cta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cta)


func _toast(alert: Dictionary, y: float) -> void:
	var card := _card(alert, y, 62.0)
	var rect := ChunkyRect.panel(_CARD_BG, 16.0, Tokens.GREEN_GRAD_TOP, 2.0, _SHADOW_DARK)
	rect.shadow_offset = Vector2(0, 5)
	UI.fill(card, rect)
	var pad := UI.margin(13, 11)
	UI.fill(card, pad)
	var row := UI.hbox(11, BoxContainer.ALIGNMENT_CENTER)
	pad.add_child(row)

	var circle := Control.new()
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.custom_minimum_size = Vector2(36, 36)
	var circle_rect := ChunkyRect.new()
	circle_rect.with_gradient(Tokens.GREEN_GRAD_TOP, Tokens.GREEN_GRAD_BOTTOM)
	circle_rect.corner_radius = 18.0
	circle_rect.border_color = Color.WHITE
	circle_rect.border_width = 2.0
	UI.fill(circle, circle_rect)
	UI.place(circle, Icons.rect("check", 18, Tokens.ON_GREEN, 3.0), Vector2(9, 9))
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(circle)

	var col := UI.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(UI.display(String(alert["title"]), 12, Tokens.GREEN_GRAD_TOP))
	# Re-split the catalog body so the "+N gold" tail goes gold (mock inline
	# color).
	var body := String(alert["body"])
	var cut := body.rfind(" · ")
	var body_row := UI.hbox(0)
	body_row.add_child(UI.body(body.substr(0, cut + 3), 10, Tokens.white(0.65)))
	body_row.add_child(UI.body(body.substr(cut + 3), 10, Tokens.GOLD_GRAD_TOP))
	col.add_child(body_row)
	row.add_child(col)

	var when := UI.body(String(alert["time_label"]), 9, Tokens.white(0.35), 800)
	when.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(when)


func _push(alert: Dictionary, y: float) -> void:
	var card := _card(alert, y, 62.0)
	UI.fill(card, ChunkyRect.panel(_PUSH_BG, 16.0))
	var pad := UI.margin(13, 11)
	UI.fill(card, pad)
	var row := UI.hbox(11)
	pad.add_child(row)

	var tile := Control.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.custom_minimum_size = Vector2(36, 36)
	var tile_rect := ChunkyRect.new()
	tile_rect.with_gradient(Tokens.CYAN_GRAD_TOP, Tokens.CYAN_GRAD_BOTTOM)
	tile_rect.corner_radius = 9.0
	tile_rect.border_color = Color(0, 0, 0, 0.1)
	tile_rect.border_width = 1.5
	UI.fill(tile, tile_rect)
	UI.place(tile, Icons.rect("bolt", 19, Tokens.ON_CYAN, 2.6), Vector2(8.5, 8.5))
	row.add_child(tile)

	var col := UI.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UI.hbox(0)
	head.add_child(UI.body(String(alert["sender"]), 11, _PUSH_TITLE, 800))
	head.add_child(UI.spacer())
	head.add_child(UI.body(String(alert["time_label"]), 9, _PUSH_TIME, 600))
	col.add_child(head)
	col.add_child(UI.body(String(alert["body"]), 11, _PUSH_BODY))
	row.add_child(col)
