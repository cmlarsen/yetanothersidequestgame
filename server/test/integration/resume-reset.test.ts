// Integration (g)+(i)+(j-reducer): (g) the DAILY_RESET_UTC_H boundary re-arms the
// daily board through the real tick path; (i) a mid-activity world survives the
// FULL persistence round-trip (repo.save → repo.load) and RESUME with the bearer
// session token reattaches the same player — including a wall-clock minion job
// that completes across the restart; (j) the reducer-level protocol gates: JOIN/
// RESUME version mismatch and unknown-session RESUME each cost one ERR frame and
// mutate nothing. (Gateway-level (j) — malformed frames, close 4400 — lives in
// gateway.test.ts.)

import { describe, expect, it } from 'vitest';
import '../../sim/commands_combat.js';
import '../../sim/commands_economy.js';
import { SimHarness } from '../harness/sim-harness.js';
import { openDb } from '../../persistence/db.js';
import { load, save } from '../../persistence/repo.js';
import { serialize } from '../../sim/world.js';
import { hexCenter } from '../../shared/hexgrid.js';
import { OP, PROTOCOL_VERSION } from '../../shared/protocol.js';
import type { HelloMsg, MinionReportMsg, SnapshotMsg } from '../../shared/protocol.js';
import {
  DAILY_WALK_GOLD,
  DAILY_WALK_STEPS,
  GATHER_LUMBER_MINUTES,
  GATHER_LUMBER_YIELD_MAX,
  GATHER_LUMBER_YIELD_MIN,
} from '../../shared/tuning.js';

const MIN_MS = 60_000;
const DAY_MS = 24 * 60 * MIN_MS;

describe('(g) daily reset rolls quests at the boundary (tick-driven)', () => {
  it('crossing dailyResetAt re-arms dailies, zeroes steps, and opens a fresh claim window', () => {
    const h = SimHarness.create({ seed: 'reset-int' });
    const { player, conn } = h.join('early-bird');

    h.gpsAt(conn, { x: 0, y: 0 }, { steps: DAILY_WALK_STEPS });
    h.apply({ op: OP.QUEST_CLAIM, t: h.clock.now(), questId: 'daily_walk' }, conn);
    expect(player.gold).toBe(DAILY_WALK_GOLD);
    expect(player.quests.daily_walk.state).toBe('done');

    const firstReset = h.world.dailyResetAt;
    h.clock.advance(firstReset - h.clock.now() + 1000);
    h.tick(1);

    expect(h.world.dailyResetAt).toBe(firstReset + DAY_MS);
    expect(player.quests.daily_walk).toMatchObject({ progress: 0, state: 'active' });
    expect(player.quests.daily_defeat).toMatchObject({ progress: 0, state: 'active' });
    expect(player.stepsToday).toBe(0);

    // the re-armed daily pays again in the new window
    h.gpsAt(conn, { x: 0, y: 0 }, { steps: DAILY_WALK_STEPS });
    h.apply({ op: OP.QUEST_CLAIM, t: h.clock.now(), questId: 'daily_walk' }, conn);
    expect(player.gold).toBe(2 * DAILY_WALK_GOLD);
  });
});

describe('(i) persistence round-trip mid-activity + RESUME reattaches', () => {
  it('save mid-run through repo, load, RESUME by token: progress intact, job completes', () => {
    const h1 = SimHarness.create({ seed: 'resume-int' });
    const { player, conn, frames } = h1.join('phoenix');
    const token = (frames[0] as HelloMsg).sessionToken;
    expect(token).not.toBe('');

    // mid-activity: an active run with claims, banked gold, and a minion mid-job
    h1.runStart(conn);
    h1.tick(1); // claim 0,0 (home anchor)
    const c = hexCenter(1, 0);
    h1.teleport(player, c.x, c.y);
    h1.tick(1); // claim 1,0
    player.gold = 300;
    const [gruncle] = h1.world.minions.get(player.id)!;
    h1.apply(
      { op: OP.MINION_SEND, t: h1.clock.now(), minionId: gruncle.id, jobId: 'gather_lumber' },
      conn,
    );
    expect(gruncle.state).toBe('on_job');
    const jobEndsAt = gruncle.job!.endsAt;
    expect(player.run).not.toBeNull();

    const db = openDb(':memory:');
    save(db, h1.world);
    const h2 = SimHarness.fromSave(serialize(load(db)!));

    // RESUME with the persisted bearer token binds the SAME player on a fresh conn
    const conn2 = h2.newConn();
    const resumed = h2.apply(
      { op: OP.RESUME, t: h2.clock.now(), protocolVersion: PROTOCOL_VERSION, sessionToken: token },
      conn2,
    );
    expect(resumed.map((f) => f.op)).toEqual([OP.HELLO, OP.SNAPSHOT, OP.INVENTORY_UPDATE]);
    expect((resumed[0] as HelloMsg).playerId).toBe(player.id);
    expect(conn2.playerId).toBe(player.id);

    const snap = resumed[1] as SnapshotMsg;
    expect(snap.self.gold).toBe(300);
    expect(snap.self.homeHex).toBe('0,0');
    expect(snap.hexes.map((hx) => hx.k).sort()).toEqual(['0,0', '1,0']);

    // runtime state is never persisted: the run machine came back idle
    const p2 = h2.world.players.get(player.id)!;
    expect(p2.run).toBeNull();
    expect(p2.lifeState).toBe('alive');

    // …but the wall-clock minion job survived the restart and completes on schedule
    const [gruncle2] = h2.world.minions.get(player.id)!;
    expect(gruncle2.job).toMatchObject({ jobId: 'gather_lumber', endsAt: jobEndsAt });
    h2.clock.advance(jobEndsAt - h2.clock.now() + 1000);
    h2.tick(1);
    const report = h2.apply(
      { op: OP.MINION_COLLECT, t: h2.clock.now(), minionId: gruncle2.id },
      conn2,
    )[0] as MinionReportMsg;
    expect(report.op).toBe(OP.MINION_REPORT);
    expect(report.materials).toBeGreaterThanOrEqual(GATHER_LUMBER_YIELD_MIN);
    expect(report.materials).toBeLessThanOrEqual(GATHER_LUMBER_YIELD_MAX);
    expect(gruncle2.state).toBe('idle');
  });

  it('an unknown session token gets one SESSION_UNKNOWN and binds nothing', () => {
    const h = SimHarness.create({ seed: 'resume-unknown' });
    h.join('someone');
    const conn = h.newConn();
    const out = h.apply(
      { op: OP.RESUME, t: h.clock.now(), protocolVersion: PROTOCOL_VERSION, sessionToken: 'bogus' },
      conn,
    );
    expect(out).toHaveLength(1);
    expect(out[0]).toMatchObject({ op: OP.ERR, code: 'SESSION_UNKNOWN' });
    expect(conn.playerId).toBeNull();
  });
});

describe('(j) reducer-level protocol gates', () => {
  it('JOIN/RESUME with a wrong protocolVersion: one ERR VERSION_MISMATCH, zero mutation', () => {
    const h = SimHarness.create({ seed: 'version-int' });
    const conn = h.newConn();
    const out = h.apply(
      {
        op: OP.JOIN,
        t: h.clock.now(),
        protocolVersion: PROTOCOL_VERSION + 1,
        gamertag: 'timetraveler',
        characterId: 'knight',
      },
      conn,
    );
    expect(out).toHaveLength(1);
    expect(out[0]).toMatchObject({ op: OP.ERR, code: 'VERSION_MISMATCH', refOp: OP.JOIN });
    expect(h.world.players.size).toBe(0);
    expect(conn.playerId).toBeNull();

    const out2 = h.apply(
      { op: OP.RESUME, t: h.clock.now(), protocolVersion: 0, sessionToken: 'tok' },
      conn,
    );
    expect(out2[0]).toMatchObject({ op: OP.ERR, code: 'VERSION_MISMATCH', refOp: OP.RESUME });
  });
});
