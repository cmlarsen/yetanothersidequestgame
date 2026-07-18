// shared/rng.ts — seeded, pure PRNG. NO Math.random anywhere (enforced by lint:purity).
// Deterministic: same seed + same call sequence ⇒ same stream, in Node and the browser.
// Ported verbatim from SideQuestAppV2 shared/rng.ts.

/** A pure PRNG closure returning floats in [0,1). */
export interface Rng {
  (): number;
  /** float in [min, max). */
  uniform(min: number, max: number): number;
  /** integer in [min, max] inclusive. */
  int(min: number, max: number): number;
  /** true with probability p. */
  chance(p: number): boolean;
  /** uniform pick from a non-empty array. */
  pick<T>(arr: readonly T[]): T;
}

/**
 * mulberry32 — a fast 32-bit PRNG. Given a uint32 seed, returns a stateful
 * generator producing floats in [0,1). Pure & deterministic.
 */
export function mulberry32(seed: number): Rng {
  let a = seed >>> 0;
  const next = (): number => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const rng = next as Rng;
  rng.uniform = (min, max) => min + next() * (max - min);
  rng.int = (min, max) => min + Math.floor(next() * (max - min + 1));
  rng.chance = (p) => next() < p;
  rng.pick = (arr) => arr[Math.floor(next() * arr.length)];
  return rng;
}

/**
 * hashSeed — fold string/number parts into a deterministic uint32 (FNV-1a style),
 * for namespacing sub-seeds (e.g. per-front, per-entity). Pure.
 */
export function hashSeed(...parts: Array<string | number>): number {
  let h = 0x811c9dc5; // FNV offset basis
  for (const part of parts) {
    const s = typeof part === 'number' ? numToStr(part) : part;
    for (let i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = Math.imul(h, 0x01000193); // FNV prime
    }
    h ^= 0x2c; // ',' separator so ("a","b") ≠ ("ab")
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

/** Deterministic number→string (no locale, no Date). */
function numToStr(n: number): string {
  return Number.isInteger(n) ? n.toString(10) : n.toString();
}

/** Convenience: seed a mulberry32 directly from string/number parts. */
export function seededRng(...parts: Array<string | number>): Rng {
  return mulberry32(hashSeed(...parts));
}
