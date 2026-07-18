// sim/systems/gloom.ts — the §1/§8 Gloom pressure process. PURE, CLOCK-INJECTED,
// deterministic: every capture pick draws from seededRng(seed, 'gloom', frontId,
// tick[, n]) so the same seed + tick history spreads identically.
//
// Model: each front with any gloom hexes (and not resting after completion)
// accrues a fractional capture budget at GLOOM_HEXES_PER_FRONT_PER_HOUR. When the
// budget covers a capture, one hex adjacent to the front's existing gloom flips.
// Towers modify (§8): a Chill Bell makes captures in its radius cost more (−40%
// effective rate, +25%/level), a standing Bastion Post blocks flips in radius 1,
// and any standing tower holds its own hex. Towers in gloom contact bleed
// durability (5/h) and crumble to rubble at 0.

import type { Front, Tower, World } from '../../shared/entities.js';
import { towerDef } from '../../shared/catalog.js';
import {
  BASTION_POST_RADIUS_HEXES,
  CHILL_BELL_RADIUS_HEXES,
  CHILL_BELL_SLOW_PCT,
  FRONT_RESET_HOURS,
  GLOOM_HEXES_PER_FRONT_PER_HOUR,
  TOWER_DURABILITY_LOSS_PER_HOUR,
  TOWER_UPGRADE_EFFECT_PCT,
} from '../../shared/tuning.js';
import { hexDistance, hexKey, hexNeighbors, parseHexKey } from '../../shared/hexgrid.js';
import { seededRng } from '../../shared/rng.js';
import { frontCounts, frontIdAt } from './fronts.js';
import { setHexOwner } from './territory.js';
import { pushGameEvents } from './outbox.js';

const HOUR_MS = 3_600_000;
/** Sanity cap on captures resolved in a single tick (a tick's accrual is ~1/12000
 * of a capture, so >1 per tick only ever means injected pressure in tests). */
const MAX_CAPTURES_PER_TICK = 8;

export function stepGloom(world: World, dtMs: number, now: number): void {
  const perTick = GLOOM_HEXES_PER_FRONT_PER_HOUR * (dtMs / HOUR_MS);
  const fronts = [...world.fronts.values()].sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  for (const front of fronts) {
    const counts = frontCounts(world, front.id);
    if (counts.gloom === 0) {
      // No foothold, no pressure — a cleansed front doesn't bank a comeback.
      front.gloomAccum = 0;
      continue;
    }
    if (isResting(front, now)) continue;
    front.gloomAccum += perTick;
    advanceCapture(world, front, now);
  }
  stepTowerDecay(world, dtMs, now);
}

/** §1: after 100%-player completion the front's pressure rests for FRONT_RESET_HOURS. */
export function isResting(front: Front, now: number): boolean {
  return front.completedAt !== undefined && now < front.completedAt + FRONT_RESET_HOURS * HOUR_MS;
}

function advanceCapture(world: World, front: Front, now: number): void {
  for (let n = 0; n < MAX_CAPTURES_PER_TICK && front.gloomAccum >= 1; n++) {
    const candidates = captureCandidates(world, front);
    if (candidates.length === 0) {
      // Fully spread or blockaded: cap the banked pressure at one hour's worth so a
      // lifted blockade can't unleash a burst.
      front.gloomAccum = Math.min(front.gloomAccum, GLOOM_HEXES_PER_FRONT_PER_HOUR);
      return;
    }
    const rng = seededRng(world.seed, 'gloom', front.id, world.tick, n);
    const key = rng.pick(candidates);
    const cost = captureCost(world, key);
    if (front.gloomAccum < cost) return; // slowed by a Chill Bell — keep accruing
    front.gloomAccum -= cost;
    setHexOwner(world, key, 'gloom', now);
  }
}

/**
 * Flip candidates for a front: non-gloom hexes inside the front, hexNeighbors-
 * adjacent to the front's existing gloom, not mid-contest, not held by a standing
 * tower, not inside a standing Bastion Post's no-flip zone. Sorted for a
 * pick-order independent of Map insertion history.
 */
export function captureCandidates(world: World, front: Front): string[] {
  const out = new Set<string>();
  for (const [key, hs] of world.hexes) {
    if (hs.owner !== 'gloom' || hs.frontId !== front.id) continue;
    const qr = parseHexKey(key);
    if (!qr) continue;
    for (const nb of hexNeighbors(qr.q, qr.r)) {
      if (frontIdAt(nb.q, nb.r) !== front.id) continue;
      const nk = hexKey(nb.q, nb.r);
      const ns = world.hexes.get(nk);
      if (ns?.owner === 'gloom') continue;
      if (ns?.contestedMobId !== undefined) continue; // a fight settles this hex, not pressure
      if (isFlipBlocked(world, nb.q, nb.r, ns?.towerId)) continue;
      out.add(nk);
    }
  }
  return [...out].sort();
}

/** A standing tower holds its own hex; a standing Bastion Post holds radius 1. */
function isFlipBlocked(world: World, q: number, r: number, towerId: string | undefined): boolean {
  if (towerId) {
    const t = world.towers.get(towerId);
    if (t && !t.isRubble) return true;
  }
  for (const t of world.towers.values()) {
    if (t.type !== 'bastion_post' || t.isRubble) continue;
    const tq = parseHexKey(t.hexKey);
    if (tq && hexDistance(q, r, tq.q, tq.r) <= BASTION_POST_RADIUS_HEXES) return true;
  }
  return false;
}

/** Capture cost in accrued-hex units: 1, raised by the strongest Chill Bell in
 * range (−40% effective rate at level 1, +25% effect per level, §8). */
export function captureCost(world: World, key: string): number {
  const qr = parseHexKey(key);
  if (!qr) return 1;
  let slowPct = 0;
  for (const t of world.towers.values()) {
    if (t.type !== 'chill_bell' || t.isRubble) continue;
    const tq = parseHexKey(t.hexKey);
    if (!tq || hexDistance(qr.q, qr.r, tq.q, tq.r) > CHILL_BELL_RADIUS_HEXES) continue;
    const pct = CHILL_BELL_SLOW_PCT * (1 + (TOWER_UPGRADE_EFFECT_PCT / 100) * (t.level - 1));
    slowPct = Math.max(slowPct, Math.min(90, pct));
  }
  return slowPct > 0 ? 1 / (1 - slowPct / 100) : 1;
}

/** §8 durability bleed: TOWER_DURABILITY_LOSS_PER_HOUR while any gloom hex sits
 * within the tower's effect radius; rubble at 0 (rebuild needs a visit). */
function stepTowerDecay(world: World, dtMs: number, now: number): void {
  const loss = TOWER_DURABILITY_LOSS_PER_HOUR * (dtMs / HOUR_MS);
  for (const tower of world.towers.values()) {
    if (tower.isRubble) continue;
    if (!inGloomContact(world, tower)) continue;
    tower.durability -= loss;
    if (tower.durability <= 0) {
      tower.durability = 0;
      tower.isRubble = true;
      tower.log.push({ at: now, event: 'crumbled to rubble under Gloom pressure' });
      if (tower.log.length > 20) tower.log.splice(0, tower.log.length - 20);
      const name = towerDef(tower.type)?.name ?? tower.type;
      pushGameEvents(world, tower.ownerId, now, [{ k: 'notice', text: `${name} crumbled to rubble` }]);
    }
  }
}

function inGloomContact(world: World, tower: Tower): boolean {
  const tq = parseHexKey(tower.hexKey);
  if (!tq) return false;
  const radius = towerDef(tower.type)?.radiusHexes ?? 1;
  // Enumerate the ≤ few-dozen cells in radius rather than scanning every owned hex.
  for (let dq = -radius; dq <= radius; dq++) {
    for (let dr = -radius; dr <= radius; dr++) {
      if (hexDistance(0, 0, dq, dr) > radius) continue;
      const hs = world.hexes.get(hexKey(tq.q + dq, tq.r + dr));
      if (hs?.owner === 'gloom') return true;
    }
  }
  return false;
}
