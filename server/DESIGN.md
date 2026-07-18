# YAS game server — design (v1)

Authoritative Node/TS server for the YAS v1.0 game (docs/design/yas-v1/
GAME-RULES.md + DATA-MODEL.md are the rules of record). Architecture ports
the field-tested patterns from the archived SideQuestAppV2 prototype
(~/CalebApps/SideQuestAppV2) — reference-mined module by module, never
copied wholesale. This doc records what carries, what's new, and the
contracts between modules.

## Stack

Node ≥22 · TypeScript run directly via **tsx** (no build emit — carried
V2 pattern) · **zod** (protocol source of truth, per server/README) ·
**better-sqlite3** (sync, between-ticks only) · **hono** (healthz/status,
hand-rolled Node adapter — no @hono/node-server) · **ws** · **vitest**.
Self-contained npm package in `server/` (own package.json, Dockerfile,
fly.toml).

## Carried patterns (V2-proven; see git history for the source maps)

- **Sim purity** — `server/sim/**` + `server/shared/**` never touch
  `Date.now`/`Math.random`/fs/net/ws/sqlite. Time is injected (`now`),
  randomness is `seededRng(worldSeed, ...namespace, world.tick)`
  (mulberry32 + FNV-1a hashSeed). Enforced by `tools/check-sim-purity.ts`
  in CI (`npm run lint:purity`).
- **Fixed-timestep loop** — accumulator with `maxBurst=100`, interval as
  scheduling nudge only, injected Clock; tests drive `step()` with a
  ManualClock. TICK_HZ=10.
- **Single reducer** — every client intent flows through
  `applyCommand(world, cmd, ctx) → ServerMsg[]`; ctx injects
  `{now, rng, genId, conn, tickHz}`. Illegal intent → one ERR frame,
  zero mutation.
- **Two-lane outbound** — audience-tagged outbox events drain **every
  tick** (combat/claims/notices); positional DELTAs broadcast at **5 Hz**
  (`tick % 2`), per-connection interest window with change fingerprints,
  no empty frames.
- **Snapshot-on-join burst** — JOIN/RESUME reply `[HELLO, SNAPSHOT,
  INVENTORY_UPDATE]`; `REQUEST_SNAPSHOT` re-sends on demand.
- **Heartbeat** — server-initiated PING every 10 s, terminate after 2
  missed PONGs. Client (future) mirrors V2's reconnect machine: backoff
  [500…8000] ms **plus jitter** (V2 gotcha fixed), 30 s idle watchdog,
  resume-token reattach, per-action errors never tear the socket.
- **GPS ingestion** — a fix is a *move target*, never a teleport: reject
  accuracy >50 m, deadband 2.5 m, genuine-relocation snap at 60 m,
  per-tick movement clamp; claiming pauses above SPEED_PAUSE_KMH.
- **Persistence** — SQLite WAL snapshot model, no journal. Only *touched*
  rows persist (non-neutral hexes, changed entities); one transaction per
  save; autosave 15 s + forced save on front-completion/tower/minion
  milestones + SIGTERM/SIGINT final save. Runtime state (mobs, combat,
  interest) is never persisted — it re-derives from seed + persisted
  progress. `world.tick` persists so the RNG cursor can't save-scum.
- **Determinism gates** — golden tests: byte-stable `serialize()` fixture
  + chi-square goodness-of-fit on loot rarity odds; `boot`-style test:
  same seed + same command history ⇒ byte-identical serialize.
- **Wire discipline** — numeric ops, frozen forever, retired numbers
  reserved; new data rides optional fields. **ProtocolVersion is
  enforced** (V2 declared but never checked it): JOIN/RESUME carry it;
  mismatch → ERR `VERSION_MISMATCH` and close.

## Deliberately dropped from V2 (for v1)

Geo-sharding/WorldManager (single world; keep the seam — everything takes
`world`), breach/veil fiction, Cairn combat tables, camps, name-only
identity kept but **noted as untrusted** (bearer resume token, no auth —
acceptable for a closed test; harden before open TestFlight).

## The YAS model (new; rules → GAME-RULES.md §)

- **Hexes** (§1): flat-top axial grid in projected metre space (equirect
  local tangent at origin), `HEX_ACROSS_M = 60`, `"q,r"` keys, explicit
  `hexNeighbors` (new — V2 only had radius scans). Ownership is a world
  map `hexes: Map<key, {owner: 'players'|'gloom', frontId, towerId?,
  contestedMobId?, lastChangedAt}>` — absent = neutral. One shared player
  side (no PvP factions in v1).
- **Fronts** (§1): static seed-derived partition of the hex plane into
  named neighbourhoods (8×8-hex super-cells; names drawn from a seeded
  street-name list — placeholder until real map data). Tug-of-war % =
  owned counts / front size, computed on read. Completion (100 % player)
  pays FRONT_BONUS_GOLD + a Grumble Chest, then that front's gloom
  pressure rests for FRONT_RESET_H.
- **Claiming** (§1): entering a hex you don't own claims it instantly for
  your side. Entering a GLOOM hex adjacent to player territory marks it
  CONTESTED and engages its mob (§3) — winner owns it.
- **Gloom pressure** (§1 §8): per-front accumulator advances gloom
  capture along adjacency from existing gloom hexes, up to
  GLOOM_RATE_PER_H=3 hexes/front/h while unopposed; Chill Bell −40 % in
  radius 2, Bastion Post blocks flips in radius 1 while standing; towers
  in contact lose durability 5/h. Deterministic
  (`seededRng(seed,'gloom',frontId,tick)`).
- **Mobs** (§3): seed-derived spawn field tethered to gloom territory
  (V2 ambient-field pattern, lissajous roam); mobs paint their hex for
  GLOOM as they roam. Gloomlings + Turf Tyrants (4-segment HP, 100 %
  drop). Combat is real-time server-resolved: hotbar slot ops validated
  by range (mob hex + 1-hex buffer), cooldown stamps, weak ×1.5 / resist
  ×0.5, crit 10 % + gear. Victory → hex flips, XP+gold, 25 % item drop.
- **Death** (§5): 60 s revive window (party member within 30 m), or
  respawn at home hex; lose contested-this-run hexes (cap 3) + gold drop
  max(50, 10 %) recoverable 1 h within 10 m.
- **Chests** (§6): server-spawned on hexes, open within 10 m; 3-item
  staged rarity roll (weights in tuning; chi-square golden).
- **Progression** (§7): xp curve 100×1.35^(n−1), +2 ATK/+1 DEF/+10 HP,
  Pocket Blizzard LV 13, cape slot LV 15, hammer set 2/4.
- **Economy** (§11): gold + materials strictly per rules; shop stock +
  daily deal −30 % + mystery box 199 g; sell 50 %.
- **Towers** (§8): build gated on standing ≤10 m on an owned untowered
  hex, cap 5; remote repair 6 / upgrade 22 (+25 %/lvl, max 3) / salvage
  ~40 %; rubble at 0 durability (rebuild needs a visit).
- **Minions** (§9): wall-clock jobs (Gather ~30 min / Scout ~15 min /
  Scavenge ~1 h, 20 % injury); reports with rumor deep-links; heal 50 g,
  hire 200 g.
- **Quests** (§10): 3 dailies + territory + one story chain; dailies
  reset at DAILY_RESET_UTC_H (approximation of "dawn local" until real
  timezone handling).
- **Runs** (§2): client-signaled start/end; server tracks per-run
  counters (hexes, mobs, gold-this-run, loot) and applies the
  early-end/death gold-drop rule; summary frame at end.
- **Party** (§12): ≤4, join by code (`BONK-4242`-style, seeded
  generator) — shared side, co-op combat within 50 m, revive.

## Protocol v1

`server/shared/protocol.ts`: zod discriminated union on numeric `op`;
`decode` = JSON.parse + schema parse (reject → ERR BAD_REQUEST);
`PROTOCOL_VERSION = 1`. Envelope `{op, t, seq?}` client / `{op, t}`
server. Op numbers are the contract; keep client 1–39, server 100–139,
never reuse. Full catalog lives in protocol.ts (single source; the
GDScript mirror is generated by `tools/protocol-gen`).

## Tuning

`server/shared/tuning.ts` holds every GAME-RULES DEFAULT (server-side
source of truth per CLAUDE.md). The Godot shell's `Rules`/`Catalog` must
agree: `tools/protocol-gen` emits `game/src/net/server_protocol.gd` and
`game/src/data/server_tuning.gd`, and `game/tests/data_sanity.gd` asserts
the shell's constants match the generated values — drift fails CI.

## Ops

Fly.io app `yas-server` (sjc, shared-cpu-1x/512 MB, 1 GB volume →
`/data/world.db`, `/healthz` checks, `auto_stop_machines = "suspend"`
scale-to-zero). `npm run deploy` = ci:fast + `flyctl deploy`.
Env: PORT, DATA_DIR, WORLD_SEED, ORIGIN_LAT/LNG, TICK_HZ, AUTOSAVE_MS,
DAILY_RESET_UTC_H. `config.ts` is the only env reader; `main.ts` the only
`Date.now`.
