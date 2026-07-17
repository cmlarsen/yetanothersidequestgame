class_name AvatarFace
extends Control
## Circle-cropped face portrait with a ring border, optional conic HP arc
## around the outside (combat/exploration pins) and status dots.

const _SEGMENTS := 48
# Depleted-HP track color from the combat mock's conic-gradient (#26331f).
const _HP_REST := Color(38.0 / 255.0, 51.0 / 255.0, 31.0 / 255.0)
const _HP_WIDTH := 5.0

var _diameter: float = 56.0
var _ring_color: Color = Color.WHITE
var _ring_width: float = 3.0
var _tex: Texture2D
var _hp_ratio: float = -1.0
var _hp_color: Color = Tokens.GREEN_GRAD_TOP
var _status_dots: Array[Color] = []


static func make(face_id: String, diameter: float, ring_color: Color = Color.WHITE,
		ring_width: float = 3.0) -> AvatarFace:
	var a := AvatarFace.new()
	a._diameter = diameter
	a._ring_color = ring_color
	a._ring_width = ring_width
	a._tex = load("res://assets/ui/faces/face-%s.png" % face_id)
	a.custom_minimum_size = Vector2(diameter, diameter)
	a.size = Vector2(diameter, diameter)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return a


func set_hp_ring(ratio: float, color: Color) -> void:
	_hp_ratio = clampf(ratio, 0.0, 1.0)
	_hp_color = color
	queue_redraw()


func add_status_dot(color: Color) -> void:
	_status_dots.append(color)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var face_r := _diameter / 2.0 - _ring_width
	if _hp_ratio >= 0.0:
		var hp_r := _diameter / 2.0 + _HP_WIDTH / 2.0
		draw_arc(c, hp_r, 0.0, TAU, 64, _HP_REST, _HP_WIDTH, true)
		if _hp_ratio > 0.0:
			draw_arc(c, hp_r, -PI / 2.0, -PI / 2.0 + TAU * _hp_ratio,
				maxi(8, int(64.0 * _hp_ratio)), _hp_color, _HP_WIDTH, true)
	if _tex != null:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in _SEGMENTS:
			var a := TAU * float(i) / _SEGMENTS
			var v := Vector2(cos(a), sin(a))
			pts.append(c + v * face_r)
			uvs.append(Vector2(0.5, 0.5) + v * 0.5)
		draw_colored_polygon(pts, Color.WHITE, uvs, _tex)
	if _ring_width > 0.0:
		draw_arc(c, face_r + _ring_width / 2.0, 0.0, TAU, 64, _ring_color, _ring_width, true)
	for i in _status_dots.size():
		var pos := c + Vector2.ONE.normalized() * face_r - Vector2(float(i) * 13.0, 0.0)
		draw_circle(pos, 6.5, Tokens.BG_PANEL)
		draw_circle(pos, 5.0, _status_dots[i])
