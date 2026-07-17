extends Screen
## Chunk 21 — Run ended / retreat. Rotated title + timestamp line, tally chips
## (hexes/XP/gold), SECURED vs LEFT BEHIND loot cards (45% opacity on the
## latter), gold-recovery info chip (Rules hours), BACK TO MAP → home,
## VIEW RUN STATS visual.

# One-off mock colors (no token equivalents).
const _BG_INNER := Color("#2a3550")
const _TITLE_SHADOW := Color("#1a2438")
const _GOLD_CHIP_BORDER := Color("#3a2430")
const _RARE_ART_TEXT := Color("#5d9df0")
const _COMMON_ART := Color("#4a5570")


func build() -> void:
	var bg := _RadialBg.new()
	bg.center = Vector2(201, 122)
	bg.inner = _BG_INNER
	bg.outer = Tokens.BG_SCREEN
	bg.radius = 428.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, bg, Vector2.ZERO, DESIGN_SIZE)

	# "RUN ENDED" heading is mock-pinned copy with no Catalog/GameState home.
	var title := DamageFloat.make("RUN ENDED", Color.WHITE, 34, -1.5, _TITLE_SHADOW)
	UI.shadowed(title, _TITLE_SHADOW, 3)
	UI.place_centered_x(self, title, 208)
	UI.place_centered_x(self, UI.body(String(GameState.run_summary["ended_line"]), 12,
		Tokens.white(0.5)), 260)

	_build_tally()
	_build_loot()
	_build_recovery()
	_build_ctas()


func _build_tally() -> void:
	var row := UI.hbox(9)
	row.add_child(_tally_chip("+%d" % int(GameState.run_summary["hexes_kept"]),
		Tokens.CYAN_LIGHT, "HEXES KEPT", Tokens.BORDER))
	row.add_child(_tally_chip("+%d" % int(GameState.run_summary["xp_kept"]),
		Tokens.GREEN_GRAD_TOP, "XP KEPT", Tokens.BORDER))
	row.add_child(_tally_chip("-%d" % int(GameState.run_summary["gold_dropped"]),
		Tokens.PINK, "GOLD DROPPED", _GOLD_CHIP_BORDER))
	UI.place_centered_x(self, row, 300)


func _tally_chip(value: String, value_color: Color, label: String, border: Color) -> Control:
	var chip := Control.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(chip, ChunkyRect.panel(Tokens.BG_CARD, 13.0, border, 2.0))
	var pad := UI.margin(14, 10)
	UI.fill(chip, pad)
	var col := UI.vbox(0, BoxContainer.ALIGNMENT_CENTER)
	pad.add_child(col)
	col.add_child(UI.centered(UI.display(value, 18, value_color)))
	col.add_child(UI.centered(UI.micro(label, 8, Tokens.white(0.45), 0)))
	# Sized from real font metrics — pre-tree container measurements ignore
	# font overrides.
	chip.custom_minimum_size = Vector2(maxf(
		_text_w(Tokens.display_font(), value, 18),
		_text_w(Tokens.body_font(800), label, 8)) + 28.0, 54.0)
	return chip


static func _text_w(font: Font, text: String, px: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


func _build_loot() -> void:
	var row := UI.hbox(10)
	for entry in GameState.run_summary["loot"]:
		row.add_child(_loot_card(String(entry["item"]), String(entry["state"])))
	UI.place_centered_x(self, row, 378)


func _loot_card(item_id: String, state: String) -> Control:
	var item := Catalog.item(item_id)
	var rarity := String(item.get("rarity", "common"))
	var secured := state == "secured"
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(111, 113)

	var rect := ChunkyRect.panel(Tokens.BG_CARD, 15.0,
		Tokens.RARITY_RARE if rarity == "rare" else Tokens.BORDER, 2.5)
	UI.fill(card, rect)
	var pad := UI.margin(9, 11)
	UI.fill(card, pad)
	var col := UI.vbox(6)
	pad.add_child(col)

	var art_color := _RARE_ART_TEXT if rarity == "rare" else _COMMON_ART
	var art := Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size = Vector2(48, 48)
	var art_rect := ChunkyRect.new()
	art_rect.fill_top = Color(0, 0, 0, 0)
	art_rect.border_color = Tokens.RARITY_RARE if rarity == "rare" else art_color
	art_rect.border_width = 2.0
	art_rect.corner_radius = 10.0
	art_rect.dashed = true
	UI.fill(art, art_rect)
	var art_label := UI.centered(UI.micro("ART", 7, art_color))
	art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(art, art_label)
	var art_wrap := CenterContainer.new()
	art_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_wrap.add_child(art)
	col.add_child(art_wrap)

	var name_label := UI.centered(UI.wrap(UI.body(String(item["name"]), 10, Color.WHITE)))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(name_label)
	col.add_child(UI.centered(UI.micro("SECURED" if secured else "LEFT BEHIND", 8,
		Tokens.GREEN_GRAD_TOP if secured else Tokens.PINK)))

	if not secured:
		card.modulate.a = 0.45
	return card


func _build_recovery() -> void:
	var chip := Control.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(chip, ChunkyRect.panel(Tokens.BG_CARD, 13.0, Tokens.GOLD_GRAD_TOP, 2.0))
	var pad := UI.margin(13, 9)
	UI.fill(chip, pad)
	var row := UI.hbox(8)
	pad.add_child(row)
	var icon := Icons.rect("clock", 16, Tokens.GOLD_GRAD_TOP)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	# Catalog copy with the "N hour" span re-colored gold (mock inline color).
	var full := String(Catalog.COPY["gold_recovery_line"])
	var span := "%d hour" % Rules.DROPPED_GOLD_PERSIST_HOURS
	var at := full.find(span)
	var gold_hex := Tokens.GOLD_GRAD_TOP.to_html(false)
	var bbcode := full if at < 0 else "%s[color=#%s]%s[/color]%s" % [
		full.substr(0, at), gold_hex, span, full.substr(at + span.length())]
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_override("normal_font", Tokens.body_font(700))
	text.add_theme_font_size_override("normal_font_size", 11)
	text.add_theme_color_override("default_color", Tokens.white(0.7))
	text.text = bbcode
	text.custom_minimum_size = Vector2(272, 0)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)

	chip.custom_minimum_size = Vector2(330, 52)
	UI.place_centered_x(self, chip, 512, Vector2(330, 52))


func _build_ctas() -> void:
	var back := ChunkyButton.make("BACK TO MAP", "cta_cyan", Vector2(300, 48), 15)
	UI.place_centered_x(self, back, 590, Vector2(300, 48))
	back.pressed.connect(func() -> void: Router.go("home"))
	# VIEW RUN STATS has no target in the v1 flow — pressed feedback only.
	UI.place_centered_x(self, ChunkyButton.make("VIEW RUN STATS", "secondary",
		Vector2(300, 44), 13), 647, Vector2(300, 44))


## Opaque radial background (mock: radial-gradient circle) via stacked
## outer→inner circles.
class _RadialBg:
	extends Control

	const _STEPS := 40

	var center := Vector2.ZERO
	var inner := Color.BLACK
	var outer := Color.BLACK
	var radius := 400.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), outer)
		for i in range(_STEPS, 0, -1):
			var t := float(i) / _STEPS
			draw_circle(center, radius * t, inner.lerp(outer, t))
