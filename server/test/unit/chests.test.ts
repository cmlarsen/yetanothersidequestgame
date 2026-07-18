// Chests (§6): spawn cadence near activity, the 10 m proximity gate, the 3-item
// staged roll (deterministic per seed), reopen/unknown guards, and the §1
// front-completion Grumble Chest.

import { describe, expect, it } from 'vitest';
import '../../sim/commands_combat.js';
import { SimHarness } from '../harness/sim-harness.js';
import {
  CHEST_GOLD_MAX,
  CHEST_GOLD_MIN,
  CHEST_SPAWN_INTERVAL_MS,
  CHEST_SPAWN_RADIUS_M,
  CHEST_XP,
} from '../../sim/systems/chests.js';
import { rarityRank } from '../../sim/systems/loot.js';
import { claimHexForPlayer } from '../../sim/systems/territory.js';
import { hexKey } from '../../shared/hexgrid.js';
import { distM } from '../../shared/geo.js';
import { FRONT_CELL_HEXES } from '../../shared/constants.js';
import { OP } from '../../shared/protocol.js';
import type { InventoryUpdateMsg, LootResultMsg } from '../../shared/protocol.js';
import type { Chest } from '../../shared/entities.js';
import type { Rarity } from '../../shared/catalog.js';

function setup(seed = 'chest-test') {
  const h = SimHarness.create({ seed });
  const jp = h.join('looter');
  h.runStart(jp.conn);
  h.tick(1); // primes the per-player spawn stamp
  return { h, ...jp };
}

function spawnOne(seed = 'chest-test') {
  const s = setup(seed);
  s.h.advance(CHEST_SPAWN_INTERVAL_MS + 1_000);
  const chest = [...s.h.world.chests.values()][0];
  return { ...s, chest };
}

describe('spawn cadence (server, near activity)', () => {
  it('spawns a seeded chest near an in-run player after the interval', () => {
    const { h, player } = setup();
    h.advance(60_000);
    expect(h.world.chests.size).toBe(0); // not yet
    h.advance(CHEST_SPAWN_INTERVAL_MS);
    expect(h.world.chests.size).toBe(1);
    const chest = [...h.world.chests.values()][0];
    expect(distM(chest.pos, player.pos)).toBeLessThanOrEqual(CHEST_SPAWN_RADIUS_M);
    expect(chest.openedBy).toBeUndefined();
  });

  it('placement is deterministic per seed', () => {
    const a = spawnOne();
    const b = spawnOne();
    expect(a.chest).toBeDefined();
    expect(a.chest.id).toBe(b.chest.id);
    expect(a.chest.hexKey).toBe(b.chest.hexKey);
  });

  it('does not spawn for players outside a run', () => {
    const h = SimHarness.create({ seed: 'chest-test' });
    h.join('idler');
    h.tick(1);
    h.advance(CHEST_SPAWN_INTERVAL_MS * 2);
    expect(h.world.chests.size).toBe(0);
  });

  it('caps unopened chests near one player', () => {
    const { h } = setup();
    for (let i = 0; i < 5; i++) h.advance(CHEST_SPAWN_INTERVAL_MS + 1_000);
    expect(h.world.chests.size).toBe(2); // CHEST_MAX_NEARBY
  });
});

describe('CHEST_OPEN (§6)', () => {
  it('within 10 m: 3-item staged roll, center is highest rarity, +gold +XP', () => {
    const { h, player, conn, chest } = spawnOne();
    h.teleport(player, chest.pos.x + 5, chest.pos.y);
    const invBefore = player.inventory.length;
    const xpBefore = player.xp;
    const goldBefore = player.gold;
    const frames = h.apply({ op: OP.CHEST_OPEN, t: h.clock.now(), chestId: chest.id }, conn);
    const loot = frames[0] as LootResultMsg;
    expect(loot.op).toBe(OP.LOOT_RESULT);
    expect(loot.sourceId).toBe(chest.id);
    expect(loot.items).toHaveLength(3);
    const ranks = loot.items.map((i) => rarityRank(i.rarity as Rarity));
    expect(ranks[1]).toBeGreaterThanOrEqual(ranks[0]);
    expect(ranks[1]).toBeGreaterThanOrEqual(ranks[2]);
    expect(loot.gold).toBeGreaterThanOrEqual(CHEST_GOLD_MIN);
    expect(loot.gold).toBeLessThanOrEqual(CHEST_GOLD_MAX);
    expect(loot.xp).toBe(CHEST_XP);
    expect(frames[1].op).toBe(OP.INVENTORY_UPDATE);
    expect((frames[1] as InventoryUpdateMsg).inventory).toHaveLength(invBefore + 3);
    expect(player.inventory).toHaveLength(invBefore + 3);
    expect(player.xp).toBe(xpBefore + CHEST_XP);
    expect(player.gold).toBe(goldBefore + loot.gold);
    expect(player.run!.lootItemIds).toHaveLength(3);
    expect(chest.openedBy).toBe(player.id);
  });

  it('loot is deterministic: same seed + same script ⇒ identical items', () => {
    const runs = [spawnOne(), spawnOne()].map(({ h, player, conn, chest }) => {
      h.teleport(player, chest.pos.x, chest.pos.y);
      const frames = h.apply({ op: OP.CHEST_OPEN, t: h.clock.now(), chestId: chest.id }, conn);
      return frames[0] as LootResultMsg;
    });
    expect(runs[0].items).toEqual(runs[1].items);
    expect(runs[0].gold).toBe(runs[1].gold);
  });

  it('proximity gate: beyond 10 m refuses without mutation', () => {
    const { h, player, conn, chest } = spawnOne();
    h.teleport(player, chest.pos.x + 50, chest.pos.y);
    const frames = h.apply({ op: OP.CHEST_OPEN, t: h.clock.now(), chestId: chest.id }, conn);
    expect(frames[0]).toMatchObject({ op: OP.ERR, code: 'OUT_OF_RANGE' });
    expect(chest.openedBy).toBeUndefined();
    expect(player.inventory.length).toBe(4); // starter kit only
  });

  it('reopen / unknown chest / no run are illegal', () => {
    const { h, player, conn, chest } = spawnOne();
    h.teleport(player, chest.pos.x, chest.pos.y);
    h.apply({ op: OP.CHEST_OPEN, t: h.clock.now(), chestId: chest.id }, conn);
    const again = h.apply({ op: OP.CHEST_OPEN, t: h.clock.now(), chestId: chest.id }, conn);
    expect(again[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    const unknown = h.apply({ op: OP.CHEST_OPEN, t: h.clock.now(), chestId: 'nope' }, conn);
    expect(unknown[0]).toMatchObject({ op: OP.ERR, code: 'NOT_FOUND' });
    h.runEnd(conn);
    const noRun = h.apply({ op: OP.CHEST_OPEN, t: h.clock.now(), chestId: chest.id }, conn);
    expect(noRun[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
  });

  it('opened chests cull after their linger window', () => {
    const { h, player, conn, chest } = spawnOne();
    h.teleport(player, chest.pos.x, chest.pos.y);
    h.apply({ op: OP.CHEST_OPEN, t: h.clock.now(), chestId: chest.id }, conn);
    h.tick(1); // stamp
    h.advance(61_000);
    expect(h.world.chests.has(chest.id)).toBe(false);
  });
});

describe('front completion (§1)', () => {
  it('bringing a front to 100% player spawns the Grumble Chest', () => {
    const { h, player } = setup();
    const now = h.clock.now();
    for (let q = 0; q < FRONT_CELL_HEXES; q++) {
      for (let r = 0; r < FRONT_CELL_HEXES; r++) {
        claimHexForPlayer(h.world, player, hexKey(q, r), now);
      }
    }
    expect(h.world.fronts.get('f0,0')?.completedAt).toBe(now);
    const grumble = [...h.world.chests.values()].find((c: Chest) => c.id.startsWith('ch:f:f0,0:'));
    expect(grumble).toBeDefined();
    expect(grumble!.openedBy).toBeUndefined();
  });
});
