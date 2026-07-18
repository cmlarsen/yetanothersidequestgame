// Progression & gear (§7): xp curve boundaries + LEVEL_UP frames (skill unlock
// LV13, cape LV15), gear stat aggregation, hammer set 2/4 flag, and the EQUIP /
// EQUIP_GEAR validation surface.

import { describe, expect, it } from 'vitest';
import '../../sim/commands_combat.js';
import { SimHarness } from '../harness/sim-harness.js';
import {
  gearSlotForItem,
  grantXp,
  knockbackMultiplier,
  knockbackMultiplierFromPieces,
  setProgress,
} from '../../sim/systems/progression.js';
import { playerStats } from '../../sim/world.js';
import { OP } from '../../shared/protocol.js';
import type { InventoryUpdateMsg, LevelUpMsg } from '../../shared/protocol.js';
import { ITEMS, SETS, itemDef } from '../../shared/catalog.js';
import {
  CAPE_UNLOCK_LEVEL,
  LEVEL_UP_HP,
  POCKET_BLIZZARD_UNLOCK_LEVEL,
  xpForLevel,
} from '../../shared/tuning.js';

function setup() {
  const h = SimHarness.create({ seed: 'progression-test' });
  const { player, conn } = h.join('leveler');
  return { h, player, conn };
}

function levelUps(h: SimHarness): LevelUpMsg[] {
  return h
    .drain()
    .filter((e) => e.msg.op === OP.LEVEL_UP)
    .map((e) => e.msg as LevelUpMsg);
}

describe('xp curve (§7: next = 100 × 1.35^(level−1))', () => {
  it('boundary values', () => {
    expect(xpForLevel(1)).toBe(100);
    expect(xpForLevel(2)).toBe(135);
    expect(xpForLevel(3)).toBe(182);
  });

  it('exactly the threshold levels up with zero remainder and bumps stats', () => {
    const { h, player } = setup();
    const maxHpBefore = player.maxHp;
    grantXp(h.world, player, xpForLevel(1), h.clock.now());
    expect(player.level).toBe(2);
    expect(player.xp).toBe(0);
    expect(player.maxHp).toBe(maxHpBefore + LEVEL_UP_HP);
    const ups = levelUps(h);
    expect(ups).toHaveLength(1);
    expect(ups[0]).toMatchObject({ level: 2, hp: LEVEL_UP_HP, unlocks: [] });
  });

  it('one grant can clear multiple levels, carrying the remainder', () => {
    const { h, player } = setup();
    grantXp(h.world, player, xpForLevel(1) + xpForLevel(2) + 50, h.clock.now());
    expect(player.level).toBe(3);
    expect(player.xp).toBe(50);
    expect(levelUps(h).map((u) => u.level)).toEqual([2, 3]);
  });

  it('one below the threshold does not level', () => {
    const { h, player } = setup();
    grantXp(h.world, player, xpForLevel(1) - 1, h.clock.now());
    expect(player.level).toBe(1);
    expect(player.xp).toBe(xpForLevel(1) - 1);
  });

  it('LV13 unlocks Pocket Blizzard, LV15 unlocks the cape slot', () => {
    const { h, player } = setup();
    player.level = POCKET_BLIZZARD_UNLOCK_LEVEL - 1;
    grantXp(h.world, player, xpForLevel(player.level), h.clock.now());
    expect(levelUps(h)[0].unlocks).toEqual(['pocket_blizzard']);
    player.level = CAPE_UNLOCK_LEVEL - 1;
    player.xp = 0;
    grantXp(h.world, player, xpForLevel(player.level), h.clock.now());
    expect(levelUps(h)[0].unlocks).toEqual(['cape_slot']);
  });
});

describe('gear stat aggregation (§7)', () => {
  it('equipped pieces add their stats; maxHp recomputes on equip', () => {
    const { h, player, conn } = setup();
    const hammerIid = player.inventory.find((i) => i.itemId === 'bonk_hammer')!.iid;
    const frames = h.apply(
      { op: OP.EQUIP_GEAR, t: h.clock.now(), gearSlot: 'main_hand', iid: hammerIid },
      conn,
    );
    const inv = frames[0] as InventoryUpdateMsg;
    expect(inv.op).toBe(OP.INVENTORY_UPDATE);
    expect(inv.stats.atk).toBe(ITEMS.bonk_hammer.stats.atk); // base ATK 0 at LV1
    player.inventory.push({ iid: 'helm1', itemId: 'hammered_helm', isNew: false });
    h.apply({ op: OP.EQUIP_GEAR, t: h.clock.now(), gearSlot: 'helm', iid: 'helm1' }, conn);
    const stats = playerStats(player);
    expect(stats.maxHp).toBe(12 + ITEMS.hammered_helm.stats.hp!);
    expect(stats.def).toBe(5 + ITEMS.hammered_helm.stats.def!);
    expect(player.maxHp).toBe(stats.maxHp); // cached
  });

  it('hammer set counts equipped pieces: 2/4 flag, bonus only when complete', () => {
    const { h, player, conn } = setup();
    const hammerIid = player.inventory.find((i) => i.itemId === 'bonk_hammer')!.iid;
    player.inventory.push({ iid: 'helm1', itemId: 'hammered_helm', isNew: false });
    h.apply({ op: OP.EQUIP_GEAR, t: h.clock.now(), gearSlot: 'main_hand', iid: hammerIid }, conn);
    h.apply({ op: OP.EQUIP_GEAR, t: h.clock.now(), gearSlot: 'helm', iid: 'helm1' }, conn);
    expect(setProgress(player, 'hammer')).toEqual({ pieces: 2, total: 4, active: false });
    expect(knockbackMultiplier(player)).toBe(1);
    expect(knockbackMultiplierFromPieces('hammer', SETS.hammer.piecesTotal)).toBeCloseTo(1.1, 10);
  });

  it('re-equipping an instance moves it (never referenced from two gear slots)', () => {
    const { h, player, conn } = setup();
    player.inventory.push({ iid: 'w2', itemId: 'thwack_o_matic', isNew: false });
    const hammerIid = player.inventory.find((i) => i.itemId === 'bonk_hammer')!.iid;
    h.apply({ op: OP.EQUIP_GEAR, t: h.clock.now(), gearSlot: 'main_hand', iid: hammerIid }, conn);
    h.apply({ op: OP.EQUIP_GEAR, t: h.clock.now(), gearSlot: 'main_hand', iid: 'w2' }, conn);
    expect(player.equipment.main_hand).toBe('w2');
    expect(player.inventory.some((i) => i.iid === hammerIid)).toBe(true); // back in the bag
  });
});

describe('EQUIP / EQUIP_GEAR validation', () => {
  it('hotbar slots take weapons/spells/consumables only, level-locked refuses', () => {
    const { h, player, conn } = setup();
    player.inventory.push({ iid: 'helm1', itemId: 'hammered_helm', isNew: false });
    const wrong = h.apply({ op: OP.EQUIP, t: h.clock.now(), slot: 4, iid: 'helm1' }, conn);
    expect(wrong[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    player.inventory.push({ iid: 'pb1', itemId: 'pocket_blizzard', isNew: false });
    const locked = h.apply({ op: OP.EQUIP, t: h.clock.now(), slot: 4, iid: 'pb1' }, conn);
    expect(locked[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    expect(player.hotbar[4]).toBeNull();
  });

  it('hotbar equip moves an instance between slots and null clears', () => {
    const { h, player, conn } = setup();
    const zapIid = player.hotbar[1]!;
    h.apply({ op: OP.EQUIP, t: h.clock.now(), slot: 4, iid: zapIid }, conn);
    expect(player.hotbar[1]).toBeNull(); // moved, not duplicated
    expect(player.hotbar[4]).toBe(zapIid);
    h.apply({ op: OP.EQUIP, t: h.clock.now(), slot: 4, iid: null }, conn);
    expect(player.hotbar[4]).toBeNull();
  });

  it('gear slot compatibility + ownership + the LV15 cape lock', () => {
    const { h, player, conn } = setup();
    const zapIid = player.hotbar[1]!;
    const mismatch = h.apply(
      { op: OP.EQUIP_GEAR, t: h.clock.now(), gearSlot: 'main_hand', iid: zapIid },
      conn,
    );
    expect(mismatch[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' }); // spell ≠ gear
    const unowned = h.apply(
      { op: OP.EQUIP_GEAR, t: h.clock.now(), gearSlot: 'helm', iid: 'nope' },
      conn,
    );
    expect(unowned[0]).toMatchObject({ op: OP.ERR, code: 'NOT_FOUND' });
    player.inventory.push({ iid: 'cape1', itemId: 'cape_of_mild_dramatics', isNew: false });
    const capeLocked = h.apply(
      { op: OP.EQUIP_GEAR, t: h.clock.now(), gearSlot: 'cape', iid: 'cape1' },
      conn,
    );
    expect(capeLocked[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    player.level = CAPE_UNLOCK_LEVEL;
    const capeOk = h.apply(
      { op: OP.EQUIP_GEAR, t: h.clock.now(), gearSlot: 'cape', iid: 'cape1' },
      conn,
    );
    expect(capeOk[0].op).toBe(OP.INVENTORY_UPDATE);
    expect(player.equipment.cape).toBe('cape1');
  });

  it('gearSlotForItem maps the catalog vocabulary', () => {
    expect(gearSlotForItem(itemDef('bonk_hammer')!)).toBe('main_hand');
    expect(gearSlotForItem(itemDef('grippy_gauntlets')!)).toBe('off_hand');
    expect(gearSlotForItem(itemDef('sneaky_boots')!)).toBe('boots');
    expect(gearSlotForItem(itemDef('zap_scroll')!)).toBeNull();
    expect(gearSlotForItem(itemDef('fizzy_mender')!)).toBeNull();
  });
});
