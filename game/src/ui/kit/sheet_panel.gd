class_name SheetPanel
extends Control
## Bottom sheet (NPC dialogue, tower manage): BG_PANEL, 26px top radius, 3px
## accent border on top+sides (the body extends past the screen bottom so the
## border's bottom edge never shows), 36×5 drag handle. Callers place it at
## the bottom via UI.place and add children to `content`.

const _BLEED := 40.0

var content: VBoxContainer


static func make(accent: Color, height: float) -> SheetPanel:
	var s := SheetPanel.new()
	s.custom_minimum_size = Vector2(Screen.DESIGN_SIZE.x, height)
	var body := ChunkyRect.panel(Tokens.BG_PANEL, 0.0, accent, 3.0)
	body.corner_radii = Vector4(26, 26, 0, 0)
	UI.fill(s, body)
	body.offset_bottom = _BLEED

	var pad := UI.margin(18, 10, 18, 28)
	UI.fill(s, pad)
	var column := UI.vbox(12)
	pad.add_child(column)

	var handle_row := CenterContainer.new()
	handle_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var handle := ChunkyRect.panel(Tokens.BORDER, 3.0)
	handle.custom_minimum_size = Vector2(36, 5)
	handle_row.add_child(handle)
	column.add_child(handle_row)

	s.content = UI.vbox(12)
	s.content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(s.content)
	return s
