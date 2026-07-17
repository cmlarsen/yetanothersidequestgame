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
