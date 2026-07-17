class_name Placeholder3D
## Marks every region the real app fills with a KayKit render ("3D KEY ART
## RENDER", "ART"): transparent box, dashed 2px border, centered micro label.


static func make(p_size: Vector2, label: String) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = p_size
	var box := ChunkyRect.new()
	box.fill_top = Color(0, 0, 0, 0)
	box.border_color = Tokens.white(0.25)
	box.border_width = 2.0
	box.corner_radius = 12.0
	box.dashed = true
	UI.fill(root, box)
	var text := UI.centered(UI.wrap(UI.micro(label, 8, Tokens.white(0.45))))
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.fill(root, text)
	return root
