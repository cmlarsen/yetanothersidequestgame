extends Screen
## Party management (chunk 10): PARTY header, member rows with status dots and
## XP bars, open-slot row, gold party-code pill, PLAYERS NEARBY list with
## INVITE chips, START GROUP RUN.

# One-off chunk-10 colors (inline CSS only).
const _TITLE_SHADOW := Color("#1a5a6e")
const _CROWN_SHADOW := Color("#8a5a08")
const _CARD_SHADOW := Color(8.0 / 255.0, 12.0 / 255.0, 20.0 / 255.0, 0.5)

const _SVG_CROWN := '<path d="M4 16.5h16L21.5 7l-5.2 3.6L12 4.5 7.7 10.6 2.5 7z"/>'

const _CARD_H := 77.0
const _CARD_GAP := 9.0
const _CARDS_Y := 133.0


class HBar:
	extends Control
	## Horizontal-gradient XP bar (the kit StatBarChunky gradients vertically).
	var ratio := 1.0
	var from := Tokens.CYAN
	var to := Tokens.GREEN_GRAD_TOP
	var radius := 5.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var radii := Vector4(radius, radius, radius, radius)
		var track := ChunkyRect.rounded_points(Rect2(Vector2.ZERO, size), radii)
		draw_colored_polygon(track, Tokens.BG_INSET)
		var w := size.x * clampf(ratio, 0.0, 1.0)
		if w < 1.0:
			return
		var r := minf(radius, w * 0.5)
		var pts := ChunkyRect.rounded_points(Rect2(Vector2.ZERO, Vector2(w, size.y)),
			Vector4(r, r, r, r))
		var colors := PackedColorArray()
		for p in pts:
			colors.append(from.lerp(to, clampf(p.x / w, 0.0, 1.0)))
		draw_polygon(pts, colors)


func build() -> void:
	add_bg(Tokens.BG_SCREEN)
	_build_header()
	for i in GameState.party.size():
		_member_card(GameState.party[i], _CARDS_Y + i * (_CARD_H + _CARD_GAP))
	var slots_y := _CARDS_Y + GameState.party.size() * (_CARD_H + _CARD_GAP)
	_open_slot_row(slots_y)
	_code_row(slots_y + 51.0 + 14.0)
	_nearby_section(slots_y + 51.0 + 14.0 + 46.0 + 16.0)
	_start_button()


func _build_header() -> void:
	var title := UI.shadowed(UI.display("PARTY", 26, Color.WHITE), _TITLE_SHADOW, 3)
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, wrap, Vector2(101, 71), Vector2(200, 32))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fill(wrap, title)
	title.pivot_offset = Vector2(100, 16)
	title.rotation_degrees = -1.0
	var sub := UI.centered(UI.body("%s · holds %d%% of %s" % [GameState.party_name,
		GameState.front_pct_player, GameState.front_name], 10, Tokens.CYAN_LIGHT, 700))
	UI.place_centered_x(self, sub, 103)


func _member_card(m: Dictionary, y: float) -> void:
	var is_self := bool(m.get("is_self", false))
	var card := Control.new()
	UI.place(self, card, Vector2(14, y), Vector2(374, _CARD_H))
	var rect := ChunkyRect.panel(Tokens.BG_CARD, 16.0,
		Tokens.CYAN if is_self else Tokens.BORDER, 2.0, _CARD_SHADOW)
	rect.shadow_offset = Vector2(0, 4)
	UI.fill(card, rect)

	var face := AvatarFace.make(String(m["face"]), 52.0, Color.WHITE, 2.5)
	UI.place(card, face, Vector2(12, 12.5))
	if m.get("is_leader", false):
		var crown := _svg_fill_rect(_SVG_CROWN, 13, Tokens.GOLD_GRAD_TOP, _CROWN_SHADOW)
		UI.place(card, crown, Vector2(12 + 26 - 6.5, 2.5))
	var dot := ChunkyRect.panel(_status_color(String(m["status"])), 6.5,
		Tokens.BG_CARD, 2.5)
	UI.place(card, dot, Vector2(12 + 52 - 13, 12.5 + 52 - 13), Vector2(13, 13))

	var name_row := UI.hbox(0)
	UI.place(card, name_row, Vector2(75, 13), Vector2(287, 18))
	var name_label := UI.display(String(m["name"]), 14, Color.WHITE)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(name_label)
	name_row.add_child(UI.spacer())
	var status := UI.micro(_status_label(String(m["status"])), 9,
		_status_color(String(m["status"])))
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(status)

	var sub_text := "LV %d · %s" % [int(m["level"]), String(m["epithet"])]
	if is_self:
		sub_text = "You · " + sub_text
	UI.place(card, UI.body(sub_text, 9, Tokens.white(0.45), 700), Vector2(75, 33))

	var bar := HBar.new()
	bar.ratio = float(m["xp_ratio"])
	UI.place(card, bar, Vector2(75, 54), Vector2(287, 8))


func _open_slot_row(y: float) -> void:
	var open := Rules.PARTY_MAX - GameState.party.size()
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, row, Vector2(14, y), Vector2(374, 51))
	var rect := ChunkyRect.panel(Color(0, 0, 0, 0), 16.0, Tokens.SLOT_BORDER, 2.0)
	rect.dashed = true
	rect.dash_length = 7.0
	rect.gap_length = 5.0
	UI.fill(row, rect)
	var content := UI.hbox(7, BoxContainer.ALIGNMENT_CENTER)
	UI.fill(row, content)
	var plus := UI.display("+", 16, Tokens.SLOT_BORDER)
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(plus)
	var label := UI.micro("%d SLOT OPEN — INVITE A PLAYER" % open, 10, Tokens.SLOT_BORDER)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(label)


func _code_row(y: float) -> void:
	var row := Control.new()
	UI.place(self, row, Vector2(14, y), Vector2(374, 46))
	UI.fill(row, ChunkyRect.panel(Tokens.BG_CARD, 14.0, Tokens.GOLD_GRAD_TOP, 2.0))
	var content := UI.margin(13, 0)
	UI.fill(row, content)
	var h := UI.hbox(8)
	content.add_child(h)
	var code := UI.display("PARTY CODE · %s" % GameState.party_code, 13,
		Tokens.GOLD_GRAD_TOP)
	code.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(code)
	h.add_child(UI.spacer())
	var copy_wrap := UI.vbox(0, BoxContainer.ALIGNMENT_CENTER)
	copy_wrap.add_child(Chip.make("COPY", {
		"bg": Tokens.GOLD_GRAD_TOP, "border_w": 0.0, "radius": 9.0,
		"font": "display", "font_size": 10, "text_color": Tokens.ON_GOLD,
		"pad_h": 12.0, "pad_v": 5.0, "shadow": Tokens.GOLD_SHADOW,
	}))
	h.add_child(copy_wrap)


func _nearby_section(y: float) -> void:
	UI.place(self, UI.micro("PLAYERS NEARBY (%d)" % GameState.nearby_players.size(),
		10, Tokens.white(0.45)), Vector2(14, y))
	var row_y := y + 13.0 + 8.0
	for p in GameState.nearby_players:
		_nearby_row(p, row_y)
		row_y += 60.0 + 8.0


func _nearby_row(p: Dictionary, y: float) -> void:
	var row := Control.new()
	UI.place(self, row, Vector2(14, y), Vector2(374, 60))
	UI.fill(row, ChunkyRect.panel(Tokens.BG_CARD, 14.0, Tokens.BORDER, 2.0))
	var content := UI.margin(11, 8)
	UI.fill(row, content)
	var h := UI.hbox(10)
	content.add_child(h)
	var face_wrap := UI.vbox(0, BoxContainer.ALIGNMENT_CENTER)
	face_wrap.add_child(AvatarFace.make(String(p["face"]), 40.0, Tokens.SLOT_BORDER, 2.0))
	h.add_child(face_wrap)
	var col := UI.vbox(1, BoxContainer.ALIGNMENT_CENTER)
	h.add_child(col)
	col.add_child(UI.display(String(p["name"]), 12, Color.WHITE))
	col.add_child(UI.body("LV %d · %d m away" % [int(p["level"]), int(p["distance_m"])],
		9, Tokens.white(0.45), 700))
	h.add_child(UI.spacer())
	var invite_wrap := UI.vbox(0, BoxContainer.ALIGNMENT_CENTER)
	invite_wrap.add_child(Chip.make("INVITE", {
		"bg": Tokens.CYAN_GRAD_TOP, "bg_bottom": Tokens.CYAN_GRAD_BOTTOM,
		"border": Color.WHITE, "border_w": 2.0, "radius": 11.0,
		"font": "display", "font_size": 11, "text_color": Tokens.ON_CYAN,
		"pad_h": 13.0, "pad_v": 6.0, "shadow": Tokens.CYAN_SHADOW,
	}))
	h.add_child(invite_wrap)


func _start_button() -> void:
	var btn := ChunkyButton.make("START GROUP RUN", "cta_cyan", Vector2(374, 48), 15)
	UI.place(self, btn, Vector2(14, DESIGN_SIZE.y - 26 - 48), Vector2(374, 48))
	btn.pressed.connect(func() -> void: Router.go("exploration"))


static func _status_color(status: String) -> Color:
	match status:
		"online":
			return Tokens.GREEN_GRAD_TOP
		"in_combat":
			return Tokens.WARNING
	return Tokens.TEXT_DIM


static func _status_label(status: String) -> String:
	match status:
		"online":
			return "ONLINE"
		"in_combat":
			return "IN COMBAT"
	return "OFFLINE"


static func _svg_fill_rect(body: String, px: int, color: Color, shadow: Color) -> TextureRect:
	# Crown glyph: drawn as SVG (the chunk's "♛" has no glyph in the bundled
	# fonts); hard 1px shadow via a stacked darker copy.
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="26" viewBox="0 0 24 26"><g transform="translate(0 2)" fill="#%s">%s</g><g fill="#%s">%s</g></svg>' % [
		shadow.to_html(false), body, color.to_html(false), body]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, float(px) / 24.0)
	assert(err == OK, "svg rasterize failed")
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
