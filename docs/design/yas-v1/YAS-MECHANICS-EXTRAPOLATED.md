# YAS — Mechanics Extrapolated from the Flow Map Screens

> Reverse-engineered from the UI in `YAS Flow Map.dc.html` / `YAS UI Board.dc.html`.
> Where a screen implies a rule, it's stated as one; open decisions are marked ❓.
> Contrast points with `MECHANICS.md` (the camp/turn-based prototype) are marked ⚡.

---

## 1. The game in one paragraph

A real-world territory game wearing a lighthearted RPG. Hexes overlay the actual
GPS map; walking claims them for your side, while an AI faction (the Gloomlings)
spreads and claims them back. Combat is **real-time on the map** — you fight
where you stand, with equipped items on cooldowns — and can be joined by nearby
players. The strategic layer is a persistent, per-neighborhood **territory war**;
the session layer is a 5–15 minute **run**.

⚡ Biggest divergences from MECHANICS.md: persistent shared world map instead of
per-scan radar encounters; real-time cooldown combat instead of turn-based;
territory as the core progression currency instead of camp economies; death has
territorial stakes instead of being cost-free.

---

## 2. Core loop (from the flow map's columns)

**Home → Start run → Walk & claim hexes → Encounter (mob / NPC / chest) →
Real-time combat → Victory: hex flips → Loot/Rewards → Run summary → Home.**

- A **run** is an explicit session: started from Home, summarized at the end
  (hexes claimed, mobs defeated, run time). 5–15 min target.
- Ending early is allowed: you keep hexes and XP, but drop gold on the map
  (recoverable for 1 hour — a reason to go back out).
- The world moves between runs: Gloomlings capture your hexes while you're
  away (push notification: "territory under attack").

## 3. Territory (the spine of the game)

- Every hex you **enter** is claimed for your side; mobs claim hexes as they
  move. Claim = tint on the map (cyan vs purple).
- Each real-world street/neighborhood is a **front**: a persistent tug-of-war
  meter (e.g. "Elm St — Cyan 34% / Gloom 21%"). Meters move when hexes flip.
- **Contested hexes** occur where sides meet; entering one triggers combat —
  the winner takes the hex ("contested hex" ring on the map).
- Quests gate on territory ("Claim 5 hexes on Elm St in one run"), and
  neighborhood completion pays a chest (the Grumble Chest was "reward for
  claiming all of Elm Street").
- ❓ Decay rules: do unvisited hexes fade to neutral, or only fall to mob
  movement? (Screens imply the latter — Gloomlings actively spread.)
- ❓ Faction identity: "Cyan Crew" currently doubles as party AND map side.
  Needs a split: a *side* (probably all players vs Gloomlings, or team colors
  per neighborhood) and a *party* (your 4-player group).

## 4. Combat (real-time, arcade)

- Fights happen **on the map itself** — no scene change. The mob is a 3D
  render standing on its hex; allies within range can walk in and join
  (multi-player, drop-in).
- **Hot bar** (the chosen 2a design): 5 uniform slots you equip from your
  inventory — any mix of weapons, spells, potions. Slot 1 convention: your
  weapon (drives basic attack).
  - Weapons: no cooldown; define your basic hit (e.g. Bonk Hammer — 24 dmg,
    knockback).
  - Spells: cooldown-driven (shown as radial sweep + seconds), e.g. Zap
    Scroll 12 dmg to 3 mobs; Turtle Up block 3 s; Pocket Blizzard 18 dmg
    cone + slow.
  - Consumables: charge-limited (Fizzy Mender ×3, heal 40 HP).
  - Empty slots exist; more slots ❓ (rail design showed 6+ with paging).
- Swapping gear mid-fight: hold a slot → equip drawer (weapons/spells/
  potions tabs). ❓ Whether swap is allowed in combat or map-only.
- Boss-type mobs ("Turf Tyrants") have segmented HP bars; damage floats,
  crits, and combo counters are core feedback.
- Skills unlock by level and are **added to the hot bar** (level-up screen) —
  so the hot bar is also the skill bar. Loadout depth comes from choosing 5.
- ⚡ vs MECHANICS.md: no accuracy roll, no turn structure, no block/dodge
  actions — defense is spells (Turtle Up) + movement (you can physically
  walk away). Auto-battle doesn't exist; instead combat is simple enough to
  thumb through while stationary.

## 5. Death & risk

- HP 0 → death screen. Stakes are **territorial + economic**: you keep some
  claimed hexes, **lose the contested ones** (−3 in the mock), and **drop
  gold** where you fell.
- Revive options: wait for a party member within range (Britt, 30 m) on a
  countdown, or respawn at your **home hex** and eat the hex loss.
- ⚡ vs MECHANICS.md soft death (lose nothing): this version makes multiplayer
  matter (rescue) and gives death a map consequence. ❓ Tune so it never
  feels like griefing — maybe hex loss caps per day.

## 6. World objects (tap anything)

Every map element supports an **info popover** (tap → anchored card):
- **Mobs**: name/title, level, bio line, hexes held, threat stars, loot drop
  rarity, weakness/resist tags ("Weak to BONK · resists ZAP"), then
  ATTACK / AVOID. Weakness system exists but is ability-flavored ❓ (define
  damage types: does BONK/ZAP map to phys/shock…?)
- **Chests**: spawn on hexes, visible from a distance with a beacon;
  **proximity-gated** ("get within 10 m to open") — walking is the key.
  Opening is a celebration: staged rarity reveal, legendary centerpiece.
- **NPCs**: dialogue with personality, offer quests with visible rewards
  (gold + mystery item), three response options.

## 7. Progression

- **XP → levels**: from combat, exploration ("new area +10 XP"), and quests.
  Level-ups grant stat bumps (ATK/DEF/HP) and **new skills** at thresholds;
  equipment slots also gate by level (Cape at LV 20).
- **Gear**: 6 paper-doll slots (Helm, Chest, Main hand, Off hand, Boots,
  Cape-locked) + rarity tiers (Common/Rare/Epic/Legendary). Each piece shows
  its stat contribution; the sheet totals HP/ATK/DEF/SPD/CRIT with a green
  "from gear" line — min/max is a first-class activity.
- **Set bonuses** (Hammer Set 2/4 → +10% knockback) reward themed loadouts.
- **Steps** are tracked and quested ("Walk 2,000 steps") — walking is both
  movement AND a quest currency. ⚡ No separate EP/DP economies: walking
  feeds quests directly, and there's no camp/downtime layer. ❓ Whether an
  idle/away system is wanted at all in this shape.

## 8. Economy

- **Gold**: combat, quests, chests, neighborhood rewards → spent at the shop.
  Dropped on death/retreat (recoverable, 1 h).
- **Shop** (roaming NPC merchant): rotating stock, rarity-priced, daily
  deals, mystery box, restocks when you visit a **new neighborhood** —
  commerce is tied to exploring, not to a home base.
- ❓ No crafting/materials in this shape. If wanted, chest dupes → materials
  is the obvious hook.

## 9. Quests

- **Quest board** with three tabs: DAILY (steps, kills), STORY (NPC chains),
  TERRITORY (claim N hexes on a front). New dailies on a timer.
- Progress from any activity; collect at the board. NPC story quests turn in
  via dialogue.

## 10. Multiplayer

- Party of up to 4; members visible on the map with distance + status
  (online / in combat / offline). Party code invites; nearby-player
  discovery.
- Drop-in co-op combat within physical range; shared territory credit
  (hexes feed the same side meter); revive mechanic (see §5).
- ❓ Server truth needed for: hex ownership, mob positions, chest spawns,
  co-op combat state.

## 11. Sessions & retention

- Session = run (5–15 min). Home screen between runs: map preview with
  live threats, daily quests, party status.
- Retention beats: territory-under-attack notifications, chest-spawn
  notifications, daily quest reset, neighborhood completion chests.
- ⚡ Instead of an away-report gift, the pull is *defensive*: come back or
  lose ground. ❓ This is spicier but harsher — consider a floor (Gloomlings
  can't push your side below X% per day).

## 12. Safety & settings (already designed)

GPS accuracy vs battery, screen-off step tracking, auto-pause above 15 km/h,
reduced motion, per-category notifications.

---

## 13. Defense layer — towers & sentries (proposal)

The missing "couch half" of the game, and the answer to §11's harshness ❓:
instead of a floor on Gloomling pushback, you **build** your floor.

- **Placement is physical**: you must stand on a hex you own to plant a
  tower there (same proximity rule as chests — legs are the gate). Placing
  is a walk decision: chokepoints where Gloom fronts advance, corridors
  between your quest routes, a guard by your home hex.
- **Management is remote**: from anywhere (couch), you can upgrade, repair,
  reroute, and re-target every tower you've placed. The map hub gains a
  DEFENSE view: your fronts with tower health/ammo overlays.
- **What towers do while you're away**: slow or stop Gloomling hex capture
  in their radius; log what they fought ("Bonk Turret held Elm St — 14
  Gloomlings repelled overnight"). Attack notifications become actionable:
  open app → repair/redeploy remotely, or go out and reinforce in person.
- **Tower lifecycle**: build (costs materials, see §14) → level tiers
  (radius/damage/durability) → take damage while defending → **repair from
  couch** with materials, or decay to rubble (recoverable stub, must
  physically revisit to rebuild ❓).
- Types (KayKit-flavored, 3 is plenty to start):
  - 🔨 **Bonk Turret** — single-target damage, holds a chokepoint
  - ❄️ **Chill Bell** — AoE slow, buys time for your walk over
  - 🏰 **Bastion Post** — no damage; hexes in radius can't flip while it
    stands (the "floor," made buyable)
- Caps: N towers per player scaling with level; 1 tower per hex; ❓ whether
  party members' towers stack on shared fronts.
- ⚡ This imports MECHANICS.md's downtime spirit (meaningful couch play,
  wall-clock processes) without importing the camp: your **territory is the
  base**.

## 14. Minions & sidequests (proposal)

Gold finally gets a strategic sink, and materials enter this shape:

- **Hire NPC minions** with gold (the shop NPC sells contracts, or a
  barracks tower ❓). Roster is small: 2–4 active minions with names and
  KayKit personality ("Gruncle, semi-retired mole").
- **Dispatch from the couch**: send a minion on a timed sidequest —
  *Gather lumber* (~30 min), *Scavenge the front* (~1 h, materials + salvage
  from fallen towers), *Scout* (~15 min, reveals Gloom buildup on a front).
  Jobs run on wall-clock time, app closed. ⚡ Direct import of the
  away-crafting pattern — but the output feeds the defense layer.
- **Materials** (🔩 or lumber/stone flavored ❓) are the tower currency:
  build, upgrade, repair all draw from the same pool, so "send minions"
  vs "walk and fight" becomes the couch/boots resource split.
- Minion returns are the retention beat: "Gruncle's back — 14 lumber and a
  rumor: Gloomlings massing on Maple Ave" (report doubles as a quest hook).
- Risk knob ❓: minion sidequests into contested territory pay better but
  can fail/injure the minion (repair with gold, mirrors tower repair).
- Boundary to keep: minions **gather and scout**; they don't claim hexes or
  fight your battles — walking stays the only way to take ground.

**The loop this creates:** walk to claim ground and place towers → towers
hold ground while you're away → minions gather the materials that keep
towers standing → gold from fights/quests hires more minions → deeper
fronts to defend → more reasons to walk.

## 15. The two shapes, side by side

| | **Flow-map shape (this doc)** | **MECHANICS.md prototype** |
| --- | --- | --- |
| World | Persistent shared hex map | Per-scan radar, transient |
| Combat | Real-time, on-map, co-op | Turn-based, solo, scene |
| Skill expression | Loadout building + positioning | Turn decisions + timing (planned) |
| Death | Lose contested hexes + drop gold | Free (half HP at camp) |
| Walking | Claims territory directly | Earns EP for training |
| Home base | None (map is home) | Camp (forge/train/craft) |
| Idle layer | Defensive (world moves against you) | Generous (away gifts, crafting) |
| Multiplayer | Core (co-op, revive, shared fronts) | None yet |
| Couch mode | ❓ unsolved | First-class |

Hybrids worth considering: keep the hex/territory world layer + real-time
co-op combat, but adopt MECHANICS.md's **away-report generosity** (your held
hexes produce a trickle) and its **couch mode** answer (simulated strides
still claim a "phantom" route ❓).
