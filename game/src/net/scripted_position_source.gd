class_name ScriptedPositionSource
extends PositionProvider
## Follows an Array of metre waypoints at walking speed — recorded/scripted
## routes for tests and demos. Fixes at ≤4 Hz while moving, one final fix on
## arrival. Synthetic routes never report speedKmh (< 0 = omit): test routes
## can run faster than a walk and an honest speed would trip the §14
## speed-pause claim guard.
##
## hop mode (the live-check gate): instead of continuous motion, jump to the
## next waypoint every hop_interval_s and emit one fix. Waypoints spaced
## > GPS_TELEPORT_M (60 m) ride the server's relocation snap — the pawn
## teleports with no claim trail — so each hop claims exactly the hex it
## lands in. The only way to cover 6+ 60 m hexes inside a CI budget.

signal route_done

var waypoints: Array[Vector2] = []
var speed_mps := 1.4
var loop := false
var done := false
var hop := false
var hop_interval_s := 0.7

var _index := 0
var _since_fix := 0.0
var _since_hop := 0.0
var _started := false


func _process(delta: float) -> void:
	if done or waypoints.is_empty() or not has_origin():
		return
	if not _started:
		_started = true
		pos_m = waypoints[0]
		_index = 1 if waypoints.size() > 1 else 0
		emit_fix(ACCURACY_M, -1.0)
	if hop:
		_since_hop += delta
		if _since_hop >= hop_interval_s:
			_since_hop = 0.0
			pos_m = waypoints[_index]
			emit_fix(ACCURACY_M, -1.0)
			_index += 1
			if _index >= waypoints.size():
				if loop:
					_index = 0
				else:
					done = true
					route_done.emit()
		return
	var remaining := speed_mps * delta
	while remaining > 0.0 and not done:
		var target := waypoints[_index]
		var d := pos_m.distance_to(target)
		if d <= remaining:
			pos_m = target
			remaining -= d
			_index += 1
			if _index >= waypoints.size():
				if loop:
					_index = 0
				else:
					done = true
					emit_fix(ACCURACY_M, -1.0)
					route_done.emit()
		else:
			pos_m += (target - pos_m) / d * remaining
			remaining = 0.0
	_since_fix += delta
	if not done and _since_fix >= 1.0 / FIX_HZ:
		emit_fix(ACCURACY_M, -1.0)
		_since_fix = 0.0


## Axial spiral from the centre hex outward (redblob cube_spiral over
## Geo.HEX_DIRECTIONS), as metre-space waypoints offset by center_m.
static func spiral_route(hex_count: int, center_m := Vector2.ZERO) -> Array[Vector2]:
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var k := 1
	while cells.size() < hex_count:
		var hex := Vector2i(0, -k)  # k * HEX_DIRECTIONS[4], the ring's start corner
		for dir_i in 6:
			for _step in k:
				if cells.size() >= hex_count:
					break
				cells.append(hex)
				hex += Geo.HEX_DIRECTIONS[dir_i]
		k += 1
	var out: Array[Vector2] = []
	for c in cells:
		out.append(Geo.hex_center(c.x, c.y) + center_m)
	return out
