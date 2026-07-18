// Loot rolls (§6): rollRarity boundaries, the golden chi-square on the tuning
// weights, chest staging (center = highest rarity), and the mob drop gate.

import { describe, expect, it } from 'vitest';
import {
  rarityRank,
  rollChestLoot,
  rollLootItem,
  rollMobDrop,
  rollRarity,
} from '../../sim/systems/loot.js';
import { seededRng } from '../../shared/rng.js';
import type { Rng } from '../../shared/rng.js';
import { LOOT_POOL, RARITIES } from '../../shared/catalog.js';
import type { Rarity } from '../../shared/catalog.js';
import {
  CHEST_RARITY_WEIGHTS,
  MOB_DROP_RARITY_WEIGHTS,
} from '../../shared/tuning.js';

/** Scripted rng: () pops the next value; helper methods mirror shared/rng.ts. */
function seqRng(vals: number[]): Rng {
  let i = 0;
  const next = (): number => vals[Math.min(i++, vals.length - 1)];
  const rng = next as Rng;
  rng.uniform = (min, max) => min + next() * (max - min);
  rng.int = (min, max) => min + Math.floor(next() * (max - min + 1));
  rng.chance = (p) => next() < p;
  rng.pick = (arr) => arr[Math.floor(next() * arr.length)];
  return rng;
}

describe('rollRarity', () => {
  it('maps the unit interval onto the cumulative chest weights (60/30/9/1)', () => {
    const cases: Array<[number, Rarity]> = [
      [0, 'common'],
      [0.5999, 'common'],
      [0.6, 'rare'],
      [0.8999, 'rare'],
      [0.9, 'epic'],
      [0.9899, 'epic'],
      [0.99, 'legendary'],
      [0.9999, 'legendary'],
    ];
    for (const [v, want] of cases) {
      expect(rollRarity(CHEST_RARITY_WEIGHTS, seqRng([v]))).toBe(want);
    }
  });

  it('golden chi-square: 10k seeded draws fit the chest weights', () => {
    const rng = seededRng('loot-golden-1');
    const n = 10_000;
    const counts: Record<Rarity, number> = { common: 0, rare: 0, epic: 0, legendary: 0 };
    for (let i = 0; i < n; i++) counts[rollRarity(CHEST_RARITY_WEIGHTS, rng)] += 1;
    let chi2 = 0;
    let total = 0;
    for (const r of RARITIES) total += CHEST_RARITY_WEIGHTS[r];
    for (const r of RARITIES) {
      const exp = (n * CHEST_RARITY_WEIGHTS[r]) / total;
      chi2 += (counts[r] - exp) ** 2 / exp;
    }
    expect(chi2).toBeLessThan(16.27); // df=3, p=0.001
    // Golden pin: mulberry32 is integer-math deterministic, so these exact counts
    // hold on every platform — a drifted rng or weight table fails loudly here.
    expect(counts).toEqual({ common: 5917, rare: 3114, epic: 853, legendary: 116 });
  });
});

describe('rollChestLoot (§6 staged roll)', () => {
  it('returns 3 items with the highest rarity in the center slot', () => {
    // scripted draws: (rarity, pick) ×3 → common, epic, rare
    const rng = seqRng([0.0, 0.0, 0.95, 0.0, 0.7, 0.0]);
    const rolls = rollChestLoot(rng);
    expect(rolls).toHaveLength(3);
    expect(rolls.map((r) => r.rarity)).toEqual(['rare', 'epic', 'common']);
    expect(rarityRank(rolls[1].rarity)).toBeGreaterThanOrEqual(rarityRank(rolls[0].rarity));
    expect(rarityRank(rolls[1].rarity)).toBeGreaterThanOrEqual(rarityRank(rolls[2].rarity));
  });

  it('every rolled item comes from its rarity pool', () => {
    const rng = seededRng('loot-pool-check');
    for (let i = 0; i < 50; i++) {
      for (const roll of rollChestLoot(rng)) {
        expect(LOOT_POOL[roll.rarity]).toContain(roll.itemId);
      }
    }
  });
});

describe('rollMobDrop (§6 25% / tyrant 100%)', () => {
  it('gates at the drop pct (draw order: gate, rarity, pick)', () => {
    expect(rollMobDrop(seqRng([0.249, 0.0, 0.0]), false)).not.toBeNull();
    expect(rollMobDrop(seqRng([0.25]), false)).toBeNull();
    expect(rollMobDrop(seqRng([0.9]), false)).toBeNull();
  });

  it('tyrants always drop', () => {
    for (let v = 0; v < 10; v++) {
      const roll = rollMobDrop(seqRng([v / 10 + 0.0999, 0.0, 0.0]), true);
      expect(roll).not.toBeNull();
    }
  });

  it('drops draw from the mob weight table', () => {
    const roll = rollMobDrop(seqRng([0.0, 0.999, 0.0]), true);
    expect(roll?.rarity).toBe('legendary');
    expect(LOOT_POOL.legendary).toContain(roll?.itemId);
    expect(MOB_DROP_RARITY_WEIGHTS.legendary).toBe(1);
  });

  it('rollLootItem picks uniformly inside the pool', () => {
    const roll = rollLootItem(MOB_DROP_RARITY_WEIGHTS, seqRng([0.0, 0.0]));
    expect(roll.itemId).toBe(LOOT_POOL.common[0]);
  });
});
