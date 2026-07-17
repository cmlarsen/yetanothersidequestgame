class_name RingPulse
extends Control
## Attention ring (mock keyframe "ringpulse"): scales 1→1.25 while fading,
## looping. Frozen mid-pulse (scale 1.1, alpha .6) when motion is off so
## screenshots still show it.

const _PERIOD := 1.8

var _radius: float = 30.0
var _color: Color = Color.WHITE
var _width: float = 4.0
var _dashed: bool = false


static func make(radius: float, color: Color, width: float = 4.0,
		dashed: bool = false) -> RingPulse:
	var rp := RingPulse.new()
	rp._radius = radius
	rp._color = color
	rp._width = width
	rp._dashed = dashed
	var side := radius * 2.0 + width
	rp.custom_minimum_size = Vector2(side, side)
	rp.size = Vector2(side, side)
	rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rp


func _ready() -> void:
	pivot_offset = size / 2.0
	if AppMode.freeze_motion:
		scale = Vector2(1.1, 1.1)
		modulate.a = 0.6
		return
	var tw := create_tween().set_loops()
	tw.tween_property(self, "scale", Vector2(1.25, 1.25), _PERIOD) \
		.from(Vector2.ONE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, _PERIOD).from(0.9)


func _draw() -> void:
	var c := size / 2.0
	if not _dashed:
		draw_arc(c, _radius, 0.0, TAU, 64, _color, _width, true)
		return
	var n := maxi(8, int(round(TAU * _radius / 18.0)))
	var seg := TAU / float(n)
	for i in n:
		draw_arc(c, _radius, seg * i, seg * (float(i) + 0.62), 6, _color, _width, true)
