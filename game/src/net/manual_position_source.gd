class_name ManualPositionSource
extends PositionProvider
## Desktop fake GPS: arrows/WASD move the local metre position at walking
## speed (Shift = brisk 4.0 m/s — the server's MOVE_MAX_MPS clamp). Emits
## fixes at ≤4 Hz only while moving, plus one resting fix on stop so the
## pawn settles exactly where you released the keys.

const WALK_MPS := 1.4
const RUSH_MPS := 4.0

var _since_fix := 0.0
var _was_moving := false


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		dir.y += 1.0  # metre frame y = north
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		dir.y -= 1.0
	var moving := dir != Vector2.ZERO
	var speed := RUSH_MPS if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_MPS
	if moving:
		pos_m += dir.normalized() * speed * delta
		_since_fix += delta
		if _since_fix >= 1.0 / FIX_HZ:
			emit_fix(ACCURACY_M, speed)
			_since_fix = 0.0
	elif _was_moving:
		emit_fix(ACCURACY_M, 0.0)
		_since_fix = 0.0
	_was_moving = moving
