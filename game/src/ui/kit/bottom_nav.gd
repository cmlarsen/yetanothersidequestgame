class_name BottomNav
extends Control
## 84px bottom tab bar (chunk 06): panel bg, 2px top border, 5 icon+label
## tabs. Optional big round run button overlapping upward through the bar
## (it covers the middle tab while shown).

signal tab_selected(id: String)
signal center_pressed

const HEIGHT := 84.0
const _TABS: Array[Array] = [
	["home", "home", "HOME"],
	["map", "map", "MAP"],
	["party", "party", "PARTY"],
	["items", "bag", "ITEMS"],
	["more", "dots", "MORE"],
]
const _CENTER_D := 62.0
const _CENTER_SHADOW := 5.0

var active: String = ""

var _icons: Dictionary = {}
var _labels: Dictionary = {}
var _center_rect: ChunkyRect
var _center_icon: Control


static func make(p_active: String, with_center_button: bool = false) -> BottomNav:
	var nav := BottomNav.new()
	nav.custom_minimum_size = Vector2(Screen.DESIGN_SIZE.x, HEIGHT)
	var bg := ColorRect.new()
	bg.color = Tokens.BG_PANEL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(nav, bg)
	var top_line := ColorRect.new()
	top_line.color = Tokens.BORDER
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(nav, top_line)
	top_line.anchor_bottom = 0.0
	top_line.offset_bottom = 2.0

	var row := UI.hbox(0)
	UI.fill(nav, row)
	for tab in _TABS:
		var id: String = tab[0]
		var b := BaseButton.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(44, HEIGHT)
		var col := UI.vbox(3, BoxContainer.ALIGNMENT_CENTER)
		UI.fill(b, col)
		var icon := Icons.rect(tab[1], 22, Tokens.white(0.4))
		var wrap := CenterContainer.new()
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(icon)
		col.add_child(wrap)
		var label := UI.centered(UI.micro(tab[2], 9, Tokens.white(0.4)))
		col.add_child(label)
		b.pressed.connect(nav._on_tab_pressed.bind(id))
		row.add_child(b)
		nav._icons[id] = icon
		nav._labels[id] = label
	nav.set_active(p_active)

	if with_center_button:
		nav._add_center_button()
	return nav


func set_active(id: String) -> void:
	active = id
	for tab in _TABS:
		var tab_id: String = tab[0]
		var color := Tokens.CYAN if tab_id == id else Tokens.white(0.4)
		var icon: TextureRect = _icons[tab_id]
		icon.texture = Icons.tex(tab[1], 22, color)
		var label: Label = _labels[tab_id]
		label.add_theme_color_override("font_color", color)


func _on_tab_pressed(id: String) -> void:
	if id == active:
		return
	set_active(id)
	tab_selected.emit(id)


func _add_center_button() -> void:
	var b := BaseButton.new()
	add_child(b)
	b.anchor_left = 0.5
	b.anchor_right = 0.5
	b.offset_left = -_CENTER_D * 0.5
	b.offset_right = _CENTER_D * 0.5
	b.offset_top = -_CENTER_D * 0.42
	b.offset_bottom = _CENTER_D * 0.58
	_center_rect = ChunkyRect.new()
	_center_rect.with_gradient(Tokens.CYAN_GRAD_TOP, Tokens.CYAN_GRAD_BOTTOM)
	_center_rect.corner_radius = _CENTER_D * 0.5
	_center_rect.border_color = Color.WHITE
	_center_rect.border_width = 3.0
	_center_rect.shadow_color = Tokens.CYAN_SHADOW
	_center_rect.shadow_offset = Vector2(0, _CENTER_SHADOW)
	UI.fill(b, _center_rect)
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fill(b, wrap)
	wrap.add_child(Icons.rect("steps", 28, Tokens.ON_CYAN))
	_center_icon = wrap
	b.button_down.connect(_on_center_down.bind(true))
	b.button_up.connect(_on_center_down.bind(false))
	b.pressed.connect(func() -> void: center_pressed.emit())


func _on_center_down(down: bool) -> void:
	var dy := _CENTER_SHADOW if down else 0.0
	for c: Control in [_center_rect, _center_icon]:
		c.offset_top = dy
		c.offset_bottom = dy
	_center_rect.shadow_color = Color(Tokens.CYAN_SHADOW, 0.0 if down else 1.0)
	_center_rect.queue_redraw()
