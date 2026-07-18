// Integration (e)+(f): the §8 tower build/repair/upgrade/salvage cycle and the §9
// minion dispatch→collect loop, driven end-to-end through applyCommand with a
// ManualClock — including every affordability/validity ERR the commands guard.

import { describe, expect, it } from 'vitest';
import '../../sim/commands_economy.js';
import { SimHarness, type JoinedPlayer } from '../harness/sim-harness.js';
import type { Conn } from '../../sim/commands.js';
import { hexCenter } from '../../shared/hexgrid.js';
import { OP } from '../../shared/protocol.js';
import type { MinionReportMsg, ServerMsg } from '../../shared/protocol.js';
import {
  BONK_TURRET_COST,
  CHILL_BELL_COST,
  GATHER_LUMBER_MINUTES,
  GATHER_LUMBER_YIELD_MAX,
  GATHER_LUMBER_YIELD_MIN,
  MINION_HEAL_COST,
  MINION_HIRE_COST,
  SCOUT_FRONT_MINUTES,
  TOWER_CAP,
  TOWER_MAX_LEVEL,
  TOWER_REPAIR_COST,
  TOWER_UPGRADE_COST,
  TOWER_UPGRADE_DURABILITY_BONUS,
  towerDurabilityMax,
  towerSalvageRefund,
} from '../../shared/tuning.js';

const MIN_MS = 60_000;

function setup(): { h: SimHarness } & JoinedPlayer {
  const h = SimHarness.create({ seed: 'towers-minions-int' });
  const jp = h.join('builder');
  return { h, ...jp };
}

/** Walk (teleport + tick) onto a hex so the run's claim-on-enter takes it. */
function claimByEntering(h: SimHarness, jp: JoinedPlayer, q: number, r: number): void {
  const c = hexCenter(q, r);
  h.teleport(jp.player, c.x, c.y);
  h.tick(1);
}

function build(h: SimHarness, conn: Conn, type: 'bonk_turret' | 'chill_bell' | 'bastion_post', hexKey: string): ServerMsg[] {
  return h.apply({ op: OP.TOWER_BUILD, t: h.clock.now(), type, hexKey }, conn);
}

describe('tower lifecycle (§8) through applyCommand', () => {
  it('build → wear → repair → upgrade ×2 → salvage, with every gate ERRing first', () => {
    const { h, player, conn, ...rest } = setup();
    void rest;
    const jp = { player, conn, frames: [] as ServerMsg[] };

    // not-owned: standing on a neutral hex refuses before any run/claim exists
    h.teleport(player, 0, 0);
    expect(build(h, conn, 'bonk_turret', '0,0')[0]).toMatchObject({
      op: OP.ERR,
      code: 'ILLEGAL_STATE',
    });

    h.runStart(conn);
    h.tick(1); // claims 0,0 (home)
    claimByEntering(h, jp, 1, 0);

    // out of range: targeting a hex you are not standing on
    expect(build(h, conn, 'bonk_turret', '5,5')[0]).toMatchObject({
      op: OP.ERR,
      code: 'OUT_OF_RANGE',
    });

    // affordability: broke builder
    h.teleport(player, 0, 0);
    player.materials = BONK_TURRET_COST - 1;
    expect(build(h, conn, 'bonk_turret', '0,0')[0]).toMatchObject({
      op: OP.ERR,
      code: 'INSUFFICIENT_MATERIALS',
    });
    expect(h.world.towers.size).toBe(0);
    expect(player.materials).toBe(BONK_TURRET_COST - 1); // zero mutation on ERR

    // build for real
    player.materials = 100;
    const built = build(h, conn, 'bonk_turret', '0,0');
    expect(built[0].op).toBe(OP.INVENTORY_UPDATE);
    expect(player.materials).toBe(100 - BONK_TURRET_COST);
    const tower = [...h.world.towers.values()][0];
    expect(tower).toMatchObject({ type: 'bonk_turret', level: 1, isRubble: false });
    expect(h.world.hexes.get('0,0')!.towerId).toBe(tower.id);

    // one tower per hex
    expect(build(h, conn, 'chill_bell', '0,0')[0]).toMatchObject({
      op: OP.ERR,
      code: 'ILLEGAL_STATE',
    });

    // repair: full → refuse; worn → 6🪵 back to full; broke → refuse
    const repair = (): ServerMsg[] =>
      h.apply({ op: OP.TOWER_REPAIR, t: h.clock.now(), towerId: tower.id }, conn);
    expect(repair()[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    tower.durability = 40;
    const beforeRepair = player.materials;
    expect(repair()[0].op).toBe(OP.INVENTORY_UPDATE);
    expect(tower.durability).toBe(towerDurabilityMax(1));
    expect(player.materials).toBe(beforeRepair - TOWER_REPAIR_COST);
    tower.durability = 40;
    player.materials = TOWER_REPAIR_COST - 1;
    expect(repair()[0]).toMatchObject({ op: OP.ERR, code: 'INSUFFICIENT_MATERIALS' });

    // upgrade to the cap: +25 durability each level, then CAP_REACHED
    const upgrade = (): ServerMsg[] =>
      h.apply({ op: OP.TOWER_UPGRADE, t: h.clock.now(), towerId: tower.id }, conn);
    player.materials = TOWER_UPGRADE_COST - 1;
    expect(upgrade()[0]).toMatchObject({ op: OP.ERR, code: 'INSUFFICIENT_MATERIALS' });
    player.materials = 2 * TOWER_UPGRADE_COST;
    tower.durability = towerDurabilityMax(1);
    expect(upgrade()[0].op).toBe(OP.INVENTORY_UPDATE);
    expect(tower.level).toBe(2);
    expect(tower.durability).toBe(towerDurabilityMax(1) + TOWER_UPGRADE_DURABILITY_BONUS);
    expect(upgrade()[0].op).toBe(OP.INVENTORY_UPDATE);
    expect(tower.level).toBe(TOWER_MAX_LEVEL);
    player.materials = TOWER_UPGRADE_COST;
    expect(upgrade()[0]).toMatchObject({ op: OP.ERR, code: 'CAP_REACHED' });

    // retarget
    expect(
      h.apply(
        { op: OP.TOWER_TARGET, t: h.clock.now(), towerId: tower.id, priority: 'guard_home' },
        conn,
      ),
    ).toEqual([]);
    expect(tower.targetPriority).toBe('guard_home');

    // salvage: refund ~40% of base cost, tower + hex link gone; works on rubble too
    const beforeSalvage = player.materials;
    expect(
      h.apply({ op: OP.TOWER_SALVAGE, t: h.clock.now(), towerId: tower.id }, conn)[0].op,
    ).toBe(OP.INVENTORY_UPDATE);
    expect(player.materials).toBe(beforeSalvage + towerSalvageRefund(BONK_TURRET_COST));
    expect(h.world.towers.size).toBe(0);
    expect(h.world.hexes.get('0,0')!.towerId).toBeUndefined();

    player.materials = CHILL_BELL_COST;
    build(h, conn, 'chill_bell', '0,0');
    const bell = [...h.world.towers.values()][0];
    bell.durability = 0;
    bell.isRubble = true;
    expect(
      h.apply({ op: OP.TOWER_SALVAGE, t: h.clock.now(), towerId: bell.id }, conn)[0].op,
    ).toBe(OP.INVENTORY_UPDATE);
    expect(player.materials).toBe(towerSalvageRefund(CHILL_BELL_COST));

    // unknown / not-yours
    expect(
      h.apply({ op: OP.TOWER_REPAIR, t: h.clock.now(), towerId: 'nope' }, conn)[0],
    ).toMatchObject({ op: OP.ERR, code: 'NOT_FOUND' });
  });

  it('repair-all fixes damaged towers in id order while materials last; cap 5 towers', () => {
    const { h, player, conn, ...rest } = setup();
    void rest;
    const jp = { player, conn, frames: [] as ServerMsg[] };
    h.runStart(conn);
    h.tick(1);
    player.materials = 1000;
    for (let q = 1; q < TOWER_CAP; q++) claimByEntering(h, jp, q, 0);
    for (let q = 0; q < TOWER_CAP; q++) {
      const c = hexCenter(q, 0);
      h.teleport(player, c.x, c.y);
      expect(build(h, conn, 'bonk_turret', `${q},0`)[0].op).toBe(OP.INVENTORY_UPDATE);
    }
    // 6th tower: cap
    claimByEntering(h, jp, 5, 0);
    expect(build(h, conn, 'bonk_turret', '5,0')[0]).toMatchObject({
      op: OP.ERR,
      code: 'CAP_REACHED',
    });

    const towers = [...h.world.towers.values()].sort((a, b) => (a.id < b.id ? -1 : 1));
    for (const t of towers) t.durability = 10;
    player.materials = 2 * TOWER_REPAIR_COST; // only covers the first two in id order
    expect(h.apply({ op: OP.TOWER_REPAIR_ALL, t: h.clock.now() }, conn)[0].op).toBe(
      OP.INVENTORY_UPDATE,
    );
    expect(towers.map((t) => t.durability)).toEqual([100, 100, 10, 10, 10]);
    expect(player.materials).toBe(0);
    expect(h.apply({ op: OP.TOWER_REPAIR_ALL, t: h.clock.now() }, conn)[0]).toMatchObject({
      op: OP.ERR,
      code: 'INSUFFICIENT_MATERIALS',
    });
  });
});

describe('minion jobs (§9) across a ManualClock advance', () => {
  it('dispatch → advance 30 min → completion notice → collect report + haul', () => {
    const { h, player, conn } = setup();
    const [gruncle] = h.world.minions.get(player.id)!;
    const send = (minionId: string): ServerMsg[] =>
      h.apply({ op: OP.MINION_SEND, t: h.clock.now(), minionId, jobId: 'gather_lumber' }, conn);
    const collect = (minionId: string): ServerMsg[] =>
      h.apply({ op: OP.MINION_COLLECT, t: h.clock.now(), minionId }, conn);

    expect(send(gruncle.id)).toEqual([]);
    expect(gruncle.state).toBe('on_job');
    expect(gruncle.job).toMatchObject({
      jobId: 'gather_lumber',
      endsAt: h.clock.now() + GATHER_LUMBER_MINUTES * MIN_MS,
    });
    // still working / double-send refuse
    expect(collect(gruncle.id)[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    expect(send(gruncle.id)[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });

    h.clock.advance(GATHER_LUMBER_MINUTES * MIN_MS + 1000);
    h.tick(1); // the §13 "returned" beat fires once
    const notices = h
      .drain()
      .filter((e) => e.to === player.id && e.msg.op === OP.EVENTS)
      .flatMap((e) => (e.msg.op === OP.EVENTS ? e.msg.events : []))
      .filter((ev) => ev.k === 'notice' && ev.text.includes('returned'));
    expect(notices).toHaveLength(1);

    const frames = collect(gruncle.id);
    expect(frames.map((f) => f.op)).toEqual([OP.MINION_REPORT, OP.INVENTORY_UPDATE]);
    const report = frames[0] as MinionReportMsg;
    expect(report.jobId).toBe('gather_lumber');
    expect(report.materials).toBeGreaterThanOrEqual(GATHER_LUMBER_YIELD_MIN);
    expect(report.materials).toBeLessThanOrEqual(GATHER_LUMBER_YIELD_MAX);
    expect(report.injured).toBe(false); // gather carries no injury risk
    expect(player.materials).toBe(report.materials);
    expect(gruncle.state).toBe('idle');
    expect(gruncle.job).toBeNull();
  });

  it('scout needs a front and plants intel on it', () => {
    const { h, player, conn } = setup();
    const [, pip] = h.world.minions.get(player.id)!;
    expect(
      h.apply(
        { op: OP.MINION_SEND, t: h.clock.now(), minionId: pip.id, jobId: 'scout_front' },
        conn,
      )[0],
    ).toMatchObject({ op: OP.ERR, code: 'BAD_REQUEST' });
    expect(
      h.apply(
        {
          op: OP.MINION_SEND,
          t: h.clock.now(),
          minionId: pip.id,
          jobId: 'scout_front',
          frontId: 'f0,0',
        },
        conn,
      ),
    ).toEqual([]);
    h.clock.advance(SCOUT_FRONT_MINUTES * MIN_MS + 1000);
    h.tick(1);
    const frames = h.apply({ op: OP.MINION_COLLECT, t: h.clock.now(), minionId: pip.id }, conn);
    const report = frames[0] as MinionReportMsg;
    expect(report.rumorFrontId).toBe('f0,0');
    expect(h.world.fronts.get('f0,0')!.scoutIntel).toMatchObject({ scoutedAt: h.clock.now() });
    void player;
  });

  it('hire (200 g, roster cap 3) and heal (50 g) gate on gold and state', () => {
    const { h, player, conn } = setup();
    const hire = (): ServerMsg[] => h.apply({ op: OP.MINION_HIRE, t: h.clock.now() }, conn);
    player.gold = MINION_HIRE_COST - 1;
    expect(hire()[0]).toMatchObject({ op: OP.ERR, code: 'INSUFFICIENT_GOLD' });
    player.gold = MINION_HIRE_COST;
    expect(hire()[0].op).toBe(OP.INVENTORY_UPDATE);
    expect(player.gold).toBe(0);
    expect(h.world.minions.get(player.id)!).toHaveLength(3);
    player.gold = MINION_HIRE_COST;
    expect(hire()[0]).toMatchObject({ op: OP.ERR, code: 'CAP_REACHED' });

    const [gruncle] = h.world.minions.get(player.id)!;
    const heal = (): ServerMsg[] =>
      h.apply({ op: OP.MINION_HEAL, t: h.clock.now(), minionId: gruncle.id }, conn);
    expect(heal()[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' }); // not injured
    gruncle.state = 'injured';
    expect(
      h.apply({ op: OP.MINION_SEND, t: h.clock.now(), minionId: gruncle.id, jobId: 'gather_lumber' }, conn)[0],
    ).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' }); // injured can't work
    player.gold = MINION_HEAL_COST - 1;
    expect(heal()[0]).toMatchObject({ op: OP.ERR, code: 'INSUFFICIENT_GOLD' });
    player.gold = MINION_HEAL_COST;
    expect(heal()[0].op).toBe(OP.INVENTORY_UPDATE);
    expect(gruncle.state).toBe('idle');
    expect(player.gold).toBe(0);
  });
});
