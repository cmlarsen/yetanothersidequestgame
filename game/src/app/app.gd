extends Control
## App shell: hosts the current screen and implements the dev/CI entry modes.
##
## User args (after `--` on the command line):
##   (none)            normal run, starts at splash (offline fake data)
##   --screen=<id>     open one screen directly
##   --smoke           instantiate every route headlessly, then quit (CI gate)
##   --autoshot=<dir>  screenshot every route to <dir>/NN-<id>.png, then quit
##   --only=<a,b>      limit --autoshot to specific route ids
##   --freeze          disable looping/entrance motion (implied by autoshot)
##   --server=<url>    connect NetClient to a game server on boot
##   --offline         never connect (explicit override of --server)
##   --autowalk        drive a ScriptedPositionSource on a hop spiral (claims
##                     a demo patch of hexes; pair with --server)
##   --live-check[=<url>]  headless end-to-end gate vs a running server
##                     (default ws://127.0.0.1:8399/ws), prints LIVE CHECK
##                     PASS/FAIL and quits 0/1
##   --live-shot=<path>  windowed live demo: connect (--server), RUN_START,
##                     walk ~14 s, save a PNG of the live exploration screen,
##                     quit 0/1

const LIVE_CHECK_URL_DEFAULT := "ws://127.0.0.1:8399/ws"
const LIVE_CHECK_BUDGET_S := 55.0
const LIVE_CHECK_HEXES_NEEDED := 6
## Claim past the assert floor: on a long-running world, gloom pressure banks
## per-front capture budget and can flip a fresh claim back within seconds.
const LIVE_CHECK_HEXES_CLAIM := 9

var _screen_holder: Control
var _lc_deadline_ms := 0
var _lc_failed := false


func _ready() -> void:
	get_window().title = "SideQuest"
	var bg := ColorRect.new()
	bg.color = Tokens.BG_CANVAS
	UI.fill(self, bg)
	_screen_holder = Control.new()
	UI.fill(self, _screen_holder)
	Router.route_changed.connect(_on_route_changed)

	var args := _parse_args()
	AppMode.freeze_motion = args.has("freeze") or args.has("autoshot") or args.has("smoke")
	if args.has("live-check"):
		var url := LIVE_CHECK_URL_DEFAULT
		if args["live-check"] is String:
			url = args["live-check"]
		await _run_live_check(url)
		return
	if args.has("smoke"):
		await _run_smoke()
	elif args.has("autoshot"):
		await _run_autoshot(args["autoshot"], args.get("only", ""))
	elif args.has("screen"):
		Router.go(args["screen"])
	else:
		Router.go("splash")
	if args.has("server") and not args.has("offline"):
		_go_online(str(args["server"]), args.has("autowalk"))
		if args.get("live-shot", false) is String:
			_run_live_shot(str(args["live-shot"]), args.has("screen"))


## Boot-time online mode: connect and attach the position source (Manual on
## desktop by default; --autowalk swaps in the scripted demo route).
func _go_online(url: String, autowalk: bool) -> void:
	var source: PositionProvider
	if autowalk:
		var walker := ScriptedPositionSource.new()
		# Every-other spiral cell = 120 m hops (> the 60 m relocation snap):
		# each hop claims exactly the hex it lands in, so a visible patch grows
		# in seconds — a 1.4 m/s walk would claim ~1 hex per minute (same trick
		# as the live-check gate).
		var cells := ScriptedPositionSource.spiral_route(61)
		var hops: Array[Vector2] = []
		for i in range(0, cells.size(), 2):
			hops.append(cells[i])
		walker.waypoints = hops
		walker.hop = true
		walker.hop_interval_s = 0.8
		source = walker
	else:
		source = ManualPositionSource.new()
	add_child(source)
	NetClient.set_position_source(source)
	NetClient.connect_to(url)


# ── Live shot (windowed demo capture for visual verification) ────────────────

const LIVE_SHOT_WALK_S := 14.0

## keep_screen: an explicit --screen wins over the default exploration capture.
func _run_live_shot(path: String, keep_screen: bool = false) -> void:
	if not keep_screen:
		Router.go("exploration")
	while NetClient.status != "online":
		if NetClient.status.begins_with("error"):
			print("LIVE SHOT FAIL: %s" % NetClient.status)
			get_tree().quit(1)
			return
		await get_tree().process_frame
	NetClient.send_op(int(ServerProtocol.OP.RUN_START), {})
	GameState.run_active = true
	var until := Time.get_ticks_msec() + int(LIVE_SHOT_WALK_S * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("LIVE SHOT -> %s (%s) owned=%d" % [path, error_string(err),
		GameState.live_hexes_owned(1)])
	get_tree().quit(0 if err == OK else 1)


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var eq := arg.find("=")
		if eq >= 0:
			out[arg.substr(2, eq - 2)] = arg.substr(eq + 1)
		elif arg.begins_with("--"):
			out[arg.substr(2)] = true
	return out


func _on_route_changed(id: String) -> void:
	for child in _screen_holder.get_children():
		child.queue_free()
	_screen_holder.add_child(Router.make_screen(id))


func _show_and_settle(id: String) -> void:
	for child in _screen_holder.get_children():
		_screen_holder.remove_child(child)
		child.free()
	_screen_holder.add_child(Router.make_screen(id))
	for i in 3:
		await get_tree().process_frame


func _run_smoke() -> void:
	var failures: Array[String] = []
	var stubbed: Array[String] = []
	for id in Router.ORDER:
		if not ResourceLoader.exists(Router.script_path(id)):
			stubbed.append(id)
		await _show_and_settle(id)
		var screen: Screen = _screen_holder.get_child(0)
		if screen == null or screen.get_child_count() == 0:
			failures.append(id)
	print("SMOKE ROUTES: %d  stubs: %s" % [Router.ORDER.size(), ", ".join(stubbed) if stubbed.size() > 0 else "none"])
	if failures.is_empty():
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		print("SMOKE FAIL: " + ", ".join(failures))
		get_tree().quit(1)


func _run_autoshot(dir: String, only: String) -> void:
	var ids: Array[String] = Router.ORDER.duplicate()
	if only != "":
		ids.clear()
		for part in only.split(","):
			ids.append(part.strip_edges())
	DirAccess.make_dir_recursive_absolute(dir)
	for id in ids:
		await _show_and_settle(id)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var idx := Router.ORDER.find(id) + 1  # off-registry ids land at 00-
		var path := "%s/%02d-%s.png" % [dir, idx, id]
		var err := img.save_png(path)
		print("SHOT %s -> %s (%s)" % [id, path, error_string(err)])
	print("AUTOSHOT DONE")
	get_tree().quit(0)


# ── Live check (the end-to-end gate: tools/dev/live_check.sh) ───────────────
# connect → JOIN fresh → HELLO asserts → RUN_START → scripted spiral walk →
# ≥6 hexes owned by side 1 + a front pct change → disconnect → reconnect →
# RESUME reattach asserts. Prints LIVE CHECK PASS / FAIL, quits 0/1.

func _run_live_check(url: String) -> void:
	_lc_deadline_ms = Time.get_ticks_msec() + int(LIVE_CHECK_BUDGET_S * 1000.0)
	GameState.player_name = "LIVECHECK-%05d" % (randi() % 100000)
	GameState.character_id = "knight"
	print("LIVE CHECK: url=%s gamertag=%s" % [url, GameState.player_name])
	# Collectors hook up BEFORE connecting: the JOIN reply burst [HELLO,
	# SNAPSHOT, INVENTORY_UPDATE] can land inside one NetClient poll, so
	# connecting a handler after awaiting HELLO would miss the snapshot.
	var hellos: Array[Dictionary] = []
	NetClient.hello.connect(func(msg: Dictionary) -> void: hellos.append(msg))
	var snap_count: Array[int] = [0]
	NetClient.snapshot.connect(func(_msg: Dictionary) -> void: snap_count[0] += 1)
	NetClient.forget_session(url)  # deterministic: first connect must JOIN
	NetClient.connect_to(url)

	if not await _lc_wait(func() -> bool: return hellos.size() >= 1, "hello"):
		return
	var hello_msg: Dictionary = hellos[0]
	if int(hello_msg.get("protocolVersion", -1)) != ServerProtocol.VERSION:
		_lc_fail("hello", "protocolVersion=%s (want %d)" % [hello_msg.get("protocolVersion"), ServerProtocol.VERSION])
		return
	if int(hello_msg.get("tickHz", 0)) <= 0:
		_lc_fail("hello", "tickHz=%s" % hello_msg.get("tickHz"))
		return
	var first_player_id := str(hello_msg.get("playerId", ""))
	print("LIVE CHECK: HELLO ok — player=%s tickHz=%s handshake=%s" % [
		first_player_id, hello_msg.get("tickHz"), NetClient.last_handshake])

	NetClient.send_op(int(ServerProtocol.OP.RUN_START), {})
	GameState.run_active = true
	if not await _lc_wait(func() -> bool: return snap_count[0] >= 1, "first snapshot"):
		return
	var baseline := {}
	for id: String in GameState.live_fronts:
		baseline[id] = [GameState.live_fronts[id]["pct_player"], GameState.live_fronts[id]["pct_gloom"]]

	# Random spiral centre far from origin: the deployed world is persistent, so
	# claims must land on fresh hexes for the front-pct-change assert to hold.
	var ang := randf() * TAU
	var center := Vector2(cos(ang), sin(ang)) * randf_range(1500.0, 3000.0)
	var walker := ScriptedPositionSource.new()
	# Every-other spiral cell = 120 m hops (> the 60 m relocation-snap floor):
	# one discrete hex claim per hop. Always expand OUTWARD, never loop — a
	# claimed cell that gloom flips back becomes CONTESTED on re-entry (combat,
	# not a claim), so revisiting old cells can never raise the count.
	var cells := ScriptedPositionSource.spiral_route(151, center)
	var hops: Array[Vector2] = []
	for i in range(0, cells.size(), 2):
		hops.append(cells[i])
	walker.waypoints = hops
	walker.hop = true
	walker.hop_interval_s = 0.6
	add_child(walker)
	NetClient.set_position_source(walker)

	var claimed_enough := func() -> bool:
		return GameState.live_hexes_owned(1) >= LIVE_CHECK_HEXES_CLAIM and _lc_front_changed(baseline)
	if not await _lc_wait(claimed_enough, "claiming"):
		print("LIVE CHECK: at timeout owned=%d fronts=%s hexes_seen=%d" % [
			GameState.live_hexes_owned(1), JSON.stringify(GameState.live_fronts), GameState.live_hexes.size()])
		return
	var owned := GameState.live_hexes_owned(1)
	print("LIVE CHECK: %d hexes owned by side 1, front pct changed — reconnecting" % owned)

	walker.done = true  # stop emitting fixes across the reconnect
	NetClient.disconnect_from()
	for i in 10:
		await get_tree().process_frame
	NetClient.connect_to(url)
	if not await _lc_wait(func() -> bool: return hellos.size() >= 2, "resume hello"):
		return
	var hello2: Dictionary = hellos[1]
	if NetClient.last_handshake != "resume":
		_lc_fail("resume", "handshake was '%s', expected resume" % NetClient.last_handshake)
		return
	if str(hello2.get("playerId", "")) != first_player_id:
		_lc_fail("resume", "playerId %s != %s" % [hello2.get("playerId"), first_player_id])
		return
	if not await _lc_wait(func() -> bool: return snap_count[0] >= 2, "resume snapshot"):
		return
	var owned_after := GameState.live_hexes_owned(1)
	if owned_after < LIVE_CHECK_HEXES_NEEDED:
		_lc_fail("resume", "owned after resume=%d (before=%d)" % [owned_after, owned])
		return
	print("LIVE CHECK: RESUME reattached — player=%s, %d hexes still owned" % [first_player_id, owned_after])
	print("LIVE CHECK PASS")
	get_tree().quit(0)


func _lc_front_changed(baseline: Dictionary) -> bool:
	for id: String in GameState.live_fronts:
		var f: Dictionary = GameState.live_fronts[id]
		if not baseline.has(id):
			if int(f["pct_player"]) > 0 or int(f["pct_gloom"]) > 0:
				return true
			continue
		var base: Array = baseline[id]
		if int(f["pct_player"]) != int(base[0]) or int(f["pct_gloom"]) != int(base[1]):
			return true
	return false


func _lc_fail(stage: String, saw: String) -> void:
	if _lc_failed:
		return
	_lc_failed = true
	print("LIVE CHECK FAIL at %s — saw: %s" % [stage, saw])
	get_tree().quit(1)


## Spin frames until pred() holds; false (after printing FAIL) on deadline.
func _lc_wait(pred: Callable, stage: String) -> bool:
	while not pred.call():
		if _lc_failed:
			return false
		if Time.get_ticks_msec() > _lc_deadline_ms:
			_lc_fail(stage, "timeout (status=%s)" % NetClient.status)
			return false
		await get_tree().process_frame
	return not _lc_failed
