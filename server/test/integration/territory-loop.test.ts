// Integration (a)+(b)+(h): the core outdoor loop end-to-end through applyCommand +
// the real tick — (a) JOIN → GPS-walk claims hexes and moves the front %,
// (b) contested gloom hex → ATTACK → victory flips it and pays XP/gold,
// (h) RUN_START → claims counted → RUN_END summary, with the §2 early-retreat
// gold drop and its 10 m recovery.

import { describe, expect, it } from 'vitest';
import '../../sim/commands_combat.js';
import '../../sim/commands_economy.js';
import { SimHarness } from '../harness/sim-harness.js';
import { makeMob, mobFieldSpec, mobGoldReward, mobXpReward } from '../../sim/systems/mobs.js';
import { setHexOwner } from '../../sim/systems/territory.js';
import { hexCenter, hexDistance } from '../../shared/hexgrid.js';
import { OP, OWNER_PLAYERS } from '../../shared/protocol.js';
import type { LootResultMsg, RunSummaryMsg, SnapshotMsg } from '../../shared/protocol.js';
import { NEW_AREA_XP } from '../../shared/tuning.js';

/** The walked path for (a): three colinear hexes east from the origin. */
const WALK_PATH = [
  { q: 0, r: 0 },
  { q: 1, r: 0 },
  { q: 2, r: 0 },
];

/**
 * A GPS-established player sprouts the seeded mob field, so (a) walks under a seed
 * whose field leaves the path fight-free. A mob strays at most ANCHOR_JITTER +
 * ROAM_R = 52 m from its cell centre; a path hex's farthest point is 34.6 m from
 * its own centre (circumradius), so a distance-1 anchor (60 m) can reach in but a
 * distance-2 anchor (≥103.9 m) never can. Painted-gloom escalation only ever adds
 * mobs at a hex's own seeded cell, so scanning distance ≤1 at the denser gloom
 * rate covers every spawn path. Deterministic: same scan, same seed.
 */
function pickCleanWalkSeed(): string {
  outer: for (let i = 0; i < 1000; i++) {
    const seed = `walk-${i}`;
    for (const p of WALK_PATH) {
      for (let dq = -2; dq <= 2; dq++) {
        for (let dr = -2; dr <= 2; dr++) {
          if (hexDistance(0, 0, dq, dr) > 1) continue;
          if (mobFieldSpec(seed, p.q + dq, p.r + dr, true) !== null) continue outer;
        }
      }
    }
    return seed;
  }
  throw new Error('no clean walk seed in range — mob field tuning changed?');
}

describe('(a) join → GPS walk claims hexes and moves the front %', () => {
  it('walking three hex centres claims all three and lifts pctPlayer', () => {
    const h = SimHarness.create({ seed: pickCleanWalkSeed() });
    const { player, conn } = h.join('walker');
    h.runStart(conn);

    const before = h.apply({ op: OP.REQUEST_SNAPSHOT, t: h.clock.now() }, conn)[0] as SnapshotMsg;
    expect(before.fronts.find((f) => f.id === 'f0,0')?.pctPlayer ?? 0).toBe(0);

    h.gpsAt(conn, { x: 0, y: 0 }); // first fix of the session snaps the pawn
    h.tick(1);
    expect(h.world.hexes.get('0,0')?.owner).toBe('players');
    expect(player.homeHex).toBe('0,0');

    // walk east in ~30 m GPS legs; the movement system eases the pawn between fixes
    h.drain();
    const legs = [
      { x: 26, y: 15 },
      { x: 52, y: 30 },
      { x: 78, y: 45 },
      { x: 104, y: 60 },
    ];
    for (const leg of legs) {
      h.gpsAt(conn, leg);
      h.tick(130); // 13 s per leg at 10 Hz — enough for 30 m at the 4 m/s clamp
    }

    for (const p of WALK_PATH) {
      expect(h.world.hexes.get(`${p.q},${p.r}`)?.owner).toBe('players');
    }
    expect(player.run!.hexesClaimed).toEqual(['0,0', '1,0', '2,0']);
    expect(player.xp).toBe(NEW_AREA_XP); // first visit to the f0,0 front

    // claim beats reached the outbox for everyone
    const claims = h
      .drain()
      .flatMap((e) => (e.msg.op === OP.EVENTS ? e.msg.events : []))
      .filter((ev) => ev.k === 'claim' && ev.o === OWNER_PLAYERS);
    expect(claims.length).toBeGreaterThanOrEqual(2); // 1,0 + 2,0 (0,0 drained earlier)

    const after = h.apply({ op: OP.REQUEST_SNAPSHOT, t: h.clock.now() }, conn)[0] as SnapshotMsg;
    expect(after.fronts.find((f) => f.id === 'f0,0')!.pctPlayer).toBe(Math.round((3 / 64) * 100));
    expect(after.self.homeHex).toBe('0,0');
  });
});

describe('(b) contested hex → ATTACK → victory flips it and pays out', () => {
  it('kills the defender through the command path; hex, xp, gold, quest all settle', () => {
    const h = SimHarness.create({ seed: 'contest-int' });
    const { player, conn } = h.join('duelist');
    h.runStart(conn);
    h.tick(1); // claim 0,0
    const xpAfterArea = player.xp;

    setHexOwner(h.world, '1,0', 'gloom', h.clock.now());
    const c = hexCenter(1, 0);
    h.teleport(player, c.x, c.y);
    h.tick(1); // CONTESTED + defender spawned & engaged via the combat hook
    const hs = h.world.hexes.get('1,0')!;
    expect(hs.owner).toBe('gloom');
    expect(hs.contestedMobId).toBe('mobd:1,0');
    const defender = h.world.mobs.get('mobd:1,0')!;
    expect(defender.engagedBy).toEqual([player.id]);
    expect(defender.isTyrant).toBe(false); // this seed's defender is a gloomling

    h.drain();
    const goldBefore = player.gold;
    for (let swings = 0; h.world.mobs.has(defender.id); swings++) {
      expect(swings).toBeLessThan(10);
      h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: defender.id }, conn);
    }

    expect(h.world.hexes.get('1,0')!.owner).toBe('players');
    expect(h.world.hexes.get('1,0')!.contestedMobId).toBeUndefined();
    expect(player.run!.contestedClaimed).toContain('1,0');
    expect(player.xp).toBe(xpAfterArea + mobXpReward(defender));
    expect(player.gold).toBe(goldBefore + mobGoldReward(defender));
    expect(player.run!.mobsDefeated).toBe(1);
    expect(player.quests.daily_defeat.progress).toBe(1);

    const out = h.drain();
    const beats = out.flatMap((e) => (e.msg.op === OP.EVENTS ? e.msg.events : []));
    expect(beats.some((ev) => ev.k === 'kill' && ev.mobId === defender.id)).toBe(true);
    const loot = out.find((e) => e.to === player.id && e.msg.op === OP.LOOT_RESULT)!
      .msg as LootResultMsg;
    expect(loot.xp).toBe(mobXpReward(defender));
    expect(loot.gold).toBe(mobGoldReward(defender));
  });
});

describe('(h) run start → claims counted → run end summary + early-end gold drop', () => {
  it('a mid-combat RUN_END retreats: run gold drops on the map, recoverable at 10 m', () => {
    const h = SimHarness.create({ seed: 'run-int' });
    const { player, conn } = h.join('runner');
    h.runStart(conn);
    h.tick(1); // claim 0,0

    for (const [q, r] of [
      [1, 0],
      [0, 1],
    ]) {
      const c = hexCenter(q, r);
      h.teleport(player, c.x, c.y);
      h.tick(1);
    }

    // earn gold this run: kill a 1 hp mob on the next hex
    const prey = makeMob('prey', 'gloomling', hexCenter(2, 0));
    prey.hp = 1;
    h.world.mobs.set(prey.id, prey);
    h.teleport(player, prey.pos.x, prey.pos.y);
    h.tick(1);
    h.apply({ op: OP.ATTACK, t: h.clock.now(), mobId: prey.id }, conn);
    const earned = mobGoldReward(prey);
    expect(player.gold).toBe(earned);

    // pick a fight we don't finish, then bail mid-combat
    const brute = makeMob('brute', 'gloomling', hexCenter(3, 0));
    brute.hp = 100_000;
    brute.maxHp = 100_000;
    h.world.mobs.set(brute.id, brute);
    h.teleport(player, brute.pos.x, brute.pos.y);
    h.tick(1); // auto-engage; first swing is still 1 s out
    expect(brute.engagedBy).toEqual([player.id]);

    const frames = h.runEnd(conn);
    const summary = frames[0] as RunSummaryMsg;
    expect(summary.op).toBe(OP.RUN_SUMMARY);
    expect(summary.hexesClaimed).toBe(5); // 0,0 1,0 0,1 2,0 3,0
    expect(summary.mobsDefeated).toBe(1);
    expect(summary.xp).toBe(NEW_AREA_XP + mobXpReward(prey));
    expect(summary.gold).toBe(earned);
    expect(summary.goldDropped).toBe(earned); // §2 retreat: run gold above the start bank drops
    expect(summary.frontDelta['f0,0']).toBe(Math.round((5 / 64) * 100));
    expect(player.gold).toBe(0);
    expect(player.run).toBeNull();

    // the drop sits where the runner bailed; stepping within 10 m recovers it
    const drop = [...h.world.goldDrops.values()][0];
    expect(drop.gold).toBe(earned);
    h.teleport(player, drop.pos.x + 5, drop.pos.y);
    h.tick(1);
    expect(h.world.goldDrops.size).toBe(0);
    expect(player.gold).toBe(earned);
  });

  it('a clean RUN_END keeps the gold and reports zero dropped', () => {
    const h = SimHarness.create({ seed: 'run-clean-int' });
    const { player, conn } = h.join('runner');
    h.runStart(conn);
    h.tick(1);
    player.gold = 50;
    const summary = h.runEnd(conn)[0] as RunSummaryMsg;
    expect(summary.goldDropped).toBe(0);
    expect(summary.hexesClaimed).toBe(1);
    expect(player.gold).toBe(50);
  });
});
