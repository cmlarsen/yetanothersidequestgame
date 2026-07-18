import { describe, expect, it } from 'vitest';
import { hashSeed, mulberry32, seededRng } from '../../shared/rng.js';

describe('rng', () => {
  it('same seed ⇒ identical stream', () => {
    const a = seededRng('world-1', 'loot', 42);
    const b = seededRng('world-1', 'loot', 42);
    for (let i = 0; i < 100; i++) expect(a()).toBe(b());
  });

  it('helpers are deterministic too', () => {
    const a = seededRng('x');
    const b = seededRng('x');
    expect(a.int(1, 6)).toBe(b.int(1, 6));
    expect(a.uniform(0, 10)).toBe(b.uniform(0, 10));
    expect(a.chance(0.5)).toBe(b.chance(0.5));
    expect(a.pick(['x', 'y', 'z'])).toBe(b.pick(['x', 'y', 'z']));
  });

  it('different namespaces ⇒ independent streams', () => {
    const a = seededRng('world-1', 'loot', 42);
    const b = seededRng('world-1', 'gloom', 42);
    const c = seededRng('world-2', 'loot', 42);
    const aVals = Array.from({ length: 20 }, () => a());
    const bVals = Array.from({ length: 20 }, () => b());
    const cVals = Array.from({ length: 20 }, () => c());
    expect(aVals).not.toEqual(bVals);
    expect(aVals).not.toEqual(cVals);
  });

  it('hashSeed separates part boundaries ("a","b") ≠ ("ab")', () => {
    expect(hashSeed('a', 'b')).not.toBe(hashSeed('ab'));
    expect(hashSeed(1, 23)).not.toBe(hashSeed(12, 3));
  });

  it('outputs stay in [0,1) and helpers respect bounds', () => {
    const rng = mulberry32(0xdeadbeef);
    for (let i = 0; i < 1000; i++) {
      const v = rng();
      expect(v).toBeGreaterThanOrEqual(0);
      expect(v).toBeLessThan(1);
    }
    for (let i = 0; i < 200; i++) {
      const n = rng.int(3, 7);
      expect(n).toBeGreaterThanOrEqual(3);
      expect(n).toBeLessThanOrEqual(7);
      expect(Number.isInteger(n)).toBe(true);
    }
  });
});
