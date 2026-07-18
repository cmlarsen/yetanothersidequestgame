// shared/tuning.ts — EVERY DEFAULT-marked number from docs/design/yas-v1/GAME-RULES.md
// as a named constant (§ refs point there). Names and meanings align 1:1 with the
// Godot shell's game/src/rules/rules.gd — tools codegen will later enforce equality;
// until then test/unit cross-checks. Balance lives HERE (server-side source of truth);
// structural net constants live in constants.ts. I/O-free, deterministic.

import type { Rarity } from './catalog.js';
import { HEX_ACROSS_M } from './hexgrid.js';

// ── §1 World & territory ────────────────────────────────────────────────────
export const HEX_SIZE_M = HEX_ACROSS_M; // §1 hex width across flats (owned by hexgrid.ts)
export const H3_RESOLUTION = 10; // §1 "H3 res 10 or equivalent" (we use our own flat-top axial grid)
export const GLOOM_HEXES_PER_FRONT_PER_HOUR = 3; // §1 unopposed capture rate
export const FRONT_COMPLETION_GOLD = 200; // §1 100%-player front bonus
export const FRONT_RESET_HOURS = 24; // §1 Gloom pressure pause after completion
export const NEW_AREA_XP = 10; // §1 first visit to a named area

// ── §2 Runs ─────────────────────────────────────────────────────────────────
export const RUN_TARGET_MIN_MINUTES = 5; // §2
export const RUN_TARGET_MAX_MINUTES = 15; // §2
export const DROPPED_GOLD_PERSIST_HOURS = 1; // §2/§5 recoverable window
export const DROPPED_GOLD_RECOVER_RADIUS_M = 10; // §2

// ── §3 Combat ───────────────────────────────────────────────────────────────
export const PARTY_JOIN_RADIUS_M = 50; // §3 drop-in co-op range
export const HOTBAR_SLOTS = 5; // §3
export const MIDCOMBAT_SWAP_ALLOWED = true; // §3
export const CRIT_BASE_PCT = 10; // §3 before gear CRIT
export const COMBO_WINDOW_SEC = 3; // §3 hit-chain window and idle reset
export const WEAK_MULTIPLIER = 1.5; // §3 ability affinity
export const RESIST_MULTIPLIER = 0.5; // §3
export const TYRANT_HP_SEGMENTS = 4; // §3 boss HP bar segments
export const FLEE_BUFFER_HEXES = 1; // §3 walk-out distance past the mob's hex

// ── §5 Death & revive ───────────────────────────────────────────────────────
export const DEATH_CONTESTED_HEX_LOSS_CAP = 3; // §5
export const DEATH_GOLD_DROP_MIN = 50; // §5 flat floor
export const DEATH_GOLD_DROP_PCT = 10; // §5 % of carried, whichever larger
export const REVIVE_COUNTDOWN_SEC = 60; // §5 wait-for-revive timer
export const REVIVE_RADIUS_M = 30; // §5 ally walk-to-revive range

// ── §6 Loot & chests ────────────────────────────────────────────────────────
export const CHEST_NOTIFY_RADIUS_M = 200; // §6 spawn push radius
export const CHEST_OPEN_RADIUS_M = 10; // §6 proximity gate
export const CHEST_ITEM_COUNT = 3; // §6 celebration screen items
export const MOB_ITEM_DROP_PCT = 25; // §6
export const TYRANT_ITEM_DROP_PCT = 100; // §6

// §6 loot rarity weight tables (sum 100 each; golden test pins the resulting odds).
// The staged chest roll draws CHEST_ITEM_COUNT items from CHEST_RARITY_WEIGHTS
// (center item = highest rarity); mob item drops (after the §6 drop-chance gate)
// roll MOB_DROP_RARITY_WEIGHTS.
export const CHEST_RARITY_WEIGHTS: Record<Rarity, number> = {
  common: 60,
  rare: 30,
  epic: 9,
  legendary: 1,
};
export const MOB_DROP_RARITY_WEIGHTS: Record<Rarity, number> = {
  common: 70,
  rare: 25,
  epic: 4,
  legendary: 1,
};

// ── §7 Progression & gear ───────────────────────────────────────────────────
export const XP_BASE = 100; // §7 level curve base
export const XP_GROWTH = 1.35; // §7 level curve growth
export const LEVEL_UP_ATK = 2; // §7 per-level stat bumps
export const LEVEL_UP_DEF = 1; // §7
export const LEVEL_UP_HP = 10; // §7
export const POCKET_BLIZZARD_UNLOCK_LEVEL = 13; // §7 skill unlock
export const CAPE_UNLOCK_LEVEL = 15; // §7 canonical (an older mock's LV 20 is wrong)

// ── §8 Towers ───────────────────────────────────────────────────────────────
export const TOWER_CAP = 5; // §8 per player
export const TOWER_PLACE_RADIUS_M = 10; // §8 must stand on the hex
export const TOWERS_PER_HEX = 1; // §8
export const BONK_TURRET_COST = 12; // §8 🪵
export const CHILL_BELL_COST = 18; // §8 🪵
export const BASTION_POST_COST = 30; // §8 🪵
export const BONK_TURRET_DMG_PER_TICK = 8; // §8
export const BONK_TURRET_RADIUS_HEXES = 2; // §8
export const CHILL_BELL_SLOW_PCT = 40; // §8
export const CHILL_BELL_RADIUS_HEXES = 2; // §8
export const BASTION_POST_RADIUS_HEXES = 1; // §8 no-flip zone, no damage
export const TOWER_DURABILITY_MAX = 100; // §8 at level 1
export const TOWER_DURABILITY_LOSS_PER_HOUR = 5; // §8 while resisting Gloom contact
export const TOWER_REPAIR_COST = 6; // §8 🪵 to full
export const TOWER_UPGRADE_COST = 22; // §8 🪵 per level
export const TOWER_UPGRADE_EFFECT_PCT = 25; // §8 per level
export const TOWER_UPGRADE_DURABILITY_BONUS = 25; // §8 max durability per level
export const TOWER_MAX_LEVEL = 3; // §8
export const TOWER_SALVAGE_REFUND_PCT = 40; // §8 ~40%, rounded up (8 🪵 on Chill Bell)

// ── §9 Minions ──────────────────────────────────────────────────────────────
export const MINION_ROSTER_START = 2; // §9
export const MINION_HIRE_COST = 200; // §9 3rd slot at merchant
export const MINION_HEAL_COST = 50; // §9 instant
export const GATHER_LUMBER_MINUTES = 30; // §9
export const GATHER_LUMBER_YIELD_MIN = 10; // §9 🪵
export const GATHER_LUMBER_YIELD_MAX = 16; // §9 🪵
export const SCOUT_FRONT_MINUTES = 15; // §9
export const SCAVENGE_MINUTES = 60; // §9
export const SCAVENGE_YIELD_BONUS_PCT = 50; // §9
export const SCAVENGE_INJURY_PCT = 20; // §9

// ── §10 Quests ──────────────────────────────────────────────────────────────
export const DAILY_WALK_STEPS = 2000; // §10
export const DAILY_WALK_GOLD = 80; // §10
export const DAILY_DEFEAT_COUNT = 5; // §10
export const DAILY_DEFEAT_GOLD = 120; // §10
export const TERRITORY_CLAIM_COUNT = 5; // §10 hexes on one front in one run
export const TERRITORY_CLAIM_GOLD = 200; // §10
export const NPC_REPLY_OPTIONS = 3; // §10 accept / detail / decline

// ── §11 Economy ─────────────────────────────────────────────────────────────
export const SHOP_STOCK_SIZE = 4; // §11 rotating stock
export const SHOP_DEAL_DISCOUNT_PCT = 30; // §11 daily deal
export const MYSTERY_BOX_COST = 199; // §11 gold
export const SHOP_SELL_PCT = 50; // §11 of item value
export const MOB_MATERIALS_DROP_PCT = 10; // §11 rare 🪵 drop

// ── §12 Party ───────────────────────────────────────────────────────────────
export const PARTY_MAX = 4; // §12

// ── §13 Notifications ───────────────────────────────────────────────────────
export const ATTACK_ALERT_HEX_LOSS = 5; // §13 front loses ≥N hexes
export const ATTACK_ALERT_TOWER_PCT = 25; // §13 tower durability below N%

// ── §14 Safety & settings ───────────────────────────────────────────────────
export const SPEED_PAUSE_KMH = 15; // §14 driving guard: claiming + combat pause above this

// ── derived helpers (mirror rules.gd's static funcs; integer math kept identical) ──

/** §7 XP needed to clear the given level (next = 100 × 1.35^(level−1)). */
export function xpForLevel(level: number): number {
  return Math.round(XP_BASE * Math.pow(XP_GROWTH, level - 1));
}

/** §5 gold dropped on death: flat floor or % of carried, whichever larger. */
export function deathGoldDrop(carriedGold: number): number {
  return Math.max(DEATH_GOLD_DROP_MIN, Math.floor((carriedGold * DEATH_GOLD_DROP_PCT) / 100));
}

/** §11 daily-deal price (120 → 84 in the shop mock). */
export function dealPrice(value: number): number {
  return Math.round((value * (100 - SHOP_DEAL_DISCOUNT_PCT)) / 100);
}

/** §11 sell-back price at the merchant. */
export function sellValue(value: number): number {
  return Math.floor((value * SHOP_SELL_PCT) / 100);
}

/** §8 salvage refund on base cost, rounded up (Chill Bell 18 → 8). */
export function towerSalvageRefund(baseCost: number): number {
  return Math.ceil((baseCost * TOWER_SALVAGE_REFUND_PCT) / 100);
}

/** §8 max durability at a tower level (+25 per level past 1). */
export function towerDurabilityMax(level: number): number {
  return TOWER_DURABILITY_MAX + TOWER_UPGRADE_DURABILITY_BONUS * (level - 1);
}
