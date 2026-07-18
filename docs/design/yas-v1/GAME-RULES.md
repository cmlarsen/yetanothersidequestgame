# YAS v1.0 — Game Rules (authoritative)

> Build to this document. Numbers marked DEFAULT are decided-but-tunable — implement them
> as config constants, not hardcoded literals. Nothing here requires interpretation; if a
> case is genuinely unspecified, prefer the simplest behavior and file it, don't invent.

## 1. World & territory

- The world map is the real GPS map overlaid with a fixed hex grid. DEFAULT hex size:
  ~60 m across flats (H3 resolution 10 or equivalent).
- Hex ownership: NEUTRAL | PLAYER_SIDE | GLOOM. Player side is one shared color (cyan) for
  the player and their party. v1 has no player-vs-player factions.
- **Claiming**: entering a hex you don't own claims it for your side instantly (walk-through
  claim). Mobs claim hexes for GLOOM as they roam (server tick).
- **Contested hex**: a GLOOM hex adjacent to player territory that a player enters becomes
  CONTESTED and spawns/holds a combat encounter. Winner's side owns it.
- **Fronts**: hexes aggregate into named neighborhood fronts (streets/areas from map data).
  Each front shows a tug-of-war meter: %PLAYER vs %GLOOM of its hexes (e.g. Elm St 34/21,
  remainder neutral).
- Gloom pressure: a server process advances GLOOM capture along fronts over time.
  DEFAULT rate: up to 3 hexes per front per hour while unopposed; towers modify (see §8).
  No decay to neutral in v1 — hexes only change by claim/capture.
- Front completion: bringing a front to 100% player-owned awards a Grumble Chest (§6) and
  a gold bonus (DEFAULT 200 g), then the front's Gloom pressure resets after 24 h.
- Fog of war: unvisited areas render darkened; entering reveals. First visit to a named
  area: toast "NEW AREA — <name> · +10 XP".

## 2. Sessions ("runs")

- A run starts from Home (START RUN) and targets 5–15 min of play.
- During a run: claiming, encounters, chests, NPCs, quests all active.
- Ending a run: RUN ENDED summary — hexes claimed and XP earned are always kept; **gold
  earned this run that exceeds banked gold drops on your last hex** if you end early via
  retreat from combat or death (see §5). Dropped gold persists 1 h, recoverable by
  returning within 10 m.
- Run summary shows: hexes claimed, mobs defeated, run time, loot list, level progress,
  front % change.
- Outside a run the app is fully usable for couch systems: quests board, inventory,
  party, shop browsing (buy allowed), towers (manage only), minions.

## 3. Combat (real-time, on-map, drop-in co-op)

- Combat begins when the player enters a mob's hex or taps ATTACK on its popover, and
  happens in place on the map (no scene change). Fleeing = physically walking out of the
  mob's hex + 1 hex buffer, or tapping FLEE.
- Party members within DEFAULT 50 m may join instantly; all participants share the kill
  credit and the hex flips to the player side on victory.
- **Hot bar**: 5 slots, uniform. Any slot holds a weapon, spell, or consumable, equipped
  from inventory (drag on the paper-doll/equip drawer; hold a slot in combat to open the
  drawer — swapping IS allowed mid-combat, DEFAULT). Slot contents:
  - Weapons: no cooldown; tapping performs the basic attack (also usable via the big
    ATTACK button which triggers the slot-1 weapon). Example: Bonk Hammer — 24 dmg,
    knockback 1 hex.
  - Spells: tap to cast, then cooldown (radial sweep + seconds label). Examples:
    Zap Scroll 12 dmg to up to 3 mobs, cd 8 s · Turtle Up: block all damage 3 s,
    reflects 20%, cd 12 s · Pocket Blizzard (LV13 unlock): 18 dmg cone + 3 s slow, cd 8 s.
  - Consumables: tap to use, decrement charge badge. Fizzy Mender: heal 40 HP, 3 charges.
  - Empty slots show a dashed "+" and open the equip drawer.
- Cooldown state renders as a conic overlay + remaining seconds; unaffordable/locked
  states are 60% opacity with a lock/level badge.
- Damage: floating numbers (white normal, gold big hits, pink "CRIT −N!" at DEFAULT 10%
  crit base + gear CRIT). Combo counter increments per hit landed within 3 s of the last;
  resets after 3 s idle; purely celebratory in v1 (no damage bonus).
- Mobs: regular Gloomlings (small HP bar) and boss-class **Turf Tyrants** (name plate,
  level, HP bar segmented into 4; e.g. GRUMBLESHROOM · TURF TYRANT · LV 8).
- Ability affinity: mobs list weak/resist tags against ability types (e.g. weak to BONK,
  resists ZAP). Weak hit ×1.5, resisted ×0.5. Tags shown on the info popover only.
- Player HP: ring around own avatar + allies' avatars. At 0 HP → death (§5).
- Mob defeat → VICTORY overlay on the map: defeated mob grays out, hex-claim ring, front
  meter ticks (+2% shown), +XP and +gold floats, CONTINUE.

## 4. Info popover (tap any map element)

Tap mob/NPC/chest/owned-or-enemy hex → anchored card with: name/title, level, one-line
flavor bio, stat chips (mob: hexes held, threat ★1–3, loot-drop rarity), weakness/resist
chip, and actions (mob: ATTACK / AVOID · NPC: TALK · chest: distance + open state ·
hex: owner + claim history). Tap-away dismisses.

## 5. Death & revive

On HP 0:
- Screen: "YOU WERE DEFEATED" + tallies: hexes kept (+4 style), **contested hexes lost**
  (DEFAULT: the hexes claimed-but-contested this run, cap 3), **gold dropped** (DEFAULT
  50 g or 10% of carried, whichever larger) at death location, recoverable 1 h.
- Options: (a) WAIT FOR REVIVE — 60 s countdown; any party member within 30 m can revive
  by walking to you; (b) RESPAWN AT HOME hex immediately, accepting the hex loss.
- Nothing else is lost (gear, quest/bounty progress, XP all kept).

## 6. Loot, chests, rewards

- Chests spawn on hexes (server), visible on the map with a gold beacon; push notification
  when one spawns within 200 m (if enabled). **Proximity gate: within 10 m to open.**
  Out of range: progress bar toward it + disabled button "OUT OF RANGE — MOVE CLOSER".
- Opening = celebration screen: spinning rays, staged pop-in of 3 items (center item is the
  highest rarity), +gold and +XP chips, COLLECT ALL.
- Rarity tiers: COMMON, RARE, EPIC, LEGENDARY (colors in README). Item cards always show:
  art, name, rarity pill, and when relevant a delta vs equipped.
- Mob drops: on victory, gold + XP always; item drop DEFAULT 25% (Tyrants 100%).

## 7. Progression & gear

- XP sources: mob kills, quests, exploration (+10 new area), chests. Level curve DEFAULT:
  next = 100 × 1.35^(level−1).
- Level-up (full-screen moment): stat bumps (DEFAULT +2 ATK, +1 DEF, +10 HP), and at skill
  levels a NEW SKILL card with ADD TO HOT BAR action. Skill unlock levels DEFAULT:
  13 Pocket Blizzard; next tease shown (LV 15 — Cape equipment slot).
  NOTE: one older mock says cape at LV 20 — **LV 15 is canonical**.
- Paper doll: 6 slots — HELM, CHEST, MAIN HAND, OFF HAND, BOOTS, CAPE (level-locked).
  Melee/main may be empty in v1 (no forced weapon). Stats panel totals HP/ATK/DEF/SPD/CRIT
  with the gear contribution shown in green (e.g. HP 184 (+52)). Each equipped piece lists
  its contribution (Helm +30 HP · +6 DEF etc.).
- Set bonuses: named sets (HAMMER SET 2/4 — equip 2 more pieces for +10% knockback).
  v1 ships exactly this one set. Sets count equipped pieces sharing the set tag.
- Inventory grid: rarity-colored borders, E badge = equipped, gold dot = new/unseen,
  filter tabs ALL/WEAPONS/ARMOR/POTIONS, +N overflow tile.

## 8. Towers (defense layer)

- **Placement is physical**: player must be standing (≤10 m) on a player-owned hex.
  1 tower per hex. Tower cap DEFAULT 5 per player (scales later).
- **Management is remote** from the Defense view: upgrade, repair, retarget, salvage all
  work from anywhere. Rebuilding a destroyed tower (rubble) requires a physical visit.
- Types & DEFAULT stats (cost 🪵 materials):
  - Bonk Turret — 12 🪵 · single-target dmg 8/tick · radius 2 hexes
  - Chill Bell — 18 🪵 · slows Gloom capture 40% in radius 2
  - Bastion Post — 30 🪵 · hexes in radius 1 cannot flip while it stands · no damage
- Durability 100. Towers lose durability while resisting Gloom pressure (DEFAULT 5/h of
  active front contact). At 0 → rubble (stub on map, salvageable stats retained).
- Repair cost DEFAULT 6 🪵 to full · Upgrade LV2→LV3 22 🪵 (each level +25% effect,
  +25 max durability, 3 levels max) · Salvage refunds ~40% (8 🪵 on Chill Bell LV2).
- Target priority per tower: NEAREST | STRONGEST | GUARD HOME HEX.
- Overnight/away digest: "your towers repelled N Gloomlings · <tower> took heavy damage"
  surfaces on Defense view and in the attack notification.

## 9. Minions (couch economy)

- Roster: 2 starting minions (Gruncle, Pip), 3rd slot hire at merchant for 200 g.
  Personality lives in their names/bios/return quotes — buttons stay transactional.
- Jobs (one per minion, wall-clock, run with app closed):
  - Gather Lumber · ~30 min · returns 10–16 🪵
  - Scout the Front · ~15 min · reveals Gloom buildup on one front (shows incoming push
    timing on Defense view)
  - Scavenge Contested Ground · ~1 h · 🪵 +50% yield + chance of tower salvage part
    (perk item) · 20% minion injury
- Injured minion: unavailable until healed (DEFAULT 50 g, instant).
- Returns produce a report modal: haul, any salvage, and a "rumor" hook that deep-links to
  the relevant front. Minions NEVER claim hexes or fight.
- Materials (🪵) are used ONLY by the tower system (build/upgrade/repair).

## 10. Quests & NPCs

- Quest board tabs: DAILY | STORY | TERRITORY. Dailies reset at dawn local time
  ("New quests in 7h 12m" countdown). Claim rewards at the board (COLLECT state).
  v1 dailies: Walk 2,000 steps (80 g) · Defeat 5 Gloomlings (120 g) ·
  territory: Claim 5 hexes on <front> in one run (200 g).
- Story quests come from map NPCs via dialogue (3 reply options: accept / ask detail /
  decline). Quest chip shows objective + reward (gold + mystery item). One active story
  chain at a time.
- NPC voice: punny, warm (see mock copy). UI chrome copy stays transactional.

## 11. Economy summary

Gold: combat, quests, chests, front completion → shop items, minion hires/heals.
Materials 🪵: minion jobs (+ rare mob drops DEFAULT 10%) → towers only.
Potions/consumables: shop, chests → hot bar charges.
Shop (roaming merchant NPC): 4-item rotating stock + daily deal (−30%), Mystery Grumble
Box 199 g (random item, rarity-weighted), restocks when the player enters a new
neighborhood. Sell: any item at 50% value. Unaffordable items show red price state.

## 12. Party & multiplayer

- Party max 4, invite by code (BONK-4242 style) or nearby-player list (distance shown).
- Member states: ONLINE (on map) | IN COMBAT | OFFLINE. Party members visible on the map
  with face pin + HP ring; tap → popover.
- Shared: territory side, co-op combat, revives. START GROUP RUN pings all online members.
- Server-authoritative: hex ownership, mob state, chest spawns, tower state, combat
  resolution with multiple participants.

## 13. Notifications (push)

Triggers (each toggleable in Settings): territory under attack (front loses ≥5 hexes or a
tower falls below 25%) · chest spawned within 200 m · party invite / group run ping ·
minion job complete. Deep-link each to the relevant screen.

## 14. Safety & system settings

GPS accuracy HIGH/SAVER · screen-off step tracking toggle · auto-pause claiming above
15 km/h (driving guard; combat also disabled while moving fast) · reduced motion ·
notification toggles · account (Sign in with Apple shown) · version/legal footer.
Steps counted via pedometer APIs; 1,204/2,000 style progress on Home + quest board.

## 15. Copy & tone rules

- Buttons and system UI: clear, transactional, uppercase display font
  (ATTACK, AVOID, ACCEPT QUEST, COLLECT ALL, OUT OF RANGE — MOVE CLOSER).
- Personality lives ONLY in: character names/titles/bios, NPC dialogue, item names,
  minion quotes. Never in button labels or error states.
- Naming glossary: territory (not turf, except in proper nouns like "Turf Tyrant") ·
  character (not hero) · run (not crawl) · materials 🪵 · Gloomlings (enemy faction) ·
  fronts (named neighborhood battlegrounds).
