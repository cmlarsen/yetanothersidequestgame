# YAS v1.0 — Screen Specs

28 screens as laid out in **YAS v1.0.dc.html** (columns = app areas, arrows = primary
navigation). Every screen is a 402×874 portrait frame. All screens share the token set in
README.md. "3D" = KayKit render region (placeholder in mocks). Rules references → GAME-RULES.md (§).

---
## Column 0 · FIRST LAUNCH

### 1. Splash
Key art (3D), stacked logo ("YET ANOTHER" small / "SIDEQUEST" 46px cyan glow, −2°),
tagline "Walk the real world. Claim the map.", TAP TO START, version footer.
→ tap anywhere → Location permission.

### 2. Location permission (pre-prompt)
Pin icon medallion, headline "YOUR LEGS ARE THE JOYSTICK", rationale copy, two reassurance
chips (only while app open · never shown to other players), then the OS dialog (mocked).
Interactions: request on CTA; on deny show soft-retry state (not mocked — reuse layout with
warning copy). → Notification permission.

### 3. Notification permission (pre-prompt)
Bell medallion, "KNOW WHEN IT MATTERS", 3 value rows (territory attack / chest nearby /
friend invite), ALLOW NOTIFICATIONS + MAYBE LATER (skip allowed). → first map view.

### 4. Tutorial overlay (first map view)
Dimmed live map, spotlight ring on player avatar, SKIP top-right, coach card ("THIS IS
YOU" + claim explanation), 4 progress dots, NEXT. 4 steps DEFAULT: you/claiming, fronts
meter, encounters, hot bar. Dots advance; SKIP ends tutorial.

## Column 1 · ONBOARDING

### 5. Character selection
"CHOOSE YOUR CHARACTER", featured card (face, name SIR BONKALOT, epithet, flavor line,
ATK/DEF/SPD stat bars, MOST PLAYED badge), swipe row of 5 faces (selected enlarged w/ cyan
ring; locked entry dimmed w/ lock + unlock hint "Grumbeard unlocks at LV 15"),
CONFIRM SELECTION. Swiping the row swaps the featured card.

## Column 2 · HOME

### 6. Home / pre-run
Header: avatar+name+LV+XP bar | gold pill. Live map preview card (front % chip, mob-count
chip). START RUN (primary). DAILY QUESTS section (2 rows w/ progress). PARTY row (stacked
faces, status line, VIEW). Bottom nav: HOME · MAP · PARTY · ITEMS · MORE (5 tabs, active
cyan). §2.

### 7. Level up + skill unlock
Radial celebration bg, "LEVEL UP!" + big number, 3 stat-bump pills (ATK/DEF/HP), NEW SKILL
card (icon, name, effect line, ADD TO HOT BAR), next-unlock tease chip, CONTINUE.
Pop-in stagger: title → pills → card (0.2 s steps). §7.

## Column 3 · MAP HUB

### 8. Exploration map (core map)
Grass hex map w/ turf tints (player cyan / gloom purple / fog dark rings per §1), roads as
sand paths, player avatar w/ pulse ring + YOU tag, "?" markers in fog, NEW AREA toast
(green chip), steps pill + compass pill (top), quest-progress chip (bottom, e.g.
"Chest in the fog — 3 hexes north"). Bottom nav as Home with MAP active + big CRAWL/START
center button opens run controls. §1 §2.

### 9. Map info popover
Dimmed map, tapped element highlighted (white pulse ring), anchored card w/ pointer:
name/title/LV, flavor bio, 3 stat chips (HEXES HELD / THREAT ★ / LOOT DROP), weakness
chip ("Weak to BONK · resists ZAP"), ATTACK (red) / AVOID buttons, dismiss hint. §4.

### 10. Paper doll + inventory
Name/epithet/LV header; 5 stat cells w/ green gear deltas (HP 184 +52 · ATK 42 +18 ·
DEF 31 +14 · SPD 12 +2 · CRIT 8% +8%); center 3D character flanked by 6 gear slots
(HELM, MAIN HAND w/ item+stat line, OFF HAND, CHEST·EPIC, BOOTS, CAPE·LV-locked) each w/
per-piece stat contribution; HAMMER SET 2/4 bonus bar; filter tabs; 5-col inventory grid
(rarity borders, E=equipped, gold dot=new, +12 overflow); legend footer. Tap slot →
unequip; tap bag item → equip (delta badge). §7.

### 11. Party management
"PARTY" header, party code pill (BONK-4242, tap to share), member rows (face, name, LV,
status ONLINE/IN COMBAT/OFFLINE w/ color dot, distance if online), 1 open slot row
(INVITE A PLAYER), PLAYERS NEARBY (2) list w/ distance + INVITE, START GROUP RUN. §12.

## Column 4 · ENCOUNTERS

### 12. NPC dialogue
Map bg dimmed; NPC portrait (gold ring) + name/title; bottom sheet: dialogue line
(personality copy), quest chip (name, objective, reward), 3 stacked replies —
primary accept (cyan), secondary detail, tertiary decline (dim). §10.

### 13. Quest board
"QUEST BOARD" header, tabs DAILY/STORY/TERRITORY, parchment quest cards (pin dot, title,
tag, flavor line, progress bar + fraction, gold reward; completed card gets rotated DONE!
stamp + CLAIM state), "New quests in 7h 12m" slot, CLAIM REWARD CTA. §10.

### 14. Shop (merchant)
Merchant portrait + parchment speech bubble (voice line), BUY/SELL tabs (sell = 50% note),
gold pill, 2×2 item cards (art, name, rarity pill, price chip; states: deal badge −30% w/
strikethrough, unaffordable red price w/ red-bordered chip, mystery box ??? rarity),
restock note, BUY CTA reflecting selection. §11.

## Column 5 · COMBAT

### 15. Real-time combat ("Turf brawl")
Map stays visible. Boss plate top (name, TURF TYRANT · LV, segmented HP bar ×4).
3D mob center (bob anim) + contested-hex dashed gold ring. Ally avatars w/ HP conic rings
+ name tags. Damage floats (white/gold/pink CRIT). Player avatar bottom-left w/ HP ring.
Bottom gradient scrim + hot bar: 5 slots (weapon w/ rare-blue glow border, spell w/
cooldown sweep+seconds, spell ready, consumable ×3 badge, empty dashed +) with names
under; FLEE round button bottom-left. Hold any slot → Equip drawer. §3.

### 16. Equip drawer (hot bar editing)
Combat/map dimmed; mob small at top; the 5-slot bar shown with target slot highlighted
(SLOT 2 tag + pulse); bottom sheet: drag handle, "EQUIP · SLOT 2" + hint, tabs
WEAPONS/SPELLS/POTIONS, 3×2 item grid (rarity borders, selected glows cyan, locked cell w/
lock + source hint "Found in Gloom chests · LV 15"), EQUIP <ITEM> CTA. §3.

### 17. Victory
Map bg; defeated mob grayed + tipped (opacity .55); cyan claim ring pulse; "VICTORY!"
gold display + "HEX CLAIMED FOR <side>" chip; +80 XP / +40 GOLD floats (staggered pop-in);
front meter at top ticks (36% ▲ / 19% ▼); CONTINUE. §3 §1.

### 18. Death screen
Dark red radial bg. "YOU WERE / DEFEATED" stacked (intentional overlap treatment),
cause line, 3D fallen-character region, tally chips (HEXES KEPT +4 / HEXES LOST −3 /
GOLD DROPPED −50), revive helper chip (ally face, "Britt is 30 m away and can revive
you"), WAIT FOR REVIVE · 0:42 (green, live countdown) + RESPAWN AT HOME (−3 HEXES). §5.

## Column 6 · LOOT LOOP

### 19. Loot box found (proximity)
Map w/ glowing chest (gold radial halo, bob, GRUMBLE CHEST tag), player + white path dots,
"CHEST NEARBY · 18 m away" banner, bottom: "GET WITHIN 10 m TO OPEN" + distance progress
bar + disabled gray CTA "OUT OF RANGE — MOVE CLOSER" (enables + goes gold in range). §6.

### 20. Rewards (chest open)
Dark bg + slow-spinning gold rays + confetti ticks. "GRUMBLE CHEST!" title + source line.
3D chest region w/ pulse ring. 3 loot cards staggered pop-in (center = highest rarity,
raised + glow). +250 gold / +120 XP chips. COLLECT ALL. §6.

### 21. Run ended / retreat
"RUN ENDED" + timestamp line, tally chips (HEXES KEPT +4 / XP KEPT +310 / GOLD DROPPED
−120), loot state cards (SECURED vs LEFT BEHIND at 45% opacity), gold-recovery info chip
(1 h), BACK TO MAP + VIEW RUN STATS. §2.

## Column 7 · ANYTIME

### 22. Notification elements
OS-style push mocks (app icon, sender "Yet Another Sidequest", copy per trigger:
territory attack / chest spawn / party invite) + in-app toast variants. Deep links per
§13.

### 23. Settings
Sections: LOCATION & BATTERY (GPS HIGH/SAVER segmented, screen-off steps toggle),
SAFETY (pause >15 km/h, reduced motion), NOTIFICATIONS (3 toggles), ACCOUNT (avatar,
gamertag, Signed in with Apple, MANAGE), legal footer. Toggle = 44×26 pill. §14.

## Column 8 · DEFENSE & MINIONS

### 24. Tower placement (in person)
Map; standing-on-owned-hex confirmation chip (green check); 3D tower ghost + dashed range
ring (RANGE: 2 HEXES tag); YOU avatar; header "PLACE A TOWER" + 🪵 balance; bottom sheet:
"CHOOSE A TOWER" + "3/5 PLACED · 1 PER HEX", 3 tower cards (icon medallion, name, effect
line, 🪵 cost; unaffordable card dimmed w/ red "NOT ENOUGH"), BUILD CTA, placement-rule
footnote. §8.

### 25. Defense view (remote)
Dark remote-map render, tower pins w/ durability conic rings (green ok / yellow+⚠️ REPAIR
badge low), GLOOM PUSH marker (bobbing), header "DEFENSE — <front>" + "🛋️ REMOTE" chip,
front meter, overnight digest chip ("repelled 14 Gloomlings…"), REPAIR ALL · 🪵 9 +
FRONTS ▾ selector. §8.

### 26. Tower manage sheet
Bottom sheet over dimmed map: tower icon + name + LV + placement meta/effect line,
durability bar w/ rubble warning, TARGET PRIORITY pills (NEAREST/STRONGEST/GUARD HOME
HEX), REPAIR · 🪵 6 (green primary) + UPGRADE LV 3 · 🪵 22, footer: remote note +
SALVAGE (🪵 8 back). §8.

### 27. Minion dispatch
"MINIONS" + gold pill; rule line ("they never fight or claim ground"); roster rows
(selected w/ cyan glow; busy w/ ON JOB timer + progress; hire slot dashed w/ price);
"SEND <NAME> ON…" job rows (icon, name, duration, output; risky job w/ ⚠️ 20% INJURY);
SEND CTA; wall-clock + injury footnote. §9.

### 28. Minion return report
Dimmed bg, gold-green modal: minion face pop-in, "<NAME>'S BACK!", personality quote,
haul rows (+14 🪵), salvage row (perk description), rumor row (⚠️ front intel + VIEW FRONT
button), COLLECT · SEND HIM OUT AGAIN. §9.

---
## Cross-screen behaviors
- Persistent celebrations use popIn (scale 0→1.12→1, .5 s ease-out, staggered .2 s).
- Idle 3D mobs/chests bob (translateY ±6 px, 2–2.4 s ease-in-out loop).
- Attention rings use ringpulse (scale 1→1.25 fade, 1.4–2 s loop).
- All modals/sheets: #141a28, 26 px top radii (sheets) or 22 px (centered), 3 px accent
  border keyed to content (gold=reward, red=danger, green=success, blue=info).
- Disabled/locked: 50–65% opacity + explanatory badge, never hidden.
- Currency/pill order in headers: gold first, then materials.
