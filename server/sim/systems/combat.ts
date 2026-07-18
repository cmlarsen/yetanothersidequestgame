// sim/systems/combat.ts — §3 real-time server-resolved combat. PURE, CLOCK-
// INJECTED, deterministic: crit/drop draws come off injected rngs, retaliation and
// cooldowns compare injected `now` against stamps. Engagement lives on the Mob
// (engagedBy — drop-in co-op shares kill credit); per-player block/reflect state and
// the contested-hex bookkeeping are WeakMap runtime maps keyed by World identity.
//
// The flee boundary IS the range gate (§3): mob hex + FLEE_BUFFER_HEXES. Walking
// past it (or tapping FLEE, or ending the run) disengages; standing inside it keeps
// the mob swinging on its cooldown while it chases within its leash.
//
// Death and territory consequences are NOT duplicated here: HP 0 routes into
// territory.applyDeath (penalties, DEATH frame, revive window), and victory flips
// hexes through territory.claimHexForPlayer — the single flip primitive.

import type { Mob, Player, World } from '../../shared/entities.js';
import type { GameEvent, LootItemWire, ServerMsg } from '../../shared/protocol.js';
import { OP } from '../../shared/protocol.js';
import type { Rng } from '../../shared/rng.js';
import { seededRng } from '../../shared/rng.js';
import { MOBS, itemDef, questDef } from '../../shared/catalog.js';
import type { MobSpeciesId, QuestId } from '../../shared/catalog.js';
import {
  FLEE_BUFFER_HEXES,
  MOB_MATERIALS_DROP_PCT,
  PARTY_JOIN_RADIUS_M,
  RESIST_MULTIPLIER,
  WEAK_MULTIPLIER,
} from '../../shared/tuning.js';
import { hexDistance, hexKeyAt, parseHexKey } from '../../shared/hexgrid.js';
import { distM, within } from '../../shared/geo.js';
import {
  registerTicker,
  buildInventoryUpdate,
  playerStats,
} from '../world.js';
import { err } from '../commands.js';
import {
  applyDeath,
  claimHexForPlayer,
  grantGold,
  grantXp,
  registerCombatProbe,
  registerContestHandler,
} from './territory.js';
import { pushEvent, pushGameEvents } from './outbox.js';
import { isSpeedPaused } from './movement.js';
import { ensureMobOnHex, mobGoldReward, mobSwingDmg, mobXpReward } from './mobs.js';
import { rollMobDrop } from './loot.js';
import { knockbackMultiplier } from './progression.js';

// Not GAME-RULES DEFAULTs (§3 gives no retaliation cadence) — local until promoted.
export const MOB_SWING_COOLDOWN_MS = 2500;
/** Grace before a freshly engaged mob's first swing (engage isn't an instant hit). */
export const MOB_FIRST_SWING_DELAY_MS = 1000;
export const MOB_CHASE_MPS = 1.5;
/** Chase leash from the mob's home anchor — it fights near its ground, never across the map. */
export const MOB_LEASH_M = 120;
export const CRIT_MULTIPLIER = 2;

// ---------------------------------------------------------------------------
// Runtime state (WeakMap by World identity — never persisted).
// ---------------------------------------------------------------------------

interface BlockState {
  blockUntil: number;
  reflectPct: number;
}

const blocks = new WeakMap<World, Map<string, BlockState>>();
const contestHexByMob = new WeakMap<World, Map<string, string>>();

function blockMap(world: World): Map<string, BlockState> {
  let m = blocks.get(world);
  if (!m) {
    m = new Map();
    blocks.set(world, m);
  }
  return m;
}

function contestMap(world: World): Map<string, string> {
  let m = contestHexByMob.get(world);
  if (!m) {
    m = new Map();
    contestHexByMob.set(world, m);
  }
  return m;
}

// ---------------------------------------------------------------------------
// Engagement.
// ---------------------------------------------------------------------------

export function engage(world: World, mob: Mob, player: Player, now: number): void {
  if (mob.engagedBy.includes(player.id)) return;
  if (mob.engagedBy.length === 0) {
    mob.swingReadyAt = Math.max(mob.swingReadyAt, now + MOB_FIRST_SWING_DELAY_MS);
  }
  mob.engagedBy.push(player.id);
  mob.engagedBy.sort();
}

export function disengagePlayer(world: World, player: Player): void {
  for (const mob of world.mobs.values()) {
    const i = mob.engagedBy.indexOf(player.id);
    if (i >= 0) mob.engagedBy.splice(i, 1);
  }
}

export function isEngaged(world: World, player: Player): boolean {
  for (const mob of world.mobs.values()) {
    if (mob.engagedBy.includes(player.id)) return true;
  }
  return false;
}

/** §3 the flee boundary: inside = mob's hex + FLEE_BUFFER_HEXES around it. */
export function inFleeBoundary(player: Player, mob: Mob): boolean {
  const p = parseHexKey(hexKeyAt(player.pos.x, player.pos.y));
  const m = parseHexKey(mob.hexKey);
  if (!p || !m) return false;
  return hexDistance(p.q, p.r, m.q, m.r) <= FLEE_BUFFER_HEXES;
}

/** §3 attack reach: the flee boundary, or §12 party drop-in (ally engaged + ≤50 m). */
function inAttackRange(world: World, player: Player, mob: Mob): boolean {
  if (inFleeBoundary(player, mob)) return true;
  if (player.partyId === null) return false;
  if (!within(player.pos, mob.pos, PARTY_JOIN_RADIUS_M)) return false;
  return mob.engagedBy.some((pid) => world.players.get(pid)?.partyId === player.partyId);
}

// ---------------------------------------------------------------------------
// Hotbar slot resolution (§3) — the ATTACK / USE_SLOT core.
// ---------------------------------------------------------------------------

type Acquired = { targets: Mob[] } | { fail: ServerMsg };

/** Primary target (named or nearest in range) + up to n−1 nearest extras. */
function acquireTargets(
  world: World,
  player: Player,
  mobId: string | undefined,
  n: number,
  now: number,
  refOp: number,
): Acquired {
  const inRange = [...world.mobs.values()]
    .filter((m) => m.hp > 0 && inAttackRange(world, player, m))
    .sort((a, b) => {
      const d = distM(player.pos, a.pos) - distM(player.pos, b.pos);
      return d !== 0 ? d : a.id < b.id ? -1 : 1;
    });
  let primary: Mob | undefined;
  if (mobId !== undefined) {
    const named = world.mobs.get(mobId);
    if (!named || named.hp <= 0) return { fail: err(now, 'NOT_FOUND', 'no such mob', refOp) };
    if (!inAttackRange(world, player, named)) {
      return { fail: err(now, 'OUT_OF_RANGE', 'move closer to attack', refOp) };
    }
    primary = named;
  } else {
    primary = inRange[0];
  }
  if (!primary) return { fail: err(now, 'OUT_OF_RANGE', 'no mob in range', refOp) };
  const targets = [primary, ...inRange.filter((m) => m !== primary)].slice(0, Math.max(1, n));
  return { targets };
}

/** One damage application: engage → affinity → crit → hp, hit beat, settle on kill.
 * Rng draw order (pinned by tests): one crit draw per target. */
function dealDamage(
  world: World,
  attacker: Player,
  mob: Mob,
  baseDmg: number,
  abilityTag: string | undefined,
  kbHexes: number | undefined,
  rng: Rng,
  now: number,
): void {
  engage(world, mob, attacker, now);
  const stats = playerStats(attacker);
  // affinity (§3): weak ×1.5 / resist ×0.5 by the ability tag vs the mob's tags
  const mult = affinityMult(mob.speciesId, abilityTag);
  const crit = rng.chance(stats.critPct / 100);
  const dmg = Math.max(1, Math.round((baseDmg + stats.atk) * mult * (crit ? CRIT_MULTIPLIER : 1)));
  mob.hp -= dmg;
  const ev: GameEvent = { k: 'hit', mobId: mob.id, by: attacker.id, dmg };
  if (crit) ev.crit = true;
  if (mult !== 1) ev.mult = mult;
  if (kbHexes !== undefined && kbHexes > 0) {
    ev.kb = Math.round(kbHexes * knockbackMultiplier(attacker) * 100) / 100;
  }
  pushGameEvents(world, 'all', now, [ev]);
  if (mob.hp <= 0) settleVictory(world, mob, attacker, now);
}

function affinityMult(speciesId: MobSpeciesId, abilityTag: string | undefined): number {
  if (abilityTag === undefined) return 1;
  const def = MOBS[speciesId];
  if ((def.weakTags as readonly string[]).includes(abilityTag)) return WEAK_MULTIPLIER;
  if ((def.resistTags as readonly string[]).includes(abilityTag)) return RESIST_MULTIPLIER;
  return 1;
}

export interface UseSlotCtx {
  now: number;
  rng: Rng;
  genId: (kind: string) => string;
}

/**
 * useSlot — resolve one hotbar slot press (ATTACK is slot 0 restricted to a
 * weapon; USE_SLOT is any slot). Weapons: no cooldown. Spells: readyAt stamp vs
 * now. Consumables: charge budget. All-or-nothing: every validation failure
 * returns one ERR frame before any mutation.
 */
export function useSlot(
  world: World,
  player: Player,
  slot: number,
  mobId: string | undefined,
  refOp: number,
  ctx: UseSlotCtx,
): ServerMsg[] {
  const now = ctx.now;
  const iid = player.hotbar[slot];
  if (!iid) return [err(now, 'ILLEGAL_STATE', `hotbar slot ${slot + 1} is empty`, refOp)];
  const inst = player.inventory.find((i) => i.iid === iid);
  if (!inst) return [err(now, 'ILLEGAL_STATE', 'equipped item is missing', refOp)];
  const def = itemDef(inst.itemId);
  if (!def) return [err(now, 'BAD_REQUEST', `unknown item '${inst.itemId}'`, refOp)];
  if (def.levelReq !== undefined && player.level < def.levelReq) {
    return [err(now, 'ILLEGAL_STATE', `locked until LV ${def.levelReq}`, refOp)];
  }

  if (def.slotType === 'consumable') {
    if (def.effect.healHp === undefined) {
      return [err(now, 'ILLEGAL_STATE', 'that item cannot be used', refOp)];
    }
    if ((inst.charges ?? 0) <= 0) return [err(now, 'ILLEGAL_STATE', 'no charges left', refOp)];
    inst.charges = (inst.charges ?? 0) - 1;
    player.hp = Math.min(player.maxHp, player.hp + def.effect.healHp);
    player.updatedAt = now;
    return [buildInventoryUpdate(player, now)];
  }

  if (def.slotType === 'spell') {
    if (player.slotReadyAt[slot] > now) {
      const secs = Math.ceil((player.slotReadyAt[slot] - now) / 1000);
      return [err(now, 'ON_COOLDOWN', `ready in ${secs}s`, refOp)];
    }
    let targets: Mob[] = [];
    if (def.effect.dmg !== undefined) {
      const got = acquireTargets(world, player, mobId, def.effect.targets ?? 1, now, refOp);
      if ('fail' in got) return [got.fail];
      targets = got.targets;
    }
    player.slotReadyAt[slot] = now + (def.effect.cooldownSec ?? 0) * 1000;
    if (def.effect.blockSec !== undefined) {
      blockMap(world).set(player.id, {
        blockUntil: now + def.effect.blockSec * 1000,
        reflectPct: def.effect.reflectPct ?? 0,
      });
    }
    for (const mob of targets) {
      dealDamage(world, player, mob, def.effect.dmg ?? 0, def.abilityTag, undefined, ctx.rng, now);
      if (def.effect.slowSec !== undefined && world.mobs.has(mob.id)) {
        mob.slowedUntil = Math.max(mob.slowedUntil, now + def.effect.slowSec * 1000);
      }
    }
    player.updatedAt = now;
    return [];
  }

  // weapon — no cooldown, single target, knockback flavor rides the hit beat
  const got = acquireTargets(world, player, mobId, 1, now, refOp);
  if ('fail' in got) return [got.fail];
  dealDamage(
    world,
    player,
    got.targets[0],
    def.effect.dmg ?? 0,
    def.abilityTag,
    def.effect.knockbackHexes,
    ctx.rng,
    now,
  );
  player.updatedAt = now;
  return [];
}

// ---------------------------------------------------------------------------
// Victory settlement (§3/§6): hex flips, shared kill credit, drops, quests.
// ---------------------------------------------------------------------------

/** Quest hooks for kills — keyed by id because the catalog's objective is display
 * copy, not a machine type (v1 has exactly these two defeat quests). */
function bumpDefeatQuests(player: Player, speciesId: MobSpeciesId): void {
  const ids: QuestId[] = speciesId === 'gloomling' ? ['daily_defeat'] : ['story_grumble_park'];
  for (const id of ids) {
    const qp = player.quests[id];
    const def = questDef(id);
    if (!qp || !def || qp.state !== 'active') continue;
    qp.progress = Math.min(def.target, qp.progress + 1);
    if (qp.progress >= def.target) qp.state = 'claimable';
  }
}

export function settleVictory(world: World, mob: Mob, killer: Player, now: number): void {
  world.mobs.delete(mob.id); // mobs.ts self-heals the field cell (respawn cooldown)
  const pids = new Set(mob.engagedBy);
  pids.add(killer.id);
  mob.engagedBy = [];
  pushGameEvents(world, 'all', now, [
    { k: 'kill', mobId: mob.id, by: killer.id, hexKey: mob.hexKey },
  ]);

  // Hex settlement: the mob's hex, plus the contested hex it was defending (they
  // can differ after a chase). Winner's side owns it (§1) — through the flip primitive.
  const keys = new Set<string>([mob.hexKey]);
  const contested = contestMap(world).get(mob.id);
  if (contested !== undefined) {
    keys.add(contested);
    contestMap(world).delete(mob.id);
  }
  for (const key of [...keys].sort()) {
    const hs = world.hexes.get(key);
    if (hs?.owner === 'players') continue;
    claimHexForPlayer(world, killer, key, now, { contested: hs?.owner === 'gloom' });
  }

  const xp = mobXpReward(mob);
  const gold = mobGoldReward(mob);
  for (const pid of [...pids].sort()) {
    const p = world.players.get(pid);
    if (!p || p.lifeState !== 'alive') continue;
    grantXp(world, p, xp, now, 'combat');
    grantGold(world, p, gold, now, 'combat');
    if (p.run) p.run.mobsDefeated += 1;
    bumpDefeatQuests(p, mob.speciesId);

    // Per-participant drop, seeded off (world seed, mob, player) so reconnects and
    // replays agree. Draw order: item gate/rarity/pick, then the §11 materials gate.
    const rng = seededRng(world.seed, 'mob-drop', mob.id, p.id);
    const items: LootItemWire[] = [];
    const roll = rollMobDrop(rng, mob.isTyrant);
    if (roll) {
      const rollDef = itemDef(roll.itemId);
      p.inventory.push({
        iid: `it:${mob.id}:${p.id}`,
        itemId: roll.itemId,
        isNew: true,
        ...(rollDef?.effect.charges !== undefined ? { charges: rollDef.effect.charges } : {}),
      });
      if (p.run) p.run.lootItemIds.push(roll.itemId);
      items.push({ itemId: roll.itemId, rarity: roll.rarity });
    }
    if (rng.chance(MOB_MATERIALS_DROP_PCT / 100)) {
      p.materials += 1;
      pushGameEvents(world, p.id, now, [{ k: 'notice', text: 'found 1 🪵 in the gloom' }]);
    }
    pushEvent(world, {
      to: p.id,
      msg: { op: OP.LOOT_RESULT, t: now, sourceId: mob.id, items, gold, xp },
    });
    if (items.length > 0) pushEvent(world, { to: p.id, msg: buildInventoryUpdate(p, now) });
    p.updatedAt = now;
  }
}

// ---------------------------------------------------------------------------
// The per-tick combat step: auto-engage, prune, chase, retaliate.
// ---------------------------------------------------------------------------

function eligibleFighter(p: Player): boolean {
  return p.connId !== null && p.lifeState === 'alive' && p.run !== null;
}

export function stepCombat(world: World, dtMs: number, now: number): void {
  // §3 "combat begins when the player enters a mob's hex" — auto-engage on entry.
  // §14: no engagement while speed-paused (driving guard).
  for (const p of [...world.players.values()].sort((a, b) => (a.id < b.id ? -1 : 1))) {
    if (!eligibleFighter(p)) continue;
    if (isSpeedPaused(p)) continue;
    const key = hexKeyAt(p.pos.x, p.pos.y);
    for (const mob of world.mobs.values()) {
      if (mob.hp > 0 && mob.hexKey === key) engage(world, mob, p, now);
    }
  }

  for (const mob of [...world.mobs.values()].sort((a, b) => (a.id < b.id ? -1 : 1))) {
    if (mob.engagedBy.length === 0) continue;

    // prune: offline/downed/run-over/fled participants drop out (§3 flee boundary)
    mob.engagedBy = mob.engagedBy.filter((pid) => {
      const p = world.players.get(pid);
      return p !== undefined && eligibleFighter(p) && inFleeBoundary(p, mob);
    });
    if (mob.engagedBy.length === 0) continue;

    const target = mob.engagedBy
      .map((pid) => world.players.get(pid))
      .filter((p): p is Player => p !== undefined)
      .sort((a, b) => {
        const d = distM(mob.pos, a.pos) - distM(mob.pos, b.pos);
        return d !== 0 ? d : a.id < b.id ? -1 : 1;
      })[0];
    if (!target) continue;

    // chase within leash (slow halves the pace)
    const slowed = now < mob.slowedUntil;
    const step = MOB_CHASE_MPS * (slowed ? 0.5 : 1) * (dtMs / 1000);
    const dx = target.pos.x - mob.pos.x;
    const dy = target.pos.y - mob.pos.y;
    const d = Math.hypot(dx, dy);
    if (d > 1) {
      const k = Math.min(1, step / d);
      const nx = mob.pos.x + dx * k;
      const ny = mob.pos.y + dy * k;
      if (Math.hypot(nx - mob.homePos.x, ny - mob.homePos.y) <= MOB_LEASH_M) {
        mob.pos.x = nx;
        mob.pos.y = ny;
        mob.hexKey = hexKeyAt(nx, ny); // no painting while fighting — roam paints
      }
    }

    // retaliation swing on cooldown (a slow defers the swing entirely)
    if (now < mob.swingReadyAt || now < mob.slowedUntil) continue;
    mob.swingReadyAt = now + MOB_SWING_COOLDOWN_MS;
    const raw = mobSwingDmg(mob);
    const block = blockMap(world).get(target.id);
    if (block && block.blockUntil > now) {
      // Turtle Up: all damage blocked, reflectPct returned to the attacker.
      const reflected = Math.round((raw * block.reflectPct) / 100);
      pushGameEvents(world, 'all', now, [
        { k: 'player_hit', playerId: target.id, by: mob.id, dmg: 0 },
      ]);
      if (reflected > 0) {
        mob.hp -= reflected;
        pushGameEvents(world, 'all', now, [
          { k: 'hit', mobId: mob.id, by: target.id, dmg: reflected },
        ]);
        if (mob.hp <= 0) settleVictory(world, mob, target, now);
      }
      continue;
    }
    const dealt = Math.max(1, raw - playerStats(target).def);
    target.hp -= dealt;
    target.updatedAt = now;
    pushGameEvents(world, 'all', now, [
      { k: 'player_hit', playerId: target.id, by: mob.id, dmg: dealt },
    ]);
    if (target.hp <= 0) {
      target.hp = 0;
      disengagePlayer(world, target);
      applyDeath(world, target, now); // §5 penalties + DEATH frame + revive window
    }
  }
}

// ---------------------------------------------------------------------------
// Registration: tick order slot, the territory contest hook, the RUN_END probe.
// ---------------------------------------------------------------------------

registerTicker('combat', stepCombat);

registerContestHandler((world, player, hexKey, now) => {
  const mob = ensureMobOnHex(world, hexKey, now);
  const hs = world.hexes.get(hexKey);
  if (hs) hs.contestedMobId = mob.id;
  contestMap(world).set(mob.id, hexKey);
  engage(world, mob, player, now);
});

registerCombatProbe((world, player) => isEngaged(world, player));
