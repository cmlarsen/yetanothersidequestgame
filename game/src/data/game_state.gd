extends Node
## Autoload: the fake client game state the v1 shell renders. Values mirror the
## mocks in docs/design/yas-v1 (they are the same "real v1 tuning defaults" as
## GAME-RULES.md). Later this becomes the client mirror of server state; the
## shell must only ever read from here, never hardcode player numbers inline.

# ── Player ──────────────────────────────────────────────────────────────────
var player_name := "SIR BONKALOT"
var player_epithet := "The Unbothered"
var character_id := "knight"
var level := 8
var xp := 210
var xp_next := 100.0 * pow(1.35, 8 - 1)  # Rules.level_curve — kept in sync by tests
var gold := 1240
var materials := 14
var steps_today := 1204
var hp := 184
var hp_max := 184

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

# ── Party ───────────────────────────────────────────────────────────────────
var party_code := "BONK-4242"
var party := [
	{"name": "Britt", "face": "huntress", "level": 9, "status": "online", "distance_m": 30},
	{"name": "Grumbeard", "face": "dwarf", "level": 11, "status": "in_combat", "distance_m": 120},
	{"name": "Moss", "face": "druid", "level": 6, "status": "offline", "distance_m": -1},
]

# ── Hot bar (5 uniform slots) ───────────────────────────────────────────────
var hotbar := [
	{"item": "bonk_hammer", "state": "ready"},
	{"item": "zap_scroll", "state": "cooldown", "cooldown_left": 3.2},
	{"item": "turtle_up", "state": "ready"},
	{"item": "fizzy_mender", "state": "ready", "charges": 3},
	{},
]

# ── Towers / minions ────────────────────────────────────────────────────────
var towers_placed := 3
var tower_cap := 5

# ── Run state ───────────────────────────────────────────────────────────────
var run_active := false


func face_texture(face_id: String) -> Texture2D:
	return load("res://assets/ui/faces/face-%s.png" % face_id)
