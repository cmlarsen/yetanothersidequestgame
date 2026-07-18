// shared/hexgrid.ts — the hex lattice territory is measured in. PURE, I/O-free,
// deterministic: no GPS / clock / RNG. Single source for both the sim (claim/capture
// paints hexes) and the Godot shell (via tools codegen) so a claimed hex lines up
// exactly with the tile drawn under it. Ported from SideQuestAppV2 shared/hexgrid.ts
// (re-scaled to the GAME-RULES §1 hex; hexNeighbors/hexDistance are new — V2 only
// had radius scans).
//
// Layout: flat-top axial grid (q east-ish column, r row), centres in sim metres
// (x east, y north). Rounding in hexAt is the cheap round carried from V2: corners
// can misassign by a sliver, but sim + render agree, which is what matters.

import type { Vec2 } from './entities.js';

/** World metres flat-to-flat across one hex (GAME-RULES §1: ~60 m across flats). */
export const HEX_ACROSS_M = 60;

/** circumradius (centre → corner) derived from the flat-to-flat width. */
const R = HEX_ACROSS_M / Math.sqrt(3);

/** flat-top axial hex centre → world metres. */
export function hexCenter(q: number, r: number): Vec2 {
  return { x: 1.5 * R * q, y: Math.sqrt(3) * R * (r + q / 2) };
}

/** world point → the axial hex it falls in (cheap round; matches V2's terrain builder). */
export function hexAt(x: number, y: number): { q: number; r: number } {
  const q = Math.round(x / (1.5 * R));
  const r = Math.round(y / (Math.sqrt(3) * R) - q / 2);
  return { q, r };
}

/** stable string key for an axial hex (the on-the-wire + map-key form). */
export function hexKey(q: number, r: number): string {
  return q + ',' + r;
}

/** the hex a world point falls in, as a key. */
export function hexKeyAt(x: number, y: number): string {
  const { q, r } = hexAt(x, y);
  return hexKey(q, r);
}

/** parse a hex key back to axial coords (null on a malformed key). */
export function parseHexKey(key: string): { q: number; r: number } | null {
  const i = key.indexOf(',');
  if (i < 0) return null;
  const q = Number(key.slice(0, i));
  const r = Number(key.slice(i + 1));
  return Number.isFinite(q) && Number.isFinite(r) ? { q, r } : null;
}

/** The 6 axial direction offsets, CCW starting east-northeast (+q). Same for every hex. */
export const HEX_DIRECTIONS: readonly { q: number; r: number }[] = [
  { q: 1, r: 0 },
  { q: 0, r: 1 },
  { q: -1, r: 1 },
  { q: -1, r: 0 },
  { q: 0, r: -1 },
  { q: 1, r: -1 },
];

/** the 6 axial neighbors of a hex — adjacency for claiming/contest/gloom spread (§1). */
export function hexNeighbors(q: number, r: number): { q: number; r: number }[] {
  return HEX_DIRECTIONS.map((d) => ({ q: q + d.q, r: r + d.r }));
}

/** axial hex distance in steps (cube distance: s = −q−r). */
export function hexDistance(aq: number, ar: number, bq: number, br: number): number {
  const dq = aq - bq;
  const dr = ar - br;
  return (Math.abs(dq) + Math.abs(dr) + Math.abs(dq + dr)) / 2;
}

/**
 * hexKeysWithin — every hex whose CENTRE lies within `radiusM` of `pos`.
 * Deterministic; scans the bounding neighbourhood.
 */
export function hexKeysWithin(pos: Vec2, radiusM: number): string[] {
  const { q: q0, r: r0 } = hexAt(pos.x, pos.y);
  const span = Math.ceil(radiusM / (HEX_ACROSS_M * 0.75)) + 1;
  const out: string[] = [];
  for (let dq = -span; dq <= span; dq++) {
    for (let dr = -span; dr <= span; dr++) {
      const q = q0 + dq;
      const r = r0 + dr;
      const c = hexCenter(q, r);
      if (Math.hypot(c.x - pos.x, c.y - pos.y) <= radiusM) out.push(hexKey(q, r));
    }
  }
  return out;
}
