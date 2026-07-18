// sim/systems/minions.ts — §9 the couch economy: wall-clock jobs that run with the
// app closed. PURE, CLOCK-INJECTED: a job is just (startedAt, endsAt) stamps against
// the injected `now`, so jobs survive restarts for free (minions are persisted).
// The ticker only announces completions; rewards resolve at MINION_COLLECT time via
// the per-command seeded rng (deterministic per world seed + command history).
// Validation lives in sim/commands_economy.ts; mutators assume gates passed.

import type { Minion, Player, World } from '../../shared/entities.js';
import type { MinionReportMsg } from '../../shared/protocol.js';
import { OP } from '../../shared/protocol.js';
import type { JobId, MinionDefId } from '../../shared/catalog.js';
import { JOBS, MINIONS } from '../../shared/catalog.js';
import {
  GATHER_LUMBER_YIELD_MAX,
  GATHER_LUMBER_YIELD_MIN,
  MINION_HEAL_COST,
  MINION_HIRE_COST,
  MINION_ROSTER_START,
  SCAVENGE_YIELD_BONUS_PCT,
} from '../../shared/tuning.js';
import type { Rng } from '../../shared/rng.js';
import { registerTicker } from '../world.js';
import { ensureFront, frontCounts } from './fronts.js';
import { pushGameEvents } from './outbox.js';
import { grantItem } from './shop.js';

const HOUR_MS = 3_600_000;
const MINUTE_MS = 60_000;

/** §9: the 2 starters + exactly one 200 g merchant hire slot. */
export const MINION_ROSTER_MAX = MINION_ROSTER_START + 1;

/** §9 "chance of tower salvage part" — the pct is unspecified in GAME-RULES;
 * local default until tuning owns it. */
export const SCAVENGE_SALVAGE_PART_PCT = 25;
export const SCAVENGE_SALVAGE_ITEM_ID = 'turret_gearbox';

/** Scout intel push-ETA window (h) — display intel only, seeded per collect. */
export const SCOUT_PUSH_ETA_MIN_H = 1;
export const SCOUT_PUSH_ETA_MAX_H = 6;

export function rosterOf(world: World, ownerId: string): Minion[] {
  return world.minions.get(ownerId) ?? [];
}

export function findMinion(world: World, ownerId: string, minionId: string): Minion | undefined {
  return rosterOf(world, ownerId).find((m) => m.id === minionId);
}

export function jobDurationMs(jobId: JobId): number {
  return JOBS[jobId].durationMin * MINUTE_MS;
}

/** Put an idle minion on a job (§9 one per minion; scout carries its front). */
export function sendMinion(minion: Minion, jobId: JobId, frontId: string | undefined, now: number): void {
  minion.job = {
    jobId,
    ...(frontId !== undefined ? { frontId } : {}),
    startedAt: now,
    endsAt: now + jobDurationMs(jobId),
    riskPct: JOBS[jobId].injuryPct,
  };
  minion.state = 'on_job';
}

export function jobComplete(minion: Minion, now: number): boolean {
  return minion.state === 'on_job' && minion.job !== null && now >= minion.job.endsAt;
}

/** Scavenge rumor: a seeded pick among fronts with any gloom foothold (the report
 * deep-links "trouble brewing on <front>"). */
function rumorFront(world: World, rng: Rng): string | undefined {
  const gloomy = [...world.fronts.keys()]
    .filter((id) => frontCounts(world, id).gloom > 0)
    .sort();
  return gloomy.length > 0 ? rng.pick(gloomy) : undefined;
}

/**
 * resolveJob — settle a completed job into rewards + the §9 report modal frame:
 * haul, salvage-part chance, injury roll, return quote, rumor deep-link. Caller
 * (MINION_COLLECT) has verified the job is complete.
 */
export function resolveJob(
  world: World,
  player: Player,
  minion: Minion,
  deps: { now: number; rng: Rng; genId: (kind: string) => string },
): MinionReportMsg {
  const job = minion.job!;
  let materials = 0;
  let salvageItemId: string | undefined;
  let rumorFrontId: string | undefined;

  if (job.jobId === 'gather_lumber') {
    materials = deps.rng.int(GATHER_LUMBER_YIELD_MIN, GATHER_LUMBER_YIELD_MAX);
  } else if (job.jobId === 'scavenge') {
    const base = deps.rng.int(GATHER_LUMBER_YIELD_MIN, GATHER_LUMBER_YIELD_MAX);
    materials = Math.round(base * (1 + SCAVENGE_YIELD_BONUS_PCT / 100));
    if (deps.rng.chance(SCAVENGE_SALVAGE_PART_PCT / 100)) {
      salvageItemId = SCAVENGE_SALVAGE_ITEM_ID;
      grantItem(player, salvageItemId, deps.genId('item'));
    }
    rumorFrontId = rumorFront(world, deps.rng);
  } else {
    // scout_front: no haul — the payoff is Defense-view intel on the chosen front.
    const frontId = job.frontId!;
    const front = ensureFront(world, frontId);
    front.scoutIntel = {
      pushEta: deps.now + deps.rng.int(SCOUT_PUSH_ETA_MIN_H, SCOUT_PUSH_ETA_MAX_H) * HOUR_MS,
      scoutedAt: deps.now,
    };
    rumorFrontId = frontId;
  }

  const injured = job.riskPct > 0 && deps.rng.chance(job.riskPct / 100);
  player.materials += materials;
  minion.job = null;
  minion.state = injured ? 'injured' : 'idle';
  notifiedSet(world).delete(minion.id);
  player.updatedAt = deps.now;

  return {
    op: OP.MINION_REPORT,
    t: deps.now,
    minionId: minion.id,
    jobId: job.jobId,
    materials,
    ...(salvageItemId !== undefined ? { salvageItemId } : {}),
    injured,
    quote: deps.rng.pick(MINIONS[minion.defId].quotes),
    ...(rumorFrontId !== undefined ? { rumorFrontId } : {}),
  };
}

/** §9 hire the 3rd slot at the merchant: a hired minion reuses a catalog def. */
export function hireMinion(
  world: World,
  player: Player,
  deps: { now: number; rng: Rng; genId: (kind: string) => string },
): Minion {
  player.gold -= MINION_HIRE_COST;
  const defId = deps.rng.pick(Object.keys(MINIONS).sort() as MinionDefId[]);
  const minion: Minion = {
    id: deps.genId('minion'),
    ownerId: player.id,
    defId,
    name: MINIONS[defId].name,
    state: 'idle',
    job: null,
    hiredAt: deps.now,
  };
  const roster = world.minions.get(player.id) ?? [];
  roster.push(minion);
  world.minions.set(player.id, roster);
  player.updatedAt = deps.now;
  return minion;
}

/** §9 heal an injured minion: MINION_HEAL_COST gold, instant. */
export function healMinion(player: Player, minion: Minion, now: number): void {
  player.gold -= MINION_HEAL_COST;
  minion.state = 'idle';
  player.updatedAt = now;
}

// ---------------------------------------------------------------------------
// Ticker — announce each completion once (the §13 "minion job complete" beat).
// Edge state is a runtime memo (never persisted): a restart may re-announce an
// uncollected return, which is harmless.
// ---------------------------------------------------------------------------

const notified = new WeakMap<World, Set<string>>();

function notifiedSet(world: World): Set<string> {
  let s = notified.get(world);
  if (!s) {
    s = new Set();
    notified.set(world, s);
  }
  return s;
}

export function stepMinions(world: World, _dtMs: number, now: number): void {
  for (const [ownerId, roster] of world.minions) {
    for (const minion of roster) {
      if (!jobComplete(minion, now)) continue;
      const seen = notifiedSet(world);
      if (seen.has(minion.id)) continue;
      seen.add(minion.id);
      pushGameEvents(world, ownerId, now, [
        { k: 'notice', text: `${minion.name} returned — collect their report` },
      ]);
    }
  }
}

registerTicker('minions', stepMinions);
