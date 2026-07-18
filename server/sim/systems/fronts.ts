// sim/systems/fronts.ts — the static seed-derived front partition (GAME-RULES §1,
// DESIGN §fronts). The hex plane is cut into FRONT_CELL_HEXES × FRONT_CELL_HEXES
// axial super-cells; each cell is one named "front" (placeholder street names until
// real map data). Fronts materialize lazily on first touch; geometry re-derives
// from seed, only progress fields persist (see Front in shared/entities.ts).
//
// Tug-of-war %s come from per-front owned COUNTERS maintained incrementally on
// every hex flip (territory.setHexOwner is the single flip primitive) — never an
// O(all hexes) scan per read. recountFront exists for load-time rebuild + tests.

import type { Front, HexOwner, World } from '../../shared/entities.js';
import type { FrontWire } from '../../shared/protocol.js';
import { FRONT_CELL_HEXES } from '../../shared/constants.js';
import { parseHexKey } from '../../shared/hexgrid.js';
import { seededRng } from '../../shared/rng.js';

/** 40 placeholder street names; a front's name mixes the seed + its super-cell
 * coords into the pick, so neighbouring cells (usually) differ. Real cities repeat
 * street names too — front IDENTITY is the id, never the name. */
export const STREET_NAMES: readonly string[] = [
  'Elm St',
  'Maple Ave',
  'Oak Ln',
  'Birch Blvd',
  'Cedar Ct',
  'Willow Way',
  'Aspen Alley',
  'Juniper Jct',
  'Grumble Park',
  'Pine Row',
  'Poplar Pl',
  'Hazel Hollow',
  'Rowan Rd',
  'Alder Arc',
  'Laurel Loop',
  'Ivy Isle',
  'Fern Field',
  'Moss Mews',
  'Bramble Bend',
  'Thistle Terrace',
  'Clover Close',
  'Dandelion Dr',
  'Foxglove Fwy',
  'Marigold Mall',
  'Nettle Nook',
  'Orchid Oval',
  'Primrose Path',
  'Quince Quay',
  'Sorrel Sq',
  'Tulip Trl',
  'Violet Vale',
  'Wisteria Walk',
  'Yarrow Yard',
  'Acorn Ave',
  'Chestnut Chase',
  'Drizzle Dell',
  'Ember End',
  'Frostbite Flats',
  'Gustwind Grove',
  'Hushfall Hts',
];

/** The front (super-cell) id for an axial hex. Stable per grid — no seed involved. */
export function frontIdAt(q: number, r: number): string {
  const cx = Math.floor(q / FRONT_CELL_HEXES);
  const cy = Math.floor(r / FRONT_CELL_HEXES);
  return `f${cx},${cy}`;
}

/** Parse a front id back to super-cell coords (null on a malformed id). */
export function parseFrontId(id: string): { cx: number; cy: number } | null {
  if (!id.startsWith('f')) return null;
  const qr = parseHexKey(id.slice(1));
  return qr ? { cx: qr.q, cy: qr.r } : null;
}

/** Seeded placeholder name for a front (deterministic per seed + cell). */
export function frontName(seed: string, cx: number, cy: number): string {
  return seededRng(seed, 'front-name', cx, cy).pick(STREET_NAMES);
}

/** Materialize a front record on first touch. Idempotent; geometry derives from seed. */
export function ensureFront(world: World, frontId: string): Front {
  const existing = world.fronts.get(frontId);
  if (existing) return existing;
  const cell = parseFrontId(frontId);
  if (!cell) throw new Error(`ensureFront: malformed front id ${frontId}`);
  const front: Front = {
    id: frontId,
    name: frontName(world.seed, cell.cx, cell.cy),
    cellX: cell.cx,
    cellY: cell.cy,
    sizeHexes: FRONT_CELL_HEXES * FRONT_CELL_HEXES,
    gloomAccum: 0,
  };
  world.fronts.set(frontId, front);
  return front;
}

// ---------------------------------------------------------------------------
// Per-front owned counters — runtime-only (WeakMap by World identity, rebuilt on
// deserialize via recountFronts), incremented by territory.setHexOwner on every flip.
// ---------------------------------------------------------------------------

export interface FrontCounts {
  players: number;
  gloom: number;
}

const countsByWorld = new WeakMap<World, Map<string, FrontCounts>>();

function countsMap(world: World): Map<string, FrontCounts> {
  let m = countsByWorld.get(world);
  if (!m) {
    m = new Map();
    countsByWorld.set(world, m);
  }
  return m;
}

/** Live owned counts for a front (zeroes until any hex in it flips). */
export function frontCounts(world: World, frontId: string): FrontCounts {
  const m = countsMap(world);
  let c = m.get(frontId);
  if (!c) {
    c = { players: 0, gloom: 0 };
    m.set(frontId, c);
  }
  return c;
}

/** Incremental counter bump — territory.setHexOwner is the only production caller. */
export function bumpFrontCount(world: World, frontId: string, owner: HexOwner, delta: number): void {
  const c = frontCounts(world, frontId);
  if (owner === 'players') c.players += delta;
  else c.gloom += delta;
}

/** Full O(hexes) rebuild — deserialize/load path + the incremental-vs-recount test. */
export function recountFronts(world: World): void {
  const m = countsMap(world);
  m.clear();
  for (const hs of world.hexes.values()) {
    ensureFront(world, hs.frontId);
    bumpFrontCount(world, hs.frontId, hs.owner, 1);
  }
}

/** One front's counts recomputed from scratch (does not touch the live counters). */
export function recountFront(world: World, frontId: string): FrontCounts {
  const c: FrontCounts = { players: 0, gloom: 0 };
  for (const hs of world.hexes.values()) {
    if (hs.frontId !== frontId) continue;
    if (hs.owner === 'players') c.players += 1;
    else c.gloom += 1;
  }
  return c;
}

/** Tug-of-war percentages (0–100 integers) from the incremental counters. */
export function frontPcts(world: World, frontId: string): { pctPlayer: number; pctGloom: number } {
  const size = FRONT_CELL_HEXES * FRONT_CELL_HEXES;
  const c = frontCounts(world, frontId);
  return {
    pctPlayer: Math.round((c.players / size) * 100),
    pctGloom: Math.round((c.gloom / size) * 100),
  };
}

/** Client-facing view of a front. READ-ONLY: never materializes (snapshot builders
 * must not mutate the world), so an untouched front reads as 0/0 with its seeded name. */
export function frontView(world: World, frontId: string): FrontWire {
  const front = world.fronts.get(frontId);
  const { pctPlayer, pctGloom } = frontPcts(world, frontId);
  if (front) return { id: front.id, name: front.name, pctPlayer, pctGloom };
  const cell = parseFrontId(frontId);
  const name = cell ? frontName(world.seed, cell.cx, cell.cy) : frontId;
  return { id: frontId, name, pctPlayer, pctGloom };
}
