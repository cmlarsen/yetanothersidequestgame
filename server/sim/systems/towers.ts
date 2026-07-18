// sim/systems/towers.ts — §8 the defense layer: build/repair/upgrade/salvage
// mechanics plus the pure tower-effect helpers the gloom & combat systems consume
// (gloom.ts keeps its own internal copies of the capture math today; these are the
// public API — keep the formulas in lock-step with gloom.captureCost/isFlipBlocked).
// PURE, CLOCK-INJECTED. Validation lives in sim/commands_economy.ts (one ERR frame,
// zero mutation); the mutators here assume every gate has already passed.

import type { Player, Tower, TargetPriority, World } from '../../shared/entities.js';
import type { TowerTypeId } from '../../shared/catalog.js';
import { TOWERS } from '../../shared/catalog.js';
import {
  BASTION_POST_RADIUS_HEXES,
  BONK_TURRET_DMG_PER_TICK,
  CHILL_BELL_SLOW_PCT,
  TOWER_PLACE_RADIUS_M,
  TOWER_REPAIR_COST,
  TOWER_UPGRADE_COST,
  TOWER_UPGRADE_DURABILITY_BONUS,
  TOWER_UPGRADE_EFFECT_PCT,
  towerDurabilityMax,
  towerSalvageRefund,
} from '../../shared/tuning.js';
import { HEX_ACROSS_M, hexCenter, hexDistance, parseHexKey } from '../../shared/hexgrid.js';
import { within } from '../../shared/geo.js';

/** Away-digest ring cap (matches the cap gloom.ts applies on its rubble entry). */
const TOWER_LOG_CAP = 20;

/** Append an away-digest line, keeping the ring capped (newest last). */
export function towerLog(tower: Tower, at: number, event: string): void {
  tower.log.push({ at, event });
  if (tower.log.length > TOWER_LOG_CAP) tower.log.splice(0, tower.log.length - TOWER_LOG_CAP);
}

/** A player's towers in stable id order (repair-all + cap checks iterate this). */
export function ownedTowers(world: World, ownerId: string): Tower[] {
  return [...world.towers.values()]
    .filter((t) => t.ownerId === ownerId)
    .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
}

/** The tower (standing or rubble) on a hex, via the hex's back-reference. */
export function towerAtHex(world: World, hexKey: string): Tower | undefined {
  const id = world.hexes.get(hexKey)?.towerId;
  return id !== undefined ? world.towers.get(id) : undefined;
}

/**
 * §8 "standing (≤10 m) on the hex": anywhere inside the hex passes (half-width
 * circle covers it), with TOWER_PLACE_RADIUS_M of GPS slack at the rim. A
 * neighbouring hex centre (60 m) stays safely outside the gate.
 */
export function isStandingOn(player: Player, hexKey: string): boolean {
  const qr = parseHexKey(hexKey);
  if (!qr) return false;
  return within(player.pos, hexCenter(qr.q, qr.r), HEX_ACROSS_M / 2 + TOWER_PLACE_RADIUS_M);
}

export function towerCost(type: TowerTypeId): number {
  return TOWERS[type].cost;
}

/** Build (or rebuild — caller removes the rubble first): debits materials, links
 * the hex, starts at LV1 / full durability / NEAREST priority. */
export function placeTower(
  world: World,
  player: Player,
  type: TowerTypeId,
  hexKey: string,
  deps: { now: number; genId: (kind: string) => string },
): Tower {
  player.materials -= towerCost(type);
  const tower: Tower = {
    id: deps.genId('tower'),
    ownerId: player.id,
    type,
    hexKey,
    level: 1,
    durability: towerDurabilityMax(1),
    targetPriority: 'nearest',
    isRubble: false,
    builtAt: deps.now,
    log: [],
  };
  towerLog(tower, deps.now, 'built');
  world.towers.set(tower.id, tower);
  const hs = world.hexes.get(hexKey);
  if (hs) hs.towerId = tower.id;
  player.updatedAt = deps.now;
  return tower;
}

/** Delete a tower record and unlink its hex (salvage + rubble-rebuild paths). */
export function removeTower(world: World, tower: Tower): void {
  world.towers.delete(tower.id);
  const hs = world.hexes.get(tower.hexKey);
  if (hs && hs.towerId === tower.id) delete hs.towerId;
}

/** §8 repair: TOWER_REPAIR_COST 🪵 back to full durability, from anywhere. */
export function repairTower(world: World, player: Player, tower: Tower, now: number): void {
  player.materials -= TOWER_REPAIR_COST;
  tower.durability = towerDurabilityMax(tower.level);
  towerLog(tower, now, 'repaired to full');
  player.updatedAt = now;
}

/** §8 upgrade: +1 level (+25% effect via towerEffectMultiplier), +25 durability
 * now and on the cap. */
export function upgradeTower(world: World, player: Player, tower: Tower, now: number): void {
  player.materials -= TOWER_UPGRADE_COST;
  tower.level += 1;
  tower.durability = Math.min(
    towerDurabilityMax(tower.level),
    tower.durability + TOWER_UPGRADE_DURABILITY_BONUS,
  );
  towerLog(tower, now, `upgraded to LV ${tower.level}`);
  player.updatedAt = now;
}

/** §8 salvage (~40% of base cost, works on rubble too): refund + remove. */
export function salvageTower(world: World, player: Player, tower: Tower, now: number): number {
  const refund = towerSalvageRefund(towerCost(tower.type));
  player.materials += refund;
  removeTower(world, tower);
  player.updatedAt = now;
  return refund;
}

/** Repair every damaged standing tower (id order) while materials last. Returns
 * how many were repaired. */
export function repairAllTowers(world: World, player: Player, now: number): number {
  let repaired = 0;
  for (const tower of ownedTowers(world, player.id)) {
    if (tower.isRubble || tower.durability >= towerDurabilityMax(tower.level)) continue;
    if (player.materials < TOWER_REPAIR_COST) break;
    repairTower(world, player, tower, now);
    repaired++;
  }
  return repaired;
}

export function retargetTower(tower: Tower, priority: TargetPriority): void {
  tower.targetPriority = priority;
}

// ---------------------------------------------------------------------------
// Pure effect reads — what a hex feels from the standing towers around it.
// ---------------------------------------------------------------------------

/** §8 "+25% effect per level" scalar. */
export function towerEffectMultiplier(level: number): number {
  return 1 + (TOWER_UPGRADE_EFFECT_PCT / 100) * (level - 1);
}

function towersCovering(world: World, q: number, r: number, type: TowerTypeId): Tower[] {
  const out: Tower[] = [];
  for (const t of world.towers.values()) {
    if (t.type !== type || t.isRubble) continue;
    const tq = parseHexKey(t.hexKey);
    if (tq && hexDistance(q, r, tq.q, tq.r) <= TOWERS[type].radiusHexes) out.push(t);
  }
  return out;
}

/** Strongest Chill Bell slow on a hex, %, capped at 90 (mirror of gloom.captureCost). */
export function chillSlowPctAt(world: World, q: number, r: number): number {
  let slowPct = 0;
  for (const t of towersCovering(world, q, r, 'chill_bell')) {
    slowPct = Math.max(slowPct, Math.min(90, CHILL_BELL_SLOW_PCT * towerEffectMultiplier(t.level)));
  }
  return slowPct;
}

/** Σ standing Bonk Turret damage covering a hex, per tick (combat/gloom consumer). */
export function bonkDamagePerTickAt(world: World, q: number, r: number): number {
  let dmg = 0;
  for (const t of towersCovering(world, q, r, 'bonk_turret')) {
    dmg += Math.round(BONK_TURRET_DMG_PER_TICK * towerEffectMultiplier(t.level));
  }
  return dmg;
}

/** §8 no-flip: any standing tower holds its own hex; a standing Bastion Post holds
 * radius 1 around it (mirror of gloom.isFlipBlocked). */
export function flipBlockedByTower(world: World, q: number, r: number): boolean {
  const hexTowerId = world.hexes.get(`${q},${r}`)?.towerId;
  if (hexTowerId !== undefined) {
    const t = world.towers.get(hexTowerId);
    if (t && !t.isRubble) return true;
  }
  for (const t of world.towers.values()) {
    if (t.type !== 'bastion_post' || t.isRubble) continue;
    const tq = parseHexKey(t.hexKey);
    if (tq && hexDistance(q, r, tq.q, tq.r) <= BASTION_POST_RADIUS_HEXES) return true;
  }
  return false;
}

/** The combined tower influence on one hex — the single read gloom/combat can call. */
export function towerEffectAt(
  world: World,
  q: number,
  r: number,
): { dmgPerTick: number; slowPct: number; flipBlocked: boolean } {
  return {
    dmgPerTick: bonkDamagePerTickAt(world, q, r),
    slowPct: chillSlowPctAt(world, q, r),
    flipBlocked: flipBlockedByTower(world, q, r),
  };
}
