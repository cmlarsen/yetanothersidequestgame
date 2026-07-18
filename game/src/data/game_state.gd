extends Node
## Autoload: the fake client game state the v1 shell renders. Values mirror the
## mocks in docs/design/yas-v1 (they are the same "real v1 tuning defaults" as
## GAME-RULES.md). Later this becomes the client mirror of server state; the
## shell must only ever read from here, never hardcode player numbers inline.
## Anything that must agree with Rules/Catalog is derived, not duplicated
## (tests/data_sanity.gd cross-checks).

# ── Player ──────────────────────────────────────────────────────────────────
var player_name := "SIR BONKALOT"
var player_epithet := "The Bonksmith"
var character_id := "knight"
var level := 13
var xp_next: float = float(Rules.xp_for_level(level))
var xp: int = roundi(xp_next * 0.38)  # home header XP bar sits at 38%
var gold := 1240
var materials := 14
var steps_today := 1204
var steps_goal: int = Rules.DAILY_WALK_STEPS
var hp_max := 184
var hp: int = roundi(hp_max * 0.76)  # combat mock: player HP ring at 76%
var app_version := "v0.1.0"

# ── Derived stats (base + gear, per the paper-doll mock) ────────────────────
var stats := {
	"hp": {"total": 184, "gear": 52},
	"atk": {"total": 42, "gear": 18},
	"def": {"total": 31, "gear": 14},
	"spd": {"total": 12, "gear": 2},
	"crit": {"total": 8, "gear": 8},
}

# ── Territory / fronts ──────────────────────────────────────────────────────
var front_name := "Elm St"
var front_pct_player := 34
var front_pct_gloom := 21
var fronts: Array[Dictionary] = [
	{"id": "elm_st", "name": "Elm St", "pct_player": 41, "pct_gloom": 18},
	{"id": "maple_ave", "name": "Maple Ave", "pct_player": 12, "pct_gloom": 44, "push_eta_hours": 6},
]
var mobs_active := 2
var gloom_push := {
	"front_id": "maple_ave", "eta_hours": 6,
	"line": "Gloomlings massing on Maple Ave",
	"eta_line": "their push starts in ~6 h",
}

# ── Party ───────────────────────────────────────────────────────────────────
var party_name := "Cyan Crew"
var party_code := "BONK-4242"
var party: Array[Dictionary] = [
	{"name": "SIR BONKALOT", "face": "knight", "level": 13, "epithet": "The Bonksmith",
		"status": "online", "is_self": true, "is_leader": true, "distance_m": 0,
		"xp_ratio": 0.76, "hp_ratio": 0.76},
	{"name": "BRITT", "face": "huntress", "level": 15, "epithet": "The Pokey One",
		"status": "in_combat", "distance_m": 30, "xp_ratio": 0.92, "hp_ratio": 0.92},
	{"name": "MAGEMIKE", "face": "mage", "level": 11, "epithet": "Spark Goblin",
		"status": "offline", "distance_m": -1, "xp_ratio": 0.45, "hp_ratio": 0.45},
]
var nearby_players: Array[Dictionary] = [
	{"name": "FLETCHLING", "face": "archer", "level": 9, "distance_m": 40},
	{"name": "TWIGBY", "face": "druid", "level": 14, "distance_m": 120},
]

# ── Hot bar (5 uniform slots; combat mock states) ───────────────────────────
var hotbar: Array[Dictionary] = [
	{"item": "bonk_hammer", "state": "ready"},
	{"item": "zap_scroll", "state": "cooldown", "cooldown_left": 4.1},
	{"item": "turtle_up", "state": "ready"},
	{"item": "fizzy_mender", "state": "ready", "charges": 3},
	{},
]

# ── Equipment / inventory (paper doll, chunk 09) ────────────────────────────
var equipment := {
	"helm": "hammered_helm",
	"main_hand": "bonk_hammer",
	"off_hand": "zap_scroll",
	"chest": "grumble_plate",
	"boots": "sneaky_boots",
	"cape": "",  # slot locked until Rules.CAPE_UNLOCK_LEVEL
}
var inventory: Array[Dictionary] = [
	{"item": "bonk_hammer", "equipped": true},
	{"item": "gloom_vacuum", "is_new": true},
	{"item": "pocket_blizzard"},
	{"item": "soggy_fireball"},
	{"item": "static_cling", "is_new": true},
	{"item": "spare_grumble"},
	{"item": "fizzy_mender"},
]
var inventory_overflow := 12

# ── Equip drawer (chunk 17: editing hot-bar slot 2, spells tab) ─────────────
var equip_drawer := {
	"slot": 2,
	"tab": "spells",
	"selected": "zap_scroll",
	"items": ["zap_scroll", "soggy_fireball", "gloom_vacuum", "static_cling",
		"pocket_blizzard", "gloom_chest_spell"],
}

# ── Quests (progress against Catalog.QUESTS; chunk 13) ──────────────────────
var quests: Array[Dictionary] = [
	{"id": "daily_walk", "progress": steps_today, "state": "active"},
	{"id": "daily_defeat", "progress": 2, "state": "active"},
	{"id": "territory_elm", "progress": 5, "state": "claimable"},
]
var quest_reset_label := "7h 12m"

# ── Exploration map (chunk 08) ──────────────────────────────────────────────
var exploration := {
	"new_area": {"name": "Maple Ave", "xp": Rules.NEW_AREA_XP},
	"quest_chip": {"text": "Chest in the fog", "hint": "3 hexes north"},
	"compass": "N",
}

# ── Combat (chunk 15: Grumbleshroom brawl mid-fight) ────────────────────────
var combat := {
	"mob": "grumbleshroom",
	"boss_hp_ratio": 0.58,
	"floats": [
		{"text": "-38", "kind": "big"},
		{"text": "-12", "kind": "normal"},
		{"text": "CRIT -77!", "kind": "crit"},
	],
}

# ── Victory (chunk 16) ──────────────────────────────────────────────────────
var victory := {
	"xp": 80, "gold": 40,
	"claim_line": "HEX CLAIMED FOR CYAN CREW",
	"front_pct_player": 36, "front_pct_gloom": 19,
}

# ── Death (chunk 18) ────────────────────────────────────────────────────────
var death := {
	"cause_line": "Defeated by Grumbleshroom · LV 8",
	"hexes_kept": 4, "hexes_lost": 3, "gold_dropped": 50,
	"reviver": "Britt", "reviver_face": "huntress", "reviver_distance_m": 30,
	"countdown_sec": 42,
}

# ── Chest proximity (chunk 19) ──────────────────────────────────────────────
var chest := {"name": "GRUMBLE CHEST", "distance_m": 18}

# ── Rewards (chunk 20; items[1] is the center/highest-rarity card) ──────────
var rewards := {
	"title": "GRUMBLE CHEST!",
	"source_line": "Reward for claiming all of Elm Street",
	"gold": 250, "xp": 120,
	"items": ["grippy_gauntlets", "crown_of_grumbling", "spare_grumble"],
}

# ── Run summary (chunk 21) ──────────────────────────────────────────────────
var run_summary := {
	"ended_line": "You retreated at 6:12 — here's what you keep.",
	"hexes_kept": 4, "xp_kept": 310, "gold_dropped": 120,
	"loot": [
		{"item": "grippy_gauntlets", "state": "secured"},
		{"item": "unopened_chest", "state": "left_behind"},
	],
	"recover_hours": Rules.DROPPED_GOLD_PERSIST_HOURS,
}

# ── Level up (chunk 07; bumps come from Rules) ──────────────────────────────
var level_up := {
	"level": level,
	"atk": Rules.LEVEL_UP_ATK, "def": Rules.LEVEL_UP_DEF, "hp": Rules.LEVEL_UP_HP,
	"new_skill": "pocket_blizzard",
	"tease_level": Rules.CAPE_UNLOCK_LEVEL, "tease_label": "Cape equipment slot",
}

# ── Shop (chunk 14; stock lives in Catalog.SHOP_STOCK) ──────────────────────
var shop_selected := "thwack_o_matic"

# ── Towers / defense (chunks 24/25/26) ──────────────────────────────────────
var towers: Array[Dictionary] = [
	{"type": "bonk_turret", "level": 1, "durability_pct": 82, "front_id": "elm_st",
		"target_priority": "nearest", "placed_days_ago": 5},
	{"type": "chill_bell", "level": 2, "durability_pct": 34, "front_id": "elm_st",
		"target_priority": "nearest", "placed_days_ago": 3, "warning": true},
	{"type": "bastion_post", "level": 1, "durability_pct": 96, "front_id": "elm_st",
		"target_priority": "guard_home", "placed_days_ago": 8},
]
var towers_placed: int = towers.size()
var tower_cap: int = Rules.TOWER_CAP
var managed_tower_index := 1  # the low-durability Chill Bell (manage sheet)
var repair_all_cost := 9
var defense_digest := {
	"repelled": 14, "tower": "chill_bell",
	"line": "Overnight: your towers repelled 14 Gloomlings · Chill Bell took heavy damage",
}
var tower_placement := {"standing_ok": true, "selected": "bonk_turret"}

# ── Minions (chunk 27: Pip mid-scavenge, ~1 h job at 63%) ───────────────────
var minions: Array[Dictionary] = [
	{"id": "gruncle", "state": "idle", "selected": true},
	{"id": "pip", "state": "on_job", "job": "scavenge", "time_left": "22:14", "progress": 0.63},
]
var selected_job := "gather_lumber"
var minion_report := {
	"minion": "gruncle",
	"haul_materials": 14, "haul_line": "Lumber gathered",
	"salvage_item": "turret_gearbox", "salvage_label": "Salvage: Turret Gearbox",
	"rumor": {
		"line": "Rumor: Gloomlings massing on Maple Ave",
		"eta_line": "their push starts in ~6 h",
		"front_id": "maple_ave", "cta": "VIEW FRONT",
	},
}

# ── Settings (chunk 23) ─────────────────────────────────────────────────────
var settings := {
	"gps_mode": "high",
	"screen_off_steps": true,
	"speed_pause": true,
	"reduced_motion": false,
	"notif_attack": true,
	"notif_chest": true,
	"notif_party": true,
	"gamertag": "SirBonkalot#4242",
	"account_line": "Signed in with Apple",
	"footer": "v0.1.0 · privacy · terms · restore purchases",
}

# ── Run state ───────────────────────────────────────────────────────────────
var run_active := false

# ── Live server state (NetClient calls apply_*; screens keep reading the same
# fields they always did — the fake defaults above stay untouched until a
# HELLO lands, so offline mode is byte-identical to before) ──────────────────
signal live_changed(what: String)

var is_live := false
var player_id := ""
var origin: Dictionary = {}  # {lat, lng} from HELLO
var server_tick_hz := 0
var home_hex := ""
var player_pos_m := Vector2.ZERO
var live_hexes: Dictionary = {}   # "q,r" → {o: int, f: String[, c: String, tw: String]}
var live_fronts: Dictionary = {}  # id → {id, name, pct_player, pct_gloom}
var live_mobs: Dictionary = {}    # id → MobWire dict (wire field names)
var live_chests: Dictionary = {}  # id → ChestWire dict
var live_towers: Dictionary = {}  # id → TowerWire dict
var live_shop_stock: Array[Dictionary] = []  # {item, price, deal_pct}

## Front the UI focuses on: the hex under the player when known, else the most
## recently updated front.
var _focus_front_id := ""


func live_hexes_owned(side: int) -> int:
	var n := 0
	for k: String in live_hexes:
		if int(live_hexes[k]["o"]) == side:
			n += 1
	return n


func apply_hello(msg: Dictionary) -> void:
	is_live = true
	player_id = str(msg.get("playerId", ""))
	var o: Dictionary = msg.get("origin", {})
	origin = {"lat": float(o.get("lat", 0.0)), "lng": float(o.get("lng", 0.0))}
	server_tick_hz = int(msg.get("tickHz", 0))
	if int(msg.get("hexAcrossM", Geo.HEX_ACROSS_M)) != int(Geo.HEX_ACROSS_M):
		push_warning("GameState: server hexAcrossM %s != client %s" % [msg.get("hexAcrossM"), Geo.HEX_ACROSS_M])
	live_changed.emit("hello")


func apply_snapshot(msg: Dictionary) -> void:
	_apply_self(msg.get("self", {}))
	live_hexes.clear()
	for h: Dictionary in msg.get("hexes", []):
		live_hexes[str(h.get("k", ""))] = _hex_entry(h)
	live_fronts.clear()
	for f: Dictionary in msg.get("fronts", []):
		live_fronts[str(f.get("id", ""))] = _front_entry(f)
	live_mobs.clear()
	for m: Dictionary in msg.get("mobs", []):
		live_mobs[str(m.get("id", ""))] = m
	live_chests.clear()
	for c: Dictionary in msg.get("chests", []):
		live_chests[str(c.get("id", ""))] = c
	live_towers.clear()
	for t: Dictionary in msg.get("towers", []):
		live_towers[str(t.get("id", ""))] = t
	_apply_minions(msg.get("minions", []))
	_apply_party_wire(msg.get("party"))
	mobs_active = live_mobs.size()
	_sync_fronts()
	_sync_towers()
	live_changed.emit("snapshot")


func apply_delta(msg: Dictionary) -> void:
	var up: Dictionary = msg.get("upserts", {})
	for p: Dictionary in up.get("players", []):
		if str(p.get("id", "")) == player_id:
			_apply_self(p)  # PlayerWire subset: pos/hp/level/state
	for h: Dictionary in up.get("hexes", []):
		live_hexes[str(h.get("k", ""))] = _hex_entry(h)
	for m: Dictionary in up.get("mobs", []):
		live_mobs[str(m.get("id", ""))] = m
	for c: Dictionary in up.get("chests", []):
		live_chests[str(c.get("id", ""))] = c
	for t: Dictionary in up.get("towers", []):
		live_towers[str(t.get("id", ""))] = t
	var removes: Dictionary = msg.get("removes", {})
	var by_kind := {"hexes": live_hexes, "mobs": live_mobs, "chests": live_chests, "towers": live_towers}
	for kind: String in removes:
		if by_kind.has(kind):
			var container: Dictionary = by_kind[kind]
			for id: String in removes[kind]:
				container.erase(id)
	mobs_active = live_mobs.size()
	_sync_fronts()
	_sync_towers()
	live_changed.emit("delta")


func apply_events(msg: Dictionary) -> void:
	for ev: Dictionary in msg.get("events", []):
		var kind := str(ev.get("k", ""))
		match kind:
			"claim":
				live_hexes[str(ev.get("hexKey", ""))] = {
					"o": int(ev.get("o", 0)), "f": str(ev.get("frontId", "")),
				}
			"contest":
				var key := str(ev.get("hexKey", ""))
				if live_hexes.has(key):
					live_hexes[key]["c"] = str(ev.get("mobId", ""))
			"kill":
				live_mobs.erase(str(ev.get("mobId", "")))
				mobs_active = live_mobs.size()
			"xp":
				xp += int(ev.get("amount", 0))
			"gold":
				gold += int(ev.get("amount", 0))
			"gold_pickup":
				gold += int(ev.get("gold", 0))
			"area":
				exploration["new_area"] = {"name": str(ev.get("name", "")), "xp": int(ev.get("xp", 0))}
			"hit":
				var dmg := int(ev.get("dmg", 0))
				var is_crit: bool = ev.get("crit", false)
				combat["floats"] = [{
					"text": ("CRIT -%d!" % dmg) if is_crit else ("-%d" % dmg),
					"kind": "crit" if is_crit else "normal",
				}]
			"player_hit":
				if str(ev.get("playerId", "")) == player_id:
					hp = maxi(0, hp - int(ev.get("dmg", 0)))
	_sync_fronts()
	live_changed.emit("events")


func apply_inventory_update(msg: Dictionary) -> void:
	gold = int(msg.get("gold", gold))
	materials = int(msg.get("materials", materials))
	var item_by_iid := {}
	var inv: Array[Dictionary] = []
	for it: Dictionary in msg.get("inventory", []):
		var iid := str(it.get("iid", ""))
		var item_id := str(it.get("itemId", ""))
		item_by_iid[iid] = item_id
		var entry := {"item": item_id, "iid": iid, "equipped": false}
		if it.get("isNew", false):
			entry["is_new"] = true
		if it.has("charges"):
			entry["charges"] = int(it["charges"])
		inv.append(entry)
	var equipped_iids := {}
	var hb: Array[Dictionary] = []
	for slot_iid: Variant in msg.get("hotbar", []):
		if slot_iid == null:
			hb.append({})
		else:
			equipped_iids[str(slot_iid)] = true
			hb.append({"item": str(item_by_iid.get(str(slot_iid), "")), "state": "ready"})
	var eq_wire: Dictionary = msg.get("equipment", {})
	var eq := {}
	for slot: String in eq_wire:
		var iid_v: Variant = eq_wire[slot]
		if iid_v == null:
			eq[slot] = ""
		else:
			equipped_iids[str(iid_v)] = true
			eq[slot] = str(item_by_iid.get(str(iid_v), ""))
	for entry in inv:
		entry["equipped"] = equipped_iids.has(entry["iid"])
	inventory = inv
	hotbar = hb
	equipment = eq
	inventory_overflow = 0
	var s: Dictionary = msg.get("stats", {})
	if not s.is_empty():
		# Wire carries totals only; the base/gear split stays server-side for now.
		stats = {
			"hp": {"total": int(s.get("maxHp", hp_max)), "gear": 0},
			"atk": {"total": int(s.get("atk", 0)), "gear": 0},
			"def": {"total": int(s.get("def", 0)), "gear": 0},
			"spd": {"total": int(s.get("spd", 0)), "gear": 0},
			"crit": {"total": int(s.get("critPct", 0)), "gear": 0},
		}
		hp = int(s.get("hp", hp))
		hp_max = int(s.get("maxHp", hp_max))
	live_changed.emit("inventory")


func apply_front_update(msg: Dictionary) -> void:
	var f: Dictionary = msg.get("front", {})
	var id := str(f.get("id", ""))
	if id != "":
		live_fronts[id] = _front_entry(f)
		_focus_front_id = id
	_sync_fronts()
	live_changed.emit("front")


func apply_run_summary(msg: Dictionary) -> void:
	run_active = false
	var loot: Array[Dictionary] = []
	for item_id: String in msg.get("lootItemIds", []):
		loot.append({"item": item_id, "state": "secured"})
	run_summary = {
		"ended_line": "Run over — here's what you keep.",
		"hexes_kept": int(msg.get("hexesClaimed", 0)),
		"xp_kept": int(msg.get("xp", 0)),
		"gold_dropped": int(msg.get("goldDropped", 0)),
		"loot": loot,
		"recover_hours": Rules.DROPPED_GOLD_PERSIST_HOURS,
	}
	live_changed.emit("run_summary")


func apply_death(msg: Dictionary) -> void:
	run_active = false
	var countdown := maxi(0, roundi((float(msg.get("reviveDeadline", 0)) - float(msg.get("diedAt", 0))) / 1000.0))
	death = {
		"cause_line": "Defeated in the Gloom",
		"hexes_kept": int(msg.get("hexesKept", 0)),
		"hexes_lost": (msg.get("hexesLost", []) as Array).size(),
		"gold_dropped": int(msg.get("goldDropped", 0)),
		"reviver": "", "reviver_face": "", "reviver_distance_m": -1,
		"countdown_sec": countdown,
	}
	live_changed.emit("death")


func apply_level_up(msg: Dictionary) -> void:
	level = int(msg.get("level", level))
	xp_next = float(Rules.xp_for_level(level))
	var unlocks: Array = msg.get("unlocks", [])
	level_up = {
		"level": level,
		"atk": int(msg.get("atk", Rules.LEVEL_UP_ATK)),
		"def": int(msg.get("def", Rules.LEVEL_UP_DEF)),
		"hp": int(msg.get("hp", Rules.LEVEL_UP_HP)),
		"new_skill": str(unlocks[0]) if unlocks.size() > 0 else "",
		"tease_level": Rules.CAPE_UNLOCK_LEVEL, "tease_label": "Cape equipment slot",
	}
	live_changed.emit("level_up")


func apply_party_update(msg: Dictionary) -> void:
	_apply_party_wire(msg.get("party"))
	live_changed.emit("party")


func apply_shop_result(msg: Dictionary) -> void:
	gold = int(msg.get("gold", gold))
	var stock: Array[Dictionary] = []
	for s: Dictionary in msg.get("stock", []):
		stock.append({
			"item": str(s.get("itemId", "")),
			"price": int(s.get("price", 0)),
			"deal_pct": int(s.get("dealPct", 0)),
		})
	live_shop_stock = stock
	live_changed.emit("shop")


func apply_loot_result(msg: Dictionary) -> void:
	var items: Array = []
	for it: Dictionary in msg.get("items", []):
		items.append(str(it.get("itemId", "")))
	rewards = {
		"title": "LOOT!",
		"source_line": "",
		"gold": int(msg.get("gold", 0)),
		"xp": int(msg.get("xp", 0)),
		"items": items,
	}
	live_changed.emit("loot")


func apply_minion_report(msg: Dictionary) -> void:
	var rumor := {}
	if msg.has("rumorFrontId"):
		rumor = {
			"line": str(msg.get("quote", "")), "eta_line": "",
			"front_id": str(msg["rumorFrontId"]), "cta": "VIEW FRONT",
		}
	minion_report = {
		"minion": str(msg.get("minionId", "")),
		"haul_materials": int(msg.get("materials", 0)),
		"haul_line": str(msg.get("quote", "")),
		"salvage_item": str(msg.get("salvageItemId", "")),
		"salvage_label": "",
		"injured": bool(msg.get("injured", false)),
		"rumor": rumor,
	}
	live_changed.emit("minion_report")


# ── Wire → field mapping helpers ────────────────────────────────────────────

## SelfWire (snapshot) or PlayerWire subset (delta upsert) → player fields.
func _apply_self(s: Dictionary) -> void:
	if s.is_empty():
		return
	player_pos_m = Vector2(float(s.get("x", player_pos_m.x)), float(s.get("y", player_pos_m.y)))
	hp = int(s.get("hp", hp))
	hp_max = int(s.get("maxHp", hp_max))
	level = int(s.get("level", level))
	if s.has("xp"):
		xp = int(s["xp"])
	if s.has("xpNext"):
		xp_next = float(s["xpNext"])
	if s.has("gold"):
		gold = int(s["gold"])
	if s.has("materials"):
		materials = int(s["materials"])
	if s.has("stepsToday"):
		steps_today = int(s["stepsToday"])
	if s.has("homeHex"):
		home_hex = str(s["homeHex"])


func _hex_entry(h: Dictionary) -> Dictionary:
	var e := {"o": int(h.get("o", 0)), "f": str(h.get("f", ""))}
	if h.has("c"):
		e["c"] = str(h["c"])
	if h.has("tw"):
		e["tw"] = str(h["tw"])
	return e


func _front_entry(f: Dictionary) -> Dictionary:
	return {
		"id": str(f.get("id", "")),
		"name": str(f.get("name", "")),
		"pct_player": int(f.get("pctPlayer", 0)),
		"pct_gloom": int(f.get("pctGloom", 0)),
	}


## Refresh the legacy fronts list + the focused front's header numbers.
func _sync_fronts() -> void:
	if not is_live or live_fronts.is_empty():
		return
	var ids: Array = live_fronts.keys()
	ids.sort()
	var list: Array[Dictionary] = []
	for id: String in ids:
		list.append(live_fronts[id])
	fronts = list
	var here: Dictionary = live_hexes.get(Geo.hex_key_at(player_pos_m.x, player_pos_m.y), {})
	var focus := str(here.get("f", ""))
	if focus == "":
		focus = _focus_front_id
	if focus == "" or not live_fronts.has(focus):
		focus = str(ids[0])
	_focus_front_id = focus
	var f: Dictionary = live_fronts[focus]
	front_name = str(f["name"])
	front_pct_player = int(f["pct_player"])
	front_pct_gloom = int(f["pct_gloom"])
	victory["front_pct_player"] = front_pct_player
	victory["front_pct_gloom"] = front_pct_gloom


func _sync_towers() -> void:
	if not is_live:
		return
	var list: Array[Dictionary] = []
	var ids: Array = live_towers.keys()
	ids.sort()
	for id: String in ids:
		var t: Dictionary = live_towers[id]
		var max_dur := maxf(1.0, float(t.get("maxDur", 100)))
		var pct := roundi(float(t.get("dur", 0)) / max_dur * 100.0)
		list.append({
			"id": id,
			"type": str(t.get("type", "")),
			"level": int(t.get("lvl", 1)),
			"durability_pct": pct,
			"front_id": str((live_hexes.get(str(t.get("k", "")), {}) as Dictionary).get("f", "")),
			"target_priority": str(t.get("prio", "nearest")),
			"rubble": bool(t.get("rubble", false)),
			"warning": pct <= 40,
			"placed_days_ago": 0,  # not on the wire yet
		})
	towers = list
	towers_placed = list.size()


## MinionWire[] → the legacy minions list; job progress derives from the
## job's endsAt against the ServerTuning duration for that jobId.
func _apply_minions(arr: Array) -> void:
	if arr.is_empty() and not is_live:
		return
	var job_minutes := {
		"gather_lumber": int(ServerTuning.VALUES["GATHER_LUMBER_MINUTES"]),
		"scout_front": int(ServerTuning.VALUES["SCOUT_FRONT_MINUTES"]),
		"scavenge": int(ServerTuning.VALUES["SCAVENGE_MINUTES"]),
	}
	var list: Array[Dictionary] = []
	for m: Dictionary in arr:
		var entry := {
			"id": str(m.get("defId", "")),
			"mid": str(m.get("id", "")),
			"name": str(m.get("name", "")),
			"state": str(m.get("state", "idle")),
		}
		if m.has("job"):
			var job: Dictionary = m["job"]
			var job_id := str(job.get("jobId", ""))
			entry["job"] = job_id
			var left_s := maxf(0.0, (float(job.get("endsAt", 0)) - Time.get_unix_time_from_system() * 1000.0) / 1000.0)
			entry["time_left"] = "%d:%02d" % [int(left_s / 60.0), int(left_s) % 60]
			var dur_s := float(job_minutes.get(job_id, 30)) * 60.0
			entry["progress"] = clampf(1.0 - left_s / dur_s, 0.0, 1.0)
		list.append(entry)
	if list.size() > 0:
		list[0]["selected"] = true
	minions = list


## PartyWire | null → the legacy party fields.
func _apply_party_wire(p: Variant) -> void:
	if p == null or not (p is Dictionary) or (p as Dictionary).is_empty():
		if is_live:
			party = []
			party_code = ""
		return
	var pd: Dictionary = p
	party_code = str(pd.get("code", ""))
	var leader := str(pd.get("leaderId", ""))
	var status_map := {"online": "online", "inCombat": "in_combat", "offline": "offline"}
	var list: Array[Dictionary] = []
	for m: Dictionary in pd.get("members", []):
		var mid := str(m.get("id", ""))
		var has_pos: bool = m.has("x") and m.has("y")
		var dist := -1
		if has_pos:
			dist = roundi(Vector2(float(m["x"]), float(m["y"])).distance_to(player_pos_m))
		var max_hp := maxf(1.0, float(m.get("maxHp", 1)))
		list.append({
			"name": str(m.get("gamertag", "")),
			"face": str(m.get("characterId", "knight")),
			"level": int(m.get("level", 1)),
			"epithet": "",
			"status": str(status_map.get(str(m.get("state", "offline")), "offline")),
			"is_self": mid == player_id,
			"is_leader": mid == leader,
			"distance_m": 0 if mid == player_id else dist,
			"hp_ratio": clampf(float(m.get("hp", max_hp)) / max_hp, 0.0, 1.0),
			"xp_ratio": 0.0,  # not on the wire
		})
	party = list


func face_texture(face_id: String) -> Texture2D:
	return load("res://assets/ui/faces/face-%s.png" % face_id)


## Equipped pieces sharing a set tag (paper doll: HAMMER SET 2/4).
func set_pieces_equipped(set_tag: String) -> int:
	var count := 0
	for slot in equipment:
		var id: String = equipment[slot]
		if id != "" and Catalog.item(id).get("set_tag", "") == set_tag:
			count += 1
	return count


## Front record for a front id ({} when unknown).
func front(front_id: String) -> Dictionary:
	for f in fronts:
		if f["id"] == front_id:
			return f
	return {}
