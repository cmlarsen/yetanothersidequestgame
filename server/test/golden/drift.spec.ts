// test/golden/drift.spec.ts — the DESIGN §Determinism-gates drift check. Two
// committed goldens, two independent checks; both FAIL on real drift and stay
// quiet under refactor (signal, not noise). Pattern ported from SideQuestAppV2
// test/golden/drift.spec.ts:
//
//   1. Loot rarity distribution — re-sample rollRarity from a DIFFERENT seed than
//      the golden and chi-square goodness-of-fit against the committed proportions.
//      A stealth tuning-weights edit shifts proportions by whole percentage points
//      → χ² blows past CHI_SQUARE_CRIT → fail. A seed change or unrelated refactor
//      leaves proportions intact → tiny χ² → pass.
//   2. World save fixture — replay the committed scripted history and assert
//      serialize() is byte-identical to the committed blob. World-shape / codec /
//      command-determinism drift fails loudly.
//
// If an INTENDED change moves a golden: `npm run golden:generate`, commit the new
// bytes alongside the change.

import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildSaveGolden, type LootGolden } from './generate.js';
import { CHI_SQUARE_CRIT, LOOT_DRIFT_SEED, LOOT_GOLDEN_N, WEIGHT_TABLES } from './fixtures.js';
import { seededRng } from '../../shared/rng.js';
import { RARITIES } from '../../shared/catalog.js';
import { rarityRank, rollRarity } from '../../sim/systems/loot.js';

const HERE = fileURLToPath(new URL('.', import.meta.url));

function loadLootGolden(): LootGolden {
  return JSON.parse(readFileSync(join(HERE, 'loot/rarity-histogram.golden.json'), 'utf8')) as LootGolden;
}

/** Pearson chi-square of observed vs expected counts, skipping zero-expected buckets. */
function chiSquare(observed: number[], expected: number[]): number {
  let x2 = 0;
  for (let i = 0; i < observed.length; i++) {
    if (expected[i] <= 0) continue; // zero-weight rarities contribute no term (must stay zero — checked separately)
    const d = observed[i] - expected[i];
    x2 += (d * d) / expected[i];
  }
  return x2;
}

describe('golden: rollRarity distribution does not drift (chi-square GOF)', () => {
  const golden = loadLootGolden();

  it('the committed golden covers exactly the current weight tables and rarity ladder', () => {
    expect(Object.keys(golden.perTable).sort()).toEqual(Object.keys(WEIGHT_TABLES).sort());
    expect(golden.rarities).toEqual([...RARITIES]);
    expect(golden.n).toBe(LOOT_GOLDEN_N);
  });

  for (const table of Object.keys(WEIGHT_TABLES)) {
    it(`${table}: a fresh sample (different seed) fits the golden proportions within χ² < ${CHI_SQUARE_CRIT}`, () => {
      const props = golden.perTable[table].proportions;

      const rng = seededRng(LOOT_DRIFT_SEED, table);
      const observed = RARITIES.map(() => 0);
      for (let i = 0; i < LOOT_GOLDEN_N; i++) {
        observed[rarityRank(rollRarity(WEIGHT_TABLES[table], rng))]++;
      }
      const expected = props.map((p) => p * LOOT_GOLDEN_N);

      // a rarity the golden never rolled must still never roll (opening it up is drift)
      for (let r = 0; r < RARITIES.length; r++) if (props[r] === 0) expect(observed[r]).toBe(0);

      const x2 = chiSquare(observed, expected);
      expect(
        x2,
        `${table} χ²=${x2.toFixed(2)} — rarity odds drifted from the committed golden`,
      ).toBeLessThan(CHI_SQUARE_CRIT);
    });
  }
});

describe('golden: world save fixture is byte-stable (serialize/codec does not drift)', () => {
  it('replaying the committed script serializes byte-identically to the golden save', () => {
    const golden = readFileSync(join(HERE, 'save/world.golden.json'), 'utf8').trimEnd();
    expect(buildSaveGolden()).toBe(golden);
  });
});
