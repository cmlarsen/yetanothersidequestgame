# Game features plan — compass heading, combat, multiplayer (native)

Successor to `RN-CONVERSION-PLAN.md` (which took us to a 60 fps native world at
runtime `m0`). This plan covers making the native client the *game*: compass
heading-up, the full combat loop, and multiplayer. Milestones are ordered by
dependency and sized so each one is a shippable OTA.

## 0. Where we actually are (survey, 2026-07-12)

The gap is smaller than "implement combat and multiplayer" sounds, because the
sim/server/store were built shared-first:

**Already done, on both platforms (in `shared/` + `client-core/`):**
- Wire protocol v2 has the whole game: `ATTACK`/`USE_ABILITY`/`FLEE`,
  `COMBAT_EVENTS`, `LOOT`/`LOOT_RESULT`, `SEAL_BREACH`, `INTERACT`/`DIALOGUE`
  (incl. chest pry), `MERCHANT`, `EQUIP`, `INVENTORY_UPDATE` (+ bestiary),
  `RESUME`, `PARTY_UPDATE` (`shared/protocol.ts`).
- The server *runs* all of it — real-time arcade combat, loot, echoes,
  progression, territory, breach sealing with **auto-scaling for co-located
  heroes** (`server/sim/systems/arcade.ts`, `breach.ts::partyAtBreach`).
- The shared store already **reduces every combat/economy frame** — events,
  echo grants, inventory, dialogue, fx (`client-core/store/store.ts`). Mobile
  needs UI + input, not state plumbing.
- The renderer already has the hooks: `frame.azimuth` (heading-up),
  `groundPoint(sx,sy)` (tap→world picking), `project(x,y)` (world→screen for
  overlays), and a user-orbit offset that composes with the base azimuth
  (`client-core/render3d/persp3d.ts`).
- Multiplayer *presence* works today: other players ride the snapshot/delta
  wire and render as actors on native already.

**Missing on native (this plan):**
- Compass heading-up camera (F1).
- Combat input + HUD + juice (F2) — web has all of it in `web/src/App.tsx`
  (~1,500 lines, tap-targeting at L324-332, cooldown panel at L774-813) and
  `web/src/render/juice.ts`; none is ported.
- Session resume — mobile always sends `JOIN`; `sessionToken` is never
  persisted, so every app launch is a fresh hero (F3).
- Multiplayer *as a feature*: name tags, social affordances, and the real infra
  gap — the server is **one world bubble** (`PLAY_R` around a single origin,
  with re-anchor heuristics in `server/sim/systems/spawns.ts`), so two players
  in different cities fight over one anchor (F4).

**Ship-vehicle rule (from the RN plan):** everything below is JS/assets ⇒ OTA
on runtime `m0`. No milestone requires a native module — compass heading comes
from `expo-location` (already in the binary) via `watchHeadingAsync`, and
token persistence uses `expo-file-system` (already in the binary) instead of
AsyncStorage/SecureStore precisely to avoid an `m1` rebuild.

---

## F1 — Compass heading-up (small; 1 OTA)

Goal: the world rotates so "up" is where you're facing — the single biggest
walking-immersion win, and it exercises the azimuth plumbing combat's
camera-relative feel depends on.

1. **Heading source** — `Location.watchHeadingAsync` (expo-location wraps
   Core Location's *fused* compass: magnetometer + gyro + accelerometer tilt
   compensation, done by the OS — no hand-rolled sensor fusion needed, same
   lesson as GPS speed/course). Use `trueHeading` when `accuracy ≥ 0`, fall
   back to `magHeading`. Lives next to the GPS watcher in
   `mobile/src/platform.ts` behind an injected `HeadingWatcher` (mirror of
   `setGeoWatcher`) so `client-core` stays platform-free.
2. **Smoothing** — pure helper in `client-core/geo/heading.ts`:
   shortest-arc exponential smoothing (τ ≈ 250 ms) + a ~2° deadband so a
   phone held still doesn't micro-wobble the whole world. Unit-test the
   wraparound (359°→1°) and deadband like `gps-filter.test.ts`.
3. **Camera wiring** — `WorldScreen` passes smoothed heading (rad) as
   `frame.azimuth`. Lock/unlock model:
   - heading-up is ON by default (locked);
   - a two-finger twist or pan-orbit sets a manual offset (persp3d already
     composes `baseAz + userOrbit`) and *breaks* the lock;
   - double-tap recenters **and** re-locks (extends the existing
     `resetView` gesture).
4. **HUD** — small compass chip (N indicator) that doubles as the lock
   toggle; tapping it re-locks north-up ↔ heading-up.
5. **Facing** — when stationary (GPS speed < 0.3 m/s) the self actor's facing
   follows compass heading instead of stale GPS course; server keeps
   authoritative facing for others.

Risk: magnetic interference indoors → `accuracy` degrades; freeze the last
good heading rather than swinging (same "trust gate" idea as the GPS filter).

## F2 — Combat on native (the core loop; 2–3 OTAs)

Goal: walk → see mob → tap → fight → loot → echo ceremony, all on the phone.

1. **Extract shared interaction logic** (`client-core/interact.ts`): the
   web's tap resolution — `groundPoint(sx,sy)` → nearest mob/breach/POI within
   tap radius → range-check vs `ARCADE.attackRangeM` → intent
   (`ATTACK`/`SEAL_BREACH`/`INTERACT`) or "too far" notice — currently lives
   inline in `web/src/App.tsx` (L300-360). Pull it into client-core, and have
   web consume it too (dedupe, and it's pure → unit-testable).
2. **Tap gesture on native** — add a single-`Tap` to the `WorldScreen`
   gesture race (before double-tap, with `requireExternalGestureToFail`
   ordering), feeding the shared resolver with buffer-scaled coordinates.
3. **Command panel HUD** — RN port of the web kit's combat controls:
   Attack / Special / Flee buttons with cooldown sweeps driven by
   server-stamped `atkReadyAt`/`spReadyAt` + optimistic local prediction on
   press (exactly the web posture, `App.tsx` L774-813). Plus HP meter, level,
   gold. New `mobile/src/ui/` — plain RN Views/Pressables, styled to match the
   web kit; **no new native deps**.
4. **Juice** — `web/src/render/juice.ts` is already pure/DOM-light by design
   ("§8.7 presentation-only, injected clock"): move it to
   `client-core/render/juice.ts` (web re-exports). Render on native as an
   **RN overlay layer** positioned via `persp.project()` — floating damage
   numbers, hit flashes, HP-drain ghosts. A couple dozen absolutely-positioned
   Texts per frame is well within budget at 60 fps; if profiling disagrees,
   fall back to in-scene sprite quads (decision recorded, not built).
5. **Loot & ceremony** — `LOOT_RESULT` toast, echo-grant ribbon
   (`store.echoes` is already populated, incl. `newEntry`), tap-to-loot on
   corpse markers.
6. **Death/respawn + dialogue** — downed state overlay; minimal `DIALOGUE`
   sheet (speaker, lines, choices, pry readout) as an RN bottom sheet — enough
   to play quests/chests; the full Veilbook/merchant/inventory screens are the
   follow-on UI milestone, *not* blockers for combat.

Suggested OTA slicing: (a) tap-to-attack + command panel + HP, (b) juice +
loot/echo ceremony, (c) dialogue/pry + death flow.

## F3 — Session resume (small; 1 OTA; prerequisite for multiplayer feel)

Goal: your hero survives app restarts and backgrounding — identity is the
foundation multiplayer stands on.

1. Persist `sessionToken` (already in the store from `HELLO`,
   `store.ts:84`) to a JSON file via **expo-file-system** `Paths.document`
   (already in the binary — deliberately *not* AsyncStorage/SecureStore, which
   would force an `m1` rebuild).
2. Launch flow: token on disk → skip JoinScreen, send `OP.RESUME`
   (server handler exists, `server/sim/commands.ts:138`); on
   `ERR SESSION_UNKNOWN` → clear token, fall back to JoinScreen.
3. Reconnect flow: `AppState` background→active + socket-close handling in
   `client-core/net/gameSocket.ts` → auto-`RESUME` with backoff, HUD shows
   "reconnecting…" instead of dumping to Join.
4. "Leave" button becomes "Switch hero" (explicit token discard).

## F4 — Multiplayer (one design decision + one real server milestone)

What already works: shared world, live presence, and **proximity co-op** —
breach garrisons auto-scale to the heroes standing there and seal credit is
shared (`partyAtBreach`). The design lean: *a party is people physically
together* — it fits the real-world premise and needs no invite flow.

**F4a — Social presence layer (client, 1 OTA):**
- Name tags + HP slivers over other players (RN overlay via `project()`,
  same layer as juice).
- Co-located party HUD: heroes within earshot (~engage radius) listed with
  HP — this is `partyAtBreach` semantics surfaced as UI, fed by data already
  on the player wire.
- One social verb to start: **ping/wave** — tap a player → emote burst others
  see. Needs a tiny wire addition: `OP.EMOTE = 18` client→server (new number;
  17 is the last used, retired numbers stay reserved) echoed on a
  `COMBAT_EVENTS`-style presentation frame or a new `EMOTE_EVENT = 117`.
  Additive, protocol version unchanged.

**F4b — Geo-sharded worlds (server; the real milestone):**
Today `server/sim/world.ts` is one world anchored at one origin with a
`PLAY_R` bubble and "don't let a far joiner yank the anchor" heuristics
(`spawns.ts`). Two players in different cities = one of them plays at the
wrong anchor. Fix:
- **Shard key = geohash cell** (~precision 4, ≈ 20 km) of the player's first
  fix: one `World` instance per active cell, lazily created, ticked on the
  shared loop, hibernated (persisted) when empty. Breach/POI lattices are
  already deterministic in `(seed, origin)` so a shard rebuilds identically.
- Route on `JOIN`/`RESUME`: hero's persisted home cell → its world; crossing
  a cell boundary re-homes on the next session (v1: no live handoff — walking
  20 km mid-session is not the POC problem).
- Persistence is per-hero already; add `worldCell` to the hero record.
- Keep single-process (one Fly machine, N worlds in memory); process-level
  sharding is a later scaling knob, not part of this milestone.
- Sim tests: two joins in different cells get independent anchors/lattices;
  same cell shares one world (extends existing world tests).

**F4c — later (explicitly deferred):** named cross-shard parties/friends,
chat, live shard handoff, PvP. None are needed to make co-op play feel real.

## 5. Sequencing & sizing

| # | Milestone | Size | Ships as |
|---|-----------|------|----------|
| F1 | Compass heading-up | S (day) | OTA `m0` |
| F2 | Combat loop (3 slices) | L (several days) | OTA `m0` ×3 |
| F3 | Session resume | S (day) | OTA `m0` |
| F4a | Social presence + ping | M | OTA `m0` (+server deploy) |
| F4b | Geo-sharded worlds | M/L (server) | Fly deploy only |

F1 → F2 → F3 → F4a → F4b. F3 could swap earlier (it's independent), but
combat is what makes field-testing everything else worthwhile. F4b touches no
client code and can proceed in parallel with F2/F3 if wanted.

## 6. Verification per milestone

- `npm run ci:fast` + `ci:mobile` gate every OTA (already wired into `ota`).
- New unit tests: heading smoother (wraparound/deadband), shared tap resolver
  (pick priority, range gating), shard routing (cell isolation/sharing).
- Web vision harness covers the shared pieces (tap resolver, juice) since the
  web client consumes the same client-core modules.
- Field pass per OTA on the preview build (auto-updates on launch), fps
  counter stays on: combat HUD + juice must hold the 60 fps floor — overlay
  approach reverts to in-scene sprites if it doesn't.

## 7. Status log

- 2026-07-12 — Plan written after codebase survey; awaiting go on F1.
- 2026-07-12 — **F1–F4b all implemented, verified, and pushed to main.** 165 tests
  green (purity + root typecheck + mobile typecheck all clean).
  - **F1 compass heading-up** (2c4d494): pure shortest-arc heading smoother
    (`client-core/geo/heading.ts`, 8 unit tests) + platform-free provider fed by
    `watchHeadingAsync`; WorldScreen owns the azimuth across heading/north/free
    modes; compass chip toggle; twist→free-orbit; double-tap recenters+re-locks;
    self faces the compass when stationary. OTA (m0).
  - **F2 combat** (75fff6c, fixes 9eed08f): shared `client-core/interact.ts`
    (tap resolver) + `combat.ts` (command-dock derivation) — web now consumes
    both (dedup); `juice.ts` moved to client-core behind an injected
    reduced-motion resolver. Native UI: CombatDock, PlayerHud, CombatOverlay
    (damage numbers + mob HP bars via `project()`, ~22 Hz), LootEcho,
    DialogueSheet (+pry), DeathOverlay. Single-tap→resolveTap. 16 shared tests.
    Adversarial review (5 findings) fixed: pinch no longer breaks heading-lock,
    faster single-tap, downed input guard, tap dead-zones. OTA (m0).
  - **F3 session resume** (da0f6cc): socket `resume(token)`/`ensureConnected()`
    + `onSessionInvalid`; SecureStore token persistence (m0-safe — already in the
    binary); App.tsx resume-on-launch splash; AppState reconnect; Leave→Switch
    hero. OTA (m0).
  - **F4a social presence + emote** (11b9bb5): additive `OP.EMOTE=18` /
    `EMOTE_EVENT=117` (protocol version unchanged); server rebroadcasts within
    `EMOTE_R`; store `emotes`; native name tags + HP slivers + emote bursts +
    PartyHud; tap-a-friend to wave. 2 server tests. OTA + Fly deploy.
  - **F4b geo-sharded worlds** (d673839): `WorldManager` splits the world into
    ~11 km cells so distant players get independent anchors (the far-joiner bug);
    `Character.worldCell`; gateway routes per message + migrates on first fix;
    loop ticks all worlds; **zero-migration persistence** (additive `cell_origin`
    table, home world unchanged → live DB safe); heroes persist globally and
    reload into their shard. 10 tests (cell isolation, routing/migration, SQLite
    round-trip). Server-only — Fly deploy, not OTA. **Follow-up:** non-home shard
    breach/POI durability; live cross-cell handoff (F4c).
