class_name Catalog
## Static content tables mined from the yas-v1 screen mocks (exact copy) and
## DATA-MODEL.md entity shapes. Personality lives here — names, epithets,
## flavor, NPC/minion voice — never in screen code (GAME-RULES §15). Numbers
## that GAME-RULES marks DEFAULT live in Rules; entries here must agree with it
## (tests/data_sanity.gd cross-checks). Platform-free: no Node or scene deps.

# ── Characters (chunk 05; face ids match assets/ui/faces/face-<id>.png) ─────
const CHARACTERS: Dictionary = {
	"knight": {
		"name": "SIR BONKALOT", "epithet": "THE BONKSMITH",
		"flavor": "Hits things with a hammer until they stop being a problem. Excellent at doors.",
		"bars": {"atk": 0.88, "def": 0.70, "spd": 0.34},
		"most_played": true, "unlock_level": 1,
	},
	"huntress": {
		"name": "LADY STABBINGTON", "epithet": "THE POKEY ONE",
		"flavor": "Believes most problems are just targets that haven't been introduced yet.",
		"bars": {"atk": 0.80, "def": 0.42, "spd": 0.72},
		"most_played": false, "unlock_level": 1,
	},
	"mage": {
		"name": "MAGEMIKE", "epithet": "SPARK GOBLIN",
		"flavor": "Learned exactly one lightning spell. Really commits to it.",
		"bars": {"atk": 0.76, "def": 0.30, "spd": 0.55},
		"most_played": false, "unlock_level": 1,
	},
	"barbarian": {
		"name": "BIG ANGRY DOUG", "epithet": "THE LOUD ONE",
		"flavor": "Negotiates exclusively in shouting. It works more often than you'd think.",
		"bars": {"atk": 0.95, "def": 0.55, "spd": 0.28},
		"most_played": false, "unlock_level": 1,
	},
	"archer": {
		"name": "FLETCHLING", "epithet": "THE QUIVER KID",
		"flavor": "Never misses. Frequently loses the arrows afterward anyway.",
		"bars": {"atk": 0.72, "def": 0.36, "spd": 0.82},
		"most_played": false, "unlock_level": 1,
	},
	"druid": {
		"name": "TWIGBY", "epithet": "BRANCH MANAGER",
		"flavor": "Speaks fluent squirrel. The squirrels wish he wouldn't.",
		"bars": {"atk": 0.50, "def": 0.62, "spd": 0.60},
		"most_played": false, "unlock_level": 1,
	},
	"beardruid": {
		"name": "MOSSBEARD", "epithet": "THE SNOOZY SAGE",
		"flavor": "Older than the park. Naps like it's a competitive sport.",
		"bars": {"atk": 0.44, "def": 0.85, "spd": 0.22},
		"most_played": false, "unlock_level": 1,
	},
	"dwarf": {
		"name": "GRUMBEARD", "epithet": "THE UNMOVED",
		"flavor": "Has strong opinions about rocks and stronger ones about everything else.",
		"bars": {"atk": 0.66, "def": 0.90, "spd": 0.20},
		"most_played": false, "unlock_level": 15,
		"unlock_hint": "Grumbeard unlocks at LV 15",
	},
}

# ── Items (DATA-MODEL Item shape; copy from chunks 07/09/14/15/17/20/21/28) ─
const ITEMS: Dictionary = {
	"bonk_hammer": {
		"name": "Bonk Hammer", "rarity": "rare", "slot_type": "weapon",
		"icon": "hammer", "ability_tag": "BONK", "stats": {"atk": 14},
		"effect": {"dmg": 24, "knockback_hexes": 1}, "set_tag": "hammer",
		"value": 320, "effect_line": "24 dmg · knocks back 1 hex",
	},
	"zap_scroll": {
		"name": "Zap Scroll", "rarity": "rare", "slot_type": "spell",
		"icon": "scroll", "ability_tag": "ZAP", "stats": {"atk": 4},
		"effect": {"dmg": 12, "targets": 3, "cooldown_sec": 8},
		"value": 260, "effect_line": "12 dmg to up to 3 mobs · 8 s cooldown",
	},
	"turtle_up": {
		"name": "Turtle Up", "rarity": "common", "slot_type": "spell",
		"icon": "shield", "ability_tag": "SHELL", "stats": {},
		"effect": {"block_sec": 3, "reflect_pct": 20, "cooldown_sec": 12},
		"value": 180, "effect_line": "blocks all damage for 3 s · reflects 20% · 12 s cooldown",
	},
	"pocket_blizzard": {
		"name": "Pocket Blizzard", "rarity": "rare", "slot_type": "spell",
		"icon": "snowflake", "ability_tag": "CHILL", "stats": {},
		"effect": {"dmg": 18, "slow_sec": 3, "cooldown_sec": 8}, "level_req": 13,
		"value": 340, "effect_line": "18 dmg cone · slows mobs for 3 s · 8 s cooldown",
	},
	"fizzy_mender": {
		"name": "Fizzy Mender", "rarity": "common", "slot_type": "consumable",
		"icon": "potion", "stats": {}, "effect": {"heal_hp": 40, "charges": 3},
		"value": 40, "effect_line": "heals 40 HP · 3 charges",
	},
	"soggy_fireball": {
		"name": "Soggy Fireball", "rarity": "common", "slot_type": "spell",
		"icon": "wand", "ability_tag": "EMBER", "stats": {},
		"effect": {"dmg": 9, "cooldown_sec": 6},
		"value": 90, "effect_line": "9 dmg · fizzles when it rains · 6 s cooldown",
	},
	"gloom_vacuum": {
		"name": "Gloom Vacuum", "rarity": "epic", "slot_type": "spell",
		"icon": "sparkle", "ability_tag": "VOID", "stats": {},
		"effect": {"dmg": 14, "targets": 4, "cooldown_sec": 10},
		"value": 900, "effect_line": "pulls 4 mobs 1 hex closer · 14 dmg · 10 s cooldown",
	},
	"static_cling": {
		"name": "Static Cling", "rarity": "common", "slot_type": "spell",
		"icon": "wand", "ability_tag": "ZAP", "stats": {},
		"effect": {"dmg": 6, "targets": 2, "cooldown_sec": 5},
		"value": 80, "effect_line": "6 dmg jumps to 2 mobs · 5 s cooldown",
	},
	"gloom_chest_spell": {
		"name": "???", "rarity": "rare", "slot_type": "spell",
		"icon": "lock", "stats": {}, "effect": {}, "level_req": 15,
		"source_hint": "Found in Gloom chests",
		"value": 0, "effect_line": "Found in Gloom chests · LV 15",
	},
	"hammered_helm": {
		"name": "Hammered Helm", "rarity": "rare", "slot_type": "helm",
		"icon": "shield", "stats": {"hp": 30, "def": 6}, "effect": {},
		"set_tag": "hammer", "value": 210, "effect_line": "+30 HP · +6 DEF",
	},
	"grumble_plate": {
		"name": "Grumbleforged Chestplate", "rarity": "epic", "slot_type": "chest",
		"icon": "shield", "stats": {"hp": 22, "def": 8}, "effect": {},
		"value": 780, "effect_line": "+22 HP · +8 DEF",
	},
	"sneaky_boots": {
		"name": "Sneaky Sneakers", "rarity": "common", "slot_type": "boots",
		"icon": "steps", "stats": {"spd": 2}, "effect": {},
		"value": 120, "effect_line": "+2 SPD",
	},
	"cape_of_mild_dramatics": {
		"name": "Cape of Mild Dramatics", "rarity": "epic", "slot_type": "cape",
		"icon": "sparkle", "stats": {"spd": 4}, "effect": {}, "level_req": 15,
		"value": 2400, "effect_line": "+4 SPD · billows dramatically indoors",
	},
	"thwack_o_matic": {
		"name": "Thwack-o-matic 3000", "rarity": "rare", "slot_type": "weapon",
		"icon": "hammer", "ability_tag": "BONK", "stats": {"atk": 18},
		"effect": {"dmg": 28, "knockback_hexes": 1}, "set_tag": "hammer",
		"value": 450, "effect_line": "28 dmg · warranty void where thwacked",
	},
	"fizzy_bucket": {
		"name": "Bucket of Fizzy Menders ×5", "rarity": "common",
		"slot_type": "consumable", "icon": "potion", "stats": {},
		"effect": {"heal_hp": 40, "charges": 5},
		"value": 120, "effect_line": "5 Fizzy Menders · heal 40 HP each",
	},
	"mystery_box": {
		"name": "Mystery Grumble Box", "rarity": "mystery", "rarity_label": "???",
		"slot_type": "consumable", "icon": "chest", "stats": {}, "effect": {},
		"value": 199, "effect_line": "random item · rarity-weighted",
	},
	"grippy_gauntlets": {
		"name": "Grippy Gauntlets", "rarity": "rare", "slot_type": "off_hand",
		"icon": "shield", "stats": {"atk": 3, "crit_pct": 2}, "effect": {},
		"value": 300, "effect_line": "+3 ATK · +2% CRIT · very grippy",
	},
	"crown_of_grumbling": {
		"name": "Crown of Grumbling", "rarity": "legendary", "slot_type": "helm",
		"icon": "star", "stats": {"hp": 40, "def": 10}, "effect": {},
		"value": 1800, "effect_line": "+40 HP · +10 DEF · radiates mild disapproval",
	},
	"spare_grumble": {
		"name": "Spare Grumble", "rarity": "common", "slot_type": "consumable",
		"icon": "question", "stats": {}, "effect": {},
		"value": 25, "effect_line": "a grumble, in case you run out",
	},
	"turret_gearbox": {
		"name": "Turret Gearbox", "rarity": "rare", "slot_type": "consumable",
		"icon": "gear", "stats": {}, "effect": {},
		"value": 150, "effect_line": "next Bonk Turret upgrade −25% cost",
	},
	"unopened_chest": {
		"name": "Unopened Chest", "rarity": "common", "slot_type": "consumable",
		"icon": "chest", "stats": {}, "effect": {},
		"value": 0, "effect_line": "you left this behind",
	},
}

# ── Gear sets (§7; chunk 09 HAMMER SET bar) ─────────────────────────────────
const SETS: Dictionary = {
	"hammer": {
		"name": "HAMMER SET", "pieces_total": 4, "bonus_pct": 10,
		"bonus_line": "equip 2 more pieces for +10% knockback",
	},
}

# ── Towers (§8; chunks 24/25/26) ────────────────────────────────────────────
const TOWERS: Dictionary = {
	"bonk_turret": {
		"name": "Bonk Turret", "emoji": "🔨", "cost": 12,
		"tagline": "single-target dmg",
		"effect_line": "8 dmg per tick · radius 2 hexes",
		"dmg_per_tick": 8, "radius_hexes": 2,
	},
	"chill_bell": {
		"name": "Chill Bell", "emoji": "🔔", "cost": 18,
		"tagline": "AoE slow",
		"effect_line": "slows Gloomlings 40% in 2 hexes",
		"slow_pct": 40, "radius_hexes": 2,
	},
	"bastion_post": {
		"name": "Bastion Post", "emoji": "🏰", "cost": 30,
		"tagline": "hexes can't flip",
		"effect_line": "hexes in radius 1 cannot flip while it stands",
		"radius_hexes": 1,
	},
}

# ── Minions (§9; chunks 27/28) ──────────────────────────────────────────────
const MINIONS: Dictionary = {
	"gruncle": {
		"name": "Gruncle", "face": "dwarf",
		"bio": "Semi-retired mole. Knows where the good lumber is.",
		"quotes": ["Lumber's heavier than it used to be. Or I'm older. Both."],
	},
	"pip": {
		"name": "Pip", "face": "druid",
		"bio": "Enthusiastic mushroom. Easily distracted, cheap.",
		"quotes": ["Found the front! Forgot where. It'll come back to me."],
	},
}

# ── Minion jobs (§9; chunk 27 exact copy) ───────────────────────────────────
const JOBS: Dictionary = {
	"gather_lumber": {
		"name": "Gather Lumber", "emoji": "🪵",
		"duration_label": "~30 min", "duration_min": 30,
		"output_line": "returns 10–16 🪵",
		"yield_min": 10, "yield_max": 16, "injury_pct": 0,
	},
	"scout_front": {
		"name": "Scout the Front", "emoji": "🧭",
		"duration_label": "~15 min", "duration_min": 15,
		"output_line": "reveals Gloom buildup on one front",
		"injury_pct": 0,
	},
	"scavenge": {
		"name": "Scavenge Contested Ground", "emoji": "⚙️",
		"duration_label": "~1 h", "duration_min": 60,
		"output_line": "🪵 +50% yield + tower salvage",
		"yield_bonus_pct": 50, "injury_pct": 20, "risk_line": "⚠️ 20% INJURY",
	},
}

# ── Quests (§10; chunks 06/12/13) ───────────────────────────────────────────
const QUESTS: Dictionary = {
	"daily_walk": {
		"tab": "daily", "title": "WALK 2,000 STEPS",
		"flavor": "Walk 2,000 steps in one day.",
		"objective": "Walk 2,000 steps",
		"target": 2000, "reward_gold": 80, "pin": "red",
	},
	"daily_defeat": {
		"tab": "daily", "title": "DEFEAT 5 GLOOMLINGS",
		"flavor": "Defeat any 5 Gloomling mobs.",
		"objective": "Defeat 5 Gloomlings",
		"target": 5, "reward_gold": 120, "pin": "blue",
	},
	"territory_elm": {
		"tab": "territory", "title": "CLAIM ELM STREET",
		"flavor": "Claim 5 Elm St hexes in one run.",
		"objective": "Claim 5 Elm St hexes in one run",
		"target": 5, "reward_gold": 200, "pin": "green", "front_id": "elm_st",
	},
	"story_grumble_park": {
		"tab": "story", "title": "CLEAR GRUMBLE PARK",
		"chip_label": "QUEST: Clear Grumble Park",
		"flavor": "Evict the Grumbleshroom and take back the napping bench.",
		"objective": "Defeat the Grumbleshroom in Grumble Park",
		"target": 1, "reward_gold": 300, "reward_item": true,
		"reward_label": "300 gold + item", "pin": "gold",
		"giver": "elder_grumblesnore",
	},
}

# ── Mobs (chunk 11; weakness line per SCREENS.md §9) ────────────────────────
const MOBS: Dictionary = {
	"grumbleshroom": {
		"name": "GRUMBLESHROOM", "title": "TURF TYRANT", "level": 8,
		"is_tyrant": true, "hp_segments": 4,
		"hexes_held": 6, "threat_stars": 2, "loot_rarity_hint": "RARE",
		"weak_tags": ["BONK"], "resist_tags": ["ZAP"],
		"weakness_line": "Weak to BONK · resists ZAP",
		"bio": "A fungus with opinions. Has been quietly annexing Grumble Park since Tuesday.",
	},
	"gloomling": {
		"name": "GLOOMLING", "title": "GLOOMLING", "level": 3,
		"is_tyrant": false, "hp_segments": 1,
		"hexes_held": 1, "threat_stars": 1, "loot_rarity_hint": "COMMON",
		"weak_tags": ["BONK"], "resist_tags": [],
		"weakness_line": "Weak to BONK",
		"bio": "A small lump of concentrated bad mood. Travels in grumbles.",
	},
}

# ── NPCs (chunks 12/14) ─────────────────────────────────────────────────────
const NPCS: Dictionary = {
	"elder_grumblesnore": {
		"name": "ELDER GRUMBLESNORE", "title": "KEEPER OF THE TURF",
		"face": "beardruid", "merchant": false,
		"line": "\"The Gloomlings took the park, the plaza, AND my favorite napping bench. This is a bench-related emergency, adventurer.\"",
		"quest_id": "story_grumble_park",
		"replies": [
			{"label": "ACCEPT QUEST", "kind": "primary"},
			{"label": "VIEW REWARD DETAILS", "kind": "secondary"},
			{"label": "DECLINE", "kind": "tertiary"},
		],
	},
	"grumbeard": {
		"name": "GRUMBEARD'S GRUMBLEMART", "title": "ROAMING MERCHANT",
		"face": "dwarf", "merchant": true,
		"line": "\"Fresh loot! Barely cursed! No refunds if it bites.\"",
		"restock_note": "Shop restocks when you visit a new neighborhood",
	},
}

# ── Shop stock (§11; chunk 14 order) ────────────────────────────────────────
const SHOP_STOCK: Array[Dictionary] = [
	{"item": "thwack_o_matic"},
	{"item": "fizzy_bucket", "deal_pct": 30, "deal_badge": "-30% TODAY"},
	{"item": "cape_of_mild_dramatics"},
	{"item": "mystery_box"},
]

# ── Alerts (§13; chunk 22 copy → Router.ORDER deep links) ───────────────────
const ALERT_SENDER := "Yet Another Sidequest"

const ALERTS: Array[Dictionary] = [
	{
		"id": "territory_attack", "kind": "banner",
		"title": "TERRITORY UNDER ATTACK!",
		"body": "Gloomlings are capturing your Elm St hexes",
		"cta": "DEFEND", "route": "defense_view",
	},
	{
		"id": "quest_complete", "kind": "toast",
		"title": "QUEST COMPLETE!",
		"body": "Bonk 5 Gloomlings · +120 gold",
		"time_label": "now", "route": "quest_board",
	},
	{
		"id": "chest_spawn", "kind": "push",
		"sender": ALERT_SENDER, "time_label": "9:41 AM",
		"body": "A Grumble Chest spawned 200 m from you.",
		"route": "loot_box",
	},
	{
		"id": "party_invite", "kind": "push",
		"sender": ALERT_SENDER, "time_label": "9:41 AM",
		"body": "Britt invited you to a group run.",
		"route": "party",
	},
]

# ── Tutorial (SCREENS.md §4: you/claiming, fronts, encounters, hot bar) ─────
const TUTORIAL_STEPS: Array[Dictionary] = [
	{
		"title": "THIS IS YOU",
		"body": "Walk in the real world and your character walks the hex map. Every hex you enter becomes your territory.",
	},
	{
		"title": "THE FRONT LINE",
		"body": "Every neighborhood is a front. The meter shows how much your side holds — and how much the Gloomlings do.",
	},
	{
		"title": "TROUBLE FINDS YOU",
		"body": "Gloomlings roam the map and grab hexes. Walk into one to start a brawl and take the hex back.",
	},
	{
		"title": "YOUR HOT BAR",
		"body": "Five slots for weapons, spells, and potions. Tap to use them in combat — hold a slot to swap gear.",
	},
]

# ── Fixed UI copy the mocks pin exactly (chunks 01–05, 11, 17, 24, 27) ──────
const COPY: Dictionary = {
	"splash_tagline": "Walk the real world. Claim the map.",
	"splash_cta": "TAP TO START",
	"splash_footer": "v0.1.0 · early access",
	"location_title": "YOUR LEGS ARE\nTHE JOYSTICK",
	"location_body": "You move in the real world, your character moves on the hex map. We need location access while you play — that's the whole game.",
	"location_chips": [
		"Only while the app is open",
		"Never shared with other players — they see your character, not you",
	],
	"location_os_title": "Allow \"Yet Another Sidequest\" to use your location?",
	"location_os_body": "Your location moves your character on the map",
	"location_os_allow": "Allow While Using App",
	"location_os_deny": "Don't Allow",
	"notif_title": "KNOW WHEN IT\nMATTERS",
	"notif_body": "The map keeps moving when you're not looking. Get alerted when:",
	"notif_rows": [
		"Your territory is under attack",
		"A chest spawns near you",
		"A friend invites you to a run",
	],
	"notif_allow": "ALLOW NOTIFICATIONS",
	"notif_later": "MAYBE LATER",
	"select_title": "CHOOSE YOUR CHARACTER",
	"select_subtitle": "8 characters · unique abilities",
	"select_swipe_hint": "swipe for more",
	"select_cta": "CONFIRM SELECTION",
	"popover_dismiss_hint": "tap anywhere else to dismiss · works on NPCs, chests & territory too",
	"equip_drawer_hint": "HOLD A SLOT TO SWAP ANYTIME",
	"chest_gate_label": "GET WITHIN 10 m TO OPEN",
	"chest_out_of_range": "OUT OF RANGE — MOVE CLOSER",
	"tower_standing_ok": "Standing on your hex — you can build here",
	"tower_placement_footnote": "placing is in-person · managing is from anywhere",
	"tower_remote_note": "🛋️ all of this works remotely — rebuilding rubble needs a visit",
	"remote_chip": "REMOTE — MANAGE FROM ANYWHERE",
	"minion_rule_line": "They gather and scout while you're on the couch. They never fight or claim ground — that's your job.",
	"minion_footnote": "jobs run on real time, app closed · injured minions heal for gold",
	"gold_recovery_line": "Dropped gold stays on the map for 1 hour — go back to recover it",
	"inventory_legend": ["E equipped", "● new", "border = rarity"],
	"osm_attribution": "© OpenStreetMap contributors",
}


# ── Lookups ─────────────────────────────────────────────────────────────────

static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func character(id: String) -> Dictionary:
	return CHARACTERS.get(id, {})


static func tower(id: String) -> Dictionary:
	return TOWERS.get(id, {})


static func minion(id: String) -> Dictionary:
	return MINIONS.get(id, {})


static func mob(id: String) -> Dictionary:
	return MOBS.get(id, {})


static func npc(id: String) -> Dictionary:
	return NPCS.get(id, {})


static func job(id: String) -> Dictionary:
	return JOBS.get(id, {})


static func quest(id: String) -> Dictionary:
	return QUESTS.get(id, {})


static func alert(id: String) -> Dictionary:
	for a in ALERTS:
		if a["id"] == id:
			return a
	return {}
