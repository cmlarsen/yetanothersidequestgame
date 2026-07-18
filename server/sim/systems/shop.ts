// sim/systems/shop.ts — §11 the roaming merchant: deterministic rotating stock,
// the daily deal, the Mystery Grumble Box, and the buy/sell price math. PURE,
// CLOCK-INJECTED, SEED-DETERMINISTIC. Restock-epoch shape ported from
// SideQuestAppV2 server/sim/systems/merchant.ts — but where V2 persisted stall
// stock on a POI, here stock is a pure function of
// (seed, playerId, areasSeen.length, dailyResetAt): both §11 restock triggers
// (new-neighbourhood visit, daily reset) advance one of those persisted inputs,
// so a restock needs no state of its own and survives a server restart bit-exact.
// Validation lives in sim/commands_economy.ts (one ERR frame, zero mutation).

import type { ItemInstance, Player, World } from '../../shared/entities.js';
import type { ShopResultMsg, ShopStockWire } from '../../shared/protocol.js';
import { OP } from '../../shared/protocol.js';
import type { ItemId, Rarity } from '../../shared/catalog.js';
import { ITEMS, LOOT_POOL, RARITIES, itemDef } from '../../shared/catalog.js';
import {
  CHEST_RARITY_WEIGHTS,
  MYSTERY_BOX_COST,
  SHOP_DEAL_DISCOUNT_PCT,
  SHOP_STOCK_SIZE,
  dealPrice,
} from '../../shared/tuning.js';
import type { Rng } from '../../shared/rng.js';
import { seededRng } from '../../shared/rng.js';

/** What the merchant will shelve: real, purchasable catalog items (the mystery box
 * rides as its own fixed slot; zero-value placeholders never sell). */
export const SHOP_ROTATION_POOL: readonly ItemId[] = (Object.keys(ITEMS) as ItemId[])
  .filter((id) => ITEMS[id].value > 0 && ITEMS[id].rarity !== 'mystery')
  .sort();

/**
 * shopStock — the player's current shelf: SHOP_STOCK_SIZE rotating items (one
 * carrying the −30% daily deal) + the Mystery Grumble Box at its fixed price.
 * Pure read; same (seed, player progress, daily window) ⇒ identical shelf.
 */
export function shopStock(world: World, player: Player): ShopStockWire[] {
  const rng = seededRng(world.seed, 'shop', player.id, player.areasSeen.length, world.dailyResetAt);
  const pool = [...SHOP_ROTATION_POOL];
  const picks: ItemId[] = [];
  for (let i = 0; i < SHOP_STOCK_SIZE; i++) {
    picks.push(pool.splice(rng.int(0, pool.length - 1), 1)[0]);
  }
  const dealIdx = rng.int(0, SHOP_STOCK_SIZE - 1);
  const stock: ShopStockWire[] = picks.map((itemId, i) => {
    const value = ITEMS[itemId].value;
    return i === dealIdx
      ? { itemId, price: dealPrice(value), dealPct: SHOP_DEAL_DISCOUNT_PCT }
      : { itemId, price: value };
  });
  stock.push({ itemId: 'mystery_box', price: MYSTERY_BOX_COST });
  return stock;
}

/** The op113 frame: current gold + the player's shelf. */
export function buildShopResult(world: World, player: Player, now: number): ShopResultMsg {
  return { op: OP.SHOP_RESULT, t: now, gold: player.gold, stock: shopStock(world, player) };
}

/** Staged rarity roll over a weight table (§6/§11). Iterates the fixed RARITIES
 * ladder so the draw order is seed-stable. */
export function pickWeightedRarity(rng: Rng, weights: Record<Rarity, number>): Rarity {
  const total = RARITIES.reduce((sum, r) => sum + weights[r], 0);
  let roll = rng.uniform(0, total);
  for (const r of RARITIES) {
    roll -= weights[r];
    if (roll < 0) return r;
  }
  return RARITIES[RARITIES.length - 1];
}

/** §11 Mystery Grumble Box contents: rarity-weighted draw from the loot pool. */
export function rollMysteryItem(rng: Rng): { itemId: ItemId; rarity: Rarity } {
  const rarity = pickWeightedRarity(rng, CHEST_RARITY_WEIGHTS);
  return { itemId: rng.pick(LOOT_POOL[rarity]), rarity };
}

/** Mint an owned instance into the inventory (gold-dot new; consumable charges
 * seeded from the catalog effect). Shared by shop buys, minion salvage, quest rewards. */
export function grantItem(player: Player, itemId: string, iid: string): ItemInstance {
  const def = itemDef(itemId);
  const inst: ItemInstance = { iid, itemId, isNew: true };
  if (def?.effect.charges !== undefined) inst.charges = def.effect.charges;
  player.inventory.push(inst);
  return inst;
}

/** An instance referenced by the hotbar or paper doll can't be sold out from under it. */
export function isEquipped(player: Player, iid: string): boolean {
  if (player.hotbar.includes(iid)) return true;
  return Object.values(player.equipment).includes(iid);
}
