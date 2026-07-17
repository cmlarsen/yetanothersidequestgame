# Tuning map — one `shared/tuning.ts`, two namespaces (M0 FROZEN)

§11.12: all balance constants live in `shared/tuning.ts` under **`COMBAT`** and **`ECON`**
(plus the `TIERS` ladder, §11.3). Sections reference; they never redefine. The balance harness
imports `shared/tuning.ts` and nothing else. This table records old-name → new-name so §4/§5/§7/§9
prose can be find-replaced. Values are first-guess (`TODO(tune)` where flagged); the **keys** are frozen.

Naming rule: §4 `C.SCREAMING_SNAKE` → `COMBAT.camelCase`; §5 `BALANCE.SCREAMING_SNAKE` splits by
domain (progression/combat-adjacent → `COMBAT`, loot/economy → `ECON`); §7 inline turret/bastion
numbers → `ECON`.

## `COMBAT` — from §4.3 `SQ_COMBAT_CONSTANTS` (`C.*`) + §5 combat-adjacent + §11.17

| New (`tuning.COMBAT.*`) | Old | Source |
|---|---|---|
| `baseHp hpPerLevel baseAtk atkPerLevel baseDef defPerLevel baseSpd baseAcc baseEva baseCrit maxFocus` | `C.BASE_HP …` | §4.3 hero base scaling |
| `atkCoeffBasic defK variance critMult weakMult resistMult neutralMult minDamage` | `C.ATK_COEFF_BASIC …` | §4.3 damage pipeline |
| `hitBase accScale hitMin hitMax` | `C.HIT_BASE …` | §4.3 hit/evade (auto path) |
| `strikeWindowMs guardWindowMs perfectMult grazeMult guardMitigate guardStanceMitigate strikeHalfwidthBase strikeHalfwidthPerSureHands focusOnGood focusOnPerfect focusOnWeak focusRegenPerRound` | `C.STRIKE_WINDOW_MS …` | §4.3 timed-tap |
| `maxBreachChains` | `C.MAX_BREACH_CHAINS` | §4.3 press-turn |
| `cmdWindowMs resolveStepMs impactMs spdJitter hitstopMs screenShakeCrit` | `C.CMD_WINDOW_MS …` | §4.3 round timing |
| `tierHpMult tierAtkMult tierXpMult tierEliteChance` | `C.TIER_HP_MULT …` | §4.3 tier arrays (index 1..5) |
| `fleeHpFrac fleeStepM fleeEscapeM pursuitRebindM chaseTrigger chaseSpeedMps chaseCatchM chaseGraceS` | `C.FLEE_HP_FRAC …` | §4.5 world-space behaviors |
| `markDmg shieldHp sunderDef evaRoll reviveRange reviveHpFrac` | (were undefined) | §11.17 added knobs — `TODO(tune)` |
| `offClassAcc lvlAccCap lvlAccPer` | `BALANCE.OFFCLASS_ACC LVL_ACC_CAP LVL_ACC_PER` | §5.17 class accuracy |
| `weaponBase` | `BALANCE.WEAPON_BASE` | §5.17 weapon base atk |
| `sealMul` | `SEAL_MUL` | §6 sealing-by-band (close/mid/far) |

## `ECON` — from §5.17 `BALANCE.*` (loot/economy/progression-currency) + §7 turret/bastion

| New (`tuning.ECON.*`) | Old | Source |
|---|---|---|
| `xpBase xpGrowth hpPerLvl defPer2Lvl class` | `BALANCE.XP_BASE XP_GROWTH HP_PER_LVL DEF_PER_2LVL CLASS` | §5.17 progression |
| `trainMax trainCost accPerRank dodgePerRank powerPerRank vigorHp metersPerEp` | `BALANCE.TRAIN_MAX …` | §5.17 EP training |
| `wAtk wDef wHp wDodge fxPower tierPower upPower goldPerPower catValue curseValue` | `BALANCE.W_ATK …` | §5.17 item power/value |
| `rarityPower rarityAffixCount affixTierWeights` | `BALANCE.RARITY_POWER …` | §5.17 rarity (length-5, §11.19) |
| `rarityOdds gearChanceBase gearChanceElite gearChanceBoss essenceChance veilshard goldTierMult xpTierMult matsPerKill depthRarityStep depthGold snapBase snapStep chestTierBonus pryMfStep` | `BALANCE.RARITY_ODDS …` | §5.17 loot |
| `temperCost temperCap reforgeCost enchantCost ascendCost forgeAtk forgeHp forgePotion` | `BALANCE.TEMPER_COST …` | §5.17 forge |
| `bagCap stackMax` | `BALANCE.BAG_CAP STACK_MAX` | §5.17 inventory |
| `sellRate sellRateCursed identifyCost potionPrice negotiatePerRank negotiateFloor merchantSpawn stockSlots tradeWindowMin` | `BALANCE.SELL_RATE …` | §5.17 merchant/co-op |
| `bastionCost bastionMax craft` | `BALANCE.BASTION_COST BASTION_MAX CRAFT` | §5.17 camp cross-refs |
| `trickleMatsCap trickleDpCap trickleGoldCap luckyFindChance luckyFindMinMin craftMasterworkChance` | (§7.6 inline formulas) | §7.6.1/7.6.2 away-progress — `TODO(tune)` |
| `turretKinds` | `TURRET_KINDS` | §7.7.1 auto-turret kinds |

## `TIERS` — the one 5-tier ladder (§11.3)

`tuning.TIERS[1..5]` = `{index, name}`: 1 Fracture · 2 Elder · 3 Giant · 4 Massive · 5 Cataclysm.
Names are display-only; combat depends only on the index. Index 0 is `null` (1-based).

## Notes for downstream

- §5's `cold` → `frost` (§11.5): turret `dmgType` and any element key uses the frozen enum in
  `shared/constants.ts` (`ELEMENTS`). `turretKinds.*.dmgType` strings are `phys/fire/shock`.
- Rarity is numeric `0..4` (§11.19): `rarityPower`/`rarityOdds` rows/arrays are length-5.
- `bastionMax` here is the §5.17 POC cap (3); §7.4 describes 6 upgrade tiers — reconcile in M7 (`TODO(tune)`).
- All function-valued constants (`trainCost`, `goldTierMult`, `temperCost`, `bastionCost`, …) are
  pure and deterministic — safe under the purity lint.
