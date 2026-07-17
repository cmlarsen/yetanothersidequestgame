class_name UI
## Factory helpers that keep screen code close to the mock structure.
## Text styles per the handoff: display = Lilita One (uppercase copy),
## body = Nunito 600–900, micro = Nunito 800 8–10px letter-spaced uppercase.


static func display(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Tokens.display_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func body(text: String, size: int, color: Color = Color.WHITE, weight: int = 700) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Tokens.body_font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func micro(text: String, size: int = 9, color: Color = Color.WHITE, spacing: int = 1) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", Tokens.body_font(800, spacing))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Hard text shadow (mock: text-shadow 0 Npx 0 <color>).
static func shadowed(l: Label, color: Color, offset_y: int = 3) -> Label:
	l.add_theme_color_override("font_shadow_color", color)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", offset_y)
	return l


static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# ── Layout ──────────────────────────────────────────────────────────────────

static func vbox(gap: int = 0, alignment: BoxContainer.AlignmentMode = BoxContainer.ALIGNMENT_BEGIN) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", gap)
	b.alignment = alignment
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func hbox(gap: int = 0, alignment: BoxContainer.AlignmentMode = BoxContainer.ALIGNMENT_BEGIN) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", gap)
	b.alignment = alignment
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func spacer(min_size: float = 0.0) -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(min_size, min_size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func margin(left: int, top: int = -1, right: int = -1, bottom: int = -1) -> MarginContainer:
	if top < 0:
		top = left
	if right < 0:
		right = left
	if bottom < 0:
		bottom = top
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


## Absolutely-positioned child inside a free-position parent (the mocks are
## position:absolute-heavy; screens mirror that with place()).
static func place(parent: Control, child: Control, pos: Vector2, child_size: Vector2 = Vector2.ZERO) -> Control:
	parent.add_child(child)
	child.position = pos
	if child_size != Vector2.ZERO:
		child.size = child_size
		child.custom_minimum_size = child_size
	return child


## Center a control horizontally at a given y (mock: left:50%; translateX(-50%)).
## Anchor-based so it stays centered as the child's content resizes it.
static func place_centered_x(parent: Control, child: Control, y: float, child_size: Vector2 = Vector2.ZERO) -> Control:
	parent.add_child(child)
	if child_size != Vector2.ZERO:
		child.custom_minimum_size = child_size
	child.anchor_left = 0.5
	child.anchor_right = 0.5
	child.grow_horizontal = Control.GROW_DIRECTION_BOTH
	child.offset_left = 0.0
	child.offset_right = 0.0
	child.offset_top = y
	child.offset_bottom = y
	return child


## Full-rect fill helper.
static func fill(parent: Control, child: Control) -> Control:
	parent.add_child(child)
	child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return child
