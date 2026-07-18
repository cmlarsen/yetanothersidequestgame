extends Node
## Autoload NetClient — the WebSocket edge to the YAS game server. Speaks the
## frozen wire from server/shared/protocol.ts via the generated ServerProtocol
## table (never hardcode op numbers). Reconnect machine per server/DESIGN.md:
## wantOpen master switch, backoff [0.5..8] s with ±25 % jitter, 30 s idle
## watchdog (any inbound frame resets it), resume-token reattach, per-action
## ERRs never tear the socket. Wall-clock use is allowed here (net edge, not
## sim). Live state lands in GameState via its apply_* layer; screens can also
## subscribe to the per-op signals below.

signal status_changed(state: String)
signal hello(msg: Dictionary)
signal snapshot(msg: Dictionary)
signal delta(msg: Dictionary)
signal events(msg: Dictionary)
signal err(msg: Dictionary)
## Per-action ERRs (OUT_OF_RANGE, ON_COOLDOWN, …): a toastable beat, never a teardown.
signal notice(code: String, message: String)
signal loot_result(msg: Dictionary)
signal inventory_update(msg: Dictionary)
signal front_update(msg: Dictionary)
signal run_summary(msg: Dictionary)
signal death(msg: Dictionary)
signal level_up(msg: Dictionary)
signal party_update(msg: Dictionary)
signal shop_result(msg: Dictionary)
signal minion_report(msg: Dictionary)

const BACKOFF_S: Array[float] = [0.5, 1.0, 2.0, 4.0, 8.0]
const BACKOFF_JITTER := 0.25
const IDLE_WATCHDOG_S := 30.0
const SESSION_CFG_PATH := "user://session.cfg"

var want_open := false
var server_url := ""
var status := "offline"
## Mode of the last handshake frame actually sent ("join" | "resume") — the
## live-check gate asserts RESUME reattached rather than silently re-joining.
var last_handshake := ""
var player_id := ""

var _ws: WebSocketPeer = null
var _prev_ws_state: int = WebSocketPeer.STATE_CLOSED
var _seq := 0
var _attempts := 0
var _reconnect_at_ms := 0
var _last_frame_ms := 0
var _joined := false
## SESSION_UNKNOWN → drop token + one fresh JOIN; a second one surfaces as error.
var _rejoined_after_unknown := false
var _position_source: PositionProvider = null


func _process(_delta: float) -> void:
	if _ws == null:
		if want_open and _reconnect_at_ms > 0 and Time.get_ticks_msec() >= _reconnect_at_ms:
			_reconnect_at_ms = 0
			_connect_now()
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if _prev_ws_state != WebSocketPeer.STATE_OPEN:
			_on_open()
		while _ws.get_available_packet_count() > 0:
			_on_frame(_ws.get_packet().get_string_from_utf8())
			if _ws == null:  # a handler may have torn the socket down
				return
		if Time.get_ticks_msec() - _last_frame_ms > int(IDLE_WATCHDOG_S * 1000.0):
			_drop_socket("idle watchdog: no frame in %d s" % int(IDLE_WATCHDOG_S))
			return
	elif state == WebSocketPeer.STATE_CLOSED and _prev_ws_state != WebSocketPeer.STATE_CLOSED:
		_on_closed()
	_prev_ws_state = state if _ws != null else WebSocketPeer.STATE_CLOSED


# ── Public API ──────────────────────────────────────────────────────────────

func connect_to(url: String) -> void:
	server_url = url
	want_open = true
	_attempts = 0
	_reconnect_at_ms = 0
	_connect_now()


func disconnect_from() -> void:
	want_open = false
	_reconnect_at_ms = 0
	if _ws != null:
		_ws.close(1000, "client disconnect")
		_ws = null
	_prev_ws_state = WebSocketPeer.STATE_CLOSED
	_joined = false
	_set_status("offline")


func ensure_connected() -> void:
	if not want_open or server_url == "":
		return
	if _ws == null:
		_connect_now()


## Envelope + send: {op, t: wall-clock ms, seq: monotonic}. Returns false when
## the socket isn't open (callers may ignore — state re-syncs on reconnect).
func send_op(op: int, payload: Dictionary) -> bool:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	var msg := payload.duplicate()
	msg["op"] = op
	msg["t"] = _now_ms()
	_seq += 1
	msg["seq"] = _seq
	return _ws.send_text(JSON.stringify(msg)) == OK


func set_position_source(src: PositionProvider) -> void:
	if _position_source != null and _position_source.fix_ready.is_connected(_on_fix):
		_position_source.fix_ready.disconnect(_on_fix)
	_position_source = src
	if src != null:
		src.fix_ready.connect(_on_fix)
		if GameState.is_live:
			src.origin = GameState.origin


func forget_session(url: String) -> void:
	var cf := ConfigFile.new()
	if cf.load(SESSION_CFG_PATH) != OK:
		return
	if cf.has_section_key("tokens", url):
		cf.erase_section_key("tokens", url)
		cf.save(SESSION_CFG_PATH)


# ── Socket lifecycle ────────────────────────────────────────────────────────

func _connect_now() -> void:
	_ws = WebSocketPeer.new()
	_prev_ws_state = WebSocketPeer.STATE_CLOSED
	_joined = false
	_last_frame_ms = Time.get_ticks_msec()
	var open_err := _ws.connect_to_url(server_url)
	if open_err != OK:
		push_warning("NetClient: connect_to_url(%s) failed: %s" % [server_url, error_string(open_err)])
		_ws = null
		_schedule_reconnect()
		return
	_set_status("connecting")


func _on_open() -> void:
	_rejoined_after_unknown = false
	var token := _stored_token(server_url)
	if token != "":
		last_handshake = "resume"
		send_op(int(ServerProtocol.OP.RESUME), {
			"protocolVersion": ServerProtocol.VERSION,
			"sessionToken": token,
		})
	else:
		_send_join()


func _send_join() -> void:
	last_handshake = "join"
	var tag := str(GameState.player_name).strip_edges().substr(0, 24)
	if tag == "":
		tag = "PLAYER"
	send_op(int(ServerProtocol.OP.JOIN), {
		"protocolVersion": ServerProtocol.VERSION,
		"gamertag": tag,
		"characterId": str(GameState.character_id),
	})


func _on_closed() -> void:
	_joined = false
	_ws = null
	if want_open:
		_schedule_reconnect()
	elif not status.begins_with("error"):  # terminal ERR statuses must stay visible
		_set_status("offline")


## Abandon a wedged socket (idle watchdog) without waiting on a close handshake.
func _drop_socket(reason: String) -> void:
	push_warning("NetClient: " + reason)
	if _ws != null:
		_ws.close(1000, "watchdog")
		_ws = null
	_joined = false
	_prev_ws_state = WebSocketPeer.STATE_CLOSED
	if want_open:
		_schedule_reconnect()
	else:
		_set_status("offline")


func _schedule_reconnect() -> void:
	var idx := mini(_attempts, BACKOFF_S.size() - 1)
	var delay := BACKOFF_S[idx] * randf_range(1.0 - BACKOFF_JITTER, 1.0 + BACKOFF_JITTER)
	_attempts += 1
	_reconnect_at_ms = Time.get_ticks_msec() + int(delay * 1000.0)
	_set_status("connecting")


# ── Inbound dispatch ────────────────────────────────────────────────────────

func _on_frame(text: String) -> void:
	_last_frame_ms = Time.get_ticks_msec()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("NetClient: undecodable frame: " + text.left(120))
		return
	var msg: Dictionary = parsed
	var op := int(msg.get("op", -1))
	var ops: Dictionary = ServerProtocol.OP
	if op == int(ops.HELLO):
		_on_hello(msg)
	elif op == int(ops.SNAPSHOT):
		GameState.apply_snapshot(msg)
		snapshot.emit(msg)
	elif op == int(ops.DELTA):
		GameState.apply_delta(msg)
		delta.emit(msg)
	elif op == int(ops.EVENTS):
		GameState.apply_events(msg)
		events.emit(msg)
	elif op == int(ops.PING):
		send_op(int(ops.PONG), {})
	elif op == int(ops.ERR):
		_on_err(msg)
	elif op == int(ops.LOOT_RESULT):
		GameState.apply_loot_result(msg)
		loot_result.emit(msg)
	elif op == int(ops.INVENTORY_UPDATE):
		GameState.apply_inventory_update(msg)
		inventory_update.emit(msg)
	elif op == int(ops.FRONT_UPDATE):
		GameState.apply_front_update(msg)
		front_update.emit(msg)
	elif op == int(ops.RUN_SUMMARY):
		GameState.apply_run_summary(msg)
		run_summary.emit(msg)
	elif op == int(ops.DEATH):
		GameState.apply_death(msg)
		death.emit(msg)
	elif op == int(ops.LEVEL_UP):
		GameState.apply_level_up(msg)
		level_up.emit(msg)
	elif op == int(ops.PARTY_UPDATE):
		GameState.apply_party_update(msg)
		party_update.emit(msg)
	elif op == int(ops.SHOP_RESULT):
		GameState.apply_shop_result(msg)
		shop_result.emit(msg)
	elif op == int(ops.MINION_REPORT):
		GameState.apply_minion_report(msg)
		minion_report.emit(msg)
	else:
		push_warning("NetClient: unknown op %d" % op)


func _on_hello(msg: Dictionary) -> void:
	_joined = true
	_attempts = 0
	_rejoined_after_unknown = false
	player_id = str(msg.get("playerId", ""))
	_store_token(server_url, str(msg.get("sessionToken", "")))
	GameState.apply_hello(msg)
	if _position_source != null:
		_position_source.origin = GameState.origin
	_set_status("online")
	hello.emit(msg)


func _on_err(msg: Dictionary) -> void:
	var code := str(msg.get("code", ""))
	match code:
		"VERSION_MISMATCH":
			# Terminal: the server closes 4400 after this frame; retrying is pointless.
			want_open = false
			_set_status("error:version_mismatch")
			err.emit(msg)
		"SESSION_UNKNOWN":
			forget_session(server_url)
			if not _rejoined_after_unknown:
				_rejoined_after_unknown = true
				_send_join()
			else:
				want_open = false
				_set_status("error:session_unknown")
				err.emit(msg)
				if _ws != null:
					_ws.close(1000, "session unknown")
		_:
			notice.emit(code, str(msg.get("message", "")))
			err.emit(msg)


# ── GPS ─────────────────────────────────────────────────────────────────────

func _on_fix(lat: float, lng: float, accuracy: float, speed_kmh: float) -> void:
	if not _joined:
		return
	var payload := {"lat": lat, "lng": lng, "accuracy": accuracy}
	if speed_kmh >= 0.0:
		payload["speedKmh"] = speed_kmh
	send_op(int(ServerProtocol.OP.GPS), payload)


# ── Helpers ─────────────────────────────────────────────────────────────────

func _set_status(state: String) -> void:
	if status == state:
		return
	status = state
	status_changed.emit(state)


func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _stored_token(url: String) -> String:
	var cf := ConfigFile.new()
	if cf.load(SESSION_CFG_PATH) != OK:
		return ""
	return str(cf.get_value("tokens", url, ""))


func _store_token(url: String, token: String) -> void:
	if token == "":
		return
	var cf := ConfigFile.new()
	cf.load(SESSION_CFG_PATH)  # missing file is fine — starts empty
	cf.set_value("tokens", url, token)
	cf.save(SESSION_CFG_PATH)
