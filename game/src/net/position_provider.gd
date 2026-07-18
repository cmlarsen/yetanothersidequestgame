class_name PositionProvider
extends Node
## Pluggable position source (CLAUDE.md desktop-first rule): the shell always
## runs against one of these; real CoreLocation arrives later behind the same
## seam. Sources keep a local metre position (server frame: x east, y north,
## relative to the HELLO origin) and emit WGS84 fixes NetClient turns into GPS
## ops. speed_kmh < 0 means "don't report" (the wire field is optional).

signal fix_ready(lat: float, lng: float, accuracy: float, speed_kmh: float)

## Mirror of server GPS_MAX_HZ — the client-side send throttle.
const FIX_HZ := 4.0
const ACCURACY_M := 5.0

var origin: Dictionary = {}  # {lat, lng} from HELLO; no fixes until it lands
var pos_m := Vector2.ZERO


func has_origin() -> bool:
	return origin.has("lat") and origin.has("lng")


func emit_fix(accuracy: float, speed_mps: float) -> void:
	if not has_origin():
		return
	var ll := Geo.unproject(origin, pos_m)
	var speed_kmh := speed_mps * 3.6 if speed_mps >= 0.0 else -1.0
	fix_ready.emit(float(ll["lat"]), float(ll["lng"]), accuracy, speed_kmh)
