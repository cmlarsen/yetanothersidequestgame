class_name HexGridMap
extends Control
## Port of the design-canvas hex generator (scratch dc-script / dc.html DCLogic):
## pointy-top hexes (corners at 60·i−30°) on a √3·r × 1.5·r grid, odd rows
## offset half a column; each hex takes the style of the first zone circle
## whose center is closer than the zone radius. Decorations (sand paths, tree
## and water blobs) draw after the hexes. Zone geometry in the presets is
## copied verbatim from the script so the shell matches the mocks pixel-close.

# Colors that exist only inside the dc-script (not in the token sheet):
# neutral hex line rgba(50,80,10,·), fog fill rgba(13,18,30,·), deep-fog line
# rgba(30,38,58,·). Kept file-local until promoted to Tokens.
const _HEX_LINE := Color(50.0 / 255.0, 80.0 / 255.0, 10.0 / 255.0)
const _FOG := Color(13.0 / 255.0, 18.0 / 255.0, 30.0 / 255.0)
const _FOG_LINE := Color(30.0 / 255.0, 38.0 / 255.0, 58.0 / 255.0)

var hex_radius: float = 34.0
## The script draws r−1 hexes on the r grid (r−2 on the r=72 combat preset).
var hex_inset: float = 1.0
## {center: Vector2, radius: float, fill: Color, stroke: Color, width: float,
##  dashed: bool, dash_len: float, gap_len: float} — first match classifies.
var zones: Array[Dictionary] = []
var default_fill: Color = Tokens.white(0.03)
var default_stroke: Color = Color(_HEX_LINE, 0.22)
var default_width: float = 1.5
## {points: PackedVector2Array, width: float} — sand roads (edge + fill).
var paths: Array[Dictionary] = []
var trees: Array[Vector2] = []
## {center: Vector2, radius: float} — water blobs with a lighter rim.
var water: Array[Dictionary] = []
## Live-world overlay (additive): per-hex styles keyed by the server's "q,r"
## axial keys ({fill: Color, stroke: Color, width: float[, dashed…]}); cells
## win over zones in the same classification pass. Setting px_per_m > 0 swaps
## the lattice to the flat-top 60 m world grid (Geo frame: x east, y north)
## projected via  screen = world_offset + (x, −y)·px_per_m;  px_per_m == 0
## keeps the classic screen-space pointy-top grid byte-identical.
var cells: Dictionary = {}
var world_offset := Vector2.ZERO
var px_per_m := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


static func _sized() -> HexGridMap:
	var m := HexGridMap.new()
	m.custom_minimum_size = Screen.DESIGN_SIZE
	m.size = Screen.DESIGN_SIZE
	return m


## Exploration map (hexesA): contested ring, player turf, gloom spread.
static func preset_a() -> HexGridMap:
	var m := _sized()
	m.hex_radius = 34.0
	m.hex_inset = 1.0
	var zs: Array[Dictionary] = [
		{"center": Vector2(206, 357), "radius": 20.0, "fill": Color(Tokens.WARNING, 0.38),
			"stroke": Tokens.WARNING, "width": 3.0, "dashed": true, "dash_len": 7.0, "gap_len": 5.0},
		{"center": Vector2(177, 510), "radius": 105.0, "fill": Color(Tokens.TURF_PLAYER, 0.30),
			"stroke": Tokens.TURF_PLAYER, "width": 2.5},
		{"center": Vector2(118, 214), "radius": 90.0, "fill": Tokens.TURF_GLOOM,
			"stroke": Tokens.GLOOM_HEX, "width": 2.5},
	]
	m.zones = zs
	m.default_fill = Tokens.white(0.03)
	m.default_stroke = Color(_HEX_LINE, 0.22)
	m.default_width = 1.5
	return m


## Combat map (hexesB): big r=72 hexes around the brawl.
static func preset_b() -> HexGridMap:
	var m := _sized()
	m.hex_radius = 72.0
	m.hex_inset = 2.0
	var zs: Array[Dictionary] = [
		{"center": Vector2(201, 430), "radius": 45.0, "fill": Color(Tokens.WARNING, 0.28),
			"stroke": Tokens.WARNING, "width": 4.0, "dashed": true, "dash_len": 10.0, "gap_len": 7.0},
		{"center": Vector2(110, 590), "radius": 90.0, "fill": Color(Tokens.TURF_PLAYER, 0.24),
			"stroke": Tokens.TURF_PLAYER, "width": 3.0},
		{"center": Vector2(310, 240), "radius": 130.0, "fill": Color(Tokens.TURF_GLOOM, 0.22),
			"stroke": Tokens.GLOOM_HEX, "width": 3.0},
	]
	m.zones = zs
	m.default_fill = Tokens.white(0.02)
	m.default_stroke = Color(_HEX_LINE, 0.20)
	m.default_width = 2.0
	return m


## Fog map (hexesC): four tiers by distance from one center — turf, neutral,
## dim fog, deep fog. Concentric zones give the same first-match classing.
static func preset_c() -> HexGridMap:
	var m := _sized()
	m.hex_radius = 34.0
	m.hex_inset = 1.0
	var zs: Array[Dictionary] = [
		{"center": Vector2(201, 620), "radius": 130.0, "fill": Color(Tokens.TURF_PLAYER, 0.30),
			"stroke": Tokens.TURF_PLAYER, "width": 2.5},
		{"center": Vector2(201, 620), "radius": 205.0, "fill": Tokens.white(0.04),
			"stroke": Color(_HEX_LINE, 0.25), "width": 1.5},
		{"center": Vector2(201, 620), "radius": 275.0, "fill": Color(_FOG, 0.55),
			"stroke": Color(Tokens.BG_PANEL, 0.7), "width": 2.0},
	]
	m.zones = zs
	m.default_fill = Color(_FOG, 0.92)
	m.default_stroke = Color(_FOG_LINE, 0.9)
	m.default_width = 2.0
	return m


func _classify(p: Vector2) -> Dictionary:
	for z in zones:
		var center: Vector2 = z["center"]
		if p.distance_to(center) < float(z["radius"]):
			return z
	return {"fill": default_fill, "stroke": default_stroke, "width": default_width}


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if px_per_m > 0.0:
		_draw_world_hexes()
	else:
		_draw_screen_hexes()
	for p in paths:
		_draw_path(p)
	for w in water:
		_draw_water(w)
	for t in trees:
		_draw_tree(t)


func _draw_screen_hexes() -> void:
	var hw := sqrt(3.0) * hex_radius
	var vs := 1.5 * hex_radius
	var draw_r := hex_radius - hex_inset
	var row := 0
	while row * vs < size.y + hex_radius:
		var col := -1
		while col * hw < size.x + hw:
			var cx := col * hw + (hw / 2.0 if row % 2 == 1 else 0.0)
			var cy := row * vs
			_draw_hex(Vector2(cx, cy), draw_r, _classify(Vector2(cx, cy)))
			col += 1
		row += 1


## The world lattice pass: every flat-top 60 m hex whose center projects into
## the viewport, styled by cells first, zones/default second. Corner at 0°
## (flat-top) vs the decorative grid's −30° (pointy-top).
func _draw_world_hexes() -> void:
	var col_w := 1.5 * Geo.HEX_R
	var row_h := sqrt(3.0) * Geo.HEX_R
	var draw_r := Geo.HEX_R * px_per_m - hex_inset
	var wx_min := -world_offset.x / px_per_m
	var wx_max := (size.x - world_offset.x) / px_per_m
	var wy_min := (world_offset.y - size.y) / px_per_m
	var wy_max := world_offset.y / px_per_m
	var q_min := int(floor(wx_min / col_w)) - 1
	var q_max := int(ceil(wx_max / col_w)) + 1
	for q in range(q_min, q_max + 1):
		var r_min := int(floor(wy_min / row_h - q / 2.0)) - 1
		var r_max := int(ceil(wy_max / row_h - q / 2.0)) + 1
		for r in range(r_min, r_max + 1):
			var w := Geo.hex_center(q, r)
			var c := world_offset + Vector2(w.x, -w.y) * px_per_m
			var cls: Dictionary = cells.get(Geo.hex_key(q, r), {})
			if cls.is_empty():
				cls = _classify(c)
			_draw_hex(c, draw_r, cls, 0.0)


func _draw_hex(c: Vector2, r: float, cls: Dictionary, corner0_deg: float = -30.0) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i + corner0_deg)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	var fill: Color = cls["fill"]
	if fill.a > 0.0:
		draw_colored_polygon(pts, fill)
	var stroke: Color = cls["stroke"]
	var width: float = cls["width"]
	if stroke.a <= 0.0 or width <= 0.0:
		return
	var loop := pts.duplicate()
	loop.append(pts[0])
	if bool(cls.get("dashed", false)):
		_draw_dashed_loop(loop, stroke, width,
			float(cls.get("dash_len", 7.0)), float(cls.get("gap_len", 5.0)))
	else:
		draw_polyline(loop, stroke, width, true)


func _draw_dashed_loop(loop: PackedVector2Array, color: Color, width: float,
		dash_len: float, gap_len: float) -> void:
	var carry := 0.0
	var drawing := true
	for i in loop.size() - 1:
		var a := loop[i]
		var b := loop[i + 1]
		var seg_len := a.distance_to(b)
		if seg_len <= 0.0:
			continue
		var dir := (b - a) / seg_len
		var t := 0.0
		while t < seg_len:
			var span := (dash_len if drawing else gap_len) - carry
			var step := minf(span, seg_len - t)
			if drawing:
				draw_line(a + dir * t, a + dir * (t + step), color, width, true)
			t += step
			if step >= span:
				drawing = not drawing
				carry = 0.0
			else:
				carry += step


func _draw_path(p: Dictionary) -> void:
	var pts: PackedVector2Array = p["points"]
	var width: float = p["width"]
	_stroke_round(pts, Tokens.MAP_PATH_EDGE, width + 6.0)
	_stroke_round(pts, Tokens.MAP_PATH, width)


## Godot polylines have butt caps/miter joints; circles at every vertex give
## the mock's round caps and smooth bends.
func _stroke_round(pts: PackedVector2Array, color: Color, width: float) -> void:
	if pts.size() >= 2:
		draw_polyline(pts, color, width, true)
	for pt in pts:
		draw_circle(pt, width / 2.0, color)


func _draw_tree(pos: Vector2) -> void:
	draw_circle(pos + Vector2(0, 7), 3.0, Tokens.MAP_TREE.darkened(0.4))
	draw_circle(pos + Vector2(-5, 3), 6.0, Tokens.MAP_TREE)
	draw_circle(pos + Vector2(5, 3), 6.0, Tokens.MAP_TREE)
	draw_circle(pos + Vector2(0, -3), 7.5, Tokens.MAP_TREE)


func _draw_water(w: Dictionary) -> void:
	var c: Vector2 = w["center"]
	var r: float = w["radius"]
	draw_circle(c, r, Tokens.MAP_WATER.lightened(0.3))
	draw_circle(c, maxf(r - 3.0, 1.0), Tokens.MAP_WATER)
