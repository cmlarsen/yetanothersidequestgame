// Territory (§1) + runs (§2) + death (§5): claim-on-enter, contested marking,
// death penalties, gold-drop recovery, early run end.

import { afterEach, describe, expect, it } from 'vitest';
import { SimHarness } from '../harness/sim-harness.js';
import {
  applyDeath,
  claimHexForPlayer,
  registerCombatProbe,
  setHexOwner,
} from '../../sim/systems/territory.js';
import { hexCenter, hexKey } from '../../shared/hexgrid.js';
import { OP } from '../../shared/protocol.js';
import type { RunSummaryMsg, DeathMsg } from '../../shared/protocol.js';
import {
  DEATH_CONTESTED_HEX_LOSS_CAP,
  NEW_AREA_XP,
  SPEED_PAUSE_KMH,
} from '../../shared/tuning.js';

afterEach(() => registerCombatProbe(null));

function setup() {
  const h = SimHarness.create({ seed: 'territory-test' });
  const { player, conn } = h.join('claimer');
  return { h, player, conn };
}

describe('claim-on-enter', () => {
  it('claims the hex under a moving in-run player, anchors home, pays NEW AREA xp', () => {
    const { h, player, conn } = setup();
    h.runStart(conn);
    h.tick(1);
    expect(h.world.hexes.get('0,0')?.owner).toBe('players');
    expect(player.homeHex).toBe('0,0');
    expect(player.run!.hexesClaimed).toEqual(['0,0']);
    expect(player.areasSeen).toEqual(['f0,0']);
    expect(player.xp).toBe(NEW_AREA_XP);
    // standing still doesn't re-claim
    h.tick(2);
    expect(player.run!.hexesClaimed).toHaveLength(1);
    // crossing into the neighbour claims it too
    const c = hexCenter(1, 0);
    h.teleport(player, c.x, c.y);
    h.tick(1);
    expect(h.world.hexes.get('1,0')?.owner).toBe('players');
    expect(player.run!.hexesClaimed).toHaveLength(2);
  });

  it('does not claim outside a run', () => {
    const { h } = setup();
    h.tick(5);
    expect(h.world.hexes.size).toBe(0);
  });

  it('does not claim while speed-paused, resumes when slowed', () => {
    const { h, player, conn } = setup();
    h.runStart(conn);
    player.speedKmh = SPEED_PAUSE_KMH + 10;
    h.tick(5);
    expect(h.world.hexes.size).toBe(0);
    player.speedKmh = 4;
    h.tick(1);
    expect(h.world.hexes.get('0,0')?.owner).toBe('players');
  });

  it('a gloom hex adjacent to player territory becomes CONTESTED, not claimed', () => {
    const { h, player, conn } = setup();
    h.runStart(conn);
    h.tick(1); // claim 0,0
    setHexOwner(h.world, '1,0', 'gloom', h.clock.now());
    h.drain();
    const c = hexCenter(1, 0);
    h.teleport(player, c.x, c.y);
    h.tick(1);
    const hs = h.world.hexes.get('1,0')!;
    expect(hs.owner).toBe('gloom');
    expect(hs.contestedMobId).toBe('');
    const contested = h
      .drain()
      .flatMap((e) => (e.msg.op === OP.EVENTS ? e.msg.events : []))
      .filter((ev) => ev.k === 'contest');
    expect(contested).toHaveLength(1);
  });

  it('a gloom hex NOT adjacent to player territory is left alone', () => {
    const { h, player, conn } = setup();
    h.runStart(conn);
    setHexOwner(h.world, '4,4', 'gloom', h.clock.now());
    const c = hexCenter(4, 4);
    h.teleport(player, c.x, c.y);
    h.tick(1);
    const hs = h.world.hexes.get('4,4')!;
    expect(hs.owner).toBe('gloom');
    expect(hs.contestedMobId).toBeUndefined();
  });
});

describe('death (§5)', () => {
  it('drops max(50, 10%) gold, loses contested hexes capped at 3, ends the run', () => {
    const { h, player, conn } = setup();
    h.runStart(conn);
    h.tick(1); // home hex 0,0
    player.gold = 1000;
    // four contested-won hexes this run
    for (let q = 1; q <= 4; q++) {
      setHexOwner(h.world, hexKey(q, 0), 'gloom', h.clock.now());
      claimHexForPlayer(h.world, player, hexKey(q, 0), h.clock.now(), { contested: true });
    }
    h.drain();
    applyDeath(h.world, player, h.clock.now());

    expect(player.lifeState).toBe('downed');
    expect(player.gold).toBe(900); // dropped max(50, 100) = 100
    const drops = [...h.world.goldDrops.values()];
    expect(drops).toHaveLength(1);
    expect(drops[0].gold).toBe(100);
    // most recent contested hexes flipped back, cap 3
    const lostOwners = [1, 2, 3, 4].map((q) => h.world.hexes.get(hexKey(q, 0))!.owner);
    expect(lostOwners).toEqual(['players', 'gloom', 'gloom', 'gloom']);
    expect(player.run).toBeNull();

    const mine = h.drain().filter((e) => e.to === player.id);
    const death = mine.find((e) => e.msg.op === OP.DEATH)?.msg as DeathMsg;
    expect(death.goldDropped).toBe(100);
    expect(death.hexesLost).toHaveLength(DEATH_CONTESTED_HEX_LOSS_CAP);
    expect(mine.some((e) => e.msg.op === OP.RUN_SUMMARY)).toBe(true);
  });

  it('death drop floors at 50 g (capped at carried)', () => {
    const { h, player } = setup();
    player.gold = 30;
    applyDeath(h.world, player, h.clock.now());
    expect(player.gold).toBe(0);
    expect([...h.world.goldDrops.values()][0].gold).toBe(30);
  });

  it('RESPAWN returns the player to the home hex at full HP; dropped gold is recoverable within 10 m', () => {
    const { h, player, conn } = setup();
    h.runStart(conn);
    h.tick(1);
    player.gold = 1000;
    const far = hexCenter(6, 2);
    h.teleport(player, far.x, far.y);
    h.tick(1);
    applyDeath(h.world, player, h.clock.now());
    const dropPos = [...h.world.goldDrops.values()][0].pos;

    const frames = h.apply({ op: OP.RESPAWN, t: h.clock.now() }, conn);
    expect(frames[0].op).toBe(OP.SNAPSHOT);
    const home = hexCenter(0, 0);
    expect(player.pos).toEqual({ x: home.x, y: home.y });
    expect(player.hp).toBe(player.maxHp);
    expect(player.lifeState).toBe('alive');

    h.teleport(player, dropPos.x + 5, dropPos.y); // within 10 m
    h.tick(1);
    expect(h.world.goldDrops.size).toBe(0);
    expect(player.gold).toBe(1000);
  });

  it('the revive window lapsing auto-respawns at home', () => {
    const { h, player, conn } = setup();
    h.runStart(conn);
    h.tick(1);
    const away = hexCenter(3, 3);
    h.teleport(player, away.x, away.y);
    h.tick(1);
    applyDeath(h.world, player, h.clock.now());
    h.tick(601); // > 60 s at 10 Hz
    expect(player.lifeState).toBe('alive');
    expect(player.pos.x).toBeCloseTo(hexCenter(0, 0).x, 6);
  });
});

describe('runs (§2)', () => {
  it('RUN_END mid-combat is a retreat: run gold above the start bank drops', () => {
    const { h, player, conn } = setup();
    player.gold = 500;
    h.runStart(conn);
    player.gold += 300; // "earned" this run
    registerCombatProbe(() => true);
    const frames = h.runEnd(conn);
    const summary = frames[0] as RunSummaryMsg;
    expect(summary.op).toBe(OP.RUN_SUMMARY);
    expect(summary.goldDropped).toBe(300);
    expect(player.gold).toBe(500);
    expect(h.world.goldDrops.size).toBe(1);
  });

  it('a clean RUN_END keeps everything and reports front deltas', () => {
    const { h, player, conn } = setup();
    player.gold = 100;
    h.runStart(conn);
    h.tick(1); // claim 0,0 (+1 hex on f0,0)
    player.gold += 300;
    const frames = h.runEnd(conn);
    const summary = frames[0] as RunSummaryMsg;
    expect(summary.goldDropped).toBe(0);
    expect(summary.hexesClaimed).toBe(1);
    expect(summary.frontDelta['f0,0']).toBe(2); // 1/64 → 2% rounded
    expect(player.gold).toBe(400);
    expect(player.run).toBeNull();
  });

  it('RUN_START twice / RUN_END without a run are illegal', () => {
    const { h, conn } = setup();
    h.runStart(conn);
    expect(h.runStart(conn)[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    h.runEnd(conn);
    expect(h.runEnd(conn)[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
  });
});
