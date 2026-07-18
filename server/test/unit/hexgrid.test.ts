import { describe, expect, it } from 'vitest';
import { distM, project, unproject } from '../../shared/geo.js';
import {
  HEX_ACROSS_M,
  hexAt,
  hexCenter,
  hexDistance,
  hexKey,
  hexKeyAt,
  hexKeysWithin,
  hexNeighbors,
  parseHexKey,
} from '../../shared/hexgrid.js';
import { seededRng } from '../../shared/rng.js';

const ORIGIN = { lat: 40.2338, lng: -111.6585 };

describe('hexgrid', () => {
  it('hexes are 60 m across flats (GAME-RULES §1)', () => {
    expect(HEX_ACROSS_M).toBe(60);
    // adjacent centres sit exactly one flat-to-flat width apart
    const c0 = hexCenter(0, 0);
    for (const n of hexNeighbors(0, 0)) {
      expect(distM(c0, hexCenter(n.q, n.r))).toBeCloseTo(60, 6);
    }
  });

  it('centre → hexAt roundtrip is exact', () => {
    for (let q = -12; q <= 12; q += 3) {
      for (let r = -12; r <= 12; r += 3) {
        const c = hexCenter(q, r);
        expect(hexAt(c.x, c.y)).toEqual({ q, r });
      }
    }
  });

  it('geo → hex roundtrip near origin: assigned hex centre is nearby', () => {
    const rng = seededRng('hexgrid-test');
    for (let i = 0; i < 50; i++) {
      const p = { lat: ORIGIN.lat + rng.uniform(-0.005, 0.005), lng: ORIGIN.lng + rng.uniform(-0.005, 0.005) };
      const v = project(ORIGIN, p);
      const hex = parseHexKey(hexKeyAt(v.x, v.y));
      expect(hex).not.toBeNull();
      const c = hexCenter(hex!.q, hex!.r);
      // cheap-round can misassign corner slivers, but never farther than a hex width
      expect(distM(v, c)).toBeLessThan(HEX_ACROSS_M);
      // and the projection itself roundtrips
      const back = project(ORIGIN, unproject(ORIGIN, v));
      expect(distM(v, back)).toBeLessThan(1e-6);
    }
  });

  it('neighbors are 6 unique adjacent cells', () => {
    const n = hexNeighbors(3, -5);
    expect(n).toHaveLength(6);
    expect(new Set(n.map((h) => hexKey(h.q, h.r))).size).toBe(6);
    for (const h of n) {
      expect(hexDistance(3, -5, h.q, h.r)).toBe(1);
      // metric adjacency too
      expect(distM(hexCenter(3, -5), hexCenter(h.q, h.r))).toBeCloseTo(HEX_ACROSS_M, 6);
    }
    expect(n.map((h) => hexKey(h.q, h.r))).not.toContain(hexKey(3, -5));
  });

  it('hexDistance sanity', () => {
    expect(hexDistance(0, 0, 0, 0)).toBe(0);
    expect(hexDistance(0, 0, 3, 0)).toBe(3);
    expect(hexDistance(0, 0, 0, -4)).toBe(4);
    expect(hexDistance(0, 0, 2, -2)).toBe(2); // along the +q/−r diagonal
    expect(hexDistance(-2, 1, 1, 1)).toBe(3);
    // symmetric
    expect(hexDistance(5, -3, -1, 2)).toBe(hexDistance(-1, 2, 5, -3));
  });

  it('hexKey/parseHexKey roundtrip; malformed keys are null', () => {
    expect(parseHexKey(hexKey(-7, 12))).toEqual({ q: -7, r: 12 });
    expect(parseHexKey('nope')).toBeNull();
    expect(parseHexKey('1,x')).toBeNull();
  });

  it('hexKeysWithin covers the origin hex and respects the radius', () => {
    const keys = hexKeysWithin({ x: 0, y: 0 }, 65);
    expect(keys).toContain('0,0');
    // 65 m catches all 6 neighbours (60 m away) and nothing beyond
    expect(keys).toHaveLength(7);
  });
});
