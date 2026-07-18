// sim/systems/territory.ts — hex ownership (GAME-RULES §1), run/death consequences
// (§2/§5), and the XP entry point (§7). PURE, CLOCK-INJECTED, deterministic.
//
// setHexOwner is THE flip primitive: every ownership change in the whole sim goes
// through it (claim-on-enter here, gloom capture in gloom.ts, combat victories via
// claimHexForPlayer), so the per-front counters in fronts.ts stay exact and every
// flip emits its outbox beat exactly once.
//
// Claim-on-enter shape ported from SideQuestAppV2 server/sim/systems/land.ts (the
// per-player last-hex memo; only hex-BOUNDARY crossings do work), reshaped onto the
// YAS ownership model: one shared player side, contested gloom hexes, fronts.

import type { GoldDrop, HexState, Player, RunState, World } from '../../shared/entities.js';
import type { DeathMsg, GameEvent, RunSummaryMsg } from '../../shared/protocol.js';
import { OP, OWNER_GLOOM, OWNER_PLAYERS } from '../../shared/protocol.js';
import { hexCenter, hexKey, hexKeyAt, hexNeighbors, parseHexKey } from '../../shared/hexgrid.js';
import { within } from '../../shared/geo.js';
import {
  CAPE_UNLOCK_LEVEL,
  DEATH_CONTESTED_HEX_LOSS_CAP,
  DROPPED_GOLD_PERSIST_HOURS,
  DROPPED_GOLD_RECOVER_RADIUS_M,
  FRONT_COMPLETION_GOLD,
  LEVEL_UP_ATK,
  LEVEL_UP_DEF,
  LEVEL_UP_HP,
  NEW_AREA_XP,
  POCKET_BLIZZARD_UNLOCK_LEVEL,
  REVIVE_COUNTDOWN_SEC,
  deathGoldDrop,
  xpForLevel,
} from '../../shared/tuning.js';
import { pushEvent, pushGameEvents } from './outbox.js';
import { bumpFrontCount, ensureFront, frontCounts, frontIdAt, frontPcts, frontView } from './fronts.js';
import { clearMoveTarget, isSpeedPaused } from './movement.js';
// Circular at module level (quests → territory for grantGold) — safe: both sides
// only export hoisted function declarations resolved at call time.
import { recordClaim } from './quests.js';

const HOUR_MS = 3_600_000;

// ---------------------------------------------------------------------------
// Cross-system hooks. The combat / chest agents register these in their own
// modules; absent hooks degrade gracefully (contested hexes wait, no chest spawns,
// RUN_END is never "early"). Registries are module-global like the command registry.
// ---------------------------------------------------------------------------

export type ContestHandler = (world: World, player: Player, hexKey: string, now: number) => void;
export type ChestSpawner = (world: World, frontId: string, hexKey: string, now: number) => void;
export type CombatProbe = (world: World, player: Player) => boolean;

let contestHandler: ContestHandler | null = null;
let chestSpawner: ChestSpawner | null = null;
let combatProbe: CombatProbe | null = null;

/** Combat system: engage the mob defending a freshly contested gloom hex. */
export function registerContestHandler(fn: ContestHandler | null): void {
  contestHandler = fn;
}
/** Chest system: spawn the §1 front-completion Grumble Chest. */
export function registerChestSpawner(fn: ChestSpawner | null): void {
  chestSpawner = fn;
}
/** Combat system: is this player mid-fight? (RUN_END while true = §2 early retreat.) */
export function registerCombatProbe(fn: CombatProbe | null): void {
  combatProbe = fn;
}

export function isInCombat(world: World, player: Player): boolean {
  return combatProbe ? combatProbe(world, player) : false;
}

// ---------------------------------------------------------------------------
// The flip primitive.
// ---------------------------------------------------------------------------

export function hexStateAt(world: World, key: string): HexState | undefined {
  return world.hexes.get(key);
}

/**
 * setHexOwner — flip one hex, maintaining the per-front counters and emitting the
 * claim beat. Idempotent on a same-owner call (no event). Clears any contested
 * marker (a flip settles the contest). `by` credits front completion gold.
 */
export function setHexOwner(
  world: World,
  key: string,
  owner: 'players' | 'gloom',
  now: number,
  by?: Player,
): HexState {
  const qr = parseHexKey(key);
  const frontId = qr ? frontIdAt(qr.q, qr.r) : 'f0,0';
  const front = ensureFront(world, frontId);
  let hs = world.hexes.get(key);
  if (hs && hs.owner === owner) return hs;
  const prev = hs?.owner;
  if (hs) {
    hs.owner = owner;
    hs.lastChangedAt = now;
    delete hs.contestedMobId;
  } else {
    hs = { owner, frontId, lastChangedAt: now };
    world.hexes.set(key, hs);
  }
  if (prev) bumpFrontCount(world, frontId, prev, -1);
  bumpFrontCount(world, frontId, owner, +1);
  pushGameEvents(world, 'all', now, [
    { k: 'claim', hexKey: key, o: owner === 'players' ? OWNER_PLAYERS : OWNER_GLOOM, frontId },
  ]);
  if (owner === 'players' && frontCounts(world, frontId).players === front.sizeHexes) {
    completeFront(world, frontId, key, now, by);
  }
  return hs;
}

/** §1 front completion: bonus gold + Grumble Chest request + pressure rest. */
function completeFront(world: World, frontId: string, atHexKey: string, now: number, by?: Player): void {
  const front = ensureFront(world, frontId);
  front.completedAt = now;
  front.gloomAccum = 0;
  const events: GameEvent[] = [{ k: 'front_complete', frontId, gold: FRONT_COMPLETION_GOLD }];
  pushGameEvents(world, 'all', now, events);
  pushEvent(world, {
    to: 'all',
    msg: { op: OP.FRONT_UPDATE, t: now, front: frontView(world, frontId), completed: true },
  });
  if (by) {
    grantGold(world, by, FRONT_COMPLETION_GOLD, now, 'front_complete');
  }
  chestSpawner?.(world, frontId, atHexKey, now);
}

// ---------------------------------------------------------------------------
// Rewards — the canonical XP/gold entry points (combat + economy systems reuse
// these so run counters, level-ups, and event beats stay consistent).
// ---------------------------------------------------------------------------

/** §7 grant XP, processing level-ups (stat bumps + LEVEL_UP frames + skill unlocks). */
export function grantXp(world: World, player: Player, amount: number, now: number, reason?: string): void {
  if (amount <= 0) return;
  player.xp += amount;
  if (player.run) player.run.xpEarned += amount;
  const ev: GameEvent = reason ? { k: 'xp', amount, reason } : { k: 'xp', amount };
  pushGameEvents(world, player.id, now, [ev]);
  while (player.xp >= xpForLevel(player.level)) {
    player.xp -= xpForLevel(player.level);
    player.level += 1;
    player.maxHp += LEVEL_UP_HP;
    player.hp += LEVEL_UP_HP;
    const unlocks: string[] = [];
    if (player.level === POCKET_BLIZZARD_UNLOCK_LEVEL) unlocks.push('pocket_blizzard');
    if (player.level === CAPE_UNLOCK_LEVEL) unlocks.push('cape_slot');
    pushEvent(world, {
      to: player.id,
      msg: {
        op: OP.LEVEL_UP,
        t: now,
        level: player.level,
        atk: LEVEL_UP_ATK,
        def: LEVEL_UP_DEF,
        hp: LEVEL_UP_HP,
        unlocks,
      },
    });
  }
  player.updatedAt = now;
}

/** Grant gold, keeping the §2 run counter in step. */
export function grantGold(world: World, player: Player, amount: number, now: number, reason?: string): void {
  if (amount <= 0) return;
  player.gold += amount;
  if (player.run) player.run.goldEarned += amount;
  const ev: GameEvent = reason ? { k: 'gold', amount, reason } : { k: 'gold', amount };
  pushGameEvents(world, player.id, now, [ev]);
  player.updatedAt = now;
}

// ---------------------------------------------------------------------------
// Claiming (§1) — the per-tick claim-on-enter pass + the combat-victory claim.
// ---------------------------------------------------------------------------

// Per-player memo of the last processed hex — only boundary crossings do work.
// Deliberately NOT set while claiming is paused (no run / speed-paused), so the hex
// you stop in gets claimed on the first eligible tick. Keyed by identity: never
// persisted, never leaks across worlds.
const lastHexByPlayer = new WeakMap<Player, string>();

/**
 * claimHexForPlayer — claim one hex for the player side, crediting the claimer's
 * run counters (and lazily recording the §2 run-summary pct baseline for the
 * front). `contested: true` marks a combat-won gloom hex (the §5 death-loss pool).
 * Also anchors homeHex on the very first claim (DESIGN: home = first claimed hex).
 */
export function claimHexForPlayer(
  world: World,
  player: Player,
  key: string,
  now: number,
  opts: { contested?: boolean } = {},
): HexState {
  const qr = parseHexKey(key);
  const frontId = qr ? frontIdAt(qr.q, qr.r) : 'f0,0';
  const run = player.run;
  if (run && !(frontId in run.frontPctStart)) {
    run.frontPctStart[frontId] = frontPcts(world, frontId).pctPlayer;
  }
  const hs = setHexOwner(world, key, 'players', now, player);
  if (run) {
    run.hexesClaimed.push(key);
    if (opts.contested) run.contestedClaimed.push(key);
  }
  recordClaim(world, player, frontId, now); // §10 territory-quest feed
  if (player.homeHex === '') player.homeHex = key;
  player.updatedAt = now;
  return hs;
}

/** Is any of the hex's 6 neighbours player-owned? (the §1 contested precondition) */
export function adjacentToPlayerTerritory(world: World, q: number, r: number): boolean {
  for (const n of hexNeighbors(q, r)) {
    if (world.hexes.get(hexKey(n.q, n.r))?.owner === 'players') return true;
  }
  return false;
}

/**
 * stepTerritory — the per-tick territory pass:
 *   1. downed players whose revive window lapsed auto-respawn at home (§5);
 *   2. claim-on-enter for online, alive, in-run, not-speed-paused players — neutral
 *      hexes claim instantly; a gloom hex adjacent to player territory becomes
 *      CONTESTED (outbox beat + combat hook); first visit to a front pays NEW_AREA_XP;
 *   3. dropped-gold pickup (§2/§5: owner within 10 m) + expiry cull.
 */
export function stepTerritory(world: World, _dtMs: number, now: number): void {
  for (const player of world.players.values()) {
    if (player.lifeState === 'downed') {
      if (player.death && now >= player.death.reviveDeadline) respawnAtHome(world, player, now);
      continue;
    }
    if (player.connId === null) continue;
    if (!player.run || isSpeedPaused(player)) continue;
    const key = hexKeyAt(player.pos.x, player.pos.y);
    if (lastHexByPlayer.get(player) === key) continue;
    lastHexByPlayer.set(player, key);
    enterHex(world, player, key, now);
  }

  for (const drop of [...world.goldDrops.values()]) {
    if (now >= drop.expiresAt) {
      world.goldDrops.delete(drop.id);
      continue;
    }
    const owner = world.players.get(drop.ownerId);
    if (!owner || owner.connId === null || owner.lifeState !== 'alive') continue;
    if (within(owner.pos, drop.pos, DROPPED_GOLD_RECOVER_RADIUS_M)) {
      world.goldDrops.delete(drop.id);
      owner.gold += drop.gold; // recovered, not "earned this run" — no run counter
      owner.updatedAt = now;
      pushGameEvents(world, owner.id, now, [{ k: 'gold_pickup', id: drop.id, gold: drop.gold }]);
    }
  }
}

function enterHex(world: World, player: Player, key: string, now: number): void {
  const qr = parseHexKey(key);
  if (!qr) return;
  const frontId = frontIdAt(qr.q, qr.r);
  const front = ensureFront(world, frontId);
  if (!player.areasSeen.includes(frontId)) {
    player.areasSeen.push(frontId);
    pushGameEvents(world, player.id, now, [
      { k: 'area', frontId, name: front.name, xp: NEW_AREA_XP },
    ]);
    grantXp(world, player, NEW_AREA_XP, now, 'new_area');
  }
  const hs = world.hexes.get(key);
  if (!hs) {
    claimHexForPlayer(world, player, key, now);
    return;
  }
  if (hs.owner === 'players') return;
  // Gloom hex. Adjacent to player territory → CONTESTED: the hex holds until the
  // fight settles it (combat flips it via claimHexForPlayer on victory). A gloom hex
  // deep in enemy ground does nothing here — the mob on it engages via §3 instead.
  if (hs.contestedMobId !== undefined) return; // already contested
  if (!adjacentToPlayerTerritory(world, qr.q, qr.r)) return;
  hs.contestedMobId = ''; // pending engagement; the combat hook stamps the real mob id
  pushGameEvents(world, 'all', now, [{ k: 'contest', hexKey: key, mobId: '' }]);
  contestHandler?.(world, player, key, now);
}

// ---------------------------------------------------------------------------
// Death & revive (§5) + run end (§2).
// ---------------------------------------------------------------------------

/** §5 contested-hex penalty: the most recent contested-won hexes this run (cap 3)
 * flip back to gloom. Returns the lost keys. */
export function loseContestedHexes(world: World, player: Player, now: number): string[] {
  const pool = player.run?.contestedClaimed ?? [];
  const lost: string[] = [];
  for (let i = pool.length - 1; i >= 0 && lost.length < DEATH_CONTESTED_HEX_LOSS_CAP; i--) {
    const key = pool[i];
    if (world.hexes.get(key)?.owner !== 'players') continue;
    setHexOwner(world, key, 'gloom', now);
    lost.push(key);
  }
  return lost;
}

/** Mint the §2/§5 recoverable gold drop at the player's position. The id derives
 * from (player, tick) so tick-driven deaths need no injected id source. */
function mintGoldDrop(world: World, player: Player, gold: number, now: number, idHint?: string): GoldDrop {
  const drop: GoldDrop = {
    id: idHint ?? `gd:${player.id}:${world.tick}`,
    ownerId: player.id,
    pos: { x: player.pos.x, y: player.pos.y },
    hexKey: hexKeyAt(player.pos.x, player.pos.y),
    gold,
    droppedAt: now,
    expiresAt: now + DROPPED_GOLD_PERSIST_HOURS * HOUR_MS,
  };
  world.goldDrops.set(drop.id, drop);
  return drop;
}

/**
 * applyDeath — the §5 death flow, called by the combat system when HP hits 0 (and
 * by tests directly). Downs the player, applies the hex + gold penalties, ends the
 * active run, and pushes DEATH (+ RUN_SUMMARY) to the player via the outbox.
 */
export function applyDeath(world: World, player: Player, now: number): void {
  if (player.lifeState !== 'alive') return;
  player.lifeState = 'downed';
  const hexesLost = loseContestedHexes(world, player, now);
  const goldDropped = Math.min(player.gold, deathGoldDrop(player.gold));
  let goldDropId: string | null = null;
  if (goldDropped > 0) {
    player.gold -= goldDropped;
    goldDropId = mintGoldDrop(world, player, goldDropped, now).id;
  }
  player.death = {
    diedAt: now,
    at: { x: player.pos.x, y: player.pos.y },
    reviveDeadline: now + REVIVE_COUNTDOWN_SEC * 1000,
    goldDropId,
  };
  const hexesKept = Math.max(0, (player.run?.hexesClaimed.length ?? 0) - hexesLost.length);
  const death: DeathMsg = {
    op: OP.DEATH,
    t: now,
    diedAt: now,
    reviveDeadline: player.death.reviveDeadline,
    goldDropped,
    hexesLost,
    hexesKept,
  };
  pushEvent(world, { to: player.id, msg: death });
  const summary = endRun(world, player, now, { goldDropped });
  if (summary) pushEvent(world, { to: player.id, msg: summary });
  player.updatedAt = now;
}

/**
 * endRun — close the §2 run state machine and build the RUN_SUMMARY frame (callers
 * deliver it: RUN_END returns it synchronously, applyDeath pushes it). `early: true`
 * applies the §2 retreat rule: gold above the run-start bank drops on your last hex.
 * Returns null when no run is active.
 */
export function endRun(
  world: World,
  player: Player,
  now: number,
  opts: { early?: boolean; goldDropped?: number; dropIdHint?: string } = {},
): RunSummaryMsg | null {
  const run = player.run;
  if (!run) return null;
  let goldDropped = opts.goldDropped ?? 0;
  if (opts.early) {
    const excess = Math.max(0, player.gold - run.goldAtStart);
    if (excess > 0) {
      player.gold -= excess;
      mintGoldDrop(world, player, excess, now, opts.dropIdHint);
      goldDropped += excess;
    }
  }
  const frontDelta: Record<string, number> = {};
  for (const frontId of Object.keys(run.frontPctStart).sort()) {
    frontDelta[frontId] = frontPcts(world, frontId).pctPlayer - run.frontPctStart[frontId];
  }
  player.run = null;
  player.updatedAt = now;
  return {
    op: OP.RUN_SUMMARY,
    t: now,
    runId: run.runId,
    durationSec: Math.round((now - run.startedAt) / 1000),
    hexesClaimed: run.hexesClaimed.length,
    mobsDefeated: run.mobsDefeated,
    xp: run.xpEarned,
    gold: run.goldEarned,
    lootItemIds: run.lootItemIds,
    goldDropped,
    frontDelta,
  };
}

/** Begin a §2 run (the RUN_START handler owns validation). */
export function startRun(player: Player, runId: string, now: number): RunState {
  const run: RunState = {
    runId,
    startedAt: now,
    goldAtStart: player.gold,
    hexesClaimed: [],
    contestedClaimed: [],
    mobsDefeated: 0,
    xpEarned: 0,
    goldEarned: 0,
    lootItemIds: [],
    frontPctStart: {},
  };
  player.run = run;
  player.updatedAt = now;
  return run;
}

/** §5(b) RESPAWN AT HOME (also the auto path when the revive window lapses).
 * The next GPS fix snaps the pawn back to physical ground — that's GPS authority
 * working as intended, not a bug. */
export function respawnAtHome(world: World, player: Player, now: number): void {
  const home = player.homeHex ? parseHexKey(player.homeHex) : null;
  if (home) {
    const c = hexCenter(home.q, home.r);
    player.pos.x = c.x;
    player.pos.y = c.y;
  }
  player.hp = player.maxHp;
  player.lifeState = 'alive';
  player.death = null;
  clearMoveTarget(player);
  player.updatedAt = now;
}

/** §5(a) party revive: back up in place at full HP; penalties already paid at death. */
export function revivePlayer(world: World, target: Player, by: Player, now: number): void {
  target.lifeState = 'alive';
  target.hp = target.maxHp;
  target.death = null;
  target.updatedAt = now;
  pushGameEvents(world, 'all', now, [{ k: 'revive', playerId: target.id, by: by.id }]);
}
