extends Screen
## Shop (mock 14): Grumbeard portrait + parchment speech bubble, BUY/SELL
## tabs, gold pill, 2×2 stock cards from Catalog.SHOP_STOCK (deal badge with
## strikethrough, unaffordable red price, mystery ??? card), restock note,
## BUY CTA reflecting the selected item.
##
## Sizing note: labels report default-theme metrics until they enter the tree,
## so every explicitly-sized pill here attaches first, then measures.

# Mock-only colors (not tokens).
const _BUBBLE_TEXT := Color("#4a3a10")
const _ART_DIM := Color("#4a5570")
const _ART_RARE_TEXT := Color("#5d9df0")
const _ART_EPIC := Color("#a678ec")
const _BADGE_COMMON_TEXT := Color("#0e1420")
const _PRICE_WARN_BORDER := Color("#7a2030")
const _DEAL_SHADOW := Color("#3a7a28")
# Mock's location-pin (no center dot) for the restock note.
const _PIN_SVG := '<path d="M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11z"/>'

const _CARD_W := 181.0
const _CARD_H := 157.0
const _CARD_POS: Array[Vector2] = [
	Vector2(14, 326), Vector2(207, 326), Vector2(14, 495), Vector2(207, 495),
]

var _npc: Dictionary
var _selected: String = GameState.shop_selected
var _rings: Dictionary = {}
var _cta_holder: Control
var _note_label: Label
var _gold_label: Label
var _tab_buttons: Array[BaseButton] = []
var _tab_rects: Array[ChunkyRect] = []
var _tab_labels: Array[Label] = []


func build() -> void:
	_npc = Catalog.npc("grumbeard")
	add_bg(Tokens.BG_SCREEN)
	_build_header()
	_build_tab_bar()
	for i in Catalog.SHOP_STOCK.size():
		_build_card(Catalog.SHOP_STOCK[i], _CARD_POS[i])
	_build_footer()
	if GameState.is_live:
		GameState.live_changed.connect(_on_live_changed)


## SHOP_RESULT (and any other gold-moving apply) refreshes the pill + CTA
## affordability; the stock cards stay Catalog-driven for now.
func _on_live_changed(what: String) -> void:
	if what in ["shop", "events", "inventory", "snapshot"]:
		_gold_label.text = Rules.fmt_thousands(GameState.gold)
		_update_cta()


func _build_header() -> void:
	# 74px face + 3px gold border + 3px dark-gold outer ring.
	var outer := ChunkyRect.panel(Tokens.GOLD_BORDER, 43.0)
	UI.place(self, outer, Vector2(13, 75), Vector2(86, 86))
	UI.place(self, AvatarFace.make(_npc["face"], 80.0, Tokens.GOLD_GRAD_TOP, 3.0),
		Vector2(16, 78))
	UI.place(self, UI.display(_npc["name"], 17), Vector2(107, 79))

	var bubble := Control.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)
	UI.fill(bubble, ChunkyRect.panel(Tokens.PARCHMENT, 12.0))
	var pad := UI.margin(12, 8)
	UI.fill(bubble, pad)
	var line := UI.body(_npc["line"], 11, _BUBBLE_TEXT, 700)
	pad.add_child(line)
	bubble.position = Vector2(107, 105)
	bubble.size = Vector2(minf(line.get_combined_minimum_size().x + 24.0, 281.0), 33)
	bubble.add_child(_bubble_tail())


func _bubble_tail() -> Control:
	var tail := _Tail.new()
	tail.position = Vector2(-7, 14)
	tail.size = Vector2(8, 14)
	return tail


func _build_tab_bar() -> void:
	var row := UI.hbox(6)
	UI.place(self, row, Vector2(16, 180))
	row.add_child(_tab_pill("BUY", 0))
	row.add_child(_tab_pill("SELL", 1))
	for i in _tab_buttons.size():
		_tab_buttons[i].custom_minimum_size = Vector2(
			_tab_labels[i].get_combined_minimum_size().x + 30.0, 23.0)
	_set_tab(0)

	var pill := Control.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pill)
	UI.fill(pill, ChunkyRect.panel(Tokens.BG_CARD, 30.0, Tokens.BORDER, 2.0))
	var pad := UI.margin(12, 6)
	UI.fill(pill, pad)
	var inner := UI.hbox(6)
	pad.add_child(inner)
	var coin := _coin(20.0, 2.0)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(coin)
	_gold_label = UI.display(Rules.fmt_thousands(GameState.gold), 13, Tokens.GOLD_GRAD_TOP)
	inner.add_child(_gold_label)
	var w := inner.get_combined_minimum_size().x + 24.0
	pill.position = Vector2(388.0 - w, 176)
	pill.size = Vector2(w, 32)


func _tab_pill(text: String, index: int) -> BaseButton:
	var b := BaseButton.new()
	var rect := ChunkyRect.new()
	rect.corner_radius = 9.0
	UI.fill(b, rect)
	var label := UI.display(text, 11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(b, label)
	b.custom_minimum_size = Vector2(44, 23)
	b.pressed.connect(_set_tab.bind(index))
	_tab_buttons.append(b)
	_tab_rects.append(rect)
	_tab_labels.append(label)
	return b


func _set_tab(index: int) -> void:
	for i in _tab_rects.size():
		var on := i == index
		var rect := _tab_rects[i]
		rect.fill_top = Tokens.GOLD_GRAD_TOP if on else Tokens.BG_CARD
		rect.border_color = Color(0, 0, 0, 0) if on else Tokens.BORDER
		rect.border_width = 0.0 if on else 1.5
		rect.shadow_color = Tokens.GOLD_SHADOW if on else Color(0, 0, 0, 0)
		rect.shadow_offset = Vector2(0, 3)
		rect.queue_redraw()
		_tab_labels[i].add_theme_color_override("font_color",
			Tokens.ON_GOLD if on else Tokens.TEXT_DIM)
	if _note_label != null:
		# SELL copy composed from Rules (SCREENS.md: "sell = 50% note").
		_note_label.text = _npc["restock_note"] if index == 0 \
			else "Items sell for %d%% of their value" % Rules.SHOP_SELL_PCT


func _build_card(entry: Dictionary, pos: Vector2) -> void:
	var item_id: String = entry["item"]
	var item := Catalog.item(item_id)
	var rarity: String = item["rarity"]

	var card := Control.new()
	UI.place(self, card, pos, Vector2(_CARD_W, _CARD_H))
	var rect := ChunkyRect.new()
	rect.fill_top = Tokens.BG_CARD
	rect.corner_radius = 16.0
	rect.border_width = 2.5
	match rarity:
		"rare":
			rect.border_color = Tokens.RARITY_RARE
		"epic":
			rect.border_color = Tokens.RARITY_EPIC_TOP
			rect.glow_color = Color(Tokens.RARITY_EPIC_TOP, 0.25)
			rect.glow_size = 12.0
		_:
			rect.border_color = Tokens.BORDER
	UI.fill(card, rect)

	var pad := UI.margin(10, 14, 10, 11)
	UI.fill(card, pad)
	var col := UI.vbox(6)
	pad.add_child(col)
	col.add_child(_center_h(_art_box(rarity)))
	col.add_child(UI.centered(UI.body(item["name"], 11, Color.WHITE, 700)))
	_add_rarity_badge(col, item)
	_add_price_pill(col, entry, item)

	if entry.has("deal_badge"):
		_add_deal_badge(card, entry["deal_badge"])

	# Selection ring, shown once a card is tapped (default state matches mock).
	var ring := Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_rect := ChunkyRect.new()
	ring_rect.fill_top = Color(0, 0, 0, 0)
	ring_rect.border_color = Tokens.CYAN
	ring_rect.border_width = 3.0
	ring_rect.corner_radius = 19.0
	UI.place(self, ring, pos - Vector2(5, 5), Vector2(_CARD_W + 10.0, _CARD_H + 10.0))
	UI.fill(ring, ring_rect)
	ring.visible = false
	_rings[item_id] = ring

	var tap := BaseButton.new()
	UI.fill(card, tap)
	tap.pressed.connect(_select.bind(item_id))


func _art_box(rarity: String) -> Control:
	var border := _ART_DIM
	var text := _ART_DIM
	match rarity:
		"rare":
			border = Tokens.RARITY_RARE
			text = _ART_RARE_TEXT
		"epic":
			border = _ART_EPIC
			text = _ART_EPIC
	var box := Control.new()
	box.custom_minimum_size = Vector2(60, 60)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := ChunkyRect.new()
	rect.fill_top = Color(0, 0, 0, 0)
	rect.border_color = border
	rect.border_width = 2.0
	rect.corner_radius = 11.0
	rect.dashed = true
	UI.fill(box, rect)
	var label := UI.centered(UI.micro("ART", 7, text))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(box, label)
	return box


func _add_rarity_badge(parent: Control, item: Dictionary) -> void:
	var text: String = item.get("rarity_label", String(item["rarity"]).to_upper())
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(root)
	var rect := ChunkyRect.new()
	rect.corner_radius = 6.0
	var text_color := Color.WHITE
	match item["rarity"]:
		"rare":
			rect.fill_top = Tokens.RARITY_RARE
		"epic":
			rect.with_gradient(Tokens.RARITY_EPIC_TOP, Tokens.RARITY_EPIC_BOTTOM)
		"mystery":
			rect.fill_top = Tokens.GOLD_GRAD_TOP
			text_color = Tokens.ON_GOLD
		_:
			rect.fill_top = Tokens.RARITY_COMMON
			text_color = _BADGE_COMMON_TEXT
	UI.fill(root, rect)
	var label := UI.micro(text, 8, text_color)
	root.add_child(label)
	var ms := label.get_combined_minimum_size()
	root.custom_minimum_size = ms + Vector2(16, 2)
	label.position = Vector2(8, 1)


func _add_price_pill(parent: Control, entry: Dictionary, item: Dictionary) -> void:
	var value: int = item["value"]
	var price := _price_of(entry)
	var affordable := price <= GameState.gold
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(root)
	var rect := ChunkyRect.panel(Tokens.BG_INSET, 9.0)
	if not affordable:
		rect.border_color = _PRICE_WARN_BORDER
		rect.border_width = 1.5
	UI.fill(root, rect)
	var row := UI.hbox(5)
	root.add_child(row)
	if entry.has("deal_pct"):
		_add_strike_price(row, value)
	var coin := _coin(12.0, 0.0)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	var color := Tokens.GOLD_GRAD_TOP
	if entry.has("deal_pct"):
		color = Tokens.GREEN_GRAD_TOP
	elif not affordable:
		color = Tokens.PINK
	row.add_child(UI.display(Rules.fmt_thousands(price), 12, color))
	var ms := row.get_combined_minimum_size()
	root.custom_minimum_size = ms + Vector2(22, 8)
	row.position = Vector2(11, 4)
	row.size = ms


func _add_strike_price(row: Control, value: int) -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(holder)
	var label := UI.body(str(value), 10, Tokens.white(0.35), 700)
	holder.add_child(label)
	var ms := label.get_combined_minimum_size()
	holder.custom_minimum_size = ms
	var line := ColorRect.new()
	line.color = Tokens.white(0.35)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	line.position = Vector2(0, ms.y * 0.5)
	line.size = Vector2(ms.x, 1.0)


func _add_deal_badge(card: Control, text: String) -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(root)
	var rect := ChunkyRect.panel(Tokens.GREEN_GRAD_TOP, 7.0)
	rect.shadow_color = _DEAL_SHADOW
	rect.shadow_offset = Vector2(0, 2)
	UI.fill(root, rect)
	var label := UI.display(text, 9, Tokens.ON_GREEN)
	root.add_child(label)
	var ms := label.get_combined_minimum_size()
	root.size = ms + Vector2(18, 6)
	label.position = Vector2(9, 3)
	root.position = Vector2(_CARD_W - 10.0 - root.size.x, -9.0)
	root.pivot_offset = root.size * 0.5
	root.rotation_degrees = 3.0


func _build_footer() -> void:
	var note := UI.hbox(7)
	var pin := _pin_icon(13, Tokens.GREEN_GRAD_TOP)
	pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note.add_child(pin)
	_note_label = UI.body(_npc["restock_note"], 10, Tokens.white(0.45), 700)
	note.add_child(_note_label)
	UI.place_centered_x(self, note, 771.0)

	_cta_holder = Control.new()
	UI.place(self, _cta_holder, Vector2(14, 797), Vector2(374, 51))
	_update_cta()


func _select(item_id: String) -> void:
	_selected = item_id
	for id: String in _rings:
		_rings[id].visible = id == item_id
	_update_cta()


func _update_cta() -> void:
	for c in _cta_holder.get_children():
		c.queue_free()
	var price := 0
	for entry: Dictionary in Catalog.SHOP_STOCK:
		if entry["item"] == _selected:
			price = _price_of(entry)
	var affordable := price <= GameState.gold
	var b := ChunkyButton.make("BUY · %s GOLD" % Rules.fmt_thousands(price),
		"cta_gold" if affordable else "cta_red", Vector2(374, 50), 16)
	b.disabled = not affordable
	b.pressed.connect(func() -> void:
		if GameState.is_live:
			NetClient.send_op(int(ServerProtocol.OP.BUY), {"itemId": _selected}))
	_cta_holder.add_child(b)


func _price_of(entry: Dictionary) -> int:
	var value: int = Catalog.item(entry["item"])["value"]
	return Rules.deal_price(value) if entry.has("deal_pct") else value


static func _center_h(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c


static func _coin(d: float, border_w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(d, d)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := ChunkyRect.new()
	r.with_gradient(Tokens.RARITY_LEGENDARY_TOP, Tokens.GOLD_GRAD_BOTTOM)
	r.corner_radius = d / 2.0
	if border_w > 0.0:
		r.border_color = Tokens.GOLD_BORDER
		r.border_width = border_w
	UI.fill(c, r)
	return c


static func _pin_icon(px: int, color: Color) -> TextureRect:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="%s" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [
		"#" + color.to_html(false), _PIN_SVG]
	var img := Image.new()
	img.load_svg_from_string(svg, float(px) / 24.0)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


class _Tail:
	extends Control
	## Speech-bubble tail (mock: CSS border triangle pointing left).

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([
			Vector2(8, 0), Vector2(8, 14), Vector2(0, 7)]), Tokens.PARCHMENT)
