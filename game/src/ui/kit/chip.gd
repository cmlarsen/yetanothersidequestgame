class_name Chip
## Generic pill/chip sized to its content: optional leading icon or emoji +
## text over a ChunkyRect. Non-interactive; defaults to the inset dark chip
## with a BORDER outline seen all over the mocks.


static func make(text: String, opts: Dictionary = {}) -> Control:
	var font: String = opts.get("font", "micro")
	var default_size := 9 if font == "micro" else (11 if font == "body" else 12)
	var font_size: int = opts.get("font_size", default_size)
	var text_color: Color = opts.get("text_color", Color.WHITE)
	var pad_h: float = opts.get("pad_h", 9.0)
	var pad_v: float = opts.get("pad_v", 4.0)

	var rect := ChunkyRect.new()
	rect.fill_top = opts.get("bg", Tokens.BG_CARD)
	if opts.has("bg_bottom"):
		rect.fill_bottom = opts["bg_bottom"]
	rect.border_color = opts.get("border", Tokens.BORDER)
	rect.border_width = opts.get("border_w", 2.0)
	rect.corner_radius = opts.get("radius", 9.0)
	if opts.has("shadow"):
		rect.shadow_color = opts["shadow"]
		rect.shadow_offset = Vector2(0, 3)

	var row := UI.hbox(6, BoxContainer.ALIGNMENT_CENTER)
	if opts.has("icon"):
		var icon_px := font_size + 4
		row.add_child(Icons.rect(opts["icon"], icon_px, opts.get("icon_color", text_color)))
	if opts.has("emoji"):
		row.add_child(UI.body(opts["emoji"], font_size + 1, Color.WHITE, 800))
	var label: Label
	match font:
		"micro":
			label = UI.micro(text, font_size, text_color)
		"body":
			label = UI.body(text, font_size, text_color, 800)
		_:
			label = UI.display(text, font_size, text_color)
	row.add_child(label)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(root, rect)
	var content := UI.margin(int(pad_h), int(pad_v))
	UI.fill(root, content)
	content.add_child(row)
	var content_min := row.get_combined_minimum_size()
	root.custom_minimum_size = content_min + Vector2(pad_h, pad_v) * 2.0
	return root
