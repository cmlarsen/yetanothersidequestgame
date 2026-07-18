// Quests (§10): board seeding, progress feeds (steps / kills / territory),
// QUEST_CLAIM states, the daily-reset boundary, and the story-chain stub.

import { describe, expect, it } from 'vitest';
import '../../sim/commands_economy.js';
import { SimHarness } from '../harness/sim-harness.js';
import type { Conn } from '../../sim/commands.js';
import { OP } from '../../shared/protocol.js';
import type { LootResultMsg, ServerMsg } from '../../shared/protocol.js';
import { QUESTS } from '../../shared/catalog.js';
import {
  DAILY_DEFEAT_COUNT,
  DAILY_DEFEAT_GOLD,
  DAILY_WALK_GOLD,
  DAILY_WALK_STEPS,
  TERRITORY_CLAIM_COUNT,
  TERRITORY_CLAIM_GOLD,
} from '../../shared/tuning.js';
import { frontName } from '../../sim/systems/fronts.js';
import {
  acceptStoryQuest,
  frontSlug,
  recordClaim,
  recordKill,
  resetRunQuests,
} from '../../sim/systems/quests.js';

const HOUR_MS = 3_600_000;
const DAY_MS = 24 * HOUR_MS;

function setup() {
  const h = SimHarness.create({ seed: 'quests-test' });
  const { player, conn } = h.join('quester');
  return { h, player, conn };
}

function claim(h: SimHarness, conn: Conn, questId: string): ServerMsg[] {
  return h.apply({ op: OP.QUEST_CLAIM, t: h.clock.now(), questId }, conn);
}

describe('board seeding', () => {
  it('a new player holds the non-story quests, active, dailies keyed to the reset', () => {
    const { h, player } = setup();
    expect(Object.keys(player.quests).sort()).toEqual(['daily_defeat', 'daily_walk', 'territory_elm']);
    for (const qp of Object.values(player.quests)) expect(qp.state).toBe('active');
    expect(player.quests.daily_walk.resetAt).toBe(h.world.dailyResetAt);
    expect(player.quests.territory_elm.resetAt).toBeUndefined();
  });
});

describe('QUEST_CLAIM validation', () => {
  it('unknown quest → NOT_FOUND; incomplete → ILLEGAL_STATE; done → ILLEGAL_STATE', () => {
    const { h, player, conn } = setup();
    expect(claim(h, conn, 'nope')[0]).toMatchObject({ op: OP.ERR, code: 'NOT_FOUND' });
    expect(claim(h, conn, 'daily_walk')[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    expect(player.gold).toBe(0);

    player.stepsToday = DAILY_WALK_STEPS;
    claim(h, conn, 'daily_walk');
    expect(claim(h, conn, 'daily_walk')[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    expect(player.gold).toBe(DAILY_WALK_GOLD); // paid exactly once
  });
});

describe('walk daily (§14 pedometer feed)', () => {
  it('steps ride the GPS stream; 2,000 steps → claimable → 80 g', () => {
    const { h, player, conn } = setup();
    h.gpsAt(conn, { x: 0, y: 0 }, { steps: DAILY_WALK_STEPS - 1 });
    expect(claim(h, conn, 'daily_walk')[0]).toMatchObject({ op: OP.ERR, code: 'ILLEGAL_STATE' });
    h.gpsAt(conn, { x: 0, y: 0 }, { steps: DAILY_WALK_STEPS });
    const frames = claim(h, conn, 'daily_walk');
    expect(frames.map((f) => f.op)).toEqual([OP.INVENTORY_UPDATE]);
    expect(player.gold).toBe(DAILY_WALK_GOLD);
    expect(player.quests.daily_walk.state).toBe('done');
  });
});

describe('defeat daily (kill feed)', () => {
  it('counts Gloomling kills only; 5 kills → 120 g', () => {
    const { h, player, conn } = setup();
    // Turf Tyrants are not Gloomlings — no progress
    recordKill(h.world, player, 'grumbleshroom', true, h.clock.now());
    expect(player.quests.daily_defeat.progress).toBe(0);

    for (let i = 0; i < DAILY_DEFEAT_COUNT; i++) {
      recordKill(h.world, player, 'gloomling', false, h.clock.now());
    }
    expect(player.quests.daily_defeat.state).toBe('claimable');
    claim(h, conn, 'daily_defeat');
    expect(player.gold).toBe(DAILY_DEFEAT_GOLD);
  });
});

describe('territory quest (front-slug match, per-run)', () => {
  /** The catalog's 'elm_st' names a front by slug — find a cell this seed calls Elm St. */
  function elmFrontId(seed: string): string {
    for (let cx = -12; cx <= 12; cx++) {
      for (let cy = -12; cy <= 12; cy++) {
        if (frontSlug(frontName(seed, cx, cy)) === QUESTS.territory_elm.frontId) {
          return `f${cx},${cy}`;
        }
      }
    }
    throw new Error('no Elm St cell within the scanned range for this seed');
  }

  it('claims on the named front count; other fronts do not; run start resets progress', () => {
    const { h, player, conn } = setup();
    const elm = elmFrontId(h.world.seed);
    const qp = player.quests.territory_elm;

    recordClaim(h.world, player, 'f99,99', h.clock.now()); // wrong front
    expect(qp.progress).toBe(0);

    recordClaim(h.world, player, elm, h.clock.now());
    recordClaim(h.world, player, elm, h.clock.now());
    expect(qp.progress).toBe(2);
    resetRunQuests(player); // §10 "in one run": a new run zeroes unfinished progress
    expect(qp.progress).toBe(0);

    for (let i = 0; i < TERRITORY_CLAIM_COUNT; i++) {
      recordClaim(h.world, player, elm, h.clock.now());
    }
    expect(qp.state).toBe('claimable');
    resetRunQuests(player); // a banked claimable survives run boundaries
    expect(qp.state).toBe('claimable');
    claim(h, conn, 'territory_elm');
    expect(player.gold).toBe(TERRITORY_CLAIM_GOLD);
  });
});

describe('daily reset boundary (DAILY_RESET_UTC_H ticker)', () => {
  it('resets daily progress + steps at the stamp, not a tick before; territory survives', () => {
    const { h, player, conn } = setup();
    player.stepsToday = DAILY_WALK_STEPS;
    claim(h, conn, 'daily_walk');
    recordKill(h.world, player, 'gloomling', false, h.clock.now());
    player.quests.territory_elm.progress = 3;
    const firstReset = h.world.dailyResetAt;

    // just before the stamp: nothing moves
    h.clock.advance(firstReset - h.clock.now() - 1000);
    h.tick(1);
    expect(player.quests.daily_walk.state).toBe('done');
    expect(player.quests.daily_defeat.progress).toBe(1);

    // crossing the stamp: dailies re-arm, steps zero, next stamp is +24 h
    h.clock.advance(2000);
    h.tick(1);
    expect(player.quests.daily_walk).toMatchObject({ progress: 0, state: 'active' });
    expect(player.quests.daily_defeat).toMatchObject({ progress: 0, state: 'active' });
    expect(player.quests.daily_walk.resetAt).toBe(firstReset + DAY_MS);
    expect(player.stepsToday).toBe(0);
    expect(player.quests.territory_elm.progress).toBe(3); // not a daily

    // the re-armed daily is claimable again in the new window
    h.gpsAt(conn, { x: 0, y: 0 }, { steps: DAILY_WALK_STEPS });
    claim(h, conn, 'daily_walk');
    expect(player.gold).toBe(2 * DAILY_WALK_GOLD); // walked in both windows, defeat never claimed
  });
});

describe('story chain stub (§10)', () => {
  it('accept once, one chain at a time, boss kill completes, claim pays gold + item', () => {
    const { h, player, conn } = setup();
    expect(acceptStoryQuest(h.world, player, 'story_grumble_park', h.clock.now())).toBe(true);
    expect(acceptStoryQuest(h.world, player, 'story_grumble_park', h.clock.now())).toBe(false);
    expect(player.quests.story_grumble_park.state).toBe('active');

    recordKill(h.world, player, 'grumbleshroom', true, h.clock.now());
    expect(player.quests.story_grumble_park.state).toBe('claimable');

    const invSize = player.inventory.length;
    const frames = claim(h, conn, 'story_grumble_park');
    expect(frames.map((f) => f.op)).toEqual([OP.LOOT_RESULT, OP.INVENTORY_UPDATE]);
    const loot = frames[0] as LootResultMsg;
    expect(loot.sourceId).toBe('story_grumble_park');
    expect(loot.gold).toBe(QUESTS.story_grumble_park.rewardGold);
    expect(loot.items).toHaveLength(1);
    expect(player.gold).toBe(QUESTS.story_grumble_park.rewardGold);
    expect(player.inventory).toHaveLength(invSize + 1);
    expect(player.quests.story_grumble_park.state).toBe('done');
  });
});
