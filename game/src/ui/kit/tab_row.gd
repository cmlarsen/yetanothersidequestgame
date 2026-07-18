class_name TabRow
extends HBoxContainer
## Pill tab strip (quest board DAILY/STORY/TERRITORY, tower target priority).
## Active pill is flat cyan with a hard shadow; inactive pills sit dim on card
## bg. Buttons are 44px hit targets; the 26px pill visual centers inside.

signal tab_changed(i: int)

const _PILL_H := 26.0
const _PAD_H := 14.0

var active: int = -1

var _rects: Array[ChunkyRect] = []
var _labels: Array[Label] = []


static func make(tabs: Array[String], p_active: int = 0) -> TabRow:
	var row := TabRow.new()
	row.add_theme_constant_override("separation", 6)
	for i in tabs.size():
		var b := BaseButton.new()
		var rect := ChunkyRect.new()
		rect.corner_radius = 9.0
		b.add_child(rect)
		rect.anchor_left = 0.0
		rect.anchor_right = 1.0
		rect.anchor_top = 0.5
		rect.anchor_bottom = 0.5
		rect.offset_top = -_PILL_H * 0.5
		rect.offset_bottom = _PILL_H * 0.5
		var label := UI.display(tabs[i].to_upper(), 11)
		UI.fill(b, label)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(
			maxf(44.0, label.get_combined_minimum_size().x + _PAD_H * 2.0), 44.0)
		b.pressed.connect(row._on_tab_pressed.bind(i))
		row.add_child(b)
		row._rects.append(rect)
		row._labels.append(label)
	row.set_active(p_active)
	return row


func set_active(i: int) -> void:
	active = i
	for t in _rects.size():
		var rect := _rects[t]
		var on := t == i
		rect.fill_top = Tokens.CYAN if on else Tokens.BG_CARD
		rect.border_color = Color(0, 0, 0, 0) if on else Tokens.BORDER
		rect.border_width = 0.0 if on else 1.5
		rect.shadow_color = Tokens.CYAN_SHADOW if on else Color(0, 0, 0, 0)
		rect.shadow_offset = Vector2(0, 3)
		rect.queue_redraw()
		_labels[t].add_theme_color_override(
			"font_color", Tokens.ON_CYAN if on else Tokens.white(0.45))


func _on_tab_pressed(i: int) -> void:
	if i == active:
		return
	set_active(i)
	tab_changed.emit(i)
