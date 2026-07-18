// sim/systems/mobs.ts — the §3 mob spawn field. PURE, CLOCK-INJECTED,
// SEED-DETERMINISTIC. Ported from SideQuestAppV2 server/sim/systems/ambient.ts
// (seeded cell occupancy + pure lissajous roam of the injected clock + per-cell
// respawn cooldowns), re-modelled onto the YAS hex world: the cell IS the hex,
// and the "tether" is gloom territory — gloom hexes host a dense field, neutral
// wilds a sparse one (the genesis path: §1 gloom exists BECAUSE mobs paint their
// hex for GLOOM as they roam, via the territory flip primitive). Player-owned
// hexes never host or get painted — gloom pressure (gloom.ts) is the only thing
// that takes player ground.
//
// Mobs are RUNTIME-ONLY (never persisted): ids derive from (seed, hex cell) so
// reconnects and parallel servers agree. Field state (cells, respawn cooldowns)
// is WeakMap-keyed by World identity, exactly like V2.

import type { Mob, Player, Vec2, World } from '../../shared/entities.js';
import type { MobSpeciesId } from '../../shared/catalog.js';
import { MOBS } from '../../shared/catalog.js';
import { hashSeed, mulberry32 } from '../../shared/rng.js';
import { within } from '../../shared/geo.js';
import { hexCenter, hexKeyAt, hexKeysWithin, parseHexKey } from '../../shared/hexgrid.js';
import { registerTicker } from '../world.js';
import { setHexOwner } from './territory.js';

const TAU = Math.PI * 2;

// ---------------------------------------------------------------------------
// Field tuning. These are NOT GAME-RULES DEFAULTs (the doc gives no mob HP/damage/
// reward numbers) — they live here, not tuning.ts, until design promotes them.
// ---------------------------------------------------------------------------

/** Cells materialize within this of an established player (V2 relevance gate). */
export const MOB_FIELD_RADIUS_M = 300;
/** An unengaged field mob with no established player inside this despawns. */
export const MOB_DESPAWN_RADIUS_M = 600;
/** Seeded per-hex occupancy: dense on gloom ground, sparse in the neutral wilds. */
export const MOB_SPAWN_P_GLOOM = 0.35;
export const MOB_SPAWN_P_WILD = 0.08;
/** Of occupied cells, this fraction hosts a Turf Tyrant instead of a Gloomling. */
export const MOB_TYRANT_P = 0.04;
export const MOB_ANCHOR_JITTER_M = 12;
/** Lissajous roam envelope — wide enough to wander into neighbour hexes and paint them. */
export const MOB_ROAM_R_M = 40;
export const MOB_ROAM_PERIOD_MS = 120_000;
/** Killed cell → fresh mob after this (the V2 respawn-timer pattern). */
export const MOB_RESPAWN_MS = 60_000;

// Combat-facing stat derivations (combat.ts reads these; §3 gives species/level/
// segments via the catalog but no raw numbers).
export const MOB_HP_BASE = 30;
export const MOB_HP_PER_LEVEL = 5;
export const MOB_SWING_BASE = 4;
export const MOB_SWING_PER_LEVEL = 2;
export const MOB_XP_PER_LEVEL = 15;
export const MOB_GOLD_PER_LEVEL = 6;
export const TYRANT_REWARD_MULT = 4;

/** §3 max HP: base + per-level, ×hpSegments for Tyrants (the 4-segment boss bar). */
export function mobMaxHp(speciesId: MobSpeciesId): number {
  const def = MOBS[speciesId];
  const perSegment = MOB_HP_BASE + MOB_HP_PER_LEVEL * def.level;
  return perSegment * (def.isTyrant ? def.hpSegments : 1);
}

export function mobSwingDmg(mob: Mob): number {
  return MOB_SWING_BASE + MOB_SWING_PER_LEVEL * mob.level;
}

export function mobXpReward(mob: Mob): number {
  return MOB_XP_PER_LEVEL * mob.level * (mob.isTyrant ? TYRANT_REWARD_MULT : 1);
}

export function mobGoldReward(mob: Mob): number {
  return MOB_GOLD_PER_LEVEL * mob.level * (mob.isTyrant ? TYRANT_REWARD_MULT : 1);
}

// ---------------------------------------------------------------------------
// The seed-derived spec: does hex (q,r) host a mob, and which one?
// ---------------------------------------------------------------------------

export interface MobSpec {
  speciesId: MobSpeciesId;
  anchor: Vec2;
  seed: number;
}

/**
 * mobFieldSpec — PURE occupancy + identity for one hex cell. The occupancy hash is
 * shared between the wild and gloom rates (wild cells are a strict subset of gloom
 * cells), so a hex flipping to gloom only ever ADDS a mob, never moves one.
 */
export function mobFieldSpec(seed: string, q: number, r: number, gloomy: boolean): MobSpec | null {
  const h = hashSeed(seed, 'mob-field', q, r);
  const occ = (h & 0xffff) / 0x10000;
  if (occ >= (gloomy ? MOB_SPAWN_P_GLOOM : MOB_SPAWN_P_WILD)) return null;
  const rng = mulberry32(h);
  const speciesId: MobSpeciesId = rng.chance(MOB_TYRANT_P) ? 'grumbleshroom' : 'gloomling';
  const c = hexCenter(q, r);
  const anchor: Vec2 = {
    x: Math.round((c.x + rng.uniform(-MOB_ANCHOR_JITTER_M, MOB_ANCHOR_JITTER_M)) * 100) / 100,
    y: Math.round((c.y + rng.uniform(-MOB_ANCHOR_JITTER_M, MOB_ANCHOR_JITTER_M)) * 100) / 100,
  };
  return { speciesId, anchor, seed: h };
}

/**
 * mobRoamPos — PURE lissajous of the injected clock around the anchor (V2 pattern:
 * absolute, never integrated, so it can't drift and reconnects reproduce it).
 */
export function mobRoamPos(spec: MobSpec, now: number): Vec2 {
  const ph = hashSeed(String(spec.seed), 'mob-roam');
  const px = (((ph >>> 4) & 0xffff) / 0x10000) * TAU;
  const py = (((ph >>> 18) & 0x3fff) / 0x4000) * TAU;
  const w = TAU / MOB_ROAM_PERIOD_MS;
  return {
    x: Math.round((spec.anchor.x + MOB_ROAM_R_M * Math.sin(now * w + px)) * 100) / 100,
    y: Math.round((spec.anchor.y + MOB_ROAM_R_M * Math.sin(now * w * 1.37 + py)) * 100) / 100,
  };
}

/** Build the runtime Mob for a spec (combat tests use this to craft fixtures). */
export function makeMob(id: string, speciesId: MobSpeciesId, anchor: Vec2): Mob {
  const def = MOBS[speciesId];
  const hp = mobMaxHp(speciesId);
  return {
    id,
    speciesId,
    level: def.level,
    isTyrant: def.isTyrant,
    hp,
    maxHp: hp,
    pos: { x: anchor.x, y: anchor.y },
    homePos: { x: anchor.x, y: anchor.y },
    hexKey: hexKeyAt(anchor.x, anchor.y),
    engagedBy: [],
    slowedUntil: 0,
    swingReadyAt: 0,
  };
}

// ---------------------------------------------------------------------------
// Runtime field state — WeakMap by World identity (never persisted, no
// cross-world leak; a fresh harness per test starts clean).
// ---------------------------------------------------------------------------

interface MobCell {
  mob: Mob;
  spec: MobSpec;
  /** Contested-hex defender (ensureMobOnHex): holds its hex, never respawns. */
  defenderKey: string | null;
}

const fields = new WeakMap<World, Map<string, MobCell>>();
const cooldowns = new WeakMap<World, Map<string, number>>();

function fieldFor(world: World): Map<string, MobCell> {
  let m = fields.get(world);
  if (!m) {
    m = new Map();
    fields.set(world, m);
  }
  return m;
}

function cooldownFor(world: World): Map<string, number> {
  let m = cooldowns.get(world);
  if (!m) {
    m = new Map();
    cooldowns.set(world, m);
  }
  return m;
}

/** Established = online with a real GPS fix ingested — the V2 gate that keeps
 * manually-teleported harness pawns from sprouting a mob field around them. */
function established(p: Player): boolean {
  return p.connId !== null && p.gpsAccuracy > 0;
}

function anyEstablishedWithin(world: World, pos: Vec2, radiusM: number): boolean {
  for (const p of world.players.values()) {
    if (established(p) && within(p.pos, pos, radiusM)) return true;
  }
  return false;
}

/** Paint the mob's hex for GLOOM via the territory flip primitive (§1 "mobs claim
 * hexes as they roam") — NEUTRAL hexes only; player ground falls to pressure, not roam. */
function paintHex(world: World, key: string, now: number): void {
  if (!world.hexes.has(key)) setHexOwner(world, key, 'gloom', now);
}

function spawnCell(
  world: World,
  id: string,
  spec: MobSpec,
  now: number,
  defenderKey: string | null,
): Mob {
  const mob = makeMob(id, spec.speciesId, spec.anchor);
  if (defenderKey === null) {
    mob.pos = mobRoamPos(spec, now);
    mob.hexKey = hexKeyAt(mob.pos.x, mob.pos.y);
  } else {
    const qr = parseHexKey(defenderKey);
    if (qr) {
      const c = hexCenter(qr.q, qr.r);
      mob.pos = { x: c.x, y: c.y };
      mob.homePos = { x: c.x, y: c.y };
    }
    mob.hexKey = defenderKey;
  }
  world.mobs.set(id, mob);
  fieldFor(world).set(id, { mob, spec, defenderKey });
  paintHex(world, mob.hexKey, now);
  return mob;
}

/**
 * ensureMobOnHex — the §1 contested-hex defender hook: return the mob standing on
 * `key` (a fight needs a defender NOW), materializing one when the roam field left
 * the hex empty. Deterministic per (seed, hex). Combat stamps it into contestedMobId.
 */
export function ensureMobOnHex(world: World, key: string, now: number): Mob {
  const standing = [...world.mobs.values()]
    .filter((m) => m.hexKey === key && m.hp > 0)
    .sort((a, b) => (a.id < b.id ? -1 : 1));
  if (standing.length > 0) return standing[0];
  const id = `mobd:${key}`;
  const existing = world.mobs.get(id);
  if (existing) return existing;
  const qr = parseHexKey(key) ?? { q: 0, r: 0 };
  const h = hashSeed(world.seed, 'mob-defender', qr.q, qr.r);
  const rng = mulberry32(h);
  const speciesId: MobSpeciesId = rng.chance(MOB_TYRANT_P) ? 'grumbleshroom' : 'gloomling';
  const c = hexCenter(qr.q, qr.r);
  return spawnCell(world, id, { speciesId, anchor: { x: c.x, y: c.y }, seed: h }, now, key);
}

/**
 * stepMobs — the per-tick field pass:
 *   1. self-heal: a cell whose mob was killed/removed frees up (respawn cooldown for
 *      roamers, gone-for-good for defenders whose contest was settled);
 *   2. despawn: unengaged roamers with no established player in range dissipate
 *      (no cooldown — the seed re-derives them on return);
 *   3. roam: unengaged roamers follow their lissajous, painting entered hexes GLOOM;
 *   4. materialize: seeded cells near established players spawn their mob.
 */
export function stepMobs(world: World, _dtMs: number, now: number): void {
  const field = fieldFor(world);
  const cd = cooldownFor(world);

  for (const [id, cell] of [...field.entries()].sort(([a], [b]) => (a < b ? -1 : 1))) {
    const live = world.mobs.get(id);
    if (live !== cell.mob || cell.mob.hp <= 0) {
      field.delete(id);
      world.mobs.delete(id);
      if (cell.defenderKey === null) cd.set(id, now + MOB_RESPAWN_MS);
      continue;
    }
    if (cell.mob.engagedBy.length > 0) continue; // combat.ts steers an engaged mob
    if (cell.defenderKey !== null) {
      // A defender stands until its contest marker is gone (fight settled elsewhere).
      if (world.hexes.get(cell.defenderKey)?.contestedMobId !== cell.mob.id) {
        field.delete(id);
        world.mobs.delete(id);
      }
      continue;
    }
    if (!anyEstablishedWithin(world, cell.mob.pos, MOB_DESPAWN_RADIUS_M)) {
      field.delete(id);
      world.mobs.delete(id);
      continue;
    }
    cell.mob.pos = mobRoamPos(cell.spec, now);
    const key = hexKeyAt(cell.mob.pos.x, cell.mob.pos.y);
    if (key !== cell.mob.hexKey) {
      cell.mob.hexKey = key;
      paintHex(world, key, now);
    }
  }

  const players = [...world.players.values()].sort((a, b) => (a.id < b.id ? -1 : 1));
  for (const player of players) {
    if (!established(player)) continue;
    for (const key of hexKeysWithin(player.pos, MOB_FIELD_RADIUS_M)) {
      const id = `mob:${key}`;
      if (field.has(id)) continue;
      if (now < (cd.get(id) ?? 0)) continue;
      const qr = parseHexKey(key);
      if (!qr) continue;
      const hs = world.hexes.get(key);
      if (hs?.owner === 'players') continue;
      const spec = mobFieldSpec(world.seed, qr.q, qr.r, hs?.owner === 'gloom');
      if (!spec) continue;
      spawnCell(world, id, spec, now, null);
    }
  }
}

registerTicker('mobs', stepMobs);
