// Cross-checks catalog content against tuning (rules) — mirrors what
// game/tests/data_sanity.gd asserts on the shell side, until tools codegen
// enforces server↔shell equality mechanically.
import { describe, expect, it } from 'vitest';
import {
  CHARACTERS,
  DEFAULT_HOTBAR,
  ITEMS,
  JOBS,
  LOOT_POOL,
  MINIONS,
  MOBS,
  NPCS,
  QUESTS,
  RARITIES,
  SETS,
  SHOP_STOCK,
  TOWERS,
  characterDef,
  itemDef,
  questDef,
} from '../../shared/catalog.js';
import * as T from '../../shared/tuning.js';

describe('catalog ↔ rules cross-checks', () => {
  it("characters match the shell's 8 (ids = face ids)", () => {
    expect(Object.keys(CHARACTERS).sort()).toEqual(
      ['knight', 'huntress', 'mage', 'barbarian', 'archer', 'druid', 'beardruid', 'dwarf'].sort(),
    );
    expect(CHARACTERS.dwarf.unlockLevel).toBe(15);
  });

  it('every hotbar id resolves', () => {
    expect(DEFAULT_HOTBAR).toHaveLength(T.HOTBAR_SLOTS);
    for (const idOrNull of DEFAULT_HOTBAR) {
      if (idOrNull !== null) expect(itemDef(idOrNull), idOrNull).toBeDefined();
    }
  });

  it('every shop stock id resolves; shelf matches §11', () => {
    expect(SHOP_STOCK).toHaveLength(T.SHOP_STOCK_SIZE);
    for (const entry of SHOP_STOCK) expect(itemDef(entry.item), entry.item).toBeDefined();
    const deal = SHOP_STOCK.find((e) => e.dealPct !== undefined);
    expect(deal?.dealPct).toBe(T.SHOP_DEAL_DISCOUNT_PCT);
    expect(ITEMS.mystery_box.value).toBe(T.MYSTERY_BOX_COST);
  });

  it('every loot pool id resolves and sits in its own rarity tier', () => {
    for (const rarity of RARITIES) {
      const pool = LOOT_POOL[rarity];
      expect(pool.length).toBeGreaterThan(0);
      for (const itemId of pool) {
        const def = itemDef(itemId);
        expect(def, itemId).toBeDefined();
        expect(def!.rarity, itemId).toBe(rarity);
      }
    }
  });

  it('tower defs agree with §8 tuning', () => {
    expect(TOWERS.bonk_turret.cost).toBe(T.BONK_TURRET_COST);
    expect(TOWERS.chill_bell.cost).toBe(T.CHILL_BELL_COST);
    expect(TOWERS.bastion_post.cost).toBe(T.BASTION_POST_COST);
    expect(TOWERS.bonk_turret.dmgPerTick).toBe(T.BONK_TURRET_DMG_PER_TICK);
    expect(TOWERS.bonk_turret.radiusHexes).toBe(T.BONK_TURRET_RADIUS_HEXES);
    expect(TOWERS.chill_bell.slowPct).toBe(T.CHILL_BELL_SLOW_PCT);
    expect(TOWERS.chill_bell.radiusHexes).toBe(T.CHILL_BELL_RADIUS_HEXES);
    expect(TOWERS.bastion_post.radiusHexes).toBe(T.BASTION_POST_RADIUS_HEXES);
  });

  it('minion jobs agree with §9 tuning', () => {
    expect(JOBS.gather_lumber.durationMin).toBe(T.GATHER_LUMBER_MINUTES);
    expect(JOBS.gather_lumber.yieldMin).toBe(T.GATHER_LUMBER_YIELD_MIN);
    expect(JOBS.gather_lumber.yieldMax).toBe(T.GATHER_LUMBER_YIELD_MAX);
    expect(JOBS.scout_front.durationMin).toBe(T.SCOUT_FRONT_MINUTES);
    expect(JOBS.scavenge.durationMin).toBe(T.SCAVENGE_MINUTES);
    expect(JOBS.scavenge.yieldBonusPct).toBe(T.SCAVENGE_YIELD_BONUS_PCT);
    expect(JOBS.scavenge.injuryPct).toBe(T.SCAVENGE_INJURY_PCT);
    expect(Object.keys(MINIONS)).toHaveLength(T.MINION_ROSTER_START);
    for (const m of Object.values(MINIONS)) expect(characterDef(m.face), m.face).toBeDefined();
  });

  it('quests agree with §10 tuning and reference real fronts/npcs', () => {
    expect(QUESTS.daily_walk.target).toBe(T.DAILY_WALK_STEPS);
    expect(QUESTS.daily_walk.rewardGold).toBe(T.DAILY_WALK_GOLD);
    expect(QUESTS.daily_defeat.target).toBe(T.DAILY_DEFEAT_COUNT);
    expect(QUESTS.daily_defeat.rewardGold).toBe(T.DAILY_DEFEAT_GOLD);
    expect(QUESTS.territory_elm.target).toBe(T.TERRITORY_CLAIM_COUNT);
    expect(QUESTS.territory_elm.rewardGold).toBe(T.TERRITORY_CLAIM_GOLD);
    // the story quest's giver exists and points back at the quest
    expect(NPCS.elder_grumblesnore.questId).toBe('story_grumble_park');
    expect(questDef(QUESTS.story_grumble_park.giver === 'elder_grumblesnore' ? 'story_grumble_park' : '')).toBeDefined();
    for (const npc of Object.values(NPCS)) expect(characterDef(npc.face), npc.face).toBeDefined();
  });

  it('level-locked items agree with §7 unlock levels', () => {
    expect(ITEMS.pocket_blizzard.levelReq).toBe(T.POCKET_BLIZZARD_UNLOCK_LEVEL);
    expect(ITEMS.cape_of_mild_dramatics.levelReq).toBe(T.CAPE_UNLOCK_LEVEL);
  });

  it('mobs agree with §3: tyrant segments, affinity tags resolve', () => {
    expect(MOBS.grumbleshroom.hpSegments).toBe(T.TYRANT_HP_SEGMENTS);
    expect(MOBS.grumbleshroom.isTyrant).toBe(true);
    expect(MOBS.gloomling.isTyrant).toBe(false);
    // every weak/resist tag is an ability tag some item actually carries
    const itemTags = new Set(
      Object.values(ITEMS)
        .map((i) => ('abilityTag' in i ? i.abilityTag : undefined))
        .filter(Boolean),
    );
    for (const mob of Object.values(MOBS)) {
      for (const tag of [...mob.weakTags, ...mob.resistTags]) expect(itemTags, tag).toContain(tag);
    }
  });

  it('the one shipped set (§7) is the hammer set with real pieces', () => {
    expect(Object.keys(SETS)).toEqual(['hammer']);
    const pieces = Object.entries(ITEMS).filter(([, d]) => 'setTag' in d && d.setTag === 'hammer');
    expect(pieces.length).toBeGreaterThanOrEqual(2); // 2/4 renders in the paper doll today
    expect(SETS.hammer.piecesTotal).toBe(4);
  });
});
