// Integration (c): gloom pressure captures ground over a ManualClock hour, a
// Chill Bell slows the capture rate, and a Bastion Post blocks flips outright.
// Time is driven through the REAL tickWorld with coarse injected steps (the gloom
// accumulator is dt-based, not tick-count-based); towers go up through the REAL
// TOWER_BUILD command path. Corner geometry (gloom at the front's 0,0 corner)
// keeps the whole capture frontier inside the towers' radii, so the expected
// capture counts are exact, not statistical.
//
// Deliberately NOT importing commands_combat: no mob/combat/chest tickers, so the
// hour advances with gloom as the only actor.

import { describe, expect, it } from 'vitest';
import '../../sim/commands_economy.js';
import { SimHarness } from '../harness/sim-harness.js';
import { tickWorld } from '../../sim/world.js';
import { setHexOwner, claimHexForPlayer } from '../../sim/systems/territory.js';
import { frontCounts } from '../../sim/systems/fronts.js';
import { hexCenter } from '../../shared/hexgrid.js';
import { OP } from '../../shared/protocol.js';
import {
  CHILL_BELL_COST,
  BASTION_POST_COST,
  GLOOM_HEXES_PER_FRONT_PER_HOUR,
  TOWER_DURABILITY_LOSS_PER_HOUR,
} from '../../shared/tuning.js';

const MIN_MS = 60_000;

/** Advance wall time through the real tick entry point in 10 s slices. */
function advanceMinutes(h: SimHarness, minutes: number, sliceMs = 10_000): void {
  const total = minutes * MIN_MS;
  for (let t = 0; t < total; t += sliceMs) {
    h.clock.advance(sliceMs);
    tickWorld(h.world, sliceMs, h.clock.now());
  }
}

function gloomHexes(h: SimHarness): number {
  return frontCounts(h.world, 'f0,0').gloom;
}

describe('gloom pressure over a ManualClock hour (§1/§8)', () => {
  it('unopposed: captures GLOOM_HEXES_PER_FRONT_PER_HOUR hexes along adjacency', () => {
    const h = SimHarness.create({ seed: 'gloom-hour' });
    h.join('warden');
    setHexOwner(h.world, '0,0', 'gloom', h.clock.now());
    expect(gloomHexes(h)).toBe(1);

    advanceMinutes(h, 61); // 1 min of slack over the float-exact hour boundary
    expect(gloomHexes(h)).toBe(1 + GLOOM_HEXES_PER_FRONT_PER_HOUR);

    // every captured hex is adjacent growth inside the front, not teleporting spread
    for (const [key, hs] of h.world.hexes) {
      expect(hs.owner).toBe('gloom');
      expect(hs.frontId).toBe('f0,0');
      void key;
    }
  });

  it('a cleansed front banks no pressure (no gloom foothold → accumulator zeroes)', () => {
    const h = SimHarness.create({ seed: 'gloom-clean' });
    const { player } = h.join('warden');
    claimHexForPlayer(h.world, player, '0,0', h.clock.now());
    advanceMinutes(h, 61);
    expect(gloomHexes(h)).toBe(0);
    expect(h.world.fronts.get('f0,0')!.gloomAccum).toBe(0);
  });

  it('a Chill Bell in radius slows captures: 1 hex/hour instead of 3', () => {
    const h = SimHarness.create({ seed: 'gloom-bell' });
    const { player, conn } = h.join('warden');
    // Player holds 0,1; the bell there covers the entire capture frontier of the
    // 0,0 corner (every candidate stays within CHILL_BELL_RADIUS_HEXES = 2).
    claimHexForPlayer(h.world, player, '0,1', h.clock.now());
    const c = hexCenter(0, 1);
    h.teleport(player, c.x, c.y);
    player.materials = CHILL_BELL_COST;
    const frames = h.apply(
      { op: OP.TOWER_BUILD, t: h.clock.now(), type: 'chill_bell', hexKey: '0,1' },
      conn,
    );
    expect(frames[0].op).toBe(OP.INVENTORY_UPDATE);
    setHexOwner(h.world, '0,0', 'gloom', h.clock.now());

    advanceMinutes(h, 61);
    // cost per capture = 1/(1−0.40) = 1.667 accrued-hex units → exactly one capture
    expect(gloomHexes(h)).toBe(2);
    // the bell's own hex held (standing tower), and it bled durability in gloom contact
    expect(h.world.hexes.get('0,1')!.owner).toBe('players');
    const bell = [...h.world.towers.values()][0];
    expect(bell.isRubble).toBe(false);
    expect(bell.durability).toBeLessThan(100);
    expect(bell.durability).toBeGreaterThan(100 - 2 * TOWER_DURABILITY_LOSS_PER_HOUR);
  });

  it('a standing Bastion Post blocks every flip in radius 1: zero captures', () => {
    const h = SimHarness.create({ seed: 'gloom-bastion' });
    const { player, conn } = h.join('warden');
    claimHexForPlayer(h.world, player, '0,1', h.clock.now());
    const c = hexCenter(0, 1);
    h.teleport(player, c.x, c.y);
    player.materials = BASTION_POST_COST;
    h.apply({ op: OP.TOWER_BUILD, t: h.clock.now(), type: 'bastion_post', hexKey: '0,1' }, conn);
    setHexOwner(h.world, '0,0', 'gloom', h.clock.now());

    advanceMinutes(h, 61);
    // Both in-front candidates (1,0 and 0,1) sit inside the bastion's no-flip zone.
    expect(gloomHexes(h)).toBe(1);
    expect(h.world.hexes.get('0,1')!.owner).toBe('players');
    // blockaded pressure banks at most one hour's worth (no burst when lifted)
    expect(h.world.fronts.get('f0,0')!.gloomAccum).toBeLessThanOrEqual(
      GLOOM_HEXES_PER_FRONT_PER_HOUR,
    );
  });
});
