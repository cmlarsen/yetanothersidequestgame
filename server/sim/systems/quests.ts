// sim/systems/quests.ts — §10 the quest board: dailies + the territory quest + the
// one story chain. PURE, CLOCK-INJECTED. Progress feeds are exported hooks the
// combat/territory flows call (recordKill, recordClaim); the walk daily reads the
// §14 pedometer counter directly so it can never drift from the GPS stream. The
// daily rollover itself is world-core (world.stepDailyReset resets daily-tab
// progress + stepsToday at the persisted dailyResetAt stamp).
// Validation lives in sim/commands_economy.ts; claimQuest assumes gates passed.

import type { Player, QuestProgress, World } from '../../shared/entities.js';
import type { ServerMsg } from '../../shared/protocol.js';
import { OP } from '../../shared/protocol.js';
import type { MobSpeciesId, QuestId } from '../../shared/catalog.js';
import { LOOT_POOL, questDef } from '../../shared/catalog.js';
import { CHEST_RARITY_WEIGHTS } from '../../shared/tuning.js';
import type { Rng } from '../../shared/rng.js';
import { buildInventoryUpdate } from '../world.js';
import { grantGold } from './territory.js';
import { parseFrontId, frontName } from './fronts.js';
import { grantItem, pickWeightedRarity } from './shop.js';

/** Catalog quests reference fronts by name slug ('elm_st' ⇢ the seeded front named
 * "Elm St") until real map data gives fronts stable ids. */
export function frontSlug(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

function frontNameOf(world: World, frontId: string): string {
  const front = world.fronts.get(frontId);
  if (front) return front.name;
  const cell = parseFrontId(frontId);
  return cell ? frontName(world.seed, cell.cx, cell.cy) : frontId;
}

/** Progress as the board shows it: the walk daily mirrors the live pedometer
 * counter; everything else uses the stored counter. */
export function effectiveProgress(player: Player, qp: QuestProgress): number {
  const def = questDef(qp.questId);
  if (!def) return qp.progress;
  if (qp.questId === 'daily_walk') return Math.min(def.target, player.stepsToday);
  return qp.progress;
}

/** Flip any completed-but-unflagged quests to claimable (COLLECT state on the board). */
export function refreshQuestStates(player: Player): void {
  for (const qp of Object.values(player.quests)) {
    const def = questDef(qp.questId);
    if (!def || qp.state !== 'active') continue;
    if (effectiveProgress(player, qp) >= def.target) qp.state = 'claimable';
  }
}

function bump(qp: QuestProgress, target: number, amount: number): void {
  qp.progress = Math.min(target, qp.progress + amount);
  if (qp.progress >= target) qp.state = 'claimable';
}

/**
 * recordKill — combat-victory hook. Feeds the defeat daily (Gloomlings only —
 * a Turf Tyrant isn't a Gloomling) and the story chain's named-boss objective.
 */
export function recordKill(
  world: World,
  player: Player,
  speciesId: MobSpeciesId,
  isTyrant: boolean,
  now: number,
): void {
  for (const qp of Object.values(player.quests)) {
    if (qp.state !== 'active') continue;
    const def = questDef(qp.questId);
    if (!def) continue;
    if (qp.questId === 'daily_defeat' && !isTyrant) bump(qp, def.target, 1);
    if (qp.questId === 'story_grumble_park' && speciesId === 'grumbleshroom') {
      bump(qp, def.target, 1);
    }
  }
  player.updatedAt = now;
}

/** recordClaim — hex-claim hook: feeds territory quests whose catalog frontId
 * matches the claimed front's name slug. */
export function recordClaim(world: World, player: Player, frontId: string, now: number): void {
  const slug = frontSlug(frontNameOf(world, frontId));
  for (const qp of Object.values(player.quests)) {
    if (qp.state !== 'active') continue;
    const def = questDef(qp.questId);
    if (!def || def.tab !== 'territory' || def.frontId !== slug) continue;
    bump(qp, def.target, 1);
  }
  player.updatedAt = now;
}

/** §10 "in one run": a fresh run zeroes unfinished territory progress (a banked
 * claimable stays claimable). Called from the run-start flow. */
export function resetRunQuests(player: Player): void {
  for (const qp of Object.values(player.quests)) {
    if (qp.state !== 'active') continue;
    if (questDef(qp.questId)?.tab !== 'territory') continue;
    qp.progress = 0;
  }
}

/**
 * acceptStoryQuest — §10 story chains start at the NPC, one active chain at a
 * time. Returns false (no mutation) when already accepted or another chain is
 * underway.
 */
export function acceptStoryQuest(world: World, player: Player, questId: QuestId, now: number): boolean {
  const def = questDef(questId);
  if (!def || def.tab !== 'story') return false;
  if (player.quests[questId]) return false;
  for (const qp of Object.values(player.quests)) {
    if (questDef(qp.questId)?.tab === 'story' && qp.state !== 'done') return false;
  }
  player.quests[questId] = { questId, progress: 0, state: 'active' };
  player.updatedAt = now;
  return true;
}

/**
 * claimQuest — pay out a claimable quest at the board: reward gold (through the
 * canonical grant so run counters + beats stay consistent), plus a rarity-rolled
 * item for story rewards ("300 gold + item"). Caller has verified claimable.
 */
export function claimQuest(
  world: World,
  player: Player,
  questId: string,
  deps: { now: number; rng: Rng; genId: (kind: string) => string },
): ServerMsg[] {
  const def = questDef(questId)!;
  const qp = player.quests[questId];
  qp.state = 'done';
  grantGold(world, player, def.rewardGold, deps.now, 'quest');
  const frames: ServerMsg[] = [];
  if (def.rewardItem) {
    const rarity = pickWeightedRarity(deps.rng, CHEST_RARITY_WEIGHTS);
    const itemId = deps.rng.pick(LOOT_POOL[rarity]);
    grantItem(player, itemId, deps.genId('item'));
    frames.push({
      op: OP.LOOT_RESULT,
      t: deps.now,
      sourceId: questId,
      items: [{ itemId, rarity }],
      gold: def.rewardGold,
      xp: 0,
    });
  }
  frames.push(buildInventoryUpdate(player, deps.now));
  return frames;
}
