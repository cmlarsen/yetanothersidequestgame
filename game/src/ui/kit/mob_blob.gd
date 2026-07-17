class_name MobBlob
extends Control
## The purple Gloomling sphere from the combat/popover mocks: radial gradient
## approximated with concentric circles drifting toward a 35%/30% highlight,
## chunky GLOOM_BORDER ring, hard offset shadow, centered white icon.

# Hard shadow under the blob (mock: 0 10px 0 rgba(40,15,90,.35)).
const _SHADOW := Color(40.0 / 255.0, 15.0 / 255.0, 90.0 / 255.0, 0.35)
const _LAYERS := 24
const _BORDER_WIDTH := 4.0


static func make(diameter: float = 96.0, icon: String = "shroom") -> MobBlob:
	var m := MobBlob.new()
	m.custom_minimum_size = Vector2(diameter, diameter)
	m.size = Vector2(diameter, diameter)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_px := int(diameter * 0.45)
	var tr := Icons.rect(icon, icon_px, Color.WHITE)
	m.add_child(tr)
	tr.position = (Vector2(diameter, diameter) - Vector2(icon_px, icon_px)) / 2.0
	return m


func _draw() -> void:
	var r := size.x / 2.0
	var c := size / 2.0
	draw_circle(c + Vector2(0, 10), r, _SHADOW)
	var highlight := Vector2(size.x * 0.35, size.y * 0.30)
	for i in _LAYERS:
		var t := float(i) / float(_LAYERS - 1)
		var col := Tokens.GLOOM_GRAD_BOTTOM.lerp(Tokens.GLOOM_GRAD_TOP, t)
		draw_circle(c.lerp(highlight, t * 0.8), r * (1.0 - t * 0.85), col)
	draw_arc(c, r - _BORDER_WIDTH / 2.0, 0.0, TAU, 64, Tokens.GLOOM_BORDER, _BORDER_WIDTH, true)
