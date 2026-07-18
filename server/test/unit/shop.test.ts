// Shop (§11): rotating stock + deal math, restock triggers, buy/sell gates,
// the Mystery Grumble Box.

import { describe, expect, it } from 'vitest';
import '../../sim/commands_economy.js';
import { SimHarness } from '../harness/sim-harness.js';
import type { Conn } from '../../sim/commands.js';
import { OP } from '../../shared/protocol.js';
import type {
  InventoryUpdateMsg,
  LootResultMsg,
  ServerMsg,
  ShopResultMsg,
} from '../../shared/protocol.js';
import { ITEMS, LOOT_POOL } from '../../shared/catalog.js';
import type { ItemId, Rarity } from '../../shared/catalog.js';
import {
  MYSTERY_BOX_COST,
  SHOP_DEAL_DISCOUNT_PCT,
  SHOP_STOCK_SIZE,
  dealPrice,
  sellValue,
} from '../../shared/tuning.js';
import { grantItem, shopStock } from '../../sim/systems/shop.js';

const DAY_MS = 24 * 3_600_000;

function setup() {
  const h = SimHarness.create({ seed: 'shop-test' });
  const { player, conn } = h.join('shopper');
  return { h, player, conn };
}

function buy(h: SimHarness, conn: Conn, itemId: string): ServerMsg[] {
  return h.apply({ op: OP.BUY, t: h.clock.now(), itemId }, conn);
}

describe('stock (§11)', () => {
  it('shelves 4 rotating items + the mystery box, exactly one deal at dealPrice', () => {
    const { h, player } = setup();
    const stock = shopStock(h.world, player);
    expect(stock).toHaveLength(SHOP_STOCK_SIZE + 1);
    expect(stock[SHOP_STOCK_SIZE]).toEqual({ itemId: 'mystery_box', price: MYSTERY_BOX_COST });

    const rotating = stock.slice(0, SHOP_STOCK_SIZE);
    expect(new Set(rotating.map((s) => s.itemId)).size).toBe(SHOP_STOCK_SIZE);
    const deals = rotating.filter((s) => s.dealPct !== undefined);
    expect(deals).toHaveLength(1);
    expect(deals[0].dealPct).toBe(SHOP_DEAL_DISCOUNT_PCT);
    for (const s of rotating) {
      const value = ITEMS[s.itemId as ItemId].value;
      expect(s.price).toBe(s.dealPct !== undefined ? dealPrice(value) : value);
    }
    // pure read: same inputs, same shelf
    expect(shopStock(h.world, player)).toEqual(stock);
  });

  it('restocks on a new-front visit and on daily reset', () => {
    const { h, player } = setup();
    const before = shopStock(h.world, player);
    player.areasSeen.push('f0,0');
    const afterVisit = shopStock(h.world, player);
    expect(afterVisit).not.toEqual(before);

    h.world.dailyResetAt += DAY_MS;
    expect(shopStock(h.world, player)).not.toEqual(afterVisit);
  });
});

describe('BUY', () => {
  it('debits gold, mints the instance, replies SHOP_RESULT + INVENTORY_UPDATE', () => {
    const { h, player, conn } = setup();
    const entry = shopStock(h.world, player)[0];
    player.gold = entry.price;
    const invSize = player.inventory.length;

    const frames = buy(h, conn, entry.itemId);
    expect(frames.map((f) => f.op)).toEqual([OP.SHOP_RESULT, OP.INVENTORY_UPDATE]);
    expect((frames[0] as ShopResultMsg).gold).toBe(0);
    expect(player.gold).toBe(0);
    expect(player.inventory).toHaveLength(invSize + 1);
    const bought = player.inventory[invSize];
    expect(bought.itemId).toBe(entry.itemId);
    expect(bought.isNew).toBe(true);
  });

  it('gold gate: one ERR, zero mutation', () => {
    const { h, player, conn } = setup();
    const entry = shopStock(h.world, player)[0];
    player.gold = entry.price - 1;
    const invSize = player.inventory.length;
    const frames = buy(h, conn, entry.itemId);
    expect(frames).toHaveLength(1);
    expect(frames[0]).toMatchObject({ op: OP.ERR, code: 'INSUFFICIENT_GOLD' });
    expect(player.gold).toBe(entry.price - 1);
    expect(player.inventory).toHaveLength(invSize);
  });

  it('rejects an item not on the current shelf', () => {
    const { h, player, conn } = setup();
    player.gold = 9999;
    expect(buy(h, conn, 'unopened_chest')[0]).toMatchObject({ op: OP.ERR, code: 'NOT_FOUND' });
  });

  it('mystery box: 199 g, rarity-weighted loot-pool item, seed-deterministic', () => {
    const { h, player, conn } = setup();
    player.gold = MYSTERY_BOX_COST;
    const frames = buy(h, conn, 'mystery_box');
    expect(frames.map((f) => f.op)).toEqual([OP.LOOT_RESULT, OP.SHOP_RESULT, OP.INVENTORY_UPDATE]);
    const loot = frames[0] as LootResultMsg;
    expect(loot.sourceId).toBe('mystery_box');
    expect(loot.items).toHaveLength(1);
    const { itemId, rarity } = loot.items[0];
    expect(LOOT_POOL[rarity as Rarity]).toContain(itemId);
    expect(player.gold).toBe(0);
    expect(player.inventory.some((i) => i.itemId === itemId)).toBe(true);

    // same seed + same command history ⇒ identical roll
    const h2 = SimHarness.create({ seed: 'shop-test' });
    const p2 = h2.join('shopper');
    p2.player.gold = MYSTERY_BOX_COST;
    const frames2 = buy(h2, p2.conn, 'mystery_box');
    expect(frames2[0]).toEqual(loot);
  });
});

describe('SELL', () => {
  it('credits 50% of catalog value and removes the instance', () => {
    const { h, player, conn } = setup();
    grantItem(player, 'bonk_hammer', 'sell_me');
    const invSize = player.inventory.length;
    const frames = h.apply({ op: OP.SELL, t: h.clock.now(), iid: 'sell_me' }, conn);
    expect(frames.map((f) => f.op)).toEqual([OP.SHOP_RESULT, OP.INVENTORY_UPDATE]);
    expect(player.gold).toBe(sellValue(ITEMS.bonk_hammer.value)); // 320 → 160
    expect(player.gold).toBe(160);
    expect(player.inventory).toHaveLength(invSize - 1);
    expect((frames[1] as InventoryUpdateMsg).gold).toBe(160);
  });

  it('refuses to sell an equipped instance or an unknown iid', () => {
    const { h, player, conn } = setup();
    const equippedIid = player.hotbar[0]!;
    expect(h.apply({ op: OP.SELL, t: h.clock.now(), iid: equippedIid }, conn)[0]).toMatchObject({
      op: OP.ERR,
      code: 'ILLEGAL_STATE',
    });
    expect(h.apply({ op: OP.SELL, t: h.clock.now(), iid: 'nope' }, conn)[0]).toMatchObject({
      op: OP.ERR,
      code: 'NOT_FOUND',
    });
    expect(player.inventory).toHaveLength(4); // starter kit intact
  });
});
