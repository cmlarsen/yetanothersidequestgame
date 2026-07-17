# Combat rules system — research & recommendation

_Question: adopt an existing, safely-licensed (non-D&D) tabletop system for SideQuest's combat /
weapons / spells instead of inventing our own from scratch._

## TL;DR

- **You can already reimplement any system's *mechanics* freely** — game rules/mechanics are **not
  copyrightable** (US law). Only the specific *written expression*, *art*, and *trademarked names* are.
  So the license only matters for **copying content verbatim** (weapon tables, spell text, monster
  stat blocks, generator tables) — which is exactly the "don't reinvent it" win we want.
- **Recommendation:** build on **Cairn 2e** (CC BY-SA 4.0) as the resolution + content backbone,
  supplemented by **Maze Rats** (CC BY 4.0) for procedural spell / monster / treasure generators.
  Both are non-D&D, cleanly licensed, and — critically — Cairn's resolution model is almost identical
  to what we already shipped (attacks auto-hit, you roll damage, saves to resist effects).
- Attribution-only, safe for a shipped commercial app. Our engine + wire stay; this is mostly
  **content + data + re-skin**, not a rewrite.

## Why Cairn fits SideQuest almost uncannily

Cairn is a rules-lite fantasy game (descended from Into the Odd) built for fast, deadly, low-bookkeeping
play. The resolution is the shape we already converged on for phone combat:

| Cairn | SideQuest today | Fit |
|---|---|---|
| **Attacks auto-hit; roll the weapon's damage die** | we already made Strike an auto-hit that always lands | 1:1 — no attack roll = fewer taps, less swing |
| Damage die by weapon (d6 dagger, d8 sword, d10 greatsword, d12 two-handed) | item mods / weapon element | drop-in weapon table |
| Armor reduces incoming damage | our `def` / mitigation curve | drop-in |
| **3 saves: STR / DEX / WIL** (d20 roll-under) | our `acc`/`eva`/`resist` → "save vs effect" | maps cleanly; enemy gimmicks become "save or suffer" |
| HP ("grit") then STR damage | our `hp` | keep hp; **soften** the stat-loss/lethality for a kids' game |
| **Spells are physical items ("Spellbooks") you carry & cast** | our inventory items | roguelike gold — a spell *is* a loot item in your bag |
| No classes; your build = your gear | roguelike loot loop | perfect for us |
| Monsters = tiny stat block (HP, armor, damage, one gimmick) | `shared/mobs.ts` | drop-in |

We'd dial Cairn's lethality **down** (it's an OSR "you can die fast" game), but the skeleton is ideal.

## Why add Maze Rats

Maze Rats is a one-page rules-lite game whose real treasure is **8 pages of 2d6 random-generation
tables**: spells, monsters, NPCs, treasures, dungeons, wilderness. For a **roguelike that wants endless
variety without hand-authoring 300 spells**, this is the missing piece:

- **Procedural spells** — roll a *form* + an *element/effect* → a unique spell (e.g. "Levitating Fog",
  "Explosive Shadow"). We are **already seed-deterministic**, so these generator tables port straight to
  our RNG for infinite, reproducible content.
- **Procedural monsters + treasures** — same idea; seeds our bestiary and loot flavor for free.
- 2d6 resolution (fast, low variance) if we ever want a dice layer.

Cairn (backbone) + Maze Rats (procedural content) is the strongest pairing for *this* game.

## The options, ranked for SideQuest

| System | License | Resolution | Content strength | Fit for a fast phone roguelike |
|---|---|---|---|---|
| **Cairn 2e** ⭐ | **CC BY-SA 4.0** | auto-hit + damage die + d20 roll-under saves | weapons, spells-as-items, monsters | **Best** — resolution already matches ours |
| **Maze Rats** ⭐ | **CC BY 4.0** | 2d6 + procedural generators | **procedural spells/monsters/loot** | **Best content mine** — pair with Cairn |
| Basic Roleplaying (BRP) | **ORC License** (free Content Doc) | d100 roll-low skills | big magic system, deep skills, mature | Good if you later want depth; heavier to automate |
| OpenD6 / D6 Fantasy | **OGL** | Xd6 dice pool vs difficulty | full weapons + magic | Fast-ish, open; more math/action; avoid the "D6/OpenD6" trademarks |
| Knave 1e (→2e) | **CC BY 4.0** | d20, gear-slot driven | items/spellbooks, generators | Solid alt to Cairn; similar spirit |
| Fate Core / Condensed | **CC BY** | aspects + fudge dice | narrative toolkit | Set aside — narrative/GM-facing, doesn't automate into tappy combat |
| Into the Odd / Electric Bastionland | "Mark of the Odd" (bespoke) | auto-hit + damage die (Cairn's parent) | great fast combat | Great mechanics, but bespoke license — Cairn gives the same feel under standard CC |
| Any D&D SRD / retroclone (OSE, Basic Fantasy…) | OGL / CC | d20 | huge | Excluded per "definitely not D&D" |

## Licensing safety (for a shipped commercial app)

- **Mechanics are free regardless** — reimplementing *how a system works* in our own code/words needs
  no license (rules aren't copyrightable). The license governs copying their **text / tables / names**.
- **CC BY 4.0** (Maze Rats, Knave, Fate): copy content freely; include an **attribution block**;
  **non-viral** — your code, art, and story stay entirely yours.
- **CC BY-SA 4.0** (Cairn): same, plus **ShareAlike** — if you *republish adapted Cairn rules text*,
  that adapted **text** must stay CC BY-SA. It does **not** reach through to our app, source code, art,
  or fiction; it only touches verbatim/adapted rules *text* we'd redistribute. In practice we implement
  the mechanics in our engine and attribute Cairn — no obligation to open-source SideQuest.
- **ORC License** (BRP): royalty-free commercial use of the free Content Document; a few trademarked
  terms excluded.
- **OGL** (OpenD6): mechanics free under the license; "D6"/"OpenD6" names + art are Product Identity —
  use the system, not the branding.
- In all cases: **no trademarks / Product Identity** (specific setting names, iconic proprietary
  monsters, logos). Generic fantasy (goblins, skeletons, longswords, fireballs) is fine.

## Recommended plan (phased, low-risk)

1. **Adopt Cairn 2e** as the rules skeleton + **Maze Rats** generators for procedural content. Add the
   attribution blocks to the app + repo.
2. **Port the content** into our seed-deterministic data: Cairn weapon/damage + armor tables →
   `shared/items.ts`; Maze Rats spell/monster/treasure generators → `shared/abilities.ts` /
   `shared/mobs.ts` (seeded). _This is the big "don't invent it" payoff._
3. **Keep the command-relay engine**; nudge resolution to Cairn's "auto-hit + damage die + save-vs-
   effect" (we already auto-hit, so this is small).
4. **Re-skin vocabulary**: elements → damage types, Focus → spell prep/slots (or keep Focus), tiers →
   CR-ish depth. The **frozen wire is untouched** — this is server-sim data + client labels.
5. Ship attribution text in-app (About / credits) + `docs/`.

## Attribution text to bundle (drafts)

- Cairn: “This work is based on Cairn (cairnrpg.com), created by Yochai Gal, licensed under CC BY-SA
  4.0.”
- Maze Rats: “This work includes material from Maze Rats by Ben Milton, licensed under CC BY 4.0.”

## Sources

- Cairn 2e license/SRD — https://cairnrpg.com/second-edition/ , https://cairnrpg.com/first-edition/cairn-srd/
- Maze Rats (CC BY 4.0) — https://questingbeast.itch.io/maze-rats , https://questingblog.com/maze-rats/
- OpenD6 (OGL) SRD — https://opend6.net/srd , https://ogc.rpglibrary.org/index.php?title=OpenD6:OpenD6_and_the_Open_Game_License
- BRP ORC License / free Content Doc — https://www.chaosium.com/orc-license/ , https://www.chaosium.com/blogdownload-the-free-basic-roleplaying-orc-content-document-sell-the-games-you-create-royaltyfree/
- Fate CC-BY licensing — https://fate-srd.com/official-licensing-fate/cc , https://www.faterpg.com/licensing/licensing-fate-cc-by/
- Into the Odd "Mark of the Odd" license/SRD — https://www.bastionland.com/2020/11/mark-of-odd-licence-and-srd.html
- Knave 1.0 CC BY 4.0 — https://www.dicemonkey.net/2023/01/10/other-games-with-an-open-game-license-or-similar/
