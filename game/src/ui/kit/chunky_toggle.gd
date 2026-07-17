class_name ChunkyToggle
extends BaseButton
## Settings toggle (chunk 23): 44×26 pill, white knob, cyan when on / inset
## border color when off. The button itself is a 44×44 hit target with the
## pill centered vertically.

signal toggled_changed(on: bool)

const _PILL_SIZE := Vector2(44, 26)
const _KNOB := 20.0
const _INSET := 3.0

var is_on: bool = true

var _track: ChunkyRect
var _knob: ChunkyRect


static func make(on: bool = true) -> ChunkyToggle:
	var t := ChunkyToggle.new()
	t.custom_minimum_size = Vector2(44, 44)
	var pill := Control.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(pill)
	pill.set_anchors_preset(Control.PRESET_CENTER)
	pill.offset_left = -_PILL_SIZE.x * 0.5
	pill.offset_right = _PILL_SIZE.x * 0.5
	pill.offset_top = -_PILL_SIZE.y * 0.5
	pill.offset_bottom = _PILL_SIZE.y * 0.5
	t._track = ChunkyRect.panel(Tokens.BORDER, _PILL_SIZE.y * 0.5)
	UI.fill(pill, t._track)
	t._knob = ChunkyRect.panel(Color.WHITE, _KNOB * 0.5)
	t._knob.shadow_color = Color(Tokens.BG_INSET, 0.35)
	t._knob.shadow_offset = Vector2(0, 2)
	pill.add_child(t._knob)
	t._knob.position = Vector2(t._knob_x(on), _INSET)
	t._knob.size = Vector2(_KNOB, _KNOB)
	t.is_on = on
	t._restyle()
	t.pressed.connect(t._on_pressed)
	return t


func set_on(on: bool, animate: bool = true) -> void:
	if on == is_on:
		return
	is_on = on
	_restyle()
	if animate and not AppMode.freeze_motion:
		var tw := _knob.create_tween()
		tw.tween_property(_knob, "position:x", _knob_x(on), 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_knob.position.x = _knob_x(on)


func _knob_x(on: bool) -> float:
	return _PILL_SIZE.x - _INSET - _KNOB if on else _INSET


func _restyle() -> void:
	_track.fill_top = Tokens.CYAN if is_on else Tokens.BORDER
	_track.queue_redraw()


func _on_pressed() -> void:
	set_on(not is_on)
	toggled_changed.emit(is_on)
