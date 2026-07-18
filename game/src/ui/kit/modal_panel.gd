class_name ModalPanel
extends PanelContainer
## Centered dialog card (info popover, confirms): radius 22, 3px accent
## border, hard shadow. Height hugs whatever callers add to `content`;
## callers center it with UI.place_centered_x / UI.place.

var content: VBoxContainer


static func make(accent: Color, width: float) -> ModalPanel:
	var m := ModalPanel.new()
	m.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	m.custom_minimum_size = Vector2(width, 0)
	var body := ChunkyRect.panel(Tokens.BG_PANEL, 22.0, accent, 3.0,
		Color(Tokens.BG_INSET, 0.5))
	body.shadow_offset = Vector2(0, 7)
	m.add_child(body)
	var pad := UI.margin(16, 15)
	m.add_child(pad)
	m.content = UI.vbox(10)
	pad.add_child(m.content)
	return m
