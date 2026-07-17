# Rift Design Brief — real-world rift roguelike

> **Status: brainstorm / inspo — nothing locked.** Notes developed in a ChatGPT
> session (imported 2026-07). At this stage everything is on the table; this is
> noodling and riffing, not a spec and not a build order. Companion pieces:
> `DESIGN.md` (veil fiction), `GENRE-LESSONS.md` (genre laws), `COMBAT-STUDY.md`
> (combat pattern library).

## House riff on session length (2026-07) — the wild/gym split

The brief's 8–12 min "standard rift" reads too long as core content. PoGO works
partly because the core encounter is ~30 seconds and *interruptible*, while
gyms/raids are the chunky, opt-in, destination tier. So:

- **Wild layer** — everywhere, free, 30–90s: random encounters, bounty ticks,
  quest objectives, resource taps. Bus-stop / dog-walk / park-with-the-kids
  play. (Our current combat is already this shape.) Rule of thumb: **the bus
  test** — every wild encounter must survive the bus arriving; interruptible or
  abandonable with no penalty.
- **Dungeon layer** — rifts fill the **Gym** role: landmark-anchored, visibly
  marked, a trip you *choose* to make. Also the future raid venue, exactly as
  gyms became raid venues.
- **Push-your-luck dissolves fixed run lengths.** If every rift is
  extract-anytime, a rift is as long as your nerve: clear depth 1 and leave in
  2–3 min, or push to depth 4-5 and *choose* a 10-minute run. Rift "tiers" are
  about how deep a tear goes, not designed duration. The long session becomes an
  emergent outcome of greed, not a requirement.
- **Fiction maps clean:** wild encounters = small stuff *leaking* through the
  thinning veil (ambient, everywhere); rifts = actual *tears* (places).

## House riff: "just one more level" dungeons (2026-07)

Dungeons are not fixed-length runs — they're floor-at-a-time slot machines
(variable-ratio reinforcement, the strongest return schedule there is):

- **Unknown floor composition.** Each floor is drawn from a pool: fight, elite,
  **pure loot room with a chest** (For the King style — a real chance of
  no-combat jackpot), shrine/bargain, trap, merchant, mystery. "What's the next
  floor?" is the lever-pull.
- **Bail anytime, resume at the same floor later.** Bailing = pausing, not
  losing — the bus test at dungeon scale, and a standing return hook alongside
  the away-systems ("you're 4 floors into the Grave Tear"). Fiction: *your
  Warden's mark holds the passage; the tear remembers you.*
- **Dungeons do end** — there's a bottom, a finish, a seal.
- **Where the risk lives if bailing is free** (open knobs, none locked):
  - risk inside the floor, not between floors — dying mid-floor costs
    something (unstable loot);
  - paused dungeons **mature** — floors deepen (harder *and* richer) while you
    stay away; the machine keeps spinning;
  - some loot only banks on *finishing* — the sealed-tear bonus keeps "finish
    the dungeon" meaningful.

## House riff: non-combat test-your-luck encounters (2026-07)

Some encounters / map pins / dungeon floors are luck mini-games, not fights
(folds in the For the King skill-check idea from COMBAT-STUDY):

- trapped chest — keep prying for better loot or *snap* (push-your-luck in
  miniature);
- fae bargain at a shrine — boon now, unknown cost later;
- dice / three-card with a merchant — gold as stakes;
- stat-check events — "rickety bridge: force it, sneak it, walk away";
- ambient oddities: lost spirits, strange finds, veil flotsam.

They give the wild layer park-bench content that isn't combat, give gold/EP/DP
something to gamble, and obey the WU law: every one is a *tiny game with real
tension*, never a tap-through.

# Real-World Rift Roguelike RPG — Design Brief

## Core Concept

A location-based roguelike RPG set in the real world, where unstable rifts between realms are forming and monsters are breaking through. The player is a real-world adventurer whose movement, rest, preparation, and local choices empower their character to survive supernatural incursions.

The strongest framing:

> **The player’s real life generates preparation; the supernatural world creates temptation; rifts create risk.**

The game should not be a simple “walk to marker and tap monster” clone. The real-world map should create opportunity, scarcity, danger, and context. The main gameplay depth should come from entering rifts, surviving short roguelike encounters, making risk/reward choices, and improving the player character, apprentice, gear, base, and world state over time.

---

## Primary Core Loop

```text
Move through the real world
→ Earn Endurance and discover encounters
→ Sleep/rest
→ Earn Recovery and improve preparation
→ Assign downtime tasks
→ Return to collect crafted items, scouting reports, and strange opportunities
→ Choose a nearby mark, quest, merchant, encounter, or rift
→ Engage from ranged, mid, or close proximity depending on build and safety
→ Fight, loot, make risk/reward choices
→ Extract, seal, harvest, or escalate the incursion
→ Spend currencies on abilities, companions, gear, and base systems
→ Repeat
```

Short version:

> **Scout nearby supernatural activity → choose a rift or encounter → fight, loot, and make risk/reward choices → extract before things collapse → upgrade your hunter, apprentice, gear, and base → use the real world to choose the next run.**

---

## Design Pillars

1. **Real-world movement creates preparation, not punishment.**  
   Movement should improve options and progression, but players should still be able to play without intense physical activity.

2. **Rifts are the main roguelike content.**  
   The map gets the player to interesting entrances; the rift itself delivers build variety, danger, loot, and decisions.

3. **Safety and accessibility always have valid play paths.**  
   If something appears in an unsafe, inaccessible, private, or awkward physical location, the player should still be able to interact using ranged attacks, apprentice actions, lures, pocket arenas, or relocation tools.

4. **Downtime should make the world feel alive.**  
   When the player returns, they should receive crafted items, scouting reports, merchant visits, companion events, and strange consequences from prior choices.

5. **The player should ask, “Is this worth the risk?”**  
   The game should create temptation: a dangerous rift nearby, a rare merchant, a named monster, a limited-time realm storm, or a valuable mark just far enough away to make the choice meaningful.

---

# Meta Currencies

The game uses two main meta currencies. Names are FPO.

## Endurance Points

**Earned by:** walking, running, cycling, wheelchairing, or other real-world movement.

Endurance represents action, exertion, exploration, and physical capability.

### Good Uses

- Upgrade active combat abilities
- Improve stamina or action economy
- Improve melee, dodge, block, sprint, or movement skills
- Unlock exploration perks
- Increase rift-entry capacity
- Fuel “push deeper” decisions inside rifts
- Improve resource gathering while moving
- Boost physical class abilities

### Example Endurance Upgrades

```text
Spend 40 Endurance:
- Heavy Strike gains +10% stagger.
- Dash cooldown reduced by 0.5s.
- You may enter one extra rift room before collapse pressure increases.
- Melee attacks gain bonus damage after real-world travel.
- Blocking at close range restores a small amount of stamina.
```

### Design Role

Endurance should feel like:

> **I moved, so my character can act.**

It should not feel like:

> **I failed to exercise enough, so I cannot play.**

---

## Recovery Points

**Earned by:** sleeping, resting, or intentional downtime.

Recovery represents healing, stability, preparation, resilience, and magical control.

### Good Uses

- Upgrade passive abilities
- Improve healing or warding
- Reduce curses
- Improve max health or resistance
- Boost crafting quality
- Repair gear
- Train apprentice or companions
- Remove injuries or corruption
- Improve downtime success rates
- Improve magical or defensive abilities

### Example Recovery Upgrades

```text
Spend 35 Recovery:
- Restore one broken relic.
- Increase curse resistance by 3%.
- Improve potion brewing quality.
- Unlock one additional downtime task slot.
- Reduce death penalty from failed extraction.
- Increase apprentice success chance on scouting tasks.
```

### Design Role

Recovery should feel like:

> **I rested, so my character can recover, prepare, and grow.**

It should not punish people for imperfect sleep or unusual schedules.

---

## Currency Design Warning

Avoid making Endurance and Recovery hard energy gates for basic play.

Better:

```text
You can always play.
Real-world wellness makes you better prepared.
```

Worse:

```text
You did not walk today, so you cannot fight.
You slept badly, so your character is useless.
```

Use these currencies for bonuses, upgrades, efficiency, optional power, and preparation. Do not make them punitive.

---

## Accessibility and Fairness

Design earning around effort bands, not raw athletic output.

Example:

```text
Light activity → small Endurance
Moderate activity → normal Endurance
Long activity → capped bonus Endurance
```

Recommended approach:

```text
Daily useful movement target: achievable
Extra movement: small diminishing returns
No movement: still playable
```

Daily caps and diminishing returns prevent the game from becoming a fitness competition and make the system more inclusive.

---

# Real-World Map Layer

The map is the opportunity layer. It should create discovery, urgency, scarcity, and local identity.

## Possible Map Elements

- Minor rifts
- Major rifts
- Realm storms
- Corrupted landmarks
- Safe havens
- Resource nodes
- Faction-controlled zones
- Boss incursions
- Wandering monsters
- Traveling merchants
- Shrines
- Clue trails
- Named marks
- Companion discoveries

Each visible event should communicate what it is and why it might be worth the trip.

Example:

```text
Grave Rift — Threat 3
Undead realm. High curse buildup. Relic reward.
Collapse in 42 minutes.
```

The player should be able to make a strategic choice before traveling.

---

# Rifts

Rifts are unstable portals into short procedural realm breaches. They are the core roguelike runs.

## Rift Entry

The player finds a rift on the real-world map, travels near enough to interact, then enters a procedural pocket-realm. The player should not have to physically walk a whole dungeon in real space. The real-world location is the entry point; the rift is the game space.

## Recommended Run Lengths

```text
Minor Rift: 3–5 minutes
Standard Rift: 8–12 minutes
Elite/Boss Rift: 15–20 minutes
Public Incursion/Raid: 20+ minutes
```

## Rift Structure

Rifts can use node-based or room-based structures.

Example:

```text
Entrance
  ├── Combat
  ├── Shrine
  ├── Treasure
  └── Elite
        ├── Curse Room
        └── Boss / Extraction
```

Each room should present a tactical encounter, reward, or decision.

---

## Roguelike Build Choices

During a rift, the player gains temporary powers that define the run.

Examples:

```text
- Fire spells chain to one extra enemy.
- Dodging leaves a frost sigil.
- Bleeding enemies explode on death.
- Gain +40% damage, but healing is reduced.
- Your summon duplicates, but both copies have half health.
- Melee finishers extend rift stability by 5 seconds.
- Ranged attacks mark targets for apprentice follow-up.
```

Permanent progression should broaden options. Temporary rift progression should create build variety.

Recommended split:

```text
Permanent progression:
- Classes
- Gear bases
- Crafting options
- Relic slots
- Faction perks
- Realm knowledge
- Apprentice specializations
- Base upgrades

Temporary run progression:
- Boons
- Curses
- Mutations
- Consumables
- Realm-specific powers
- Emergency bargains
```

---

## Push-Your-Luck Structure

The heart of the rift loop is deciding whether to extract or push deeper.

Example depth model:

```text
Depth 1: safe rewards
Depth 2: better loot, minor curse
Depth 3: elite enemy, rare drop chance
Depth 4: boss room, high collapse risk
Depth 5: overdepth, legendary chance, severe penalty
```

After each room, the player can choose:

- Extract safely with current loot
- Push deeper for better rewards
- Take a curse for a stronger boon
- Fight an elite for rare materials
- Stabilize the rift for faction or world progress
- Ignore the boss and escape
- Send apprentice to secure partial loot

---

## Rift Outcomes

At the end of a run, the player chooses what to do with the rift.

### Seal the Rift

Removes or weakens the rift. Grants safety, faction progress, and world-state improvement.

### Harvest the Rift

Takes more loot but leaves the rift open. This may allow local corruption to spread.

### Stabilize the Rift

Turns the rift into a temporary portal, social activity, resource source, or future party event.

### Fail Extraction

The player loses unstable loot but keeps some XP, knowledge, or partial progression.

---

# Combat

Combat should be fast, readable, and tactical. It should not rely on mindless tap-spamming.

## Basic Combat Kit

A player may have:

- Basic attack
- 2–4 class abilities
- Dodge, block, or parry
- Consumable slot
- Ultimate or relic power
- Apprentice assist
- Optional companion action

The combat loop should be simple enough for mobile but deep enough for builds to matter.

---

## Ranged, Melee, and Physical Proximity

The physical distance system can be one of the game’s distinctive features, but it must be safe and flexible.

Core rule:

```text
Closer = more options, better efficiency, higher commitment
Farther = safer, fewer options, lower efficiency
```

Physical proximity gives tactical advantages, but safety and accessibility always provide another valid path.

## Suggested Proximity Bands

```text
Far Range: 50–150m
- Ranged attacks
- Scouting spells
- Marking targets
- Weakening shields
- Sending apprentice/companion
- Lower efficiency, but still valid

Mid Range: 15–50m
- Ranged attacks
- Spells
- Traps
- Companion abilities
- Normal rewards

Close Range: 0–15m
- Melee attacks
- Finishers
- Interrupts
- Higher stagger chance
- Faster sealing
- Bonus loot modifiers
```

Do not require the player to stand directly on top of a GPS marker. That will be unsafe, inaccurate, and frustrating.

---

## Ranged Combat as Safety Layer

Ranged combat should exist partly because real-world placement will sometimes be unsafe.

Unsafe examples:

- Across a busy street
- Behind a fence
- On private property
- In a dangerous intersection
- Near construction
- In bad weather
- In inaccessible terrain
- In a place the player does not feel comfortable approaching

The player should always have options:

```text
- Attack from range
- Lure the enemy closer
- Send apprentice
- Shift the encounter into a pocket arena
- Mark it for later
- Report bad placement
- Consume an item to relocate the encounter
```

Safety should be slightly less efficient, not meaningfully punished.

Better penalty:

```text
Ranged engagement takes longer or uses more resources.
```

Worse penalty:

```text
Ranged engagement gives bad rewards or blocks completion.
```

---

## Melee Role

Melee should be powerful when safe to approach, but not mandatory.

Melee strengths:

- High burst damage
- Stagger
- Finishers
- Fast sealing
- Strong against armored enemies
- Better extraction control

Melee risk:

- Requires close engagement
- More vulnerable to ambushes
- May require resources or apprentice support when the physical location is unsafe

---

## Ranged Role

Ranged should be the safety-first option.

Ranged strengths:

- Engages from farther away
- Safer in bad locations
- Better scouting and marking
- Useful against flying or dangerous enemies
- Works well with apprentice support

Ranged limitations:

- May take longer
- May consume ammo, focus, or charges
- May have lower burst
- May struggle against shielded enemies without setup

---

## Magic Role

Magic can occupy the flexible middle ground.

Magic strengths:

- Medium-range control
- Warding
- Debuffs
- Curses
- Realm manipulation
- Emergency relocation or pocket arena access

Magic limitations:

- Can build corruption
- May rely on Recovery-linked resources
- May require preparation or rituals

---

## Summoner / Companion Role

Summoners and companion-oriented builds support accessibility and downtime.

Strengths:

- Send creatures ahead
- Interact with inaccessible marks
- Strong scouting
- Good downtime synergy
- Good for solo players

Limitations:

- Slower direct combat
- Requires training, care, or recovery
- Companions may have quirks or risks

---

# Apprentice System

The apprentice should arrive early, ideally at **Level 2**. Level 1 teaches the base loop; Level 2 introduces downtime, safety tools, and the companion relationship.

The apprentice is not just a follower. They solve several structural problems:

- Safety
- Accessibility
- Downtime
- Tutorialization
- Personality
- World flavor
- Remote interaction
- Future party/companion expansion

## Apprentice Design Role

The apprentice should expand the player’s options without replacing the player’s agency.

They should be able to:

- Scout threats
- Fetch minor resources
- Lure enemies away from unsafe locations
- Mark enemies for ranged attacks
- Help with crafting
- Negotiate with merchants
- Stabilize rifts
- Rescue partial loot after failure
- Explain mechanics in-world
- Add snark and personality

---

## Apprentice as Safety Fiction

Instead of the UI saying:

```text
This location is unsafe. Press button to relocate.
```

The game can say:

```text
Your apprentice refuses to let you cross that road for a ghoul.
They can lure it closer, mark it for ranged fire, or open a pocket skirmish.
```

Example encounter:

```text
A Bone Hound is across a busy street.

Options:
- Fire from range
- Send apprentice to mark it
- Use whistle to lure it into a pocket alley
- Ignore it
```

Possible apprentice flavor line:

```text
“Heroic plan, boss. Very brave. Also very illegal. I’ll bring it over here.”
```

---

## Early Apprentice Abilities

```text
Scout
- Reveals enemy type, threat level, modifiers, and safety warnings.

Fetch
- Collects minor resources from nearby marks without requiring exact proximity.

Lure
- Pulls a wild encounter toward a safer nearby area.

Distract
- Reduces enemy accuracy or delays an ambush.

Carry
- Increases extraction safety or saves one item on failure.

Craft
- Performs one downtime task while the player is away.
```

---

## Later Apprentice Abilities

```text
Ward
- Creates a safe engagement radius.

Tag
- Marks a target so ranged attacks can hit from farther away.

Negotiate
- Gets better merchant prices or unlocks strange trades.

Stabilize
- Slows rift collapse.

Rescue
- Recovers part of the player’s loot after a failed run.

Specialize
- Becomes a healer, scout, trapper, scholar, duelist, broker, or familiar-handler.
```

---

## Apprentice Specialization Trees

### Scout

```text
- Reveals hidden rifts
- Improves safety warnings
- Finds rare marks
- Reduces ambush chance
- Improves clue tracking
```

### Arcanist

```text
- Improves crafting
- Identifies relics
- Stabilizes rifts
- Boosts spell builds
- Reduces curse buildup
```

### Handler

```text
- Works with pets and familiars
- Improves gathering
- Distracts monsters
- Improves remote collection
- Reduces companion injury risk
```

### Duelist

```text
- Assists in combat
- Marks enemies
- Interrupts attacks
- Improves ranged/melee combos
- Enables follow-up strikes
```

### Broker

```text
- Finds merchants
- Improves trades
- Unlocks black-market bargains
- Negotiates quest rewards
- Detects scams and cursed deals
```

---

## Apprentice + Ranged Combat Example

```text
Enemy is 90m away.
Player cannot safely approach.

Player sends apprentice to scout.
Apprentice reveals: “Armored Wight. Weak to fire. Shielded from direct shots.”
Player uses ranged fire to break armor.
Apprentice places a ward.
Enemy is pulled into mid-range.
Player finishes the encounter.
```

This turns “I can’t go there” into a tactical situation instead of a dead end.

---

# Downtime System

Downtime should make it feel like the player character, apprentice, companions, and base continue working while the player is away.

The player assigns tasks before leaving. When they return, they receive variable rewards, complications, and hooks.

## Possible Downtime Tasks

- Craft potions
- Farm reagents
- Repair gear
- Research rift types
- Scout nearby anomalies
- Train apprentice
- Train companion
- Decode relics
- Prepare traps
- Brew antidotes
- Negotiate with merchants
- Fortify safehouse
- Send familiar on errands
- Track named monsters
- Stabilize corrupted items

## Downtime Return Moment

When the player opens the app, they should receive a “while you were away” report.

Example:

```text
While you were away:
- Your herb garden produced 3x Ashleaf and 1x rare Dreamcap.
- Your apprentice tracked a wounded Bone Knight nearby.
- The merchant Vex opened a pocket stall for 18 minutes.
- Your cursed dagger is repaired.
```

A more personality-heavy version:

```text
“While you were away, Mira brewed two healing draughts, ruined one perfectly good cauldron, and found a suspicious merchant under the bridge.”
```

Downtime should create return excitement without relying only on daily streaks.

---

## Recovery and Downtime

Recovery Points should improve downtime quality, reliability, and safety.

Examples:

```text
- Improve crafting success rate
- Reduce gear repair time
- Increase crop quality
- Reduce apprentice injury chance
- Improve research outcomes
- Reduce curse leakage while offline
- Add a second downtime task slot
```

---

# Mini Quests

Mini quests should be short, contextual, and tied to real-world movement or local supernatural activity.

## Local Investigation

```text
Scan three traces around this park.
Find the source of the cold spot.
Follow the trail to a minor rift.
```

## Delivery / Escort Abstraction

```text
Carry a sealed charm 500m without entering combat.
Escort a spirit to the next safe landmark.
```

## Hunt / Mark

```text
A named monster has been seen nearby.
Track it through two clues, then fight it.
```

## Crafting Quest

```text
Collect ember-salt from Infernal traces.
Bring it to a merchant or forge.
```

## Realm-Specific Quest

```text
Fae rift nearby:
Do not attack first in the next encounter.
Accept or reject a bargain.
```

Mini quests should not all require going to one exact physical point. Some should be doable from the player’s current area or a safe nearby radius.

---

# Traveling Merchants

Traveling merchants can come to the player through a magic whistle, bell, charm, or similar FPO device. The device opens a temporary pocket dimension or pocket market.

## Design Purpose

Merchants solve a location-game problem: players may not be near useful shops. They also add personality, humor, tradeoffs, and surprise.

## Merchant Functions

- Buy junk relics
- Sell consumables
- Trade realm-specific materials
- Offer cursed bargains
- Identify items
- Repair gear
- Sell rumors and map marks
- Offer mini quests
- Exchange currencies into special prep items at bad rates
- Upgrade apprentice or companion gear

## Merchant Tone

Do not let merchants become a boring shop screen. Make them feel like encounters.

Possible merchants:

```text
Mott, the Rat-Cartographer
Sells maps, lies about half of them.

Saint Candle
A wax saint who sells healing items and remembers your deaths.

The Three-Faced Pawnbroker
Trades in cursed gear, memories, and monster teeth.

Grimble & Sons
There are no sons. Grimble insists there are.
```

## Example Merchant Arrival

```text
The player blows the whistle.
A crooked door unfolds in the air.
Inside is a cramped stall, three lanterns, and a merchant pretending not to recognize the player.
The shop remains open for 8 minutes.
```

---

# Wild Encounters and Map Marks

The game should have both random ambient encounters and intentional marked destinations.

## Ambient Random Encounters

These appear while moving or checking the map. They should be quick, usually 30–90 seconds.

Examples:

- Wandering monster
- Lost spirit
- Strange chest
- Merchant rumor
- Corruption bloom
- Injured NPC
- Realm weather event
- Ambush
- Apprentice discovery
- Feral familiar

Ambient encounters create texture and surprise.

## Marked Map Encounters

These are intentional destinations with clearer value.

Examples:

- Named monster
- Rift
- Resource node
- Mini dungeon
- Merchant pocket
- Shrine
- Corrupted landmark
- Public boss
- Faction event
- Clue chain

Marked encounters create agency and planning.

---

# Session Design

The game should support multiple session lengths.

## 30–90 Seconds: Micro Action

For quick play:

- Collect ambient essence
- Scan local corruption
- Fight a wandering minor monster
- Send apprentice on task
- Craft or upgrade
- Check nearby rifts
- Open merchant pocket

## 3–5 Minutes: Minor Rift

Quick solo run:

- 3 rooms
- 1 mini-boss
- 1–2 boon choices
- Small loot payout

## 8–12 Minutes: Standard Rift

Main play session:

- 5–8 rooms
- Branching choices
- Elite encounters
- Boss
- Meaningful extraction decision

## 20+ Minutes: Group Incursion / Raid

Social event:

- Large public rift
- Multiple players
- Shared boss
- Realm-wide modifiers
- High-value rewards
- Seasonal or faction progress

---

# Early Game Unlock Sequence

Recommended pacing:

```text
Level 1:
- Basic map
- First wild encounter
- First minor rift
- Basic melee/ranged/spell attack

Level 2:
- Apprentice joins
- Downtime task unlocked
- Apprentice can scout or fetch
- First unsafe/inaccessible encounter teaches remote options

Level 3:
- Merchant whistle unlocked
- Pocket merchant appears
- Apprentice can negotiate or identify one item

Level 4:
- First class specialization
- Ranged/melee/magic path starts to matter

Level 5:
- First true rift boss
- Apprentice specialization choice
```

This avoids overloading the player while getting the main meta systems online early.

---

# Daily Player Flow Example

```text
Morning:
Player wakes up.
Recovery Points earned.
Character finished brewing two potions.
Apprentice found a Fae mark nearby.

Lunch walk:
Player earns Endurance.
A wandering Thorn Imp appears.
Player defeats it from mid-range and gets a Fae clue.

Evening:
Player opens a merchant pocket with the whistle.
A snarky merchant sells a cursed bow and a map to a Grave Rift.

Night:
Player enters the Grave Rift.
They push one room too far, extract wounded, but recover a rare bone charm.
Before logging off, they assign downtime:
repair armor, research undead, farm nightshade.
```

---

# Future Expansion Systems

## Parties

Parties can allow nearby players to enter shared rifts or contribute asynchronously.

Possible party roles:

```text
Vanguard: melee/tank
Hexer: debuffs/curses
Warden: healing/protection
Ranger: scouting/long-range
Binder: companion/summon control
```

Parties should not require everyone to stand at the exact same GPS point. A reasonable radius or linked objectives would be safer and more flexible.

---

## NPC or Creature Companions

Companions can bridge combat and downtime.

They can:

- Perform downtime tasks
- Scout rifts
- Modify encounters
- Gather materials
- Join combat
- Specialize in realm types
- Develop quirks

Example:

```text
Your crow familiar is excellent at scouting Undead rifts, but steals coins from merchants.
```

---

## Raids

Raids should be public incursions.

Example raid structure:

```text
A major rift opens at a landmark.
Players weaken shields through local encounters.
Satellite objectives appear around the area.
Then players fight a realm boss during a timed window.
```

A raid does not need everyone physically stacked at one spot. Let players contribute from a safe radius or through satellite objectives.

---

## Persistent World State

Persistent world state can become a major differentiator.

Examples:

- If players ignore rifts, corruption spreads.
- Sealed rifts improve local safety.
- Harvested rifts create better loot but worse corruption.
- Factions control districts.
- Realm types become common after weather, time, or seasonal events.
- Merchant routes change based on player actions.
- Bosses flee and reappear elsewhere if not defeated.
- Apprentice reports change based on local state.

This makes the world feel reactive instead of static.

---

# System Responsibility Map

```text
Endurance = action and exploration
Recovery = healing and preparation
Downtime = return rewards and planning
Merchants = personality and tradeoffs
Wild encounters = texture and surprise
Map marks = agency and goals
Rifts = core roguelike runs
Apprentice = safety, scouting, downtime, and remote action
Companions = progression and attachment
Persistent world = consequence
```

---

# Key Risks and Mitigations

## Risk: Real-world activity becomes punitive

Mitigation:

- Let players always play baseline content
- Use Endurance and Recovery for bonuses and upgrades
- Cap daily gains
- Use effort bands rather than raw distance or athletic performance

## Risk: GPS placement creates unsafe behavior

Mitigation:

- Use broad interaction radii
- Support ranged attacks
- Let apprentice lure, scout, or mark enemies
- Provide pocket arenas
- Add report/relocate tools
- Never require trespassing or crossing unsafe areas

## Risk: Too many disconnected systems

Mitigation:

Tie every system back to the same loop:

```text
Real life → preparation → supernatural opportunity → risk/reward run → progression → better preparation
```

## Risk: Ranged combat becomes obviously superior

Mitigation:

- Ranged is safer but slower or more resource-intensive
- Melee is faster, more rewarding, and better at sealing or staggering
- Magic offers flexible control but can cause corruption
- Apprentice helps bridge range limitations

## Risk: Downtime becomes a generic loot box

Mitigation:

- Tie downtime to apprentice, base, crafting, and local world state
- Use authored-feeling reports
- Include variable outcomes and complications
- Let the player assign tasks intentionally

---

# Recommended Final Core Loop Statement

> **Walk, wheel, ride, or travel through the real world to earn Endurance and discover supernatural opportunities. Rest to earn Recovery and prepare. Assign your apprentice and base to downtime tasks. When rifts, marks, merchants, or monsters appear, choose whether to engage from range, approach for stronger options, send help, or open a pocket encounter. Enter short roguelike realm breaches, build temporary powers, push your luck for better loot, extract before collapse, and use the rewards to improve your character, apprentice, gear, base, and influence over the persistent world.**

---

# Most Important Recommendation

Build the foundation around this model:

```text
Melee = best when safely close
Ranged = safest default interaction
Magic = flexible mid-range control
Apprentice = safety, scouting, downtime, and remote action
Pocket dimension = fallback when GPS placement is bad
Rifts = the main roguelike content
```

The apprentice should arrive early because they are not just a companion. They are the game’s solution to unsafe placement, downtime, onboarding, flavor, and future party/companion systems.

