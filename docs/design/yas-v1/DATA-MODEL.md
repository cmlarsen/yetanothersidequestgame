# YAS v1.0 — Data Model & State

Server-authoritative: hexes, fronts, mobs, chests, towers, combat sessions, party.
Client-owned: local UI prefs, tutorial progress, pedometer buffer.

## Entities

**Player** — id, gamertag, characterId, level, xp, gold, materials, homeHexId, hotbar
[5 × slotRef], equipment {helm, chest, mainHand, offHand, boots, cape}, inventory
[ItemInstance], stats derived {hp, atk, def, spd, critPct} = base(level) + Σ gear,
settings {gpsMode, stepTracking, speedPause, reducedMotion, notif{attack, chest, party}},
partyId?, steps {today}, activeRunId?

**Character** (catalog) — id, name, epithet, flavor, baseStats, unlockLevel?, modelRef

**Item** (catalog) — id, name, rarity, slotType (weapon|spell|consumable|helm|chest|boots|
cape|offHand), stats {atk?, def?, hp?, spd?, critPct?}, abilityTag (BONK|ZAP|CHILL|…),
effect {dmg?, targets?, blockSec?, healHp?, slowSec?, cooldownSec?, charges?}, setTag?,
levelReq?, value

**ItemInstance** — itemId, isNew, equippedSlot?

**Hex** — h3Id, owner (neutral|player_side|gloom), frontId?, contested?, towerId?,
lastChangedAt

**Front** — id, name, hexIds, pctPlayer, pctGloom, gloomPressureRate, completedAt?,
scoutIntel? {pushEta}

**Mob** — id, speciesId, level, isTyrant, hp/maxHp (segments=4 for tyrants), hexId,
weakTags[], resistTags[], threatStars, lootRarityHint, bio

**CombatSession** — id, mobId, participantIds[], startedAt, state, damageLog

**Chest** — id, hexId, rarityWeights, spawnedAt, openedBy?

**Tower** — id, ownerId, type (bonk_turret|chill_bell|bastion_post), hexId, level 1–3,
durability 0–100, targetPriority, isRubble, log [{ts, event}]

**Minion** — id, ownerId, name, bio, state (idle|onJob|injured), job? {type, startedAt,
durationSec, riskPct}, quotes[]

**Quest** — id, tab (daily|story|territory), title, flavor, objective {type, target,
frontId?}, progress, reward {gold, item?}, state (active|claimable|done), resetAt?

**Party** — id, code, memberIds (≤4), memberState {online|inCombat|offline, lastLoc}

## Client state machines
- **Run**: idle → active (START RUN) → summary (END/death/retreat) → idle.
- **Combat HUD**: perSlot {readyAt, chargesLeft}; combo {count, expiresAt}; playerHp;
  allies[]; bossHp.
- **Death**: countdown 60 s; reviveAvailable = ∃ partyMember within 30 m online.
- **Chest proximity**: distance stream → CTA enabled at ≤10 m.
- **Tower placement**: eligible = standingHex.owner==player && !standingHex.towerId &&
  towersPlaced < cap && materials ≥ cost.

## Notification triggers → deep links
attack → Defense view (front) · chest ≤200 m → Exploration map (chest focused) ·
party invite / group run → Party · minion done → Minion return modal.

## Key derived displays
Front meter %s · gear-contribution greens on paper doll · hit/damage floats ·
"New quests in Xh Ym" (dawn reset) · away digest (towers log since lastSeen).
