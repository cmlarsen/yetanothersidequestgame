class_name Rules
## Every DEFAULT-marked number from docs/design/yas-v1/GAME-RULES.md as a named
## constant (§ refs point there). Screens and sim code read these — never
## re-declare the literals. Platform-free: no Node or scene dependencies.

# ── §1 World & territory ────────────────────────────────────────────────────
const HEX_SIZE_M := 60.0  ## §1 hex width across flats (H3 res 10 equivalent)
const H3_RESOLUTION := 10  ## §1
const GLOOM_HEXES_PER_FRONT_PER_HOUR := 3  ## §1 unopposed capture rate
const FRONT_COMPLETION_GOLD := 200  ## §1 100%-player front bonus
const FRONT_RESET_HOURS := 24  ## §1 Gloom pressure pause after completion
const NEW_AREA_XP := 10  ## §1 first visit to a named area

# ── §2 Runs ─────────────────────────────────────────────────────────────────
const RUN_TARGET_MIN_MINUTES := 5  ## §2
const RUN_TARGET_MAX_MINUTES := 15  ## §2
const DROPPED_GOLD_PERSIST_HOURS := 1  ## §2/§5 recoverable window
const DROPPED_GOLD_RECOVER_RADIUS_M := 10.0  ## §2

# ── §3 Combat ───────────────────────────────────────────────────────────────
const PARTY_JOIN_RADIUS_M := 50.0  ## §3 drop-in co-op range
const HOTBAR_SLOTS := 5  ## §3
const MIDCOMBAT_SWAP_ALLOWED := true  ## §3
const CRIT_BASE_PCT := 10  ## §3 before gear CRIT
const COMBO_WINDOW_SEC := 3.0  ## §3 hit-chain window and idle reset
const WEAK_MULTIPLIER := 1.5  ## §3 ability affinity
const RESIST_MULTIPLIER := 0.5  ## §3
const TYRANT_HP_SEGMENTS := 4  ## §3 boss HP bar segments
const FLEE_BUFFER_HEXES := 1  ## §3 walk-out distance past the mob's hex

# ── §5 Death & revive ───────────────────────────────────────────────────────
const DEATH_CONTESTED_HEX_LOSS_CAP := 3  ## §5
const DEATH_GOLD_DROP_MIN := 50  ## §5 flat floor
const DEATH_GOLD_DROP_PCT := 10  ## §5 % of carried, whichever larger
const REVIVE_COUNTDOWN_SEC := 60  ## §5 wait-for-revive timer
const REVIVE_RADIUS_M := 30.0  ## §5 ally walk-to-revive range

# ── §6 Loot & chests ────────────────────────────────────────────────────────
const CHEST_NOTIFY_RADIUS_M := 200.0  ## §6 spawn push radius
const CHEST_OPEN_RADIUS_M := 10.0  ## §6 proximity gate
const CHEST_ITEM_COUNT := 3  ## §6 celebration screen items
const MOB_ITEM_DROP_PCT := 25  ## §6
const TYRANT_ITEM_DROP_PCT := 100  ## §6

# ── §7 Progression & gear ───────────────────────────────────────────────────
const XP_BASE := 100.0  ## §7 level curve base
const XP_GROWTH := 1.35  ## §7 level curve growth
const LEVEL_UP_ATK := 2  ## §7 per-level stat bumps
const LEVEL_UP_DEF := 1  ## §7
const LEVEL_UP_HP := 10  ## §7
const POCKET_BLIZZARD_UNLOCK_LEVEL := 13  ## §7 skill unlock
const CAPE_UNLOCK_LEVEL := 15  ## §7 canonical (an older mock's LV 20 is wrong)

# ── §8 Towers ───────────────────────────────────────────────────────────────
const TOWER_CAP := 5  ## §8 per player
const TOWER_PLACE_RADIUS_M := 10.0  ## §8 must stand on the hex
const TOWERS_PER_HEX := 1  ## §8
const BONK_TURRET_COST := 12  ## §8 🪵
const CHILL_BELL_COST := 18  ## §8 🪵
const BASTION_POST_COST := 30  ## §8 🪵
const BONK_TURRET_DMG_PER_TICK := 8  ## §8
const BONK_TURRET_RADIUS_HEXES := 2  ## §8
const CHILL_BELL_SLOW_PCT := 40  ## §8
const CHILL_BELL_RADIUS_HEXES := 2  ## §8
const BASTION_POST_RADIUS_HEXES := 1  ## §8 no-flip zone, no damage
const TOWER_DURABILITY_MAX := 100  ## §8 at level 1
const TOWER_DURABILITY_LOSS_PER_HOUR := 5  ## §8 while resisting Gloom contact
const TOWER_REPAIR_COST := 6  ## §8 🪵 to full
const TOWER_UPGRADE_COST := 22  ## §8 🪵 per level
const TOWER_UPGRADE_EFFECT_PCT := 25  ## §8 per level
const TOWER_UPGRADE_DURABILITY_BONUS := 25  ## §8 max durability per level
const TOWER_MAX_LEVEL := 3  ## §8
const TOWER_SALVAGE_REFUND_PCT := 40  ## §8 ~40%, rounded up (8 🪵 on Chill Bell)

# ── §9 Minions ──────────────────────────────────────────────────────────────
const MINION_ROSTER_START := 2  ## §9
const MINION_HIRE_COST := 200  ## §9 3rd slot at merchant
const MINION_HEAL_COST := 50  ## §9 instant
const GATHER_LUMBER_MINUTES := 30  ## §9
const GATHER_LUMBER_YIELD_MIN := 10  ## §9 🪵
const GATHER_LUMBER_YIELD_MAX := 16  ## §9 🪵
const SCOUT_FRONT_MINUTES := 15  ## §9
const SCAVENGE_MINUTES := 60  ## §9
const SCAVENGE_YIELD_BONUS_PCT := 50  ## §9
const SCAVENGE_INJURY_PCT := 20  ## §9

# ── §10 Quests ──────────────────────────────────────────────────────────────
const DAILY_WALK_STEPS := 2000  ## §10
const DAILY_WALK_GOLD := 80  ## §10
const DAILY_DEFEAT_COUNT := 5  ## §10
const DAILY_DEFEAT_GOLD := 120  ## §10
const TERRITORY_CLAIM_COUNT := 5  ## §10 hexes on one front in one run
const TERRITORY_CLAIM_GOLD := 200  ## §10
const NPC_REPLY_OPTIONS := 3  ## §10 accept / detail / decline

# ── §11 Economy ─────────────────────────────────────────────────────────────
const SHOP_STOCK_SIZE := 4  ## §11 rotating stock
const SHOP_DEAL_DISCOUNT_PCT := 30  ## §11 daily deal
const MYSTERY_BOX_COST := 199  ## §11 gold
const SHOP_SELL_PCT := 50  ## §11 of item value
const MOB_MATERIALS_DROP_PCT := 10  ## §11 rare 🪵 drop

# ── §12 Party ───────────────────────────────────────────────────────────────
const PARTY_MAX := 4  ## §12

# ── §13 Notifications ───────────────────────────────────────────────────────
const ATTACK_ALERT_HEX_LOSS := 5  ## §13 front loses ≥N hexes
const ATTACK_ALERT_TOWER_PCT := 25  ## §13 tower durability below N%

# ── §14 Safety & settings ───────────────────────────────────────────────────
const SPEED_PAUSE_KMH := 15  ## §14 driving guard


## §7 XP needed to clear the given level (next = 100 × 1.35^(level−1)).
static func xp_for_level(level: int) -> int:
	return roundi(XP_BASE * pow(XP_GROWTH, level - 1))


## §5 gold dropped on death: flat floor or % of carried, whichever larger.
static func death_gold_drop(carried_gold: int) -> int:
	return maxi(DEATH_GOLD_DROP_MIN, carried_gold * DEATH_GOLD_DROP_PCT / 100)


## §11 daily-deal price (120 → 84 in the shop mock).
static func deal_price(value: int) -> int:
	return roundi(value * (100 - SHOP_DEAL_DISCOUNT_PCT) / 100.0)


## §11 sell-back price at the merchant.
static func sell_value(value: int) -> int:
	return value * SHOP_SELL_PCT / 100


## §8 salvage refund on base cost, rounded up (Chill Bell 18 → 8).
static func tower_salvage_refund(base_cost: int) -> int:
	return ceili(base_cost * TOWER_SALVAGE_REFUND_PCT / 100.0)


## §8 max durability at a tower level (+25 per level past 1).
static func tower_durability_max(level: int) -> int:
	return TOWER_DURABILITY_MAX + TOWER_UPGRADE_DURABILITY_BONUS * (level - 1)


## "1204" → "1,204" (mock number style for steps/gold).
static func fmt_thousands(n: int) -> String:
	var sign := "-" if n < 0 else ""
	var digits := str(absi(n))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return sign + out


## 42 → "0:42" (revive countdown style).
static func fmt_mmss(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]
