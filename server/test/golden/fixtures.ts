// test/golden/fixtures.ts — the frozen constants that pin the golden fixtures.
// The GENERATOR and the DRIFT CHECK both import these so they can never silently
// disagree on seed/N/tables. Changing a value here is an explicit, reviewable act
// (it moves the golden). Keep pure — no I/O. Pattern ported from SideQuestAppV2
// test/golden/fixtures.ts (breach tiers → the two YAS rarity weight tables).

import { CHEST_RARITY_WEIGHTS, MOB_DROP_RARITY_WEIGHTS } from '../../shared/tuning.js';
import type { Rarity } from '../../shared/catalog.js';

/** Seed for the COMMITTED loot histogram sample (the golden is built from this). */
export const LOOT_GOLDEN_SEED = 'loot-golden';
/** A DIFFERENT seed the drift check re-samples from, so the GOF test is signal
 * (statistical), not a byte match. */
export const LOOT_DRIFT_SEED = 'loot-drift-check';
/** Sample size per table for both the golden and the drift re-sample. */
export const LOOT_GOLDEN_N = 100_000;

/** Seed for the committed world save fixture (byte-exact serialize()). */
export const SAVE_GOLDEN_SEED = 'golden-save';

/** Every rollRarity weight table the loot golden covers (§6/§11 tuning). */
export const WEIGHT_TABLES: Record<string, Record<Rarity, number>> = {
  chest: CHEST_RARITY_WEIGHTS,
  mob_drop: MOB_DROP_RARITY_WEIGHTS,
};

/**
 * CHI_SQUARE_CRIT — the drift threshold for the rarity GOF test. df = 3 (four
 * rarities), so the p=0.001 noise ceiling is ~16.3; 25 sits comfortably above it
 * (a fresh seed never trips by chance) while any real weights edit shifts
 * proportions by whole percentage points and lands χ² in the hundreds at N=100k.
 */
export const CHI_SQUARE_CRIT = 25;
