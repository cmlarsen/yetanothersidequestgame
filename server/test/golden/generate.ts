// test/golden/generate.ts — (re)generate the COMMITTED golden fixtures the drift
// check pins. Run deliberately (`npm run golden:generate`) ONLY when an intended
// change moves a golden, then commit the new bytes with the change so the diff is
// auditable (DESIGN §Determinism gates: "a stealth odds change gets caught").
// Pattern ported from SideQuestAppV2 test/golden/generate.ts.
//
//   loot/rarity-histogram.golden.json — rollRarity's distribution per weight table
//     (proportions from a big fixed-seed Monte-Carlo sample). The drift spec
//     re-samples from a DIFFERENT seed and chi-square goodness-of-fits against
//     these proportions — an edit to the tuning weights fails it.
//   save/world.golden.json — a byte-exact serialized World from a small scripted
//     command history (join → run → claims → run end). The drift spec replays the
//     same script and asserts byte-identical serialize() — world-shape/codec/
//     command-determinism drift all fail loudly.

import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { seededRng } from '../../shared/rng.js';
import { RARITIES } from '../../shared/catalog.js';
import { hexCenter } from '../../shared/hexgrid.js';
import { rarityRank, rollRarity } from '../../sim/systems/loot.js';
import { SimHarness } from '../harness/sim-harness.js';
import { LOOT_GOLDEN_N, LOOT_GOLDEN_SEED, SAVE_GOLDEN_SEED, WEIGHT_TABLES } from './fixtures.js';

const HERE = fileURLToPath(new URL('.', import.meta.url));

export interface LootGolden {
  seed: string;
  n: number;
  rarities: readonly string[];
  perTable: Record<string, { counts: number[]; proportions: number[] }>;
}

/** Sample the rarity histogram for every weight table (provenance included). */
export function buildLootGolden(sampleSeed: string = LOOT_GOLDEN_SEED): LootGolden {
  const perTable: LootGolden['perTable'] = {};
  for (const [name, weights] of Object.entries(WEIGHT_TABLES)) {
    const rng = seededRng(sampleSeed, name);
    const counts = RARITIES.map(() => 0);
    for (let i = 0; i < LOOT_GOLDEN_N; i++) counts[rarityRank(rollRarity(weights, rng))]++;
    perTable[name] = { counts, proportions: counts.map((c) => c / LOOT_GOLDEN_N) };
  }
  return { seed: sampleSeed, n: LOOT_GOLDEN_N, rarities: RARITIES, perTable };
}

/**
 * The scripted save fixture: a short real-command history (JOIN → RUN_START →
 * walk-claim two hexes → RUN_END) on a ManualClock from 0. Deterministic by
 * construction — the drift spec re-runs THIS function, so generator and check can
 * never diverge on the script.
 */
export function buildSaveGolden(): string {
  const h = SimHarness.create({ seed: SAVE_GOLDEN_SEED, now: 0 });
  const { player, conn } = h.join('Goldenkeeper');
  h.runStart(conn);
  h.tick(1); // claim 0,0 → home anchor + front touch + area xp
  const c = hexCenter(1, 0);
  h.teleport(player, c.x, c.y);
  h.tick(1); // claim 1,0
  h.runEnd(conn);
  h.tick(1);
  return h.serialize();
}

function main(): void {
  mkdirSync(join(HERE, 'loot'), { recursive: true });
  mkdirSync(join(HERE, 'save'), { recursive: true });
  writeFileSync(
    join(HERE, 'loot/rarity-histogram.golden.json'),
    JSON.stringify(buildLootGolden(), null, 2) + '\n',
  );
  writeFileSync(join(HERE, 'save/world.golden.json'), buildSaveGolden() + '\n');
  console.log('[golden] wrote loot/rarity-histogram.golden.json + save/world.golden.json');
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
