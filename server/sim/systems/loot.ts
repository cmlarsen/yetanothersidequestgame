// sim/systems/loot.ts — the §6 rarity rolls. PURE: every draw comes off the
// injected Rng, in a documented order (gate → rarity → pool pick) so pinned-seed
// tests stay stable. rollRarity is deliberately a tiny standalone function — the
// golden chi-square test pins its distribution against the tuning weights.

import { LOOT_POOL, RARITIES } from '../../shared/catalog.js';
import type { ItemId, Rarity } from '../../shared/catalog.js';
import {
  CHEST_ITEM_COUNT,
  CHEST_RARITY_WEIGHTS,
  MOB_DROP_RARITY_WEIGHTS,
  MOB_ITEM_DROP_PCT,
  TYRANT_ITEM_DROP_PCT,
} from '../../shared/tuning.js';
import type { Rng } from '../../shared/rng.js';

export interface LootRoll {
  itemId: ItemId;
  rarity: Rarity;
}

/** 0-based position on the rarity ladder (common=0 … legendary=3). */
export function rarityRank(r: Rarity): number {
  return RARITIES.indexOf(r);
}

/** One weighted rarity draw (single rng() consumed). Weights need not sum to 100. */
export function rollRarity(weights: Record<Rarity, number>, rng: Rng): Rarity {
  let total = 0;
  for (const r of RARITIES) total += weights[r];
  let roll = rng() * total;
  for (const r of RARITIES) {
    roll -= weights[r];
    if (roll < 0) return r;
  }
  return RARITIES[RARITIES.length - 1]; // float-edge fallback (roll === total)
}

/** Rarity draw + uniform pool pick (two rng draws). */
export function rollLootItem(weights: Record<Rarity, number>, rng: Rng): LootRoll {
  const rarity = rollRarity(weights, rng);
  return { itemId: rng.pick(LOOT_POOL[rarity]), rarity };
}

/**
 * The §6 staged chest roll: CHEST_ITEM_COUNT items off CHEST_RARITY_WEIGHTS,
 * arranged [runner-up, highest, third] so index 1 is the celebration screen's
 * center (highest-rarity) item.
 */
export function rollChestLoot(rng: Rng): LootRoll[] {
  const rolls: LootRoll[] = [];
  for (let i = 0; i < CHEST_ITEM_COUNT; i++) rolls.push(rollLootItem(CHEST_RARITY_WEIGHTS, rng));
  const byRarity = [...rolls].sort((a, b) => rarityRank(b.rarity) - rarityRank(a.rarity));
  return [byRarity[1], byRarity[0], ...byRarity.slice(2)];
}

/**
 * The §6 mob item drop: chance gate (MOB_ITEM_DROP_PCT, Tyrants TYRANT_ITEM_DROP_PCT)
 * then a MOB_DROP_RARITY_WEIGHTS roll. Null = no drop. Draw order: gate, rarity, pick.
 */
export function rollMobDrop(rng: Rng, isTyrant: boolean): LootRoll | null {
  const pct = isTyrant ? TYRANT_ITEM_DROP_PCT : MOB_ITEM_DROP_PCT;
  if (!rng.chance(pct / 100)) return null;
  return rollLootItem(MOB_DROP_RARITY_WEIGHTS, rng);
}
