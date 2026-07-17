# Cairn 2e Combat — Implementation Plan

Status: authoritative build plan. Replaces SideQuest's bespoke Focus/tier/acc-eva
combat with **Cairn 2e** (CC BY-SA 4.0), plus the SideQuest house rule
**"0 net damage renders as MISS."** Directives honored: (a) Cairn 2e; (b) 0 = MISS;
(c) the balance pipeline is CUT, not preserved; (d) PC/MOB/LOOT/SPELL stats fully
accounted; (e) nothing is precious — Focus/ability/tier code is freely deleted.

> **Attribution.** Cairn is © Yochai Gal, licensed **CC BY-SA 4.0**. This game's
> combat rules are a derivative of Cairn 2e. Add a `NOTICE`/`LICENSES/CAIRN.md`
> file crediting "Cairn by Yochai Gal (cairnrpg.com), CC BY-SA 4.0" and, because
> SA is share-alike, mark the combat-rules portion of the repo as CC BY-SA 4.0 in
> that notice. Surface a one-line credit in the client About/credits screen.

---

## 1. Overview & design decisions

### 1.1 The new core loop (Cairn 2e)
- **Attacks auto-hit.** No to-hit roll. `net = clamp(weaponDie − target.armor, 0, ∞)`, subtracted from HP.
- **House rule:** `net === 0` → deal 0, emit `CombatEvent{kind:'miss'}`. This is the only "miss" in the system.
- **HP is Hit Protection** (luck/stamina), small, **refills fully on a short safe rest**.
- **Overflow past 0 HP** subtracts the remainder from **STR**, then a **STR save** (`d20 ≤ STR`) or Critical Damage (out of fight). **STR 0 = death.**
- **HP reduced to exactly 0** → roll **d12 Scars**.
- **Armor** is flat, hard-capped at **3**, subtracted from every incoming die.
- **Ganging up:** N attackers on one foe → roll all dice, **keep the single highest** (sub-linear).
- **Spells** are physical **Spellbook items** (1 slot each, one spell); casting adds **1 Fatigue**; casting while Deprived/in danger → **WIL save**.
- **Morale:** enemies WIL-save on first casualty and at half strength; fail → flee/surrender. PCs never roll morale.
- **Determinism preserved:** every die draws from the injected `Rng` (`shared/rng.ts`), in a fixed order; no `Date.now`/`Math.random`. Add `rng.die(n) = rng.int(1, n)` sugar (or just call `rng.int(1, n)`).

### 1.2 Phone-scaling decision (the one deliberate deviation from RAW)
1d6 HP + d6–d10 weapons ends fights in 1–2 hits. Per the rules reference, **scale ONLY HP, leave damage/armor/STR raw**:
- `maxHP = max(6, hpRoll * 4)` where `hpRoll = 1d6` → **6–24**, avg ~14.
- Weapon dice (d4–d12) and Armor (0–3) **unchanged** → net damage avg ~3–4 → **~4–7 hits** to drop a combatant.
- STR stays raw 3–18, so the overflow→STR-save flow works exactly as RAW.
- Enemies use the same scale: weak `1d6*3`, standard `1d6*4`, elite `1d6*5 + flat` (§3).

### 1.3 KEEP / REPLACE / DELETE ledger
| Piece | Verdict |
|---|---|
| command→resolution→end phase skeleton + seed-deterministic auto-fill (`combat.ts`) | **KEEP** |
| real-time `deadlineMs` command window (async co-op) | **KEEP** |
| shared-encounter/join model; start/monster/sandbox entry points; win/flee/downed outcomes; wake-at-camp | **KEEP** |
| initiative `spd`+jitter order | **KEEP** (drop the `slow` term) |
| seal/veil chip meta-layer | **KEEP** (rescale its `dmg` input to the new net-damage scale) |
| seeded-rng determinism discipline + purity lint | **KEEP (backbone)** |
| `computeDamage` multiplicative pipeline (coeff·mitig·variance·element·crit·timing·mark) | **REPLACE** → `weaponDie − armor` |
| hit/miss roll (`hitBase`/`acc`/`eva`/`accScale`) | **DELETE** (auto-hit) |
| crit-as-multiplier + timing bands (`classifyTiming`, perfect/good/graze) | **DELETE** → STR-overflow crit |
| guard 0.7 mitigate / shield absorb pool / evade dodge-roll | **REPLACE** → flat Armor (cap 3) |
| **Focus meter** + `focusCost`/`spendFocus`/`canAfford`/regen | **DELETE** → Spellbooks + Fatigue |
| statuses `stagger`/`mark`/`def_break`/`slow` | **DELETE/REMAP** → Fatigue/Deprived/Scars/Morale/impaired |
| **tier atk/hp multiplier ladder** for stat inflation | **REPLACE** → die-step + Armor + HP-die-step tiering |
| **classes as mechanical drivers** (`ECON.class` hp/def/atkGrow, `abilitiesFor` unlock) | **DELETE** → cosmetic archetype + starting package |
| **XP / levels** (`xp`, `level`, `xpToNext`, `addXp` loop, `killXp`, `sealXp`, `setHeroLevel` math) | **DELETE** → horizontal (Scars + gear) |
| **the balance pipeline** (`test/balance/**`, `balance*` npm scripts, guardrail asserts) | **DELETE ENTIRELY** (§9, §10) |

### 1.4 Miss-rate & hits-to-kill validation (the winnability guardrail)
Cutting the balance pipeline (§9/§10) removes the only win-rate check, so the "0 = MISS" house rule
must be quantified up front. With `net = roll − armor` and MISS iff `roll ≤ armor`, for a die of
`f` faces vs `armor a` (a<f): **P(miss) = a/f** and **E[net per swing] = (f−a)(f−a+1)/(2f)**.

**Miss-rate table (P(miss), %):**

| die \ armor | 0 | 1 | 2 | 3 |
|---|:--:|:--:|:--:|:--:|
| d4  | 0 | 25 | 50 | **75** |
| d6  | 0 | 17 | 33 | 50 |
| d8  | 0 | 13 | 25 | 38 |
| d10 | 0 | 10 | 20 | 30 |
| d12 | 0 | 8 | 17 | 25 |

**E[net]/swing (and swings-to-kill vs a standard ~14 HP foe = 14/E[net], rounded):**

| die \ armor | 0 | 1 | 2 | 3 |
|---|:--:|:--:|:--:|:--:|
| d4  | 2.5 (6) | 1.5 (9) | 0.75 (19) | **0.25 (56)** ← stalemate |
| d6  | 3.5 (4) | 2.5 (6) | 1.67 (8) | 1.0 (14) |
| d8  | 4.5 (3) | 3.5 (4) | 2.63 (5) | 1.88 (7) |
| d10 | 5.5 (3) | 4.5 (3) | 3.6 (4) | 2.8 (5) |
| d12 | 6.5 (2) | 5.5 (3) | 4.58 (3) | 3.75 (4) |

**Read-out:** the fun band is roughly **3–8 effective swings**. Everything at or below the diagonal
`weaponDie ≥ armor+2` (a die two steps above the armor value) sits in-band; the pathological cells
are the top-right corner (`d4` vs armor 2–3, and `d6` vs armor 3), which turn into 19–56-swing slogs.

**Design guardrail (the concrete winnability decision):**
1. **Cap non-elite effective armor at 2.** Armor **3** is reserved for **elite-only** foes
   (`wraith_elite`) and rare `plate`; it never appears in the standard garrison pool (`ENEMY_ORDER`
   already excludes `wraith_elite`). This deletes the entire armor-3 column from ordinary play.
2. **Every archetype's *primary* damage tool is `weaponDie ≥ 6`.** Knight d8, Ranger d6 bow — both
   clear `weaponDie ≥ armor+2` against the capped armor-2 world. The **wizard's** primary tool is
   **Firebolt (d10, `ignoreArmor:1`)**, not the d4 dagger — the dagger is an explicit emergency
   fallback. **This is the accepted, documented "wizard-must-cast" design:** a wizard reduced to
   dagger-vs-armor is *supposed* to feel bad and push the player back to spellbooks; it is not a
   balance bug. Unarmed/dagger stays d4 by RAW (raising it would flatten the whole ladder).
3. **`unarmedDie = 4` stays**, but because armor-3 is gated (rule 1), the worst *reachable* unarmed
   matchup is d4 vs armor 2 (50% miss, ~19 swings) — a real penalty for going weaponless, not an
   unwinnable stalemate. `firebolt`'s `ignoreArmor:1` and `called_shot`'s `ignoreArmor:∞` give casters
   a hard-armor answer regardless.
4. **`combat-lab` gets pass criteria:** its HP-scaling assertion (§10.3) is joined by an
   effective-swings check — a representative party vs each breed/tier must land in the **3–8 swing**
   band (elites allowed up to 10). This is the tuning surface's acceptance gate, enforced concretely
   by the deterministic winnability fixture in §10.2(11).

Because armor-3 is elite-gated (rule 1), the `wraith_elite`/`plate` armor-3 entries in §3.2/§3.3/§4.3
are intentional exceptions, not the common case — the tier ladder (§3.3) still lets armor reach 3 at
tier 5, which is by design an elite-difficulty spike, not a stalemate for a properly-kitted party.

---

## 2. PC / hero stats

### 2.1 Attributes & derived values
- **STR / DEX / WIL** — each `3d6` (3–18) at mint, from injected rng.
  - STR = the death track (overflow sink; STR 0 = death). DEX = evade/order saves. WIL = spell + morale saves.
  - Store both current and max: `str/strMax`, `dex/dexMax`, `wil/wilMax` (attributes drop from overflow/Scars and heal back on rest).
- **HP** — `hp/maxHp`; `maxHp = max(6, (1d6)*4)` (§1.2). `hp` refills to `maxHp` on short safe rest. maxHp stays the only cached derived scalar; Scars can raise it.
- **Armor** — derived from worn gear, `min(3, Σ worn.armor)`. Not persisted as a base; recomputed like maxHp is today.

### 2.2 Concrete field changes — `shared/entities.ts`
`Stats` (L40–45): collapse `{ might, focus, sureHands }` → `{ str, dex, wil }` (keep the open `[key:string]: number`).

`Character` (§2.2, L75–98):
- **Remove:** `level`, `xp`, `focusMeter`, `abilities: AbilityRef[]` (class-unlock ladder). `classId` **stays** (cosmetic archetype, §2.4).
- **Change:** `stats: Stats` now holds `str/dex/wil`; add `strMax/dexMax/wilMax` (either on `stats` or as siblings — put them on `stats` to keep the block cohesive: `{ str, strMax, dex, dexMax, wil, wilMax }`).
- **Add:** `deprived: boolean` (derived: inventory full → blocks HP recovery). `scars: number[]` (record of d12 Scar rolls, permanent). `doomed?: boolean` (set by Scar row 12, consumed by the next failed Critical Damage save — §6.4/§6.6). `fatigue` is not a scalar — Fatigue is inventory items (§4), so `deprived` is computed from slot usage.
- **Keep:** `hp`, `maxHp`, `gold`, `status: 'alive'|'downed'`. Replace `equipment`/`inventory` per §4 (single 10-slot inventory with `worn` flags).

`Combatant` derived block (L375–396): shrinks to `{ id, side, name, spriteSubject, hp, maxHp, str, dex, wil, armor, weaponDie, statuses, cooldowns, telegraph, animState }`. Remove `atk/def/spd?/acc/eva/critChance/focusMeter/element/weakness/resist` as *combat drivers* (see §7 for what stays optional on the wire). `spd` may remain internally for initiative ordering but is not a Cairn stat.

### 2.3 Fate of classes, XP, leveling
- **XP/levels DELETED.** Progression is horizontal: Scars (§6) + gear (better die, more Armor, Spellbooks).
- `deriveHeroCombatant` stops reading `level` entirely.
- `makeCharacter` (`server/sim/world.ts` L75–111) becomes rng-injected: roll `str/dex/wil = 3d6`, `maxHp = max(6,(1d6)*4)`, `hp = maxHp`, `armor` from starting gear, 10-slot inventory seeded with a starting weapon (and a Spellbook for wizard-flavor). No `level/xp/abilities`.

### 2.4 Classes → cosmetic archetype  ✅ DECIDED
**`classId` is purely cosmetic.** It carries **no** mechanical distinction — no class-gated spells,
no class stat curves, no class levels. Its *only* jobs are: (1) sprite subject + name, (2) a soft
attribute lean, and (3) **which starting gear is placed in the fresh 10-slot inventory.** After turn
one, a hero is defined entirely by attributes + carried gear (Cairn-classless): a wizard who loots a
sword and plate *is* a knight; a knight who loots a Firebolt spellbook can cast it. Nothing reads
`classId` in resolution.

**Starting packages** (dropped into `inventory` by `makeCharacter`, §2.2/`world.ts`; each is a
concrete list of `Item`s, worn flags set). Every package clears the §1.4 `weaponDie ≥ armor+2`
winnability band against the armor-≤2 standard world:

| classId | lead attr (best 3d6 roll) | worn weapon | worn armor | spellbook(s) | total armor |
|---|---|---|---|---|:--:|
| `knight` | **STR** | `sword` (d8) | `leather` (+1) + `shield` (+1) | — | **2** |
| `ranger` | **DEX** | `bow` (d6) | `leather` (+1) | `blink` (Roll/dodge — DEX-save negate) | **1** |
| `wizard` | **WIL** | `dagger` (d4, emergency only) | — | `firebolt` (d10, `ignoreArmor:1` — the real weapon) | **0** |

- **"Best roll to X"** = of the three rolled 3d6 values, assign the highest to the class's lead
  attribute; the other two fill the remaining attributes in fixed order (STR>DEX>WIL) — deterministic,
  stable tiebreak. This is a lean, not a lock: it just biases the starting sheet.
- Spellbooks occupy inventory slots like any loot (§5.1); the wizard opens with 1 free slot so it can
  actually cast (Firebolt → Fatigue) on turn one.
- The packages are data: a `STARTER_KITS: Record<ClassId, ItemDef['defId'][]>` table in
  `shared/tuning.ts`, expanded to `Item`s at character creation. Adding/retuning a package is a
  one-line data edit, never a code change — reinforcing that class = loadout, nothing more.

### 2.5 `server/sim/systems/progression.ts`
Mostly **deleted**. Replace with rng-injected helpers:
- `rollScar(c, rng)` — d12 Scars table application (§6.4).
- `shortRest(c)` — unless `c.deprived`: `c.hp = c.maxHp`; clear all Fatigue items from inventory;
  and **fully restore dropped attributes to their max** (`c.str = c.strMax; c.dex = c.dexMax;
  c.wil = c.wilMax`). Attribute drops from combat overflow (§6.4) are temporary and heal to max on a
  safe rest — the only permanent effects are the Scar `maxHp`/attribute **raises** (which stay) and an
  unspent `doomed` flag. A rest does **not** clear `c.scars` (permanent record) and does **not** clear
  `doomed` (RAW: it rides until the next crit save resolves it, §6.6 row 12).
- `killXp`/`sealXp` deleted; `EncounterEndMsg.xpGained` becomes `0`/omitted (kept on wire for compat, §7).

---

## 3. Mob stat blocks

### 3.1 Cairn block shape — `shared/mobs.ts` (`MobDef`)
Replace the `atk/def/spd/acc/eva/crit` numeric block with:
```ts
interface MobDef {
  defId: string;
  spriteSubject: string;
  hpDie: number;        // faces of the HP die (default 6); maxHP = hpDie roll * hpMult (§3.3)
  hpMult: number;       // phone-scale band: weak 3, standard 4, elite 5
  hpFlat?: number;      // added after the *mult (elite bump)
  armor: number;        // 0..3
  str: number; dex: number; wil: number;  // wil = morale save target
  weaponDie: DieStep;   // 4|6|8|10|12
  element: Element;     // KEPT: cosmetic + optional weakness die-bump house layer
  weakness: Element; resist: Element;      // KEPT (optional die-step house rule, §6.5)
  behavior: 'guard'|'roam'|'pursue'|'flee';
  aggroRange: number;
  moraleImmune?: boolean;   // undead/rooted never flee
  gimmick?: string;         // discriminant read by combat.ts special-case switch
  xp: number; gold: number; // gold = live payout (KEPT). xp = INERT wire-compat payload only —
                            //   minted + tier-scaled for shape stability but NEVER summed anywhere
                            //   (addXp/killXp/sealXp are deleted, §2.5). Do not resurrect a consumer.
}
```
HP is rolled at spawn from injected rng: `maxHp = max(6, rng.int(1,hpDie)*hpMult + (hpFlat??0))`.

### 3.2 The 8 converted breeds
Armor ≈ `round(def/2)` capped 3; weaponDie bucketed from old `atk` (≤7→d6, 8–11→d8, 12–13→d8/d10, ≥16→d10+); WIL from behavior (flee≈7, guard/undead≈13, pursue≈12, elite 15); hpMult from old base-hp band. All rolls injected-rng.

| breed | hpDie×mult(+flat) | Armor | STR | DEX | WIL | weaponDie | element/weak/resist | gimmick |
|---|---|:--:|:--:|:--:|:--:|---|---|---|
| **goblin** | 1d6×3 | 1 | 7 | 12 | 7 | d6 | phys / fire / frost | `skittish` — first-casualty morale WIL save at **−2 penalty** (breaks early; old `flee`). |
| **skeleton** | 1d6×4 | 2 | 11 | 6 | 13, `moraleImmune` | d8 | phys / blunt / pierce | `brittle` — blunt attacks step **+1 die** vs it; pierce attacks step **−1**; never flees. |
| **flying_eye** | 1d6×3 | 1 | 6 | 15 | 9 | d8 | shadow / light / shadow | `evasive_flyer` — attacks vs it are **impaired −1 step**; light attacks step **+1**. |
| **mushroom** | 1d6×4 | 0 | 12 | 4 | 13, `moraleImmune` | d6 | acid / fire / acid | `spore_burst` — on exact-0 death, all adjacent add **1 Fatigue** (WIL save avoids); fire steps **+1**. |
| **demon** | 1d6×3 | 1 | 10 | 11 | 12 | d8 | fire / frost / fire | `burning_strike` — on a non-MISS hit, target **STR save or +1d4 fire** next turn; frost steps **+1**. |
| **slime** | 1d6×3 | 0 | 11 | 7 | 8 | d6 | acid / shock / pierce | `split` — first time it hits 0 HP, on a failed handler roll it **divides** into a 1-HP slime instead of dying; shock steps **+1**. |
| **wraith** | 1d6×4 | 2 | 8 | 13 | 12 | d10 | shadow / light / shadow | `incorporeal` — non-light weapons impaired **−1 step**; no morale while it has a target (`pursue`). |
| **wraith_elite** | 1d6×5 **+4** | 3 | 12 | 14 | 15, `moraleImmune` | d10 → **enhanced d12** | shadow / light / shadow | `the_hunter` — never routs; on disengage **pursues into the world map** (§4.5C chase); incorporeal; shadow strike **ignores 1 Armor**. |

`ENEMY_ORDER` stays the 7-breed garrison pool; `wraith_elite` stays excluded (elite-only).

### 3.3 How "tier" scales a Cairn block — `shared/tuning.ts` (replace L74–77 `tierHpMult`/`tierAtkMult`)
Prefer **die-step + Armor + HP-die-step** over raw HP inflation. Tier clamped 1–5 in `mkMonster` (garrison clamps to 4). All draws injected-rng.

| tier | HP | Armor | weaponDie | WIL/morale |
|--:|---|:--:|---|:--:|
| 1 | roll ×mult **take lower of 2** | base | **−1 step** | −2 |
| 2 | base (reference) | base | base | base |
| 3 | **+1 HP-die step** (d6→d8) **+2** | **+1** (cap 3) | **+1 step** | +1 |
| 4 | +1 step, **take higher of 2** | +1 (cap 3) | +1 step (cap d12) | +2 |
| 5 | +2 steps / 2d6-take-higher ×mult +4 | cap 3 | **enhanced** (cap d12) | +3 |

`gold` keeps the existing `ECON.*TierMult` scalars untouched (live payout). `tierXpMult` and
`MobDef.xp` are retained **only as inert wire-compat payload** — tier-scaled for shape stability but
never summed into progression (XP/levels are DELETED, §1.3/§2.5). They may be dropped in a later
cleanup pass; keeping them now avoids touching `resolveKill`/`grantWinRewards` payload shape.

### 3.4 Changes to `server/sim/systems/spawns.ts`
- `mkMonster(key, tier, id, pos, homeBreachId)` (L438–474): replace the `hp = base.hp*tierHpMult[t]` / `atk = base.atk*tierAtkMult[t]` body with: roll HP via `hpDie/hpMult` and the tier HP rule (§3.3); set `armor`, `weaponDie` (with tier die-step), `str/dex/wil` (with tier WIL bump), `element/weakness/resist`, `gimmick`, `moraleImmune`. Store on the `Monster`. Keep `tier`, `maxHp`, `telegraph:null`, `animState:'idle'`.
- `buildSandboxMonster` (L484–486): unchanged wrapper (origin, `homeBreachId:''`).
- `buildGarrison` (L494–505): unchanged structure; still party-scaled, still draws from the same `(spawnSeed, encTier, partyN)` rng so blocks stay byte-identical.

---

## 4. Loot / item stats

### 4.1 Item data shape
`DieStep = 4 | 6 | 8 | 10 | 12`.

New `ItemDef` (replace `shared/items.ts` L13–32):
```ts
interface ItemDef {
  defId: string; name: string;
  kind: 'weapon'|'armor'|'shield'|'helm'|'spellbook'|'consumable'|'pack';
  slots: 1 | 2;              // Fatigue-inventory footprint; bulky = 2
  die?: DieStep;             // weapons
  armor?: number;            // armor/shield/helm — value while worn (0..3, world-clamped to 3 total)
  spellId?: string;          // spellbooks — one spell each
  element?: Element;         // cosmetic + optional weakness house layer
  tag?: string;              // descriptive trait ('venomous','warding') — NOT a stat stack
  tier: number;              // min drop tier (kept)
  value: number;             // gold floor (kept)
}
```

New runtime `Item` (replace `shared/entities.ts` L104–127):
```ts
interface Item {
  id: string; defId: string; kind: ItemKind; slots: 1 | 2;
  die?: DieStep; armor?: number; spellId?: string;
  element?: Element; tag?: string;
  worn?: boolean;           // replaces the 3 fixed Equipment slots
  qty: number; value: number; name?: string; seed?: number;
}
```
Fatigue is just `{ defId:'fatigue', kind:'consumable', slots:1 }` occupying a slot.

### 4.2 Inventory model — 10-slot Fatigue inventory (cap 3 armor)
- **Delete `Equipment {weapon,armor,trinket}`** and the 40-slot bag. One `inventory: Item[]`; capacity `ECON.slotCap = 10` measured as `Σ slots` (bulky=2, Fatigue=1), **not array length**.
- "Equipped" = `worn:true`. Active weapon = the worn weapon (`die`, else unarmed d4). Total armor = `min(3, Σ worn.armor)`.
- **Deprived** = `usedSlots >= 10` → blocks HP recovery on rest.

### 4.3 Catalog rewrite — `shared/items.ts` `ITEM_DEFS`
- Rescale weapons onto the die ladder: daggers/bows d6, swords/axes d8, greatweapons d10. Drop `for:` class-locks (Cairn is classless) except optional spellbook affinity.
- Armor onto 0–3: cap/leather +1, mail +2, plate +3, shield +1, helm +1. Drop `hp` mods (HP is no longer gear-driven).
- **Fill the wizard gap:** add **Spellbook items** (one `spellId` each) reusing the spell ids in §5.
- Retire `AffixDef` / `AFFIX_POOL` / `affixLegalFor` entirely (no `+atk/+crit/+acc/+dodge` rolls).

### 4.4 Loot roll — how rolls pick die/armor/spellbook — `server/sim/systems/loot.ts`
Keep the **seed-determinism spine** (`mintDropItem` substream seeding L197–208, fixed draw order, `hashSeed` ids, co-op instancing, `same_seed_same_loot`). Swap only the decoration body:
1. **Category pick** (analog of `pickBase` L126–133): weighted over `weapon | armor | shield/helm | spellbook`, gated by `tier`.
2. **Weapon:** pick base `die`, then a **step roll** — repurpose `ECON.rarityOdds` (tuning L221–227) into a die-step bias: old rarity 0..4 → step offset `{−1, 0, 0, +1, +1}` (enhanced d12 = the Cairn "rare"). Clamp d4..d12.
3. **Armor:** pick base value 0..3 with the same tier-biased step; a rarer roll may grant a `tag`, but **never** pushes total past the cap-3 world clamp (enforced at wear time).
4. **Spellbook:** pick one `spellId` from the spell pool (§5), tier-gated by spell tier; always `slots:1`.
5. **Power/value** (`itemPower` L70–83, `itemValue` L86–92): derive from `die` (weapon), `armor·k` (armor), or `spellTier·k` (spellbook) instead of weighted mods.
- `resolveKill`/`grantWinRewards`/`grantAmbientRewards`/chest-pry keep their structure; only the item they mint changes shape.

### 4.5 Tuning swap — `shared/tuning.ts`
- **Retire:** `wAtk/wDef/wHp/wDodge/fxPower`, `rarityAffixCount`, `affixTierWeights`, most of `catValue`, all crit/acc/dodge combat consts.
- **Add:** `dieLadder=[4,6,8,10,12]`, `armorCap=3`, `slotCap=10`, `startHpDie=6`, `hpMult=4`, `unarmedDie=4`, `dieStepOdds[tier]` (reuse `rarityOdds` shape), the Spellbook pool, the d12 Scars table, and morale-save config.

### 4.6 Equipment system — `server/sim/systems/equipment.ts`
- `EQUIP_SLOTS` array deleted. `gearSum` → `wornWeaponDie(inv)` + `wornArmor(inv)` (clamp 3); weapon slot no longer folds `element` into a stat block.
- `equipItem` → `setWorn(itemId, worn)`: validate `Σ worn armor ≤ 3` and at most one active weapon.
- `recomputeMaxHp` **deleted** (HP not gear-driven); add `recomputeArmor` + `usedSlots`/`deprived` accounting.

---

## 5. Spells / spellbooks

### 5.1 Model
- A spell is a **Spellbook Item** (`kind:'spellbook'`, `slots:1`, one `spellId`). Knowing = carrying.
- **Cast:** legal when inventory has a free slot (to hold the Fatigue it creates). Effect resolves, then **add 1 Fatigue item** (`slots:1`; Heavy spells add 2 = a bulky Fatigue). Fatigue removed on safe rest.
- **Under duress:** casting while **Deprived** or **in danger** (in an active encounter) → **WIL save** (`d20 ≤ wil`); fail → consequence (take the spell's own die, or lose the action).
- No cooldowns, no Focus. Slot pressure + Fatigue is the throttle. (Optionally keep a soft "once per rest" on Heavy spells.)

### 5.2 Spell definitions — replace `ABILITIES` (tuning L435–460) with `SPELLS`
Shape: `{ spellId, name, die?: DieStep, targets:'one'|'two'|'all'|'self'|'party', save?: 'STR'|'DEX'|'WIL', effect: <discriminant>, heavy?: boolean, ignoreArmor?: number, element?: Element, tier }`.

| spellId | name | targets | die | effect | heavy |
|---|---|---|---|---|:--:|
| `firebolt` | Firebolt | one | d10 fire | `ignoreArmor:1`; enhanced (d12) vs fire-weak | |
| `frostbind` | Frostbind (frost_nova) | all | d6 frost | STR save or **impaired** (attack die −1, acts last) 2 rounds | |
| `falling_star` | Falling Star (meteor) | all | d12 fire | STR save or **stagger** (lose next action); cast-in-danger WIL save or take the d12 yourself | ✔ |
| `ward` | Ward (arcane_barrier/bulwark) | party | — | +2 **temporary Armor** (worn) 3 rounds; absorbs before HP | |
| `hunters_mark` | Hunter's Mark | one | — | all attacks vs target **enhanced +1 step** until dead / 3 rounds | |
| `called_shot` | Called Shot | one | d12 pierce | `ignoreArmor:∞`; vs a **marked** foe overflow spills straight to STR (auto-Critical) | ✔ |
| `sunder` | Sunder | one | d10 blunt | target **−1 Armor** 2 rounds; exact-0 → Scars | ✔ |
| `heavy_strike` | Heavy Strike | one | d10 blunt | STR save or **stagger** 1 round | |
| `volley` | Volley (twin_shot/volley) | two/all | d6 pierce | **bypasses keep-highest gang rule** (deliberate multi-target, one die per target) | |
| `blink` | Blink / Roll | self | — | next incoming attack this round → **DEX save** to negate; Blink also **discards 1 Fatigue** | |
| — | Slash / Shot / Arcane Bolt | one | d6/d8 | ordinary weapon attacks, no Fatigue — the free-cast floor | |

### 5.3 Status carry-over
| old status | Cairn encoding |
|---|---|
| `stagger` | fail a save → lose next action (blank telegraph); ties into Morale |
| `shield`(34 pool) | **temporary Armor** worn for TTL (Ward) — absorbs before HP |
| `mark`(+30%) | target attacked at **enhanced +1 die step** |
| `def_break`(−6) | target **Armor −1..2** (cap-3 world) |
| `slow`(−5) | **impaired** — attack die −1 step and acts last |
| `evade`(55%) | **DEX save** negates one incoming hit (Blink/Roll) |

Statuses remain `Combatant.statuses: string[]` + `cooldowns` on the wire (unchanged shape); magnitudes/TTL move into a small internal status table in `combat.ts`. Aging still happens at end of round via the existing `tickStatuses`.

### 5.4 Files touched
`shared/tuning.ts` (`ABILITIES`→`SPELLS`), `shared/items.ts` (spellbook catalog), `shared/abilities.ts` (`abilitiesFor` deleted / replaced by "spellbooks in inventory"), `server/sim/systems/combat.ts` (cast resolution, Fatigue add, WIL save), `web/src/ui/kit/CommandPanel.tsx` (§8).

**`server/sim/commands.ts` — the `OP.USE_ABILITY` path (L119–127) must change.** Today it calls
`submitAbility(world, enc, self.id, cmd.abilityId, …)` which validates the ability is UNLOCKED, off
cooldown, and **Focus-affordable** (L120–121 comment). In the Cairn model:
- **Reuse the OP unchanged** (§7: no OP added/renumbered). Treat `cmd.abilityId` as the **`spellId`**
  of a Spellbook the hero is carrying — no renumber, no wire change, purely a reinterpretation.
- Rewrite `submitAbility` → `submitCast(world, enc, heroId, spellId, targetId, timing, now)`:
  validate (1) the hero **carries a Spellbook with that `spellId`** (replaces the "ability unlocked"
  check — kit now comes from inventory, not the class ladder, §5.1), and (2) there is a **free
  inventory slot** to hold the Fatigue the cast creates (replaces Focus-affordability). **Delete the
  Focus/`canAfford`/cooldown gate entirely.** A cast that would go Deprived, or a cast-in-danger, does
  NOT reject at the command layer — it is admitted and the **WIL save** is resolved inside
  `resolveRound`/combat.ts (§5.1/§8.3), so the failure is a game event, not a wire `ERR`.
- Error code on illegal cast (no such spellbook / no free slot) stays the existing `err(...)` shape.
- The `OP.GUARD` path may stay as-is or be repurposed later; it is out of scope for Focus removal
  except that `submitGuard`'s Focus refund (`combat.ts` L796–797) is deleted with the rest of Focus.

---

## 6. Combat resolution algorithm — `server/sim/systems/combat.ts`

### 6.1 Turn structure (KEEP skeleton)
`command` (submit window, `deadlineMs`) → `resolveRound` (synchronous) → advance or `end`. Auto-fill missing heroes with a basic attack. All rng from `seededRng(world.seed, 'combat', breachId, round)`, drawn in a **fixed order**.

### 6.2 `deriveHeroCombatant` / `deriveEnemyCombatant`
Replace the atk/def/acc/eva/crit block:
```
weaponDie = wornWeapon?.die ?? UNARMED_DIE(4)
armor     = min(3, Σ worn.armor)   // enemy: mob.armor
{ str, dex, wil } from stats/mob
{ hp, maxHp } as-is
```

### 6.3 Damage — replace `computeDamage`
```
function resolveStrike(attackers, target, spell?, rng):
  # collect dice
  if spell && spell.targets in {two,all}:      # multi-target: one die per target, no gang keep-highest
      die = spell.die ?? attacker.weaponDie
      net = strikeOne(die, attacker, target, spell, rng)
  else:
      # GANG-UP keep-highest: roll every attacker's die on this foe, keep the max
      dice = [ effectiveDie(a, target, spell) for a in attackers ]   # apply enhance/impair steps
      rolls = [ rng.int(1, d) for d in dice ]    # fixed order = attackers order
      best  = max(rolls)
      # the single winning attacker's armor-piercing applies (keep its index)
      winner = attackers[argmax(rolls)]
      net   = applyArmor(best, target, spell, winner)
  applyNet(net, target, attackers, rng)

# "ignore N armor" is an ATTACKER/spell property (attacker.ignoreArmor), NOT a defender field.
# ignoreN = (spell?.ignoreArmor ?? 0) + (attacker.gimmick=='the_hunter' ? 1 : 0)  # the_hunter shadow strike ignores 1 Armor
function ignoreArmorFor(attacker, spell):
  n = spell?.ignoreArmor ?? 0
  if attacker.gimmick == 'the_hunter': n += 1
  return n
function applyArmor(roll, target, spell, attacker):
  armor = max(0, target.armor - ignoreArmorFor(attacker, spell))
  return max(0, roll - armor)

function applyNet(net, target, attackers, rng):
  if net == 0:
      emit CombatEvent{kind:'miss', sourceId, targetId, note:'armor'}   # HOUSE RULE
      return
  emit CombatEvent{kind:'hit', amount:net, targetId}
  overflow = net - target.hp
  target.hp = max(0, target.hp - net)
  if target.hp == 0 and overflow < 0? ...   # see below (exact-0 vs overflow)
```

### 6.4 Exact-0 (Scars) vs overflow (Critical Damage) — the precise branch
Let `dmg = net`, `hpBefore = target.hp`.
```
if dmg < hpBefore:            # ordinary hit, still standing
    target.hp -= dmg
elif dmg == hpBefore:         # HP reduced to EXACTLY 0  → SCARS
    target.hp = 0
    if target.side == 'hero': rollScar(target, dmg, rng)   # row = clamp(dmg,1,12), §6.6 (RAW)
    # enemy at exact 0 = dead (or lone-foe morale save first, §6.7)
else:                         # dmg > hpBefore → OVERFLOW / Critical Damage
    remainder = dmg - hpBefore
    target.hp = 0
    target.str = max(0, target.str - remainder)         # overflow eats STR
    if target.str == 0:
        die(target)                                     # STR 0 = death (heroes included — RAW)
    else:
        # STR save; nat1 auto-success, nat20 auto-fail
        r = rng.int(1,20)
        ok = r == 1 ? true : r == 20 ? false : r <= target.str
        if !ok:
            # DOOMED (Scar 12, RAW §6.6): a hero's doomed flag turns THIS failed save into death.
            if target.side == 'hero' and target.doomed:
                target.doomed = false
                die(target)                              # doomed + failed crit save = death (RAW)
            else:
                criticalDamage(target)                   # removed from fight (hero→'downed', enemy→dead)
                emit CombatEvent{kind:'crit', sourceId, targetId, note:'critical'}
        else if target.side == 'hero' and target.doomed:
            target.doomed = false                        # survived the save → Doomed clears (§6.6 row 12 pass)
```
Ordering note: draw the STR-save d20 **after** the damage die(s), in fixed order, so the stream is stable.

### 6.5 Enhance / impair (die steps)
`effectiveDie(attacker, target, spell)` walks the ladder `[4,6,8,10,12]`:
- +1 step: `mark`/`hunters_mark` on target, weakness match (optional house layer), gimmick bonuses (`brittle` vs blunt, `evasive`/`incorporeal` invert onto attacker as −1).
- −1 step: `impaired`/`slow` status on attacker, resist match, `incorporeal` vs non-light.
- Clamp to `[4,12]`. This replaces element ×1.5/×0.5 multipliers.

### 6.6 Scars — `rollScar(c, dmgLost, rng)` + the SCARS_TABLE (canonical, RAW Cairn 2e)  ✅ DECIDED: RAW
**Q5 resolved → full RAW Cairn lethality** (not softened). This is the authentic Cairn 2e Scars table,
including the two lethal rows (11 Mortal Wound, 12 Doomed) — so a hero **can** die. This deliberately
overrides §6.8's "heroes never permanently die" for these two rows only (see the §6.8 note). Swapping
back to non-lethal later = replace rows 11/12; the rest of the table is pure growth.

**Row selection is NOT a d12 roll.** RAW: "look up the result based on the *amount of HP lost in the
attack*." A Scar triggers only when a strike takes a hero to **exactly 0** (overflow past 0 is the
Critical-Damage path, §6.4). So the row index is the damage of that killing-to-0 blow:
`row = clamp(dmgLostThisAttack, 1, 12)` (bigger hits → worse scars; ≥12 = Doomed). No extra die for the
row itself — deterministic from the damage already rolled. The per-row *effect* dice are injected-rng,
drawn in fixed order right after. Push `{row,name}` onto `c.scars`. Table in `shared/tuning.ts` as
`SCARS_TABLE`; `rollScar` in `progression.ts` applies it.

**Phone-scaling of the growth rows.** RAW raise-dice (1d6…3d6) are tuned to RAW HP (~1–6). Our maxHp is
×`hpMult` (§1.2), so raw dice would almost never beat it and every growth row would be inert. Fix: **HP
raises scale the die total by `hpMult`; attribute raises stay raw** (attributes are un-scaled 3–18).
Helpers (fixed order — roll all dice first, then compare/apply):
```
raiseMaxHp(c, nDice, die, rng):      # "if higher" rows — HP raises scale ×hpMult (=4, §1.2)
  v = sumRoll(nDice, die, rng) * hpMult
  if v > c.maxHp: c.maxHp = v; c.hp = c.maxHp
addMaxHp(c, nDice, die, rng):        # row 3 — a guaranteed add, also scaled
  c.maxHp += sumRoll(nDice, die, rng) * hpMult; c.hp = c.maxHp
raiseAttr(c, attr, nDice, die, rng): # attr rows — raw dice vs raw max attribute
  v = sumRoll(nDice, die, rng)
  if v > c[attr+'Max']: c[attr+'Max'] = v; c[attr] = c[attr+'Max']
bumpAttrOnSave(c, attr, die, rng):   # rows 8/10 — WIL save, on pass raise max attr by +1dN (raw)
  if d20 <= c.wil: c[attr+'Max'] += rng.int(1,die); c[attr] = c[attr+'Max']
```

| row (=HP lost) | name | mechanical effect (RAW, HP-dice ×hpMult) |
|--:|---|---|
| 1 | **Lasting Scar** | flavor location (1d6); `raiseMaxHp(c, 1, 6)`. |
| 2 | **Rattling Blow** | `raiseMaxHp(c, 1, 6)`. |
| 3 | **Walloped** | **Deprived** until a few hours' rest, then `addMaxHp(c, 1, 6)` (guaranteed). |
| 4 | **Broken Limb** | 1d6 location; once mended, `raiseMaxHp(c, 2, 6)`. |
| 5 | **Diseased** | on recovery, `raiseMaxHp(c, 2, 6)`. |
| 6 | **Reorienting Head Wound** | random attr (1d6→STR/DEX/WIL); `raiseAttr(c, attr, 3, 6)`. |
| 7 | **Hamstrung** | `raiseAttr(c, 'dex', 3, 6)`. |
| 8 | **Deafened** | `bumpAttrOnSave(c, 'wil', 4)` (WIL save → +1d4 max WIL). |
| 9 | **Re-brained** | `raiseAttr(c, 'wil', 3, 6)`. |
| 10 | **Sundered** | appendage lost (cosmetic); `bumpAttrOnSave(c, 'wil', 6)`. |
| 11 | **Mortal Wound** ⚠️ | **LETHAL:** hero → `downed` + `dying` (Deprived, out of action). **Dies at encounter end unless healed/revived before then** (our real-time map of "die in one hour"). On recovery: `raiseMaxHp` set to `2d6·hpMult` (take the new result). |
| 12 | **Doomed** ⚠️ | **LETHAL:** set `c.doomed = true`. On the **next** Critical-Damage STR-save (§6.4): fail → **death**; pass → clear the flag and `raiseMaxHp(c, 3, 6)`. |

Because `row = clamp(dmgLost, 1, 12)`, the lethal rows 11/12 fire only when a single blow strips ≥11 HP
while landing exactly on 0 — a genuinely huge hit, so death-by-Scar stays rare but real (RAW intent).

### 6.7 Morale — enemies only
After each casualty in `resolveRound`, for each living enemy that is not `moraleImmune`:
- On **first casualty** and again at **half strength** (half the garrison's original count lost): WIL save `d20 ≤ wil` (goblin `skittish` at −2). Fail → set `behavior='flee'`/surrender → they disengage (feeds existing flee handling).
- **Lone foe** saves when reduced to 0 HP instead.
- PCs never roll morale.

### 6.8 Death / outcomes  (RAW lethality via Scars)
`win` (no enemies) / `downed` (no heroes) / `flee`. **Default** hero Critical Damage / STR-0 →
`status:'downed'` (wake-at-camp, full heal on rest) — the ordinary case is still non-lethal.
**RAW exceptions (§6.6, Q5=RAW):** a hero **dies permanently** in exactly two paths — (a) **Mortal Wound**
(Scar 11): `downed` + `dying`, and if the encounter ends without a heal/revive, `die()`; (b) **Doomed**
(Scar 12) followed by a failed Critical-Damage STR-save. `die(hero)` removes the character from the world
(prototype: the save is wiped anyway, Q4). Enemy death removes it. Seal chip: keep, rescale its `dmg`
input to the new net scale. `EncounterEndMsg` needs no new field — a dead hero simply isn't in the party
on the next frame; the client shows a death screen when `self` is gone/`dying` unhealed at end.

### 6.9 Deleted from this file
`classifyTiming`, timing bands, `computeDamage` multiplicative path, hit-chance roll, `spendFocus`/`canAfford`/Focus regen, `absorbShield` pool, `evade` dodge-roll, guard 0.7 mitigate, `mark/def_break/slow` magnitude math (remapped to steps). `initiativeOrder` keeps spd+jitter minus the `slow` term.

---

## 7. Wire protocol — `shared/protocol.ts`

**No OP added, removed, renumbered, or repurposed. The enum stays at exactly 33 members** (client 1–17, server 100–115). `ProtocolVersion` stays `1` (additive-only).

### 7.1 Additive OPTIONAL fields on `Combatant` (all `?`, old clients ignore)
| field | type | meaning |
|---|---|---|
| `str?` | number | STR attribute (overflow/death track + STR saves) |
| `dex?` | number | DEX attribute (evade/order saves) |
| `wil?` | number | WIL attribute (spell + morale saves) |
| `armor?` | number | Armor 0..3, subtracted from weaponDie |
| `weaponDie?` | number | 4/6/8/10/12 — drives auto-hit damage; also what the enemy telegraph shows |
| `scars?` | number[] | d12 Scar results (permanent) |
| `deprived?` | boolean | full-inventory flag (blocks HP recovery) |
| `fatigue?` | number | Fatigue slots consumed |

Existing `atk/def/acc/eva/critChance/focusMeter/element/weakness/resist` become **optional/vestigial** — leave them on the interface as `?` for one version so no non-JS client breaks, populate only `element/weakness/resist` (still meaningful as flavor), and stop reading the rest. `ENCOUNTER_UPDATE.focusMeter` stays on the wire (send `0`); mark deprecated.

### 7.2 Everything else needs zero wire change
- **MISS** rides the existing `CombatEvent{kind:'miss', note?}` — no new field.
- **Critical Damage / crit** rides existing `kind:'crit'` (+ `note:'critical'`).
- **Scar** may reuse `kind:'status'` with `note`, or (cleaner) add `'scar'` to the `CombatEvent.kind` union in `entities.ts` — a union widening, still additive, old clients fall through.
- Morale flee/surrender → existing `kind:'downed'` + `EncounterEndMsg.result:'flee'`.
- Gang-up keep-highest, short-rest refill, STR overflow are pure server resolution → ordinary events + updated `hp`/`str`.
- `EncounterEndMsg.xpGained` stays required (send `0`); `levelUp?` simply never sent.

---

## 8. Client changes — `web/src/render` + `web/src/ui`

### 8.1 HUD: STR / HP / Armor (drop Focus) — `CombatScreen.tsx`
- **Remove** `focus`/`focusPct`/`COMBAT.maxFocus` (L129,155) and the `.mp` bar (L162–170).
- HP bar stays but relabel; values are tiny (6–24) — render as a short bar or pips. Add a **STR track** (the real life meter; overflow eats it) and an **Armor readout** (icon + number, cap 3). Optionally show DEX/WIL for save context.
- Enemy `TelegraphChip` (L252–260): HP bar stays; the `estDamage` telegraph reads as the **weapon die** ("d8") since damage is `die − your armor`.
- A **save-prompt overlay** where the crit banner sits (L200–206): `STR SAVE 11 ≤ 14 ✓` / `✗ DYING`.

### 8.2 Damage + 0-as-MISS render (reuse `juice.ts`)
- **No change needed** to the float pipeline: `floatText()` (`juice.ts:173–215`) already renders grey `'MISS'` for `kind:'miss'` and `ev.amount` for `hit`. Sim emits `miss` when `net===0`, `hit` otherwise. `DMG_COLOR.miss = #b9b2a0`, 16px, already present.
- Hit-flash (`combat.ts:223–241`) keys on `hit|crit` only → MISS correctly gets the soft treatment (grey float, no red flash). Gang-up = one `hit` event with the max → one number, no client change.
- Repoint the `crit` styling (gold ✦, banner, shake) to **Critical Damage** (overflow → STR). STR→0 → existing `downed` fade (`alpha 0.4`).

### 8.3 Spellbook actions — `kit/CommandPanel.tsx` + `CombatScreen.tsx`
- Source actions from **inventory Spellbook items** (`worn`/carried), not `knownAbilityDefs`/class abilities (drop L130–149 ability build).
- Remove `costPips`/`cost`/`costMax` (Focus). Sub-label shows **"+1 Fatigue"** (or "+2" Heavy). Keep the `magic` teal tint for spellbooks.
- Gating: `disabled = noFreeSlot || locked` (can't hold the Fatigue → would go Deprived). Casting while Deprived/in-danger triggers the **WIL save** overlay (same pattern as STR save).
- The button's `×{coeff}` damage field → show the **weapon/spell die** ("d10").

### 8.4 Scar UI (new)
- Sim emits `CombatEvent{kind:'scar', ...}` (union widening §7.2) with the d12 roll + resolved text.
- Present a dedicated **Scar card** overlay (narrative, distinct from the crit banner); if the Scar raises HP/attribute, run `hpGhostFrac` (`juice.ts:227–234`) in reverse to animate the track up. Reduced-motion → clean end state (screenshot-stable).
- Trigger is exactly **HP landed on 0** (not overflow) — the sim distinguishes the two branches (§6.4), so the client just reacts to the event.

### 8.5 Morale (light)
Failed enemy morale save → a "Fleeing" status badge (`STATUS_LABEL`) or a flee telegraph on the chip. Reuses existing `downed`/status rendering.

### 8.6 Non-combat client surfaces — `web/src/App.tsx` character sheet + shared kit/css
The character sheet and a few kit/store files read the **deleted** stat/equipment/level fields and
would render `undefined`/dead UI. These are OUTSIDE `CombatScreen`/`CommandPanel` and must be fixed:
- **`web/src/App.tsx` character sheet (`tab==='hero'`, L1300–1319):**
  - Replace the three `StatPip` reads `self.stats.might / .focus / .sureHands` (L1310–1312) with
    **`STR/DEX/WIL`** from `self.stats.str/.dex/.wil` (add a small maxHP/Armor readout alongside to
    match the new model).
  - Replace the three fixed `EquipSlot` refs `self.equipment.weapon/.armor/.trinket` (L1305–1307) and
    the `EquipSlot` component (L1351) with the **worn-inventory** model (§4.2): render the single
    10-slot `inventory`, marking `item.worn` items as equipped; there are no fixed weapon/armor/trinket
    slots anymore. The paperdoll `sq-equip-ring` becomes a worn-items strip.
  - Drop the `Level` row (L1316, `self.level`) and the header `HexBadge label="Lvl" value={self.level}`
    + `xpToNext(self.level)` XP bar (L642, L649) — XP/levels are DELETED (§2.3). Replace the Lvl badge
    with an Armor or Scar-count badge, or remove it.
- **`web/src/store/store.ts` (L292, L317):** the op105/char-refresh comments and any `focusMeter` /
  `self.level`/`self.xp` field copies must stop referencing Focus/level. `focusMeter` still arrives on
  the wire as `0` (§7.1, deprecated) — the store may ignore it; drop level/xp handling.
- **`web/src/ui/kit/Hex.tsx` (L23):** the `FOCUS` stat-color entry in the `StatPip` color map is dead
  once no caller passes `label="FOCUS"` — repoint/rename the palette to `STR/DEX/WIL` (and update the
  L1–2 doc comment listing `STR/AGI/MAG/DEF/LCK`). `Gallery.tsx`'s demo `StatPip` labels are cosmetic
  but should be refreshed to STR/DEX/WIL for consistency.
- **`web/src/styles/app.css` (L193) + `web/src/ui/css/kit.css` (L101):** the `.mp` (Focus/mana) bar
  fill rules are orphaned once the Focus bar is removed from `CombatScreen` (§8.1) — delete both `.mp`
  rules.

**Phase exit gate (§11.1 phase 6 client):** before calling the client phase done, run
`grep -rniE 'focus|might|sureHands|equipment\.|focusMeter|xpToNext|\.mp\b' web/src` and
`grep -rniE 'focus|might|sureHands|killXp|sealXp|canAfford|focusCost' server/sim` — every surviving
hit must be either an intentional deprecated wire field (§7.1) or a CSS `:focus` selector, nothing
that reads a deleted Character/Stats field. This grep is the concrete completeness check that Focus
and the old stat/equipment model are fully removed on **both** client and server.

Determinism: all render timing keeps reading the injected `clockMs`; no `Date.now`/`Math.random` in render/juice (the DOM's `Date.now()` intent stamps are network I/O and stay).

---

## 9. Files to ADD / CHANGE / DELETE

### DELETE
| Path | Why |
|---|---|
| `test/balance/runner.ts` | balance sweep engine (see §10 blocker: extract `percentile` first) |
| `test/balance/knight-vs-tier3.bench.ts` | flagship win-rate guardrail |
| `test/balance/sweep.spec.ts` | sweep-engine coverage |
| `test/balance/economy-balance.spec.ts` | gold faucet/sink arc |
| `test/balance/loot-distribution.spec.ts` | **MOVE** to `test/unit/` (loot invariant, survives) — or delete if loot golden covers it |
| `test/balance/pry-ev.spec.ts` | **MOVE** to `test/unit/` (loot invariant) |
| `test/reports/**` | generated, gitignored runner output |
| `shared/abilities.ts` `abilitiesFor` + `ABILITIES` unlock ladder | classes no longer drive kits |
| Focus/timing dead code in `combat.ts` | `classifyTiming`, Focus economy, absorbShield, evade-roll, guard-mitigate |
| `AffixDef`/`AFFIX_POOL`/`affixLegalFor` in `shared/items.ts` | no affix stat rolls |
| XP/level machinery in `progression.ts` | horizontal progression |

### CHANGE
| Path | Change |
|---|---|
| `shared/entities.ts` | `Stats`→str/dex/wil(+max); `Character` drop level/xp/focusMeter/abilities, add scars/deprived; new `Item`, drop `Equipment`; `Combatant` shrink; widen `CombatEvent.kind` with `'scar'` |
| `shared/tuning.ts` | gut COMBAT atk/def/acc/eva/crit/focus + `ECON.class` growth + XP curve + `tierHp/AtkMult`; add die ladder, armorCap, slotCap, HP scale, `dieStepOdds`, Scars table, morale config, `SPELLS` |
| `shared/mobs.ts` | `MobDef` → Cairn block; convert all 8 breeds |
| `shared/items.ts` | new `ItemDef`; catalog rescaled to dice/armor + Spellbooks |
| `shared/protocol.ts` | additive optional `Combatant` fields (§7.1); deprecate `focusMeter` |
| `server/sim/systems/combat.ts` | full resolution rewrite (§6) |
| `server/sim/systems/spawns.ts` | `mkMonster` rolls Cairn block + tier steps |
| `server/sim/systems/loot.ts` | die/armor/spellbook rollers, keep seeding spine |
| `server/sim/systems/equipment.ts` | `gearSum`→worn die/armor, `setWorn`, `recomputeArmor`, slot/Deprived accounting |
| `server/sim/systems/progression.ts` | delete XP; add `rollScar` + `SCARS_TABLE` application, `shortRest` (full attr restore) |
| `server/sim/world.ts` | `makeCharacter` → 3d6 attrs + HP roll + starting package (rng-injected) |
| `server/sim/commands.ts` | `OP.USE_ABILITY` path (L119–127): `submitAbility`→`submitCast` (spellId routing, drop Focus/cooldown gate, §5.4) |
| `web/src/ui/CombatScreen.tsx` | STR/HP/Armor HUD, spellbook actions, save + Scar overlays; remove Focus bar + `.mp` (§8.1) |
| `web/src/ui/kit/CommandPanel.tsx` | spellbook-sourced actions, Fatigue label, die display |
| `web/src/App.tsx` | character sheet (§8.6): MIGHT/FOCUS/HANDS pips → STR/DEX/WIL; 3 `EquipSlot` refs → worn-inventory; drop Level/XP badge+row |
| `web/src/store/store.ts` | stop reading `focusMeter`/`self.level`/`self.xp` in op105/char refresh (L292,L317); ignore deprecated wire `focusMeter` |
| `web/src/ui/kit/Hex.tsx` | `StatPip` color map (L23): `FOCUS`→STR/DEX/WIL palette; refresh doc comment (L1–2) |
| `web/src/styles/app.css` / `web/src/ui/css/kit.css` | delete orphaned `.mp` Focus-bar fill rules (app.css L193, kit.css L101) |
| `web/src/render/combat.ts` / `juice.ts` | repoint crit→Critical Damage; Scar card; (MISS already works) |
| `package.json` | remove `balance` + `balance:quick`; drop `&& npm run balance:quick` from `ci:full` |
| `test/harness/assertions.ts` | inline `percentile` (was imported from runner); delete `assertDensityScaling`+`DensityScalingOpts`; keep garrison/escalation/density asserts |
| `test/harness/sim-harness.ts` | strip dead `autoResolveCombat`/`metrics`/`BotStrategy` (old timed-tap bot); keep `create/spawn/apply/serialize/newConn/clock` |

### ADD
| Path | What |
|---|---|
| `LICENSES/CAIRN.md` (+ NOTICE update) | CC BY-SA 4.0 attribution (§1) |
| `test/unit/cairn-combat.test.ts` | deterministic replacement for the balance guardrails (§10) |
| `test/golden/combat/*.golden.json` (optional) | canned seeded-fight event-log drift fixture |

---

## 10. Test strategy after cutting balance

The balance pipeline "proved" combat via statistical win-rate bands over thousands of Monte-Carlo trials. Cairn is **deterministic and closed-form per rule**, so it is proven by **exact deterministic unit tests over a scripted fixed-roll rng**, not sweeps.

### 10.1 The cut (mechanical)
- Delete `test/balance/**` + `test/reports/**` (§9). `vitest.config.ts` globs `test/**/*.{test,spec}.ts`, so deleting the four `*.spec.ts` files removes them from `ci:fast` with **no config edit**; only `runner.ts`/`*.bench.ts` are reached via the deleted npm scripts.
- **Blocker fix:** `test/harness/assertions.ts:17` imports `percentile` from `../balance/runner.js`. Inline the 6-line nearest-rank helper (or add `test/harness/stats.ts`) so `garrison.test.ts` / `territory.test.ts` survive. Delete `assertDensityScaling` (only consumer was `sweep.spec.ts`).

### 10.2 New: `test/unit/cairn-combat.test.ts` (fast tier, real sim resolvers, scripted rng)
1. **weaponDie − armor** exact subtraction, table-driven over the ladder; unarmed = d4.
2. **0-as-MISS** — `net ≤ 0` ⇒ 0 damage + `kind:'miss'` + it is a **legal resolved strike**, not a wire ERR (replaces old "auto ATTACK always lands").
3. **Keep-highest gang-up** — inject N distinct die results, assert only the max applies, deterministic per seed; multi-target spells bypass it.
4. **Auto-hit** — no to-hit roll consumed; assert rng draw count == damage dice (+ save dice only when overflow).
5. **STR-overflow / Critical Damage** — remainder→STR, then `d20 ≤ STR` (nat1 success, nat20 fail); STR→0 = death. Fixture cases: survive, fail→out-of-fight, lethal.
6. **Scars** — fires only on **exact 0** (not overflow, not partial), seeded, applies mapped effect incl. HP/attr-raising rows.
7. **Saves** — `d20 ≤ attr`; nat1 always success, nat20 always fail (STR/DEX/WIL).
8. **Short-rest recovery** — HP→full on safe rest; no recovery while Deprived (belongs in `camp.test.ts`).
9. **Morale** — enemy WIL save on first casualty and half-strength; fail → flee; lone foe at 0 HP; PCs never roll.
10. **Determinism** — same seed + same intents ⇒ byte-identical world + event stream (carry over `combat.test.ts` byte-determinism shape).
11. **Winnability fixture (the replacement for the cut win-rate guardrail).** A deterministic,
    scripted-rng harness — NOT a Monte-Carlo sweep — that runs a **representative party** (knight d8 +
    armor-1, ranger d6, wizard d4 + Firebolt) against **each breed at each tier (1–5)**, resolving to
    a terminal outcome with a fixed seed. Assert, per matchup: (a) **effective swings-to-kill lands in
    the 3–8 band** (elites/tier-5 allowed up to 10) — this is the numeric §1.4 guardrail encoded as a
    test; (b) the party is not stalemated — every non-fleeing enemy reaches 0 HP within a bounded
    round cap (fail loudly if any matchup exceeds it, catching a mis-tuned `d4`-vs-`armor` slog); (c)
    **downed-rate stays in band** — the party should lose a hero in the hard matchups but win overall,
    so assert `0 < heroesDowned < partySize` for elite tiers and `heroesDowned == 0` for tier-1. This
    fixture is the concrete pass criterion referenced by `combat-lab` (§1.4 rule 4 / §10.3) and is the
    single guardrail standing in for the deleted `knight-vs-tier3.bench.ts` win-rate band.

### 10.3 Keep + rewrite (encode Cairn, not sweeps)
`test/unit/combat.test.ts` (strip timed-tap/Focus/Breach!/element ×1.5; keep lattice/seal/coop/determinism), `test/integration/combat-actions.test.ts` (A4 → "auto-hit; net≤0 renders MISS, still legal"), `test/integration/combat-lab.test.ts` (best Cairn tuning surface; update HP-scaling assertion to `1d6*4`), `coop-combat`/`coop-seal`/`solo-seal` (encode keep-highest here), `camp.test.ts` (short-rest full HP refill + morale-flee).

### 10.4 Keep unchanged
`tools/check-sim-purity.ts` (**the determinism backbone — every Cairn die must draw from injected `rng`, no `Math.random`/`Date.now`**), `test/golden/**` (loot golden regenerated after loot lands, mechanism unchanged), `garrison/xp/movement/monster-interp/turret/guarantee/sprites/same-seed-loot` unit tests, all orthogonal integration/persistence/slow/vision suites. Coverage gate `server/sim/** ≥ 85%` stays.

---

## 11. Phased rollout + open questions

### 11.1 Ordered phases (each phase ends green on `ci:fast`)
1. **Cut balance** — delete `test/balance/**` + reports; fix `percentile` import; strip `assertDensityScaling` + dead harness bot; edit `package.json`. (Isolated, low risk, unblocks the rest.)
2. **Shared types** — `entities.ts` (Stats/Character/Item/Combatant/CombatEvent), `protocol.ts` additive fields, `tuning.ts` constant swap. Compile-only; nothing reads them yet.
3. **Data** — `mobs.ts` 8 breeds, `items.ts` catalog + Spellbooks, `SPELLS` table, Scars table, tier rules.
4. **Sim core** — `combat.ts` resolution rewrite (§6), `commands.ts` `USE_ABILITY`→`submitCast` (§5.4), `spawns.ts` block roll, `equipment.ts` worn/armor/slots, `loot.ts` rollers, `progression.ts` Scars/rest, `world.ts` `makeCharacter`. Land `cairn-combat.test.ts` (incl. the §10.2(11) winnability fixture) alongside. **Exit gate:** `grep -rniE 'focus|might|sureHands|killXp|sealXp|canAfford|focusCost' server/sim` returns only deprecated-wire hits.
5. **Rewrite kept combat tests** (§10.3); regenerate loot golden.
6. **Client** — HUD + spellbook dock + save/Scar overlays (`CombatScreen`/`CommandPanel`), **and** the character sheet + kit/store/css surfaces (`App.tsx`, `store.ts`, `Hex.tsx`, `app.css`/`kit.css`, §8.6); verify MISS/gang-up render unchanged. **Exit gate:** the §8.6 `grep` over `web/src` returns only intentional deprecated-wire / CSS `:focus` hits.
7. **Attribution** — `LICENSES/CAIRN.md`, NOTICE, About-screen credit.
8. **Ship** — commit/push `main`, PUT bundle to Scry per CLAUDE.md; headless smoke-test first.

### 11.2 Open questions / decisions for the user
All five gameplay questions are now **resolved** (below). Only two low-stakes engineering choices remain
(6, 7) and the plan's defaults stand unless you say otherwise.

1. ~~**HP scale factor.**~~ **DECIDED: ×4** — `maxHP = max(6, 1d6*4)` (6–24). Fights last ~4–7 hits.
2. ~~**Element/weakness house layer.**~~ **DECIDED: KEEP** — elements stay as a **die-step ±1** flavor layer (weakness +1 step, resist −1 step), on top of raw Cairn.
3. ~~**Class identity.**~~ **DECIDED (§2.4): purely cosmetic** — `classId` sets only sprite + soft attribute lean + `STARTER_KITS` starting gear. Cairn-classless.
4. ~~**Migration of saved characters.**~~ **DECIDED: WIPE** — no migration path. Old saves (`level/xp/focusMeter/might/focus/sureHands`) are discarded; every character is re-rolled fresh on the Cairn model. Simplifies `world.ts`/persistence (no legacy-field readers).
5. ~~**Scars severity.**~~ **DECIDED: full RAW lethality (§6.6)** — authentic Cairn 2e Scars table; rows 11 (Mortal Wound) and 12 (Doomed) can **kill a hero**. Row = HP lost in the killing-to-0 blow.
6. **Deprecated wire fields.** Drop vestigial `atk/def/acc/eva/critChance/focusMeter` from `Combatant` now (bump `ProtocolVersion` to 2), or leave them optional at version 1 for one release? *Plan default: leave optional at v1.*
7. **loot-distribution / pry-ev specs.** Move to `test/unit/` (plan's default) or delete with the rest of `test/balance/`? *Plan default: move to `test/unit/`.*
