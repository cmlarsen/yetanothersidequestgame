// Mob field (§1/§3): seeded occupancy tethered to gloom, established-player gate,
// gloom painting via the territory primitive, respawn timers, tyrant identity.

import { describe, expect, it } from 'vitest';
import '../../sim/commands_combat.js'; // registers tickers + hooks
import { SimHarness } from '../harness/sim-harness.js';
import {
  MOB_RESPAWN_MS,
  MOB_SPAWN_P_GLOOM,
  MOB_SPAWN_P_WILD,
  mobFieldSpec,
  mobMaxHp,
  mobRoamPos,
} from '../../sim/systems/mobs.js';
import { MOBS } from '../../shared/catalog.js';
import { claimHexForPlayer } from '../../sim/systems/territory.js';
import { hexKey } from '../../shared/hexgrid.js';

function establishedSetup(seed = 'mob-field-test') {
  const h = SimHarness.create({ seed });
  const { player, conn } = h.join('walker');
  h.gpsAt(conn, { x: 0, y: 0 }); // establishes (gpsAccuracy > 0)
  h.tick(1);
  return { h, player, conn };
}

describe('spawn field', () => {
  it('spawns nothing around a non-established (teleported) pawn', () => {
    const h = SimHarness.create({ seed: 'mob-field-test' });
    h.join('ghost');
    h.tick(5);
    expect(h.world.mobs.size).toBe(0);
  });

  it('materializes a seeded field around an established player, deterministically', () => {
    const a = establishedSetup();
    const b = establishedSetup();
    expect(a.h.world.mobs.size).toBeGreaterThan(0);
    const ids = (x: typeof a) => [...x.h.world.mobs.keys()].sort();
    expect(ids(a)).toEqual(ids(b));
    for (const id of ids(a)) {
      expect(a.h.world.mobs.get(id)!.pos).toEqual(b.h.world.mobs.get(id)!.pos);
      expect(a.h.world.mobs.get(id)!.speciesId).toBe(b.h.world.mobs.get(id)!.speciesId);
    }
  });

  it('paints its hex for GLOOM on spawn (mobs claim as they roam, §1)', () => {
    const { h } = establishedSetup();
    for (const mob of h.world.mobs.values()) {
      expect(h.world.hexes.get(mob.hexKey)?.owner).toBe('gloom');
    }
  });

  it('never spawns on player-owned ground', () => {
    const h = SimHarness.create({ seed: 'mob-field-test' });
    const { player, conn } = h.join('walker');
    let cell: { q: number; r: number } | null = null;
    outer: for (let q = -5; q <= 5; q++) {
      for (let r = -5; r <= 5; r++) {
        if (mobFieldSpec('mob-field-test', q, r, false)) {
          cell = { q, r };
          break outer;
        }
      }
    }
    expect(cell).not.toBeNull();
    claimHexForPlayer(h.world, player, hexKey(cell!.q, cell!.r), h.clock.now());
    h.gpsAt(conn, { x: 0, y: 0 });
    h.tick(1);
    expect(h.world.mobs.has(`mob:${hexKey(cell!.q, cell!.r)}`)).toBe(false);
  });

  it('roams the seeded lissajous of the injected clock', () => {
    const { h } = establishedSetup();
    const id = [...h.world.mobs.keys()].sort()[0];
    const before = { ...h.world.mobs.get(id)!.pos };
    h.advance(30_000);
    const after = h.world.mobs.get(id)!.pos;
    expect(after).not.toEqual(before);
    // same seed + same clock in a parallel world ⇒ identical trajectory
    const b = establishedSetup();
    b.h.advance(30_000);
    expect(b.h.world.mobs.get(id)!.pos).toEqual(after);
  });
});

describe('respawn timers', () => {
  it('a killed cell stays empty for MOB_RESPAWN_MS, then re-derives the same mob', () => {
    const { h } = establishedSetup();
    const id = [...h.world.mobs.keys()].sort()[0];
    const species = h.world.mobs.get(id)!.speciesId;
    h.world.mobs.delete(id); // combat kill path removes the live mob
    h.tick(1); // field self-heals: cooldown starts
    expect(h.world.mobs.has(id)).toBe(false);
    h.tick(10);
    expect(h.world.mobs.has(id)).toBe(false);
    h.advance(MOB_RESPAWN_MS + 1_000);
    expect(h.world.mobs.has(id)).toBe(true);
    expect(h.world.mobs.get(id)!.speciesId).toBe(species);
  });
});

describe('species + stats (catalog-derived)', () => {
  it('tyrant HP is 4 segments; gloomling is single-segment', () => {
    expect(MOBS.grumbleshroom.hpSegments).toBe(4);
    expect(mobMaxHp('grumbleshroom')).toBe((30 + 5 * MOBS.grumbleshroom.level) * 4);
    expect(mobMaxHp('gloomling')).toBe(30 + 5 * MOBS.gloomling.level);
  });

  it('the seeded field contains both species; gloom cells superset wild cells', () => {
    let gloomlings = 0;
    let tyrants = 0;
    for (let q = -40; q <= 40; q++) {
      for (let r = -40; r <= 40; r++) {
        const wild = mobFieldSpec('mob-field-test', q, r, false);
        const gloom = mobFieldSpec('mob-field-test', q, r, true);
        if (wild) expect(gloom).not.toBeNull(); // wild ⊂ gloom (shared occupancy hash)
        if (!gloom) continue;
        if (gloom.speciesId === 'grumbleshroom') tyrants += 1;
        else gloomlings += 1;
      }
    }
    expect(gloomlings).toBeGreaterThan(0);
    expect(tyrants).toBeGreaterThan(0);
    expect(MOB_SPAWN_P_GLOOM).toBeGreaterThan(MOB_SPAWN_P_WILD);
  });

  it('mobRoamPos is a pure function of (spec, now)', () => {
    const spec = { speciesId: 'gloomling' as const, anchor: { x: 10, y: 20 }, seed: 42 };
    expect(mobRoamPos(spec, 5_000)).toEqual(mobRoamPos(spec, 5_000));
    expect(mobRoamPos(spec, 5_000)).not.toEqual(mobRoamPos(spec, 65_000));
  });
});
