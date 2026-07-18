// Minions (§9): wall-clock job timing under ManualClock, yields, injury
// determinism, scout intel, hire/heal gates, and the completion-notice ticker.

import { describe, expect, it } from 'vitest';
import '../../sim/commands_economy.js';
import { SimHarness } from '../harness/sim-harness.js';
import type { Conn } from '../../sim/commands.js';
import { OP } from '../../shared/protocol.js';
import type { MinionReportMsg, ServerMsg } from '../../shared/protocol.js';
import type { JobId } from '../../shared/catalog.js';
import {
  GATHER_LUMBER_MINUTES,
  GATHER_LUMBER_YIELD_MAX,
  GATHER_LUMBER_YIELD_MIN,
  MINION_HEAL_COST,
  MINION_HIRE_COST,
  SCAVENGE_MINUTES,
  SCAVENGE_YIELD_BONUS_PCT,
  SCOUT_FRONT_MINUTES,
} from '../../shared/tuning.js';
import {
  MINION_ROSTER_MAX,
  SCAVENGE_SALVAGE_ITEM_ID,
  rosterOf,
} from '../../sim/systems/minions.js';

const MINUTE_MS = 60_000;

function setup(seed = 'minions-test') {
  const h = SimHarness.create({ seed });
  const { player, conn } = h.join('boss');
  const roster = rosterOf(h.world, player.id);
  return { h, player, conn, roster };
}

function send(h: SimHarness, conn: Conn, minionId: string, jobId: JobId, frontId?: string): ServerMsg[] {
  return h.apply(
    { op: OP.MINION_SEND, t: h.clock.now(), minionId, jobId, ...(frontId ? { frontId } : {}) },
    conn,
  );
}

function collect(h: SimHarness, conn: Conn, minionId: string): ServerMsg[] {
  return h.apply({ op: OP.MINION_COLLECT, t: h.clock.now(), minionId }, conn);
}

describe('roster', () => {
  it('starts with the two §9 starters, idle', () => {
    const { roster } = setup();
    expect(roster.map((m) => m.defId)).toEqual(['gruncle', 'pip']);
    expect(roster.every((m) => m.state === 'idle' && m.job === null)).toBe(true);
  });

  it('hire: 200 g fills the 3rd slot exactly once', () => {
    const { h, player, conn } = setup();
    expect(h.apply({ op: OP.MINION_HIRE, t: h.clock.now() }, conn)[0]).toMatchObject({
      op: OP.ERR,
      code: 'INSUFFICIENT_GOLD',
    });
    player.gold = 2 * MINION_HIRE_COST;
    h.apply({ op: OP.MINION_HIRE, t: h.clock.now() }, conn);
    expect(player.gold).toBe(MINION_HIRE_COST);
    expect(rosterOf(h.world, player.id)).toHaveLength(MINION_ROSTER_MAX);
    expect(h.apply({ op: OP.MINION_HIRE, t: h.clock.now() }, conn)[0]).toMatchObject({
      op: OP.ERR,
      code: 'CAP_REACHED',
    });
  });
});

describe('job timing (wall-clock via injected now)', () => {
  it('gather: ~30 min; early collect refused; on time pays 10–16 🪵', () => {
    const { h, player, conn, roster } = setup();
    const gruncle = roster[0];
    send(h, conn, gruncle.id, 'gather_lumber');
    expect(gruncle.state).toBe('on_job');
    expect(gruncle.job!.endsAt).toBe(h.clock.now() + GATHER_LUMBER_MINUTES * MINUTE_MS);

    h.advance((GATHER_LUMBER_MINUTES - 1) * MINUTE_MS);
    expect(collect(h, conn, gruncle.id)[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    expect(gruncle.state).toBe('on_job');

    h.advance(1 * MINUTE_MS);
    const frames = collect(h, conn, gruncle.id);
    expect(frames.map((f) => f.op)).toEqual([OP.MINION_REPORT, OP.INVENTORY_UPDATE]);
    const report = frames[0] as MinionReportMsg;
    expect(report.jobId).toBe('gather_lumber');
    expect(report.materials).toBeGreaterThanOrEqual(GATHER_LUMBER_YIELD_MIN);
    expect(report.materials).toBeLessThanOrEqual(GATHER_LUMBER_YIELD_MAX);
    expect(report.injured).toBe(false); // gather carries no risk
    expect(report.quote.length).toBeGreaterThan(0);
    expect(player.materials).toBe(report.materials);
    expect(gruncle.state).toBe('idle');
    expect(gruncle.job).toBeNull();
  });

  it('a working minion cannot take a second job; an unknown minion is NOT_FOUND', () => {
    const { h, conn, roster } = setup();
    send(h, conn, roster[0].id, 'gather_lumber');
    expect(send(h, conn, roster[0].id, 'gather_lumber')[0]).toMatchObject({
      op: OP.ERR,
      code: 'ILLEGAL_STATE',
    });
    expect(send(h, conn, 'ghost', 'gather_lumber')[0]).toMatchObject({
      op: OP.ERR,
      code: 'NOT_FOUND',
    });
    expect(collect(h, conn, roster[1].id)[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
  });
});

describe('scout the front (§9 intel)', () => {
  it('requires a front, takes ~15 min, stamps scoutIntel and deep-links the rumor', () => {
    const { h, conn, roster } = setup();
    expect(send(h, conn, roster[1].id, 'scout_front')[0]).toMatchObject({
      op: OP.ERR,
      code: 'BAD_REQUEST',
    });
    send(h, conn, roster[1].id, 'scout_front', 'f0,0');
    h.advance(SCOUT_FRONT_MINUTES * MINUTE_MS);
    const report = collect(h, conn, roster[1].id)[0] as MinionReportMsg;
    expect(report.op).toBe(OP.MINION_REPORT);
    expect(report.materials).toBe(0);
    expect(report.rumorFrontId).toBe('f0,0');
    const intel = h.world.fronts.get('f0,0')!.scoutIntel!;
    expect(intel.scoutedAt).toBe(h.clock.now());
    expect(intel.pushEta).toBeGreaterThan(h.clock.now());
  });
});

describe('scavenge (§9: +50% yield, 20% injury, salvage-part chance)', () => {
  /** Run a full scavenge on a fresh world; returns the report. */
  function scavenge(seed: string): { report: MinionReportMsg; h: SimHarness; conn: Conn } {
    const { h, conn, roster } = setup(seed);
    send(h, conn, roster[0].id, 'scavenge');
    h.advance(SCAVENGE_MINUTES * MINUTE_MS);
    const report = collect(h, conn, roster[0].id)[0] as MinionReportMsg;
    return { report, h, conn };
  }

  it('yield is the gather roll +50%, and the outcome is seed-deterministic', () => {
    const min = Math.round(GATHER_LUMBER_YIELD_MIN * (1 + SCAVENGE_YIELD_BONUS_PCT / 100));
    const max = Math.round(GATHER_LUMBER_YIELD_MAX * (1 + SCAVENGE_YIELD_BONUS_PCT / 100));
    const a = scavenge('scav-seed').report;
    expect(a.materials).toBeGreaterThanOrEqual(min);
    expect(a.materials).toBeLessThanOrEqual(max);
    // same seed + same command history ⇒ byte-identical report (injury roll included)
    expect(scavenge('scav-seed').report).toEqual(a);
  });

  it('injury and salvage-part paths both occur across seeds; injured minions need healing', () => {
    let sawInjury = false;
    let sawSalvage = false;
    for (let i = 0; i < 60 && !(sawInjury && sawSalvage); i++) {
      const { report, h, conn } = scavenge(`scav-${i}`);
      const player = [...h.world.players.values()][0];
      const minion = rosterOf(h.world, player.id)[0];
      if (report.injured) {
        sawInjury = true;
        expect(minion.state).toBe('injured');
        expect(send(h, conn, minion.id, 'gather_lumber')[0]).toMatchObject({
          op: OP.ERR,
          code: 'ILLEGAL_STATE',
        });
        // heal: 50 g, instant; gates on gold and on actually being injured
        expect(
          h.apply({ op: OP.MINION_HEAL, t: h.clock.now(), minionId: minion.id }, conn)[0],
        ).toMatchObject({ op: OP.ERR, code: 'INSUFFICIENT_GOLD' });
        player.gold = MINION_HEAL_COST;
        h.apply({ op: OP.MINION_HEAL, t: h.clock.now(), minionId: minion.id }, conn);
        expect(player.gold).toBe(0);
        expect(minion.state).toBe('idle');
      } else {
        expect(minion.state).toBe('idle');
        expect(
          h.apply({ op: OP.MINION_HEAL, t: h.clock.now(), minionId: minion.id }, conn)[0],
        ).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
      }
      if (report.salvageItemId !== undefined) {
        sawSalvage = true;
        expect(report.salvageItemId).toBe(SCAVENGE_SALVAGE_ITEM_ID);
        expect(player.inventory.some((it) => it.itemId === SCAVENGE_SALVAGE_ITEM_ID)).toBe(true);
      }
    }
    expect(sawInjury).toBe(true);
    expect(sawSalvage).toBe(true);
  });
});

describe('completion ticker', () => {
  it('announces a finished job exactly once via the outbox', () => {
    const { h, player, conn, roster } = setup();
    send(h, conn, roster[0].id, 'gather_lumber');
    h.drain();
    h.advance(GATHER_LUMBER_MINUTES * MINUTE_MS); // pump runs the due ticks
    const notices = h
      .drain()
      .filter((e) => e.to === player.id)
      .flatMap((e) => (e.msg.op === OP.EVENTS ? e.msg.events : []))
      .filter((ev) => ev.k === 'notice');
    expect(notices).toHaveLength(1);
    expect((notices[0] as { text: string }).text).toContain(roster[0].name);

    h.tick(10);
    const again = h
      .drain()
      .flatMap((e) => (e.msg.op === OP.EVENTS ? e.msg.events : []))
      .filter((ev) => ev.k === 'notice');
    expect(again).toHaveLength(0);
  });
});
