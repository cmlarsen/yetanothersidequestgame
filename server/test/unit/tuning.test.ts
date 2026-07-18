import { describe, expect, it } from 'vitest';
import * as T from '../../shared/tuning.js';

describe('tuning (GAME-RULES DEFAULTs)', () => {
  it('xp curve: 100 × 1.35^(level−1), rounded', () => {
    expect(T.xpForLevel(1)).toBe(100);
    expect(T.xpForLevel(2)).toBe(135);
    expect(T.xpForLevel(3)).toBe(Math.round(100 * 1.35 * 1.35));
  });

  it('tower costs 12/18/30 (§8)', () => {
    expect(T.BONK_TURRET_COST).toBe(12);
    expect(T.CHILL_BELL_COST).toBe(18);
    expect(T.BASTION_POST_COST).toBe(30);
  });

  it('weak/resist multipliers 1.5/0.5 (§3)', () => {
    expect(T.WEAK_MULTIPLIER).toBe(1.5);
    expect(T.RESIST_MULTIPLIER).toBe(0.5);
  });

  it('derived helpers match rules.gd math', () => {
    expect(T.deathGoldDrop(100)).toBe(50); // floor wins
    expect(T.deathGoldDrop(1000)).toBe(100); // 10% wins
    expect(T.dealPrice(120)).toBe(84); // shop mock: 120 → 84
    expect(T.sellValue(320)).toBe(160);
    expect(T.towerSalvageRefund(T.CHILL_BELL_COST)).toBe(8); // §8 "8 🪵 on Chill Bell"
    expect(T.towerDurabilityMax(1)).toBe(100);
    expect(T.towerDurabilityMax(3)).toBe(150);
  });

  it('loot rarity weight tables cover all 4 tiers and sum to 100', () => {
    for (const table of [T.CHEST_RARITY_WEIGHTS, T.MOB_DROP_RARITY_WEIGHTS]) {
      expect(Object.keys(table).sort()).toEqual(['common', 'epic', 'legendary', 'rare']);
      const sum = Object.values(table).reduce((a, b) => a + b, 0);
      expect(sum).toBe(100);
      for (const w of Object.values(table)) expect(w).toBeGreaterThan(0);
    }
    // commons dominate, legendaries are the chase
    expect(T.CHEST_RARITY_WEIGHTS.common).toBeGreaterThan(T.CHEST_RARITY_WEIGHTS.legendary);
  });

  it('hex size rides hexgrid (60 m across flats)', () => {
    expect(T.HEX_SIZE_M).toBe(60);
  });
});
