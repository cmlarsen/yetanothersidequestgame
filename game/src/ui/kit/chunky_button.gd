class_name ChunkyButton
extends BaseButton
## The chunky CTA/secondary button: gradient or flat ChunkyRect body, hard
## shadow, display-font uppercase label. Pressed shifts content down onto the
## (hidden) shadow; disabled drops to 55% opacity.

const _PAD_H := 18.0

var rect: ChunkyRect

var _content: MarginContainer
var _shadow_color: Color
var _shadow_h: float = 0.0
var _last_mode: int = -1


static func make(text: String, kind: String, min_size: Vector2 = Vector2(0, 52),
		font_size: int = 17, icon: String = "") -> ChunkyButton:
	var b := ChunkyButton.new()
	var h := maxf(min_size.y, 44.0)
	var radius := 20.0 if h >= 52.0 else (18.0 if h >= 46.0 else 15.0)
	b._shadow_h = 6.0 if h >= 52.0 else (5.0 if h >= 46.0 else 4.0)

	var text_color := Color.WHITE
	b.rect = ChunkyRect.new()
	b.rect.corner_radius = radius
	match kind:
		"cta_cyan":
			b.rect.with_gradient(Tokens.CYAN_GRAD_TOP, Tokens.CYAN_GRAD_BOTTOM)
			b.rect.border_color = Color.WHITE
			b.rect.border_width = 3.0
			b.rect.shadow_color = Tokens.CYAN_SHADOW
			text_color = Tokens.ON_CYAN
		"cta_green":
			b.rect.with_gradient(Tokens.GREEN_GRAD_TOP, Tokens.GREEN_GRAD_BOTTOM)
			b.rect.border_color = Color.WHITE
			b.rect.border_width = 3.0
			b.rect.shadow_color = Tokens.GREEN_SHADOW
			text_color = Tokens.ON_GREEN
		"cta_gold":
			# Gold CTAs in the mocks keep the white border but shadow in
			# GOLD_BORDER (shop BUY, rewards CLAIM) instead of GOLD_SHADOW.
			b.rect.with_gradient(Tokens.GOLD_GRAD_TOP, Tokens.GOLD_GRAD_BOTTOM)
			b.rect.border_color = Color.WHITE
			b.rect.border_width = 3.0
			b.rect.shadow_color = Tokens.GOLD_BORDER
			text_color = Tokens.ON_GOLD_ALT
		"cta_red":
			b.rect.with_gradient(Tokens.RED_GRAD_TOP, Tokens.RED_GRAD_BOTTOM)
			b.rect.border_color = Color.WHITE
			b.rect.border_width = 3.0
			b.rect.shadow_color = Tokens.RED_SHADOW
			text_color = Color.WHITE
		"secondary":
			b.rect.fill_top = Tokens.BG_CARD
			b.rect.border_color = Tokens.BORDER
			b.rect.border_width = 2.0
			b._shadow_h = 0.0
			text_color = Tokens.white(0.75)
		"tertiary":
			b.rect.fill_top = Color(0, 0, 0, 0)
			b._shadow_h = 0.0
			text_color = Tokens.white(0.5)
		_:
			assert(false, "unknown ChunkyButton kind: " + kind)
	b.rect.shadow_offset = Vector2(0, b._shadow_h)
	b._shadow_color = b.rect.shadow_color
	UI.fill(b, b.rect)

	var row := UI.hbox(8, BoxContainer.ALIGNMENT_CENTER)
	if icon != "":
		row.add_child(Icons.rect(icon, font_size + 3, text_color))
	var label := UI.display(text.to_upper(), font_size, text_color)
	row.add_child(label)

	b._content = UI.margin(0)
	UI.fill(b, b._content)
	b._content.add_child(row)

	var content_min := row.get_combined_minimum_size()
	b.custom_minimum_size = Vector2(
		maxf(min_size.x, content_min.x + _PAD_H * 2.0), h)
	return b


func _process(_delta: float) -> void:
	var mode := int(get_draw_mode())
	if mode == _last_mode:
		return
	_last_mode = mode
	var down := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	modulate.a = 0.55 if mode == DRAW_DISABLED else 1.0
	var dy := _shadow_h if down else 0.0
	for c: Control in [rect, _content]:
		c.offset_top = dy
		c.offset_bottom = dy
	rect.shadow_color = Color(_shadow_color, 0.0) if down else _shadow_color
	rect.queue_redraw()
