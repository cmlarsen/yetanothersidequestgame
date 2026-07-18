// Towers (§8): placement gates (distance / ownership / cap / 1-per-hex /
// materials), repair / upgrade / salvage math, retarget, repair-all, rubble
// rebuild, and the pure effect helpers the gloom system consumes.

import { describe, expect, it } from 'vitest';
import '../../sim/commands_economy.js';
import { SimHarness } from '../harness/sim-harness.js';
import type { Conn } from '../../sim/commands.js';
import { OP } from '../../shared/protocol.js';
import type { ServerMsg } from '../../shared/protocol.js';
import type { Player, Tower } from '../../shared/entities.js';
import { TOWERS } from '../../shared/catalog.js';
import type { TowerTypeId } from '../../shared/catalog.js';
import {
  TOWER_CAP,
  TOWER_MAX_LEVEL,
  TOWER_REPAIR_COST,
  TOWER_UPGRADE_COST,
  towerDurabilityMax,
  towerSalvageRefund,
} from '../../shared/tuning.js';
import { hexCenter, hexKey } from '../../shared/hexgrid.js';
import { claimHexForPlayer } from '../../sim/systems/territory.js';
import {
  bonkDamagePerTickAt,
  chillSlowPctAt,
  flipBlockedByTower,
  towerEffectAt,
} from '../../sim/systems/towers.js';

function setup() {
  const h = SimHarness.create({ seed: 'towers-test' });
  const { player, conn } = h.join('builder');
  return { h, player, conn };
}

/** Claim a hex and stand the player on its centre (placement is physical, §8). */
function standOnOwned(h: SimHarness, player: Player, q: number, r: number): string {
  const key = hexKey(q, r);
  claimHexForPlayer(h.world, player, key, h.clock.now());
  const c = hexCenter(q, r);
  h.teleport(player, c.x, c.y);
  return key;
}

function build(h: SimHarness, conn: Conn, type: TowerTypeId, key: string): ServerMsg[] {
  return h.apply({ op: OP.TOWER_BUILD, t: h.clock.now(), type, hexKey: key }, conn);
}

function soleTower(h: SimHarness): Tower {
  return [...h.world.towers.values()][0];
}

describe('TOWER_BUILD gates', () => {
  it('builds on the owned hex underfoot: materials debited, hex linked, LV1 full durability', () => {
    const { h, player, conn } = setup();
    const key = standOnOwned(h, player, 0, 0);
    player.materials = TOWERS.bonk_turret.cost;
    const frames = build(h, conn, 'bonk_turret', key);
    expect(frames.map((f) => f.op)).toEqual([OP.INVENTORY_UPDATE]);
    expect(player.materials).toBe(0);
    const tower = soleTower(h);
    expect(tower).toMatchObject({
      type: 'bonk_turret',
      hexKey: key,
      level: 1,
      durability: towerDurabilityMax(1),
      targetPriority: 'nearest',
      isRubble: false,
      ownerId: player.id,
    });
    expect(h.world.hexes.get(key)?.towerId).toBe(tower.id);
  });

  it('distance gate: not standing on the hex → OUT_OF_RANGE', () => {
    const { h, player, conn } = setup();
    standOnOwned(h, player, 0, 0);
    const far = hexKey(5, 5);
    claimHexForPlayer(h.world, player, far, h.clock.now());
    player.materials = 99;
    expect(build(h, conn, 'bonk_turret', far)[0]).toMatchObject({
      op: OP.ERR,
      code: 'OUT_OF_RANGE',
    });
    expect(h.world.towers.size).toBe(0);
  });

  it('ownership gate: neutral or gloom hexes refuse a tower', () => {
    const { h, player, conn } = setup();
    player.materials = 99;
    // standing on 0,0 but never claimed it
    expect(build(h, conn, 'bonk_turret', hexKey(0, 0))[0]).toMatchObject({
      op: OP.ERR,
      code: 'ILLEGAL_STATE',
    });
  });

  it('1 per hex', () => {
    const { h, player, conn } = setup();
    const key = standOnOwned(h, player, 0, 0);
    player.materials = 2 * TOWERS.bonk_turret.cost;
    build(h, conn, 'bonk_turret', key);
    expect(build(h, conn, 'bonk_turret', key)[0]).toMatchObject({
      op: OP.ERR,
      code: 'ILLEGAL_STATE',
    });
    expect(h.world.towers.size).toBe(1);
  });

  it('materials gate: one ERR, zero mutation', () => {
    const { h, player, conn } = setup();
    const key = standOnOwned(h, player, 0, 0);
    player.materials = TOWERS.bastion_post.cost - 1;
    expect(build(h, conn, 'bastion_post', key)[0]).toMatchObject({
      op: OP.ERR,
      code: 'INSUFFICIENT_MATERIALS',
    });
    expect(player.materials).toBe(TOWERS.bastion_post.cost - 1);
    expect(h.world.towers.size).toBe(0);
  });

  it(`cap: tower ${TOWER_CAP + 1} is refused`, () => {
    const { h, player, conn } = setup();
    player.materials = (TOWER_CAP + 1) * TOWERS.bonk_turret.cost;
    for (let q = 0; q < TOWER_CAP; q++) {
      const key = standOnOwned(h, player, q, 0);
      expect(build(h, conn, 'bonk_turret', key)[0].op).toBe(OP.INVENTORY_UPDATE);
    }
    const key = standOnOwned(h, player, TOWER_CAP, 0);
    expect(build(h, conn, 'bonk_turret', key)[0]).toMatchObject({
      op: OP.ERR,
      code: 'CAP_REACHED',
    });
    expect(h.world.towers.size).toBe(TOWER_CAP);
  });
});

describe('repair / upgrade / salvage / retarget', () => {
  function withTower(type: TowerTypeId = 'bonk_turret') {
    const ctx = setup();
    const key = standOnOwned(ctx.h, ctx.player, 0, 0);
    ctx.player.materials = TOWERS[type].cost;
    build(ctx.h, ctx.conn, type, key);
    return { ...ctx, key, tower: soleTower(ctx.h) };
  }

  it('repair: 6 🪵 back to full; full/rubble repairs are illegal', () => {
    const { h, player, conn, tower } = withTower();
    player.materials = TOWER_REPAIR_COST;
    expect(
      h.apply({ op: OP.TOWER_REPAIR, t: h.clock.now(), towerId: tower.id }, conn)[0],
    ).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' }); // already full
    tower.durability = 40;
    h.apply({ op: OP.TOWER_REPAIR, t: h.clock.now(), towerId: tower.id }, conn);
    expect(tower.durability).toBe(towerDurabilityMax(1));
    expect(player.materials).toBe(0);

    tower.durability = 0;
    tower.isRubble = true;
    player.materials = TOWER_REPAIR_COST;
    expect(
      h.apply({ op: OP.TOWER_REPAIR, t: h.clock.now(), towerId: tower.id }, conn)[0],
    ).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
  });

  it('upgrade: 22 🪵, +25 durability now and on the cap, max LV3', () => {
    const { h, player, conn, tower } = withTower();
    player.materials = 3 * TOWER_UPGRADE_COST;
    h.apply({ op: OP.TOWER_UPGRADE, t: h.clock.now(), towerId: tower.id }, conn);
    expect(tower.level).toBe(2);
    expect(tower.durability).toBe(towerDurabilityMax(2)); // 100 + 25, clamped to the new max
    h.apply({ op: OP.TOWER_UPGRADE, t: h.clock.now(), towerId: tower.id }, conn);
    expect(tower.level).toBe(TOWER_MAX_LEVEL);
    expect(
      h.apply({ op: OP.TOWER_UPGRADE, t: h.clock.now(), towerId: tower.id }, conn)[0],
    ).toMatchObject({ op: OP.ERR, code: 'CAP_REACHED' });
    expect(player.materials).toBe(TOWER_UPGRADE_COST); // only two upgrades were paid
  });

  it('salvage: ~40% of base cost (Chill Bell 18 → 8), tower removed, hex unlinked; works on rubble', () => {
    const { h, player, conn, key, tower } = withTower('chill_bell');
    tower.durability = 0;
    tower.isRubble = true;
    h.apply({ op: OP.TOWER_SALVAGE, t: h.clock.now(), towerId: tower.id }, conn);
    expect(player.materials).toBe(towerSalvageRefund(TOWERS.chill_bell.cost));
    expect(player.materials).toBe(8);
    expect(h.world.towers.size).toBe(0);
    expect(h.world.hexes.get(key)?.towerId).toBeUndefined();
  });

  it('retarget sets the priority; other players cannot touch your tower', () => {
    const { h, conn, tower } = withTower();
    h.apply({ op: OP.TOWER_TARGET, t: h.clock.now(), towerId: tower.id, priority: 'strongest' }, conn);
    expect(tower.targetPriority).toBe('strongest');

    const rival = h.join('rival');
    expect(
      h.apply(
        { op: OP.TOWER_TARGET, t: h.clock.now(), towerId: tower.id, priority: 'guard_home' },
        rival.conn,
      )[0],
    ).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    expect(tower.targetPriority).toBe('strongest');
  });

  it('repair-all: fixes damaged towers in id order while materials last', () => {
    const { h, player, conn } = setup();
    player.materials = 2 * TOWERS.bonk_turret.cost;
    const k1 = standOnOwned(h, player, 0, 0);
    build(h, conn, 'bonk_turret', k1);
    const k2 = standOnOwned(h, player, 1, 0);
    build(h, conn, 'bonk_turret', k2);
    const [t1, t2] = [...h.world.towers.values()].sort((a, b) => (a.id < b.id ? -1 : 1));

    expect(h.apply({ op: OP.TOWER_REPAIR_ALL, t: h.clock.now() }, conn)[0]).toMatchObject({
      op: OP.ERR,
      code: 'ILLEGAL_STATE', // nothing to repair
    });

    t1.durability = 10;
    t2.durability = 10;
    player.materials = TOWER_REPAIR_COST + 1; // enough for exactly one
    h.apply({ op: OP.TOWER_REPAIR_ALL, t: h.clock.now() }, conn);
    expect(t1.durability).toBe(towerDurabilityMax(1));
    expect(t2.durability).toBe(10);
    expect(player.materials).toBe(1);

    player.materials = 2 * TOWER_REPAIR_COST;
    h.apply({ op: OP.TOWER_REPAIR_ALL, t: h.clock.now() }, conn);
    expect(t2.durability).toBe(towerDurabilityMax(1));
  });
});

describe('rubble rebuild (§8: physical visit)', () => {
  it('TOWER_BUILD on your rubble hex replaces it at full cost; not from afar', () => {
    const { h, player, conn } = setup();
    const key = standOnOwned(h, player, 0, 0);
    player.materials = 2 * TOWERS.bonk_turret.cost;
    build(h, conn, 'bonk_turret', key);
    const old = soleTower(h);
    old.durability = 0;
    old.isRubble = true;

    // walk away → rebuild refused by the distance gate
    h.teleport(player, hexCenter(5, 5).x, hexCenter(5, 5).y);
    expect(build(h, conn, 'bonk_turret', key)[0]).toMatchObject({
      op: OP.ERR,
      code: 'OUT_OF_RANGE',
    });

    // return → rebuild consumes the rubble and mints a fresh tower
    h.teleport(player, hexCenter(0, 0).x, hexCenter(0, 0).y);
    build(h, conn, 'bonk_turret', key);
    expect(h.world.towers.size).toBe(1);
    const rebuilt = soleTower(h);
    expect(rebuilt.id).not.toBe(old.id);
    expect(rebuilt.isRubble).toBe(false);
    expect(rebuilt.durability).toBe(towerDurabilityMax(1));
    expect(player.materials).toBe(0);
    expect(h.world.hexes.get(key)?.towerId).toBe(rebuilt.id);
  });
});

describe('effect helpers (gloom/combat consumers)', () => {
  it('chill slow: 40% at LV1 in radius 2, +25%/level, 0 outside; rubble is inert', () => {
    const { h, player, conn } = setup();
    const key = standOnOwned(h, player, 0, 0);
    player.materials = TOWERS.chill_bell.cost;
    build(h, conn, 'chill_bell', key);
    const bell = soleTower(h);
    expect(chillSlowPctAt(h.world, 2, 0)).toBe(40);
    expect(chillSlowPctAt(h.world, 3, 0)).toBe(0);
    bell.level = 2;
    expect(chillSlowPctAt(h.world, 0, 0)).toBe(50);
    bell.isRubble = true;
    expect(chillSlowPctAt(h.world, 0, 0)).toBe(0);
  });

  it('bonk damage scales +25%/level and sums over covering turrets', () => {
    const { h, player, conn } = setup();
    const key = standOnOwned(h, player, 0, 0);
    player.materials = TOWERS.bonk_turret.cost;
    build(h, conn, 'bonk_turret', key);
    expect(bonkDamagePerTickAt(h.world, 1, 0)).toBe(8);
    soleTower(h).level = 2;
    expect(bonkDamagePerTickAt(h.world, 1, 0)).toBe(10);
    expect(bonkDamagePerTickAt(h.world, 4, 0)).toBe(0); // radius 2
  });

  it('flip block: any standing tower holds its hex; a bastion post holds radius 1', () => {
    const { h, player, conn } = setup();
    const key = standOnOwned(h, player, 0, 0);
    player.materials = TOWERS.bastion_post.cost;
    build(h, conn, 'bastion_post', key);
    expect(flipBlockedByTower(h.world, 0, 0)).toBe(true);
    expect(flipBlockedByTower(h.world, 1, 0)).toBe(true);
    expect(flipBlockedByTower(h.world, 2, 0)).toBe(false);
    expect(towerEffectAt(h.world, 1, 0)).toEqual({ dmgPerTick: 0, slowPct: 0, flipBlocked: true });
    soleTower(h).isRubble = true;
    expect(flipBlockedByTower(h.world, 0, 0)).toBe(false);
  });
});
