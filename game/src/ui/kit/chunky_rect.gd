class_name ChunkyRect
extends Control
## The chunky-toy rectangle behind every panel, card, chip, and button:
## vertical-gradient fill, 2–3px border, HARD offset shadow (no blur), and an
## optional layered glow. Draws in local space over the control's full rect.

@export var fill_top: Color = Tokens.BG_CARD
@export var fill_bottom: Color = Color(0, 0, 0, 0):
	set(v):
		fill_bottom = v
		_has_bottom = true
		queue_redraw()
@export var border_color: Color = Color(0, 0, 0, 0)
@export var border_width: float = 0.0
@export var corner_radius: float = 12.0
## Per-corner radii (TL, TR, BR, BL); any negative component falls back to corner_radius.
@export var corner_radii: Vector4 = Vector4(-1, -1, -1, -1)
@export var shadow_color: Color = Color(0, 0, 0, 0)
@export var shadow_offset: Vector2 = Vector2(0, 4)
## Soft outer glow approximated with fading expanded layers (mocks: 0 0 18px …).
@export var glow_color: Color = Color(0, 0, 0, 0)
@export var glow_size: float = 0.0
## Dashed border (mocks: dashed placeholder boxes, contested-hex rings).
@export var dashed: bool = false
@export var dash_length: float = 8.0
@export var gap_length: float = 6.0

var _has_bottom := false

const _ARC_STEPS := 7


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


static func panel(top: Color, radius: float, p_border: Color = Color(0, 0, 0, 0),
		p_border_w: float = 0.0, p_shadow: Color = Color(0, 0, 0, 0)) -> ChunkyRect:
	var r := ChunkyRect.new()
	r.fill_top = top
	r.corner_radius = radius
	r.border_color = p_border
	r.border_width = p_border_w
	r.shadow_color = p_shadow
	return r


func with_gradient(top: Color, bottom: Color) -> ChunkyRect:
	fill_top = top
	fill_bottom = bottom
	return self


func _radii() -> Vector4:
	return Vector4(
		corner_radii.x if corner_radii.x >= 0.0 else corner_radius,
		corner_radii.y if corner_radii.y >= 0.0 else corner_radius,
		corner_radii.z if corner_radii.z >= 0.0 else corner_radius,
		corner_radii.w if corner_radii.w >= 0.0 else corner_radius)


## Rounded-rect outline as a closed point loop (TL → TR → BR → BL).
static func rounded_points(rect: Rect2, radii: Vector4) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var half := minf(rect.size.x, rect.size.y) * 0.5
	var r := Vector4(minf(radii.x, half), minf(radii.y, half), minf(radii.z, half), minf(radii.w, half))
	var corners: Array[Vector3] = [
		Vector3(rect.position.x + r.x, rect.position.y + r.x, r.x),
		Vector3(rect.end.x - r.y, rect.position.y + r.y, r.y),
		Vector3(rect.end.x - r.z, rect.end.y - r.z, r.z),
		Vector3(rect.position.x + r.w, rect.end.y - r.w, r.w),
	]
	for i in 4:
		var c := corners[i]
		var start_angle := PI + (PI / 2.0) * i
		if c.z <= 0.0:
			# Sharp corner: single point at the rect corner itself.
			var corner_pt := Vector2(c.x, c.y)
			pts.append(corner_pt)
			continue
		for s in _ARC_STEPS + 1:
			var a := start_angle + (PI / 2.0) * (float(s) / _ARC_STEPS)
			pts.append(Vector2(c.x, c.y) + Vector2(cos(a), sin(a)) * c.z)
	return pts


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var radii := _radii()
	var rect := Rect2(Vector2.ZERO, size)
	var pts := rounded_points(rect, radii)

	if glow_color.a > 0.0 and glow_size > 0.0:
		for layer in 3:
			var grow := glow_size * (float(layer + 1) / 3.0)
			var gpts := rounded_points(rect.grow(grow), radii + Vector4(grow, grow, grow, grow))
			var gc := glow_color
			gc.a = glow_color.a * (1.0 - float(layer) / 3.0) * 0.35
			draw_colored_polygon(gpts, gc)

	if shadow_color.a > 0.0:
		var spts := PackedVector2Array()
		for p in pts:
			spts.append(p + shadow_offset)
		draw_colored_polygon(spts, shadow_color)

	if fill_top.a > 0.0 or (_has_bottom and fill_bottom.a > 0.0):
		if _has_bottom:
			var colors := PackedColorArray()
			for p in pts:
				colors.append(fill_top.lerp(fill_bottom, clampf(p.y / size.y, 0.0, 1.0)))
			draw_polygon(pts, colors)
		else:
			draw_colored_polygon(pts, fill_top)

	if border_color.a > 0.0 and border_width > 0.0:
		var inset := border_width * 0.5
		var bradii := Vector4(
			maxf(radii.x - inset, 0.0), maxf(radii.y - inset, 0.0),
			maxf(radii.z - inset, 0.0), maxf(radii.w - inset, 0.0))
		var bpts := rounded_points(rect.grow(-inset), bradii)
		bpts.append(bpts[0])
		if dashed:
			_draw_dashed(bpts)
		else:
			draw_polyline(bpts, border_color, border_width, true)


func _draw_dashed(loop: PackedVector2Array) -> void:
	var carry := 0.0
	var drawing := true
	for i in loop.size() - 1:
		var a := loop[i]
		var b := loop[i + 1]
		var seg_len := a.distance_to(b)
		var dir := (b - a) / seg_len if seg_len > 0.0 else Vector2.ZERO
		var t := 0.0
		while t < seg_len:
			var span := (dash_length if drawing else gap_length) - carry
			var step := minf(span, seg_len - t)
			if drawing:
				draw_line(a + dir * t, a + dir * (t + step), border_color, border_width, true)
			t += step
			if step >= span:
				drawing = not drawing
				carry = 0.0
			else:
				carry += step
