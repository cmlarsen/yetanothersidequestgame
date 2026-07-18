extends Screen
## NPC dialogue (mock 12): dimmed hexB map with a sand road, Elder
## Grumblesnore portrait in a double gold ring, bottom sheet with the quote,
## quest chip, and the 3 reply buttons from Catalog.

# Mock-only scrim color (rgba(10,14,20,.55)); not a token.
const _SCRIM := Color(10.0 / 255.0, 14.0 / 255.0, 20.0 / 255.0, 0.55)
const _SHEET_H := 314.0
const _NPC_ID := "elder_grumblesnore"
# Pennant icon from the mock's quest chip; not in the Icons registry.
const _BANNER_SVG := '<path d="M5 21V4l7 3 7-3v13l-7 3z"/>'

var _npc: Dictionary
var _quest: Dictionary
var _quote: Label
var _showing_detail := false


func build() -> void:
	_npc = Catalog.npc(_NPC_ID)
	_quest = Catalog.quest(_npc["quest_id"])
	add_bg(Tokens.MAP_GRASS)
	_build_map()
	_build_portrait()
	_build_sheet()


func _build_map() -> void:
	# The chunk paints the road before {{ hexB }}, so it sits under the grid.
	var road := _Road.new()
	road.points = _bezier(Vector2(-20, 300), Vector2(100, 260), Vector2(220, 240),
		Vector2(420, 210), 30)
	UI.fill(self, road)
	UI.fill(self, HexGridMap.preset_b())
	var scrim := ColorRect.new()
	scrim.color = _SCRIM
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(self, scrim)


func _build_portrait() -> void:
	# 130px face + 4px gold border + 4px dark-gold outer ring (mock box-shadow).
	var outer := ChunkyRect.panel(Tokens.GOLD_BORDER, 73.0)
	UI.place(self, outer, Vector2(128, 246), Vector2(146, 146))
	var face := AvatarFace.make(_npc["face"], 138.0, Tokens.GOLD_GRAD_TOP, 4.0)
	UI.place(self, face, Vector2(132, 250))
	var name_label := UI.shadowed(UI.display(_npc["name"], 20), Color(0, 0, 0, 0.5), 2)
	UI.place_centered_x(self, name_label, 394.0)
	UI.place_centered_x(self, UI.micro(_npc["title"], 10, Tokens.GOLD_GRAD_TOP), 420.0)


func _build_sheet() -> void:
	var sheet := SheetPanel.make(Tokens.BORDER, _SHEET_H)
	UI.place(self, sheet, Vector2(0, DESIGN_SIZE.y - _SHEET_H))
	# Mock 12's sheet has no drag handle.
	sheet.content.get_parent().get_child(0).visible = false

	_quote = UI.wrap(UI.body(_npc["line"], 13, Tokens.white(0.85), 700))
	_quote.add_theme_constant_override("line_spacing", 3)
	# Godot shapes Nunito a touch narrower than the mock; cap the wrap width
	# so the quote breaks into the mock's 3 lines.
	var quote_holder := UI.margin(0, 0, 26, 0)
	quote_holder.add_child(_quote)
	sheet.content.add_child(quote_holder)
	sheet.content.add_child(_quest_chip())

	var replies := UI.vbox(8)
	sheet.content.add_child(replies)
	for reply: Dictionary in _npc["replies"]:
		replies.add_child(_reply_button(reply))


func _quest_chip() -> Control:
	var chip := Control.new()
	chip.custom_minimum_size = Vector2(0, 40)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(chip, ChunkyRect.panel(Tokens.BG_CARD, 13.0, Tokens.GOLD_GRAD_TOP, 2.0))
	var pad := UI.margin(12, 9)
	UI.fill(chip, pad)
	var row := UI.hbox(9)
	pad.add_child(row)
	var icon := _svg_rect(_BANNER_SVG, 17, Tokens.GOLD_GRAD_TOP)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var label := UI.body(_quest["chip_label"], 11, Color.WHITE, 700)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var reward := UI.display(_quest["reward_label"], 12, Tokens.GOLD_GRAD_TOP)
	reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(reward)
	return chip


func _reply_button(reply: Dictionary) -> ChunkyButton:
	var b: ChunkyButton
	match reply["kind"]:
		"primary":
			b = ChunkyButton.make(reply["label"], "cta_cyan", Vector2(0, 44), 14)
			b.pressed.connect(func() -> void: Router.go("quest_board"))
		"secondary":
			b = ChunkyButton.make(reply["label"], "secondary", Vector2(0, 44), 13)
			b.pressed.connect(_toggle_detail)
		_:
			# The mock's DECLINE is secondary-styled with dimmer text.
			b = ChunkyButton.make(reply["label"], "secondary", Vector2(0, 44), 13)
			_recolor_label(b, Tokens.white(0.45))
			b.pressed.connect(func() -> void: Router.back())
	return b


func _toggle_detail() -> void:
	_showing_detail = not _showing_detail
	if _showing_detail:
		# Detail line has no Catalog entry; composed from the quest record.
		_quote.text = "\"%s The bounty: %s. The bench: priceless.\"" % [
			_quest["objective"], _quest["reward_label"]]
	else:
		_quote.text = _npc["line"]


static func _recolor_label(node: Node, color: Color) -> void:
	if node is Label:
		(node as Label).add_theme_color_override("font_color", color)
		return
	for child in node.get_children():
		_recolor_label(child, color)


static func _svg_rect(inner: String, px: int, color: Color) -> TextureRect:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="%s" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [
		"#" + color.to_html(false), inner]
	var img := Image.new()
	img.load_svg_from_string(svg, float(px) / 24.0)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2,
		segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments + 1:
		out.append(p0.bezier_interpolate(p1, p2, p3, float(i) / segments))
	return out


class _Road:
	extends Control
	## Sand road with round caps/joints (polyline + per-vertex circles, same
	## trick as HexGridMap._stroke_round).

	var points := PackedVector2Array()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		_stroke(Tokens.MAP_PATH_EDGE, 52.0)
		_stroke(Tokens.MAP_PATH, 40.0)

	func _stroke(color: Color, width: float) -> void:
		if points.size() >= 2:
			draw_polyline(points, color, width, true)
		for p in points:
			draw_circle(p, width / 2.0, color)
