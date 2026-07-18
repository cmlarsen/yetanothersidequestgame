class_name Geo
## Client mirror of server/shared/geo.ts (equirectangular projection) and
## server/shared/hexgrid.ts (60 m flat-top axial lattice). The math must match
## the server EXACTLY — a claimed hex has to line up with the tile drawn under
## it — so constants and formulas are ported 1:1, and rounding mirrors JS
## Math.round (half-up) rather than GDScript roundf (half-away-from-zero).
##
## Cross-check numbers (validated against the TS source):
##   hex_center(1, 0)  == (51.96152422706631, 30.0)
##   hex_center(0, 1)  == (0.0, 60.0)
##   hex_center(2, -1) == (103.92304845413263, 0.0)
##   hex_at(52.0, 30.0) == (1, 0);  hex_at(0.0, 0.0) == (0, 0)
##   project({37.7749,-122.4194}, {37.7758,-122.4194}) == (0.0, ~100.0754)
##   unproject({37.7749,-122.4194}, (100, 100)) == (~37.7757993, ~-122.4182623)

const EARTH_R := 6371000.0
const HEX_ACROSS_M := 60.0

## circumradius (centre → corner) derived from the flat-to-flat width.
const HEX_R := HEX_ACROSS_M / sqrt(3.0)

## The 6 axial direction offsets, CCW starting east-northeast (+q).
const HEX_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
]


## project(origin, {lat,lng}) → metres (x east, y north) from origin.
static func project(origin: Dictionary, lat: float, lng: float) -> Vector2:
	var x := deg_to_rad(lng - float(origin["lng"])) * EARTH_R * cos(deg_to_rad(float(origin["lat"])))
	var y := deg_to_rad(lat - float(origin["lat"])) * EARTH_R
	return Vector2(x, y)


## unproject(origin, metres) → {lat, lng}. Exact inverse of project.
static func unproject(origin: Dictionary, v: Vector2) -> Dictionary:
	var lat := float(origin["lat"]) + rad_to_deg(v.y / EARTH_R)
	var lng := float(origin["lng"]) + rad_to_deg(v.x / (EARTH_R * cos(deg_to_rad(float(origin["lat"])))))
	return {"lat": lat, "lng": lng}


static func dist_m(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b)


## flat-top axial hex centre → world metres.
static func hex_center(q: int, r: int) -> Vector2:
	return Vector2(1.5 * HEX_R * q, sqrt(3.0) * HEX_R * (r + q / 2.0))


## world point → the axial hex it falls in (the server's cheap round: corners
## can misassign by a sliver, but client and sim agree, which is what matters).
static func hex_at(x: float, y: float) -> Vector2i:
	var q := _js_round(x / (1.5 * HEX_R))
	var r := _js_round(y / (sqrt(3.0) * HEX_R) - q / 2.0)
	return Vector2i(q, r)


## stable string key for an axial hex (the on-the-wire + map-key form).
static func hex_key(q: int, r: int) -> String:
	return "%d,%d" % [q, r]


static func hex_key_at(x: float, y: float) -> String:
	var qr := hex_at(x, y)
	return hex_key(qr.x, qr.y)


## parse a hex key back to axial coords (Vector2i.MAX on a malformed key).
static func parse_hex_key(key: String) -> Vector2i:
	var i := key.find(",")
	if i < 0:
		return Vector2i.MAX
	var qs := key.substr(0, i)
	var rs := key.substr(i + 1)
	if not (qs.is_valid_int() and rs.is_valid_int()):
		return Vector2i.MAX
	return Vector2i(qs.to_int(), rs.to_int())


## JS Math.round rounds half UP (toward +inf); GDScript roundf rounds half away
## from zero. floor(x + 0.5) reproduces the JS behavior the server uses.
static func _js_round(v: float) -> int:
	return int(floor(v + 0.5))
