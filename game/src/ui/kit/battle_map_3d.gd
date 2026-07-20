class_name BattleMap3D
extends Control
## Real-time combat arena rendered in 3D (SCREENS.md §15) — the "3D" render
## region the mocks stub. A SubViewport hosts a perspective scene the 2D HUD
## draws over: a hex-tiled grass field, procedural low-poly trees (no tree GLB
## ships yet), a KayKit player character and mob, and glowing ground rings.
##
## Controls (PoGo-style): WASD/arrows walk the player (fast local movement, not
## the GPS-paced world scale); drag pans the camera; wheel / pinch / trackpad
## magnify zooms. The camera follows the player while walking and detaches while
## you drag, re-locking to the player the moment you move again.
##
## Everything degrades gracefully: if the .glb import cache or an asset is
## missing (e.g. a fresh checkout before `godot --import`), characters fall back
## to colored capsules and nothing crashes, so the headless smoke/autoshot gate
## still builds the screen.

# ── World scale / palette ────────────────────────────────────────────────────
const HEX_R := 1.15           # hex circum-radius in world units (~1 char tall)
const HEX_H := 0.28           # hex prism thickness (raised-tile look)
const FIELD_RADIUS := 11.0    # tiles within this world radius of origin
const TREE_COUNT := 14
const WALK_SPEED := 4.8        # units/s — brisk, deliberately NOT GPS-paced
const RUSH_SPEED := 9.0        # Shift
const _TRUNK := Color("#6b4b2a")

# Camera framing.
const CAM_ELEVATION_DEG := 52.0
const CAM_YAW_DEG := 0.0
const CAM_DIST_MIN := 6.0
const CAM_DIST_MAX := 20.0
const CAM_DIST_DEFAULT := 12.0
const CAM_FOV := 55.0

# character_id (Catalog.CHARACTERS / AvatarFace ids) → KayKit character GLB.
const CHAR_MODEL := {
	"knight": "Knight", "huntress": "Ranger", "mage": "Mage",
	"barbarian": "Barbarian", "archer": "Ranger", "druid": "Druid",
	"beardruid": "Druid", "dwarf": "Barbarian", "rogue": "Rogue",
}
# mob id (Catalog.MOBS) → KayKit skeleton GLB.
const MOB_MODEL := {
	"grumbleshroom": "Skeleton_Warrior", "gloomling": "Skeleton_Minion",
}
const _MODEL_DIR := "res://assets/models/"

# Player/mob spawn spots (metres, XZ plane; camera sits at +Z looking −Z).
const _PLAYER_SPAWN := Vector3(0.0, 0.0, 1.6)
const _MOB_SPAWN := Vector3(0.4, 0.0, -3.2)

var player_character := "knight"
var mob_id := "grumbleshroom"

var _viewport: SubViewport
var _cam: Camera3D
var _player: Node3D          # movement root (facing + position)
var _player_model: Node3D    # bob pivot (visual only)
var _mob: Node3D
var _mob_model: Node3D

# Camera rig state.
var _focus := Vector3.ZERO
var _cam_dist := CAM_DIST_DEFAULT
var _cam_yaw := deg_to_rad(CAM_YAW_DEG)
var _follow := true

# Idle bob (only when skeletal idle didn't take).
var _player_bob := false
var _mob_bob := true
var _t := 0.0

# Input state.
var _dragging := false
var _touches := {}           # index → last Vector2 (multitouch pinch/pan)
var _pinch_dist := -1.0
var _attack_tween: Tween


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP  # receive drag/zoom in the gaps


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_viewport()
	_build_environment()
	_build_ground()
	_build_trees()
	_build_actors()
	_focus = _player_spawn_focus()
	set_process(true)


func configure(character: String, mob: String) -> void:
	## Set before adding to the tree; _ready() reads these.
	if character != "":
		player_character = character
	if mob != "":
		mob_id = mob


# ── Scene construction ───────────────────────────────────────────────────────

func _build_viewport() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # input bubbles to us
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.fov = CAM_FOV
	_cam.near = 0.1
	_cam.far = 200.0
	_viewport.add_child(_cam)


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -42.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color("#fff4d6")
	sun.shadow_enabled = true
	_viewport.add_child(sun)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#cfe08a")  # soft grass-sky so map edges fade
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#bcd4a0")
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color("#cfe08a")
	env.fog_density = 0.02
	env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	_viewport.add_child(we)


func _build_ground() -> void:
	# Flat base plane under the tiles so the inter-tile gaps read as "grout".
	var base := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(FIELD_RADIUS * 2.6, FIELD_RADIUS * 2.6)
	base.mesh = plane
	base.position = Vector3(0.0, -0.06, 0.0)
	base.material_override = _flat_mat(Tokens.MAP_GRASS.darkened(0.35))
	_viewport.add_child(base)

	# Hex prisms (flat-top axial tiling) as one MultiMesh for cheap draw.
	var prism := CylinderMesh.new()
	prism.top_radius = HEX_R * 0.94
	prism.bottom_radius = HEX_R * 0.94
	prism.height = HEX_H
	prism.radial_segments = 6
	prism.rings = 0
	var centers := _hex_centers()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = prism
	mm.instance_count = centers.size()
	for i in centers.size():
		var c: Vector3 = centers[i]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, c))
		mm.set_instance_color(i, _tile_color(c))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := _flat_mat(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	_viewport.add_child(mmi)


func _hex_centers() -> Array[Vector3]:
	# Flat-top hexes: x = 1.5·R·q ; z = √3·R·(r + q/2). Tiles keep a hex whose
	# centre is inside FIELD_RADIUS. Prism top sits at y≈0 (centre at −HEX_H/2).
	var out: Array[Vector3] = []
	var span := int(ceil(FIELD_RADIUS / HEX_R)) + 1
	for q in range(-span, span + 1):
		for r in range(-span, span + 1):
			var x := 1.5 * HEX_R * q
			var z := sqrt(3.0) * HEX_R * (r + q / 2.0)
			if Vector2(x, z).length() <= FIELD_RADIUS:
				out.append(Vector3(x, -HEX_H / 2.0, z))
	return out


func _tile_color(c: Vector3) -> Color:
	# Deterministic 3-way jitter (no RNG) so autoshots are stable.
	var k := (abs(int(round(c.x * 3.0)) * 7 + int(round(c.z * 3.0)) * 13)) % 3
	match k:
		0:
			return Tokens.MAP_GRASS
		1:
			return Tokens.MAP_GRASS_ALT
	return Tokens.MAP_GRASS.lightened(0.06)


func _build_trees() -> void:
	for i in TREE_COUNT:
		var ang := float(i) * (TAU / TREE_COUNT) + float(i % 3) * 0.45
		var rad := 4.2 + float(i % 4) * 1.35
		var pos := Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		if pos.distance_to(_PLAYER_SPAWN) < 2.0 or pos.distance_to(_MOB_SPAWN) < 2.0:
			continue
		_viewport.add_child(_make_tree(pos, 0.85 + float(i % 3) * 0.22))


func _make_tree(pos: Vector3, sc: float) -> Node3D:
	var tree := Node3D.new()
	tree.position = pos
	tree.scale = Vector3.ONE * sc
	tree.rotation.y = pos.x + pos.z  # vary facing without RNG

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.13
	tm.bottom_radius = 0.17
	tm.height = 0.95
	tm.radial_segments = 6
	trunk.mesh = tm
	trunk.position = Vector3(0.0, 0.47, 0.0)
	trunk.material_override = _flat_mat(_TRUNK)
	tree.add_child(trunk)

	# Two stacked rounded-cube canopies (KayKit low-poly silhouette).
	var lower := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(1.5, 1.15, 1.5)
	lower.mesh = lb
	lower.position = Vector3(0.0, 1.35, 0.0)
	lower.material_override = _flat_mat(Tokens.MAP_TREE)
	tree.add_child(lower)

	var upper := MeshInstance3D.new()
	var ub := BoxMesh.new()
	ub.size = Vector3(1.05, 0.9, 1.05)
	upper.mesh = ub
	upper.position = Vector3(0.0, 2.05, 0.0)
	upper.rotation.y = 0.5
	upper.material_override = _flat_mat(Tokens.MAP_TREE.lightened(0.08))
	tree.add_child(upper)
	return tree


func _build_actors() -> void:
	# Player — glowing cyan ring, faces the mob.
	_player = Node3D.new()
	_player.position = _PLAYER_SPAWN
	_viewport.add_child(_player)
	_player.add_child(_ground_ring(1.02, Tokens.CYAN))
	_player_model = _spawn_character(CHAR_MODEL.get(player_character, "Knight"),
		Tokens.CYAN)
	_player.add_child(_player_model)
	_player_bob = not _apply_idle(_player_model)
	_face_towards(_player, _MOB_SPAWN)

	# Mob — dashed contested ring is a warning-gold ground ring here.
	_mob = Node3D.new()
	_mob.position = _MOB_SPAWN
	_viewport.add_child(_mob)
	_mob.add_child(_ground_ring(1.15, Tokens.WARNING))
	_mob_model = _spawn_character(MOB_MODEL.get(mob_id, "Skeleton_Warrior"),
		Tokens.GLOOM_HEX)
	_mob.add_child(_mob_model)
	_mob_bob = not _apply_idle(_mob_model)
	_face_towards(_mob, _PLAYER_SPAWN)


## Instance a KayKit GLB; capsule fallback if the import cache/asset is absent.
func _spawn_character(model_name: String, tint: Color) -> Node3D:
	var pivot := Node3D.new()  # bob/attack pivot, separate from facing root
	var ps: PackedScene = load(_MODEL_DIR + model_name + ".glb")
	if ps != null:
		var inst := ps.instantiate()
		if inst is Node3D:
			pivot.add_child(inst)
			return pivot
		inst.queue_free()
	# Fallback so the scene always shows something solid.
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.5
	mi.mesh = cap
	mi.position = Vector3(0.0, 0.75, 0.0)
	mi.material_override = _flat_mat(tint)
	pivot.add_child(mi)
	return pivot


func _ground_ring(radius: float, color: Color) -> MeshInstance3D:
	# A flat annulus generated directly in the XZ plane — no primitive whose
	# default axis I'd have to guess at, and double-sided so winding is moot.
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh(radius - 0.09, radius, 40)
	ring.position = Vector3(0.0, 0.03, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	ring.material_override = mat
	return ring


static func _ring_mesh(inner: float, outer: float, seg: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in seg:
		var a := TAU * float(i) / float(seg)
		verts.append(Vector3(cos(a) * outer, 0.0, sin(a) * outer))
		verts.append(Vector3(cos(a) * inner, 0.0, sin(a) * inner))
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
	for i in seg:
		var o0 := i * 2
		var in0 := i * 2 + 1
		var o1 := ((i + 1) % seg) * 2
		var in1 := ((i + 1) % seg) * 2 + 1
		for idx in [o0, in0, o1, in0, in1, o1]:
			indices.append(idx)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _flat_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.metallic = 0.0
	return mat


# ── Skeletal idle (best-effort retarget; returns true if an idle plays) ───────

func _apply_idle(model: Node) -> bool:
	var skel := _find_by_class(model, "Skeleton3D")
	if skel == null:
		return false
	var ap := AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = ap.get_path_to(model)
	var skel_rel := str(model.get_path_to(skel))
	var got_idle := false
	for glb in ["anim_general", "anim_movement"]:
		var ps: PackedScene = load(_MODEL_DIR + glb + ".glb")
		if ps == null:
			continue
		var src := ps.instantiate()
		var src_ap := _find_by_class(src, "AnimationPlayer") as AnimationPlayer
		if src_ap != null:
			var lib := AnimationLibrary.new()
			for anim_name in src_ap.get_animation_list():
				var a: Animation = src_ap.get_animation(anim_name).duplicate(true)
				_retarget(a, skel_rel)
				lib.add_animation(anim_name, a)
			ap.add_animation_library(glb, lib)
		src.queue_free()
	if ap.has_animation("anim_general/Idle_A"):
		var idle := ap.get_animation("anim_general/Idle_A")
		idle.loop_mode = Animation.LOOP_LINEAR
		if not AppMode.freeze_motion:
			ap.play("anim_general/Idle_A")
		got_idle = true
	return got_idle


## Bone tracks are stored as "<node>:<bone>"; both KayKit rigs share bone names,
## so swapping the node prefix for this model's skeleton path retargets them.
static func _retarget(a: Animation, skel_rel: String) -> void:
	for i in a.get_track_count():
		var p := str(a.track_get_path(i))
		var colon := p.find(":")
		if colon >= 0:
			a.track_set_path(i, NodePath(skel_rel + p.substr(colon)))


static func _find_by_class(root: Node, cls: String) -> Node:
	if root.is_class(cls):
		return root
	for child in root.get_children():
		var hit := _find_by_class(child, cls)
		if hit != null:
			return hit
	return null


# ── Per-frame: movement, camera, idle bob ────────────────────────────────────

func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		_step_movement(delta)
	_update_camera(delta)
	if not AppMode.freeze_motion:
		if _player_bob and _player_model != null:
			var pp := _player_model.position
			pp.y = absf(sin(_t * 2.0)) * 0.05
			_player_model.position = pp
		if _mob_bob and _mob_model != null:
			var mp := _mob_model.position
			mp.y = absf(sin(_t * 1.7 + 1.0)) * 0.06
			_mob_model.position = mp


func _step_movement(delta: float) -> void:
	if _player == null:
		return
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.z -= 1.0  # forward = away from the camera (up the screen)
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.z += 1.0
	if dir == Vector3.ZERO:
		return
	var speed := RUSH_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED
	# Move relative to camera yaw so "W" is always up-screen.
	dir = dir.rotated(Vector3.UP, _cam_yaw).normalized()
	_player.position += dir * speed * delta
	_face_dir(_player, dir)
	_follow = true  # walking re-locks the camera onto the player


func _update_camera(delta: float) -> void:
	if _cam == null:
		return
	if _follow and _player != null:
		_focus = _focus.lerp(_player.position, clampf(delta * 8.0, 0.0, 1.0))
	var horiz := _cam_dist * cos(deg_to_rad(CAM_ELEVATION_DEG))
	var vert := _cam_dist * sin(deg_to_rad(CAM_ELEVATION_DEG))
	var eye := _focus + Vector3(sin(_cam_yaw) * horiz, vert, cos(_cam_yaw) * horiz)
	_cam.look_at_from_position(eye, _focus + Vector3(0.0, 0.7, 0.0), Vector3.UP)


func _player_spawn_focus() -> Vector3:
	return _PLAYER_SPAWN


# ── Facing helpers ───────────────────────────────────────────────────────────

static func _face_towards(node: Node3D, target: Vector3) -> void:
	var to := target - node.position
	to.y = 0.0
	if to.length() > 0.001:
		node.rotation.y = atan2(to.x, to.z)


static func _face_dir(node: Node3D, dir: Vector3) -> void:
	if dir.length() > 0.001:
		node.rotation.y = lerp_angle(node.rotation.y, atan2(dir.x, dir.z), 0.3)


# ── Attack feedback (called by combat.gd on a hotbar tap) ────────────────────

func player_attack() -> void:
	_face_towards(_player, _mob.position if _mob != null else _MOB_SPAWN)
	if AppMode.freeze_motion or _player_model == null:
		return
	if _attack_tween != null and _attack_tween.is_valid():
		_attack_tween.kill()
	var home := Vector3.ZERO
	var lunge := (_MOB_SPAWN - _PLAYER_SPAWN).normalized() * 0.45
	_attack_tween = create_tween()
	_attack_tween.tween_property(_player_model, "position", lunge, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(_player_model, "position", home, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _mob_model != null:
		var recoil := create_tween()
		recoil.tween_interval(0.09)
		recoil.tween_property(_mob_model, "position:z", -0.2, 0.06)
		recoil.tween_property(_mob_model, "position:z", 0.0, 0.16)


## Mob's current position projected to this control's 2D space (for HUD floats).
func mob_screen_pos() -> Vector2:
	if _cam == null or _mob == null or not _cam.is_inside_tree():
		return size * Vector2(0.5, 0.35)
	var head := _mob.position + Vector3(0.0, 1.6, 0.0)
	if _cam.is_position_behind(head):
		return size * Vector2(0.5, 0.35)
	var vp := Vector2(_viewport.size)
	var p := _cam.unproject_position(head)
	if vp.x <= 0.0 or vp.y <= 0.0:
		return size * Vector2(0.5, 0.35)
	return p / vp * size


# ── Camera input: drag to pan, wheel/pinch/magnify to zoom ────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom(-1.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom(1.1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		_pan((event as InputEventMouseMotion).relative)
	elif event is InputEventMagnifyGesture:
		_zoom((1.0 - (event as InputEventMagnifyGesture).factor) * 8.0)
	elif event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)


func _zoom(delta: float) -> void:
	_cam_dist = clampf(_cam_dist + delta, CAM_DIST_MIN, CAM_DIST_MAX)


func _pan(screen_delta: Vector2) -> void:
	_follow = false
	var k := _cam_dist * 0.0016
	var right := Vector3(cos(_cam_yaw), 0.0, -sin(_cam_yaw))
	var fwd := Vector3(sin(_cam_yaw), 0.0, cos(_cam_yaw))
	_focus += (-right * screen_delta.x - fwd * screen_delta.y) * k


func _on_touch(t: InputEventScreenTouch) -> void:
	if t.pressed:
		_touches[t.index] = t.position
	else:
		_touches.erase(t.index)
		_pinch_dist = -1.0


func _on_drag(d: InputEventScreenDrag) -> void:
	_touches[d.index] = d.position
	if _touches.size() >= 2:
		var pts: Array = _touches.values()
		var cur: float = (pts[0] as Vector2).distance_to(pts[1])
		if _pinch_dist > 0.0:
			_zoom((_pinch_dist - cur) * 0.03)
		_pinch_dist = cur
	else:
		_pan(d.relative)
