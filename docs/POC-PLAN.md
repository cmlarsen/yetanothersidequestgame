# SideQuest POC — Living Build Plan (Foundation Contract + Sections 1–11)

> **Status — living plan for a rapid-iteration POC. Nothing here is locked.** This document assembles the Foundation Contract (§1–§3) and the domain sections (§4–§10) authored in parallel, plus an editorial reconciliation pass (§11). It is the working agreement for a throwaway prototype meant to reach two kids' phones in a forest *this week*, not a shipped-product spec. Where sections disagree, **§11 is the tie-breaker of record** — it states which section wins and why. Treat every constant, name, and schema as provisional until it survives the first forest test; expect churn, and change the plan when the woods tell you to.

**Executive summary.** SideQuest is a real-world roguelike RPG: a fantasy-skinned GPS map where a small trusted party (the kids) walk to procedurally-placed *breaches*, fight turn-based co-op combat across "the veil," seal the breach, loot, level, and build a shared camp/Bastion whose auto-turret holds territory while they're away. The architecture is one Node process on a single Fly.io machine serving both static client and authoritative WebSocket sim, with an I/O-free, clock-and-seed-injected simulation core (`server/sim` + `shared/`) that is byte-deterministic and therefore fully testable by headless bots, Monte-Carlo balance sweeps, and a vision-critique loop — the "iterate every system with no human" pillar. Sections 1–3 freeze the module tree, data model, and wire protocol that every other section must conform to; sections 4–9 fill in combat, economy, world/procgen, camp, client/art, and the test harness; section 10 sequences it all into vertical-slice milestones with an explicit **M0→M1→M2 forest-test cut line**. Because §4–§9 were drafted *without* the final §1–§3 contract text in hand, they invented divergent vocabularies for the same wire, entities, and tunables; **§11 resolves those divergences** — freezing §3 as the binding wire, a single shared world origin, one 5-tier breach ladder, one Character schema, one damage-type enum, one tuning namespace, and one code tree — and logs the genuinely open questions (apprentice scope, RP-vs-DP currency, lat/lng-in-sim) with a recommendation each, so no networked feature is blocked on ambiguity.

## Table of Contents

1. [Foundation & Architecture](#1-foundation--architecture)
2. [Data Model](#2-data-model)
3. [Network Protocol & Server Simulation Loop](#3-network-protocol--server-simulation-loop)
4. [Combat & Monsters](#4-combat--monsters)
5. [Progression, Loot, Items & Economy](#5-progression-loot-items--economy)
6. [World, Procgen, Geo & Breaches](#6-world-procgen-geo--breaches)
7. [Camp / Bastion & Meta-Progression](#7-camp--bastion--meta-progression)
8. [Client UX, Rendering & Art Pipeline](#8-client-ux-rendering--art-pipeline)
9. [Testing, Fixtures & Autonomous Iteration](#9-testing-fixtures--autonomous-iteration)
10. [Implementation Roadmap (build order)](#10-implementation-roadmap-build-order)
11. [Resolutions, Open Questions & Decisions Deferred](#11-resolutions-open-questions--decisions-deferred)

I have everything I need. Here is the Foundation Contract.

---

# SideQuest POC — Foundation Contract

> **Status: BINDING.** This is the single source of truth. Every other designer (map/procgen, combat, loot/economy, camp/territory, NPC/quest, art-pipeline, test-harness) conforms to the schema, protocol, and module boundaries defined here and does not alter them. Sections 4+ (content, combat rules, procgen, projection math) are owned by other agents and slot into the seams this document defines. Where this contract says "deferred to section N," that is another agent's territory — but the **interface** they must implement is fixed here.

## 1. Foundation & Architecture

### 1.0 Stack decision (2026-07 — governs)

The POC is built on this stack; **it supersedes any "vanilla JS / no build step" phrasing elsewhere in §1/§8/§9**, and code snippets in this doc are **illustrative pseudocode** (translate to TypeScript).

- **Language:** TypeScript (ESM) across `server/`, `shared/`, and `web/`. Node 22 runs server TS via `tsx` (or `node --experimental-strip-types`); the client is bundled by Vite.
- **Server:** **Hono** (HTTP: health, static, later auth) + **`ws`** (the WebSocket API) on one Node process / one port; `better-sqlite3` for persistence.
- **Client:** **React + Vite + TypeScript**. React renders the **UI chrome** (the Glory component kit, §8.0); the **map/combat is an imperative Canvas 2D island** (`<GameCanvas>`) with its own `requestAnimationFrame` loop reading a snapshot ref — **React never drives the 60fps loop.**
- **Client state:** **Zustand** store, fed by a reconnecting **socket service** (`GameSocket`) that encodes/decodes §3 and dispatches snapshot/delta/events. (No TanStack Query — WS-pushed authoritative state isn't request/response; TanStack Router deferred until App-Clip deep-links, LAUNCH.md.)
- **Shared contract:** `shared/` is **TypeScript** — the §3 protocol types + codec + constants + tuning, imported by both server and web. This is the *typed* decoupling boundary; a native/RN client re-implements it from the §3 spec (§1 decoupling).
- **Tests:** **Vitest** (unit + integration, TS-native) + `ws` bot clients + `playwright-core` (vision). Sim-purity lint unchanged.
- **Build:** `vite build` (client → static) + server TS run/compiled; Hono serves the built client. There IS a build step now — the earlier "no build step" was a throwaway-speed choice, dropped for maintainability + the React-Native path.

### 1.1 Stack (pinned)

| Concern | Decision | Version | Rationale |
|---|---|---|---|
| Runtime | Node.js | **22.x LTS** (`"engines": { "node": ">=22 <23" }`) | Native ESM + TS strip, native `fetch`, `structuredClone`, `AbortController`. |
| Language | **TypeScript (ESM)** across server/shared/web | `^5.x` | One typed language; `shared/` types *are* the §3 contract, so server and web can't drift. |
| Server HTTP | **Hono** | `^4.x` | Tiny, fast, TS-first routing/middleware; hosts static + `/healthz` + the WS upgrade on one Node process. |
| WebSocket | **`ws`** | `^8.18.0` | The product API; mounted on Hono's node server `'upgrade'` (or `@hono/node-ws`). |
| Persistence | **`better-sqlite3`** | `^11.0.0` | See §1.4. |
| Client | **React + Vite + TypeScript** | React `^19`, Vite `^6` | React for the Glory UI chrome; **imperative Canvas 2D island** for the game view (§8.0). Vite bundles + dev-serves. |
| Client state | **Zustand** | `^5` | Tiny store fed by the socket service *outside* React's render cycle. |
| Test/bots | **Vitest** (unit+integration), **`ws`** (bot clients), **`playwright-core`** (vision) | pinned | TS-native; Chromium pre-installed (`/opt/pw-browsers`, `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`). |
| Lint/format | `eslint` + `prettier` (dev-only) | `^9` / `^3` | Cosmetic; never in the runtime path. |

**Build & run.** Vite bundles the React/TS client to static assets; the server runs TypeScript via `tsx` (dev) / compiled or `tsx` (prod), and **Hono serves the built client on the same port as the WS**. `shared/` TS is imported by both (Vite for the client, Node for the server), so client and server run the **same** protocol codec, constants, and tuning with no duplication — the typed §3 contract. (This replaces the earlier "no build step" plan — see §1.0.)

**Front-end decoupling (API-first — the web client is disposable).** The server's product contract is the **§3 WebSocket protocol (JSON) alone**; `web/` is *one interchangeable consumer* of it, not part of the server. This is a hard rule because the front end may well be thrown out for a native / React-Native app — that swap must touch **zero** server/sim code. Guarantees:
- **No game logic in any front end.** The client only renders `snapshot`/`delta`/events and emits intents; every rule, roll, and authority lives server-side (already the server-authoritative posture). A front end can't desync the world because it never decides anything.
- **Gateway and static server are separable.** `server/net/` (the WS API) and `server/http.js` (serving `web/`) are independent; a native app opens the same `wss://…/ws` and never fetches HTML. Serving the web client is a convenience, not a dependency.
- **`shared/*.ts` is a JS/TS-client convenience, not the contract.** It byte-shares the codec/constants/tuning between the Node server and a JS/TS client (server + React web). A non-JS client (Swift/Kotlin, or a React-Native native module) **re-implements it from the §3 spec** — so **§3 must stay complete enough to build a client from with no repo access** (every message, field, type, and the tick/ordering rules). Treat §3 as a language-neutral API doc.
- **Versioned wire.** `hello.protocolVersion` lets an out-of-date native build fail loudly instead of silently desyncing.

### 1.2 Repo / module file tree

```
/
├── package.json                # type:module, engines.node>=22; deps: hono, ws, better-sqlite3, react, react-dom, zustand; devDeps: vite, typescript, vitest, playwright-core, eslint, prettier, tsx
├── tsconfig.json               # TS config shared by server/shared; web has its own via Vite
├── package-lock.json
├── Dockerfile                  # fly build (see §1.6)
├── fly.toml                    # fly config (see §1.6)
├── .dockerignore
├── CLAUDE.md
│
├── server/                     # Node-only. Never imported by the browser.
│   ├── main.js                 # ENTRYPOINT. Boots config→db→world load→sim loop→http+ws. Wires SIGTERM→final save.
│   ├── config.js               # Reads env (PORT, DATA_DIR, WORLD_SEED, ORIGIN_LAT, ORIGIN_LNG, TICK_HZ, AUTOSAVE_MS). Pure, defaulted, no I/O beyond process.env.
│   ├── http.js                 # Static file server for web/ and shared/. MIME map. Health endpoint GET /healthz.
│   ├── net/
│   │   ├── gateway.js          # ws.Server on the shared http server's 'upgrade'. Owns Connection lifecycle, join/reconnect, heartbeat ping/pong.
│   │   ├── protocol.js         # (re-exports shared/protocol.js) opcode enum + encode/decode. THE wire contract.
│   │   ├── inbound.js          # Validates + routes C→S messages into sim commands. One handler per opcode. Rejects malformed → err frame.
│   │   └── outbound.js         # Builds S→C frames: snapshot, delta, and event fan-out. Relevance filtering per connection.
│   ├── sim/
│   │   ├── world.js            # World aggregate: holds all runtime+persistent entities in memory. THE authoritative state. Constructable with (seed, clock, rng) — no I/O, no net.
│   │   ├── loop.js             # Fixed-timestep driver. Calls world.tick(dtMs) at TICK_HZ. Injectable clock. Accumulator pattern.
│   │   ├── commands.js         # Pure command reducers: applyCommand(world, conn, cmd) → events[]. The ONLY way state mutates from clients.
│   │   ├── systems/            # Per-tick systems, each pure over world state (owned by later agents; interfaces fixed here):
│   │   │   ├── movement.js      #   player GPS smoothing → world position; monster steering (approach/flee/pursue).
│   │   │   ├── combat.js        #   turn-based encounter resolution (COMBAT-STUDY agent fills rules).
│   │   │   ├── breach.js        #   incursion spawn/escalation/seal + territory claim.
│   │   │   ├── camp.js          #   bastion, auto-turret targeting/fire, upgrades.
│   │   │   ├── loot.js          #   drops, chests, XP/level-up, merchant transactions.
│   │   │   └── spawns.js        #   deterministic breach/POI/monster seeding from WORLD_SEED (procgen agent).
│   │   └── ids.js              # Monotonic + seed-namespaced id allocation (entity ids). Deterministic under a seed.
│   ├── persistence/
│   │   ├── db.js               # better-sqlite3 open, PRAGMA (WAL, synchronous=NORMAL), migrations runner.
│   │   ├── schema.sql          # DDL (mirrors §2 persistent tables).
│   │   ├── repo.js             # save(world)/load()→world. Serialize/deserialize. Dirty-set aware. Snapshot round-trip.
│   │   └── migrations/         # 0001_init.sql, ...   (append-only)
│   └── util/
│       ├── rng.js              # (re-exports shared) seeded PRNG.
│       └── log.js              # structured stderr logging, level via env.
│
├── shared/                     # Runs UNCHANGED in Node AND browser. No node:*, no DOM.
│   ├── protocol.js             # Opcode constants, message schemas (as plain validators), encode()/decode() (JSON codec for POC).
│   ├── constants.js            # Radii (engage, loot, interact), tick rate, band thresholds, class/monster base stats keys.
│   ├── geo.js                  # world-meter helpers: dist(a,b), within(a,b,r), clamp. NO lat/lng math here (that's §6, web/geo-projection).
│   ├── rng.js                  # mulberry32/xorshift seeded PRNG + hashSeed(str)→uint32. Deterministic, pure.
│   ├── entities.js             # Factory functions + field defaults for every §2 entity. Single definition of shape.
│   └── tuning.js               # Balance numbers (XP curve, damage, spawn weights). Hot-swappable by balance harness.
│
├── web/                        # React + Vite + TS client. Built to static; served by Hono. (All source .ts/.tsx.)
│   ├── index.html              # Vite entry. <meta charset=utf-8>. Mounts <App/>.
│   ├── vite.config.ts
│   ├── src/
│   │   ├── main.tsx            # React root; mounts App; boots the socket service.
│   │   ├── App.tsx             # Screen router (Zustand slice) → renders the current screen (§8.1).
│   │   ├── net/gameSocket.ts   # SOCKET SERVICE: connect, reconnect w/ backoff, session-resume, encode/decode via shared/, dispatch into the store.
│   │   ├── store/              # Zustand: world mirror (snapshot+delta, NOT authoritative) + interpolation buffers, screen slice, session.
│   │   ├── geo-projection.ts   # §6: lat/lng ⇄ world-meters using ORIGIN from server hello; watchPosition wiring.
│   │   ├── canvas/             # IMPERATIVE game island — NOT React-reconciled:
│   │   │   ├── GameCanvas.tsx  #   thin React wrapper: a <canvas> ref + rAF loop reading the store snapshot ref.
│   │   │   ├── camera.ts        #   world-meters → screen px.
│   │   │   ├── mapRender.ts     #   §6.3.4 tileset overworld (auto-tile, props, veil grade).
│   │   │   └── sprites.ts       #   manifest-driven atlas loader + animator (§1.7).
│   │   ├── ui/                 # React GLORY component kit + screens (§8.0/§8.2): kit/ (cpanel, buttons, meters, slots…), screens/ (Join, Map, Combat, Inventory, Merchant, Camp), css/ (tokens.css, kit.css, app.css).
│   │   └── input.ts            # touch/tap → §3 intents.
│   └── public/                 # static passthrough (favicon, etc.)
│
├── web-assets/                 # BUILD OUTPUT: manifest.json + packed atlas + tiles, from tools/pack-sprites (served by Hono / imported by Vite).
│
├── assets/                     # SOURCE art (existing). sprites/<char>/*, props/*, manifest.json, tags.json.
│
├── tools/
│   ├── pack-sprites.mjs        # Reads assets/manifest.json → emits web/assets/manifest.json + atlas. Zero game-code change on new art (§1.7).
│   └── seed-world.mjs          # Regenerate/inspect a world from a seed for debugging.
│
└── test/
    ├── harness/
    │   ├── sim-harness.js      # Build a World in-process: makeWorld({seed, clock, rng}). No net/browser. THE unit-of-test.
    │   ├── clock.js            # ManualClock: now(), advance(ms). Injected into loop.
    │   ├── bot-client.js       # Scriptable WS client speaking shared/protocol. join/move/engage/attack/... Same wire as real client.
    │   └── vision.js           # playwright-core: launch headless Chromium, load web client, screenshot canvas, dump to /test/artifacts.
    ├── fixtures/
    │   ├── seeds.js            # Named deterministic seeds (SMOKE, TWO_PLAYER, HEAVY_BREACH).
    │   └── worlds/             # Golden serialized snapshots for round-trip assertions.
    ├── unit/                   # sim reducers, rng determinism, protocol codec, geo.
    ├── integration/            # boot→bot join→fight→persist→restart→resume; multi-bot party sync.
    ├── balance/                # Monte-Carlo: N fights across seeds → win-rate/TTK distributions vs tuning.
    └── artifacts/              # screenshots, sim traces (gitignored except goldens).
```

### 1.3 One process, HTTP + WebSocket

`server/main.js` creates a single `http.Server`. `server/http.js` handles normal requests (static files from `web/` and `shared/`, plus `GET /healthz`). `server/net/gateway.js` attaches a `ws.WebSocketServer({ noServer: true })` and listens on the http server's `'upgrade'` event, accepting upgrades on path `/ws`. **One port, one process, one machine.** No reverse proxy, no separate WS port. Fly routes `:8080` → this process; TLS terminates at Fly's edge, so the client uses `wss://<app>.fly.dev/ws`.

Boot order in `main.js`:
```
config = loadConfig(env)
db = openDb(config.DATA_DIR)                 # runs migrations
world = repo.load(db) ?? World.create(config.WORLD_SEED, config.ORIGIN)   # load-on-boot
loop = startLoop(world, systemClock, config.TICK_HZ)   # begins ticking
http = createHttpServer(staticHandler)
gateway.attach(http, world, loop)            # WS upgrade + command routing
http.listen(config.PORT)
scheduleAutosave(repo, world, config.AUTOSAVE_MS)
onSignal('SIGTERM'|'SIGINT', () => { loop.stop(); repo.save(world); db.close(); exit })
```

### 1.4 Persistence: better-sqlite3 (decided) — and why, for *this* POC

**Decision: `better-sqlite3`, with the in-memory `World` as the single authoritative source and SQLite as a pure durability layer written by periodic snapshot.** Rejected: a raw JSON-snapshot file.

Justification against the two brief constraints — *"survives restarts"* on *"a fly.io machine with a mounted volume"*:

- **Torn-write safety on the volume.** A JSON snapshot is written with `writeFileSync` (or temp-file + rename). A crash or `fsync` gap on the Fly volume mid-write can leave a truncated/corrupt file and **lose the entire world** — the one thing persistence exists to protect. SQLite in **WAL mode** gives atomic, crash-consistent commits: a killed process resumes from the last committed transaction, never a half-written world.
- **Incremental writes.** Autosave writes only the **dirty set** (changed characters, newly-sealed breaches, camp deltas) inside one transaction, not the whole world every tick. A JSON file must be rewritten whole; SQLite scales as the world grows (more breaches sealed, more inventory) without lengthening every save.
- **Debuggability / balance harness.** `sqlite3 world.db 'SELECT level,xp FROM character'` and the balance suite querying historical state directly is free with SQLite and impossible with an opaque JSON blob. This directly serves the "iterate on balancing without a human" requirement.
- **Testability is unaffected.** Persistence is *not* in the sim path. `World` is constructed and ticked entirely in memory (§1.8); `repo.save/load` is the only SQLite touch-point and is exercised by a dedicated round-trip test. The sim never imports `better-sqlite3`.
- **Cost/footprint.** Synchronous single-file embedded DB, no server, no daemon — same operational cost as a JSON file (one file on the volume) with none of the corruption risk. Fits "one small machine" perfectly.

Why not a network DB (Postgres/LiteFS/Turso): out of scope for a single-machine private POC; adds ops surface for zero benefit at this scale.

**Storage model** (schema in §2, DDL in `persistence/schema.sql`): normalized tables for the entities that benefit from querying (`character`, `breach`, `camp`, `poi_state`, `world_meta`), each row carrying scalar columns for indexed/queried fields **plus** a `data` JSON column for the full serialized entity. Inventory/equipment/abilities persist as JSON within the owning `character` row (they are never queried independently in the POC). Runtime-only entities (monster instances, projectiles, connections, active-combat encounters) are **never** persisted — they respawn deterministically from `WORLD_SEED` + persisted world progress on boot.

### 1.5 Reconnection & persistence lifecycle

- **Autosave cadence:** every `AUTOSAVE_MS` (default **15000 ms**) `repo.save(world)` commits the dirty set in one transaction. Also a forced save on: a breach sealed, a level-up, a camp upgrade, a merchant transaction (durable-progress events), and on `SIGTERM`/`SIGINT`. Save is synchronous and fast (better-sqlite3 blocks the loop for <1 ms at POC scale); it runs between ticks, never mid-tick.
- **Load-on-boot:** `repo.load(db)` rehydrates persistent entities into a fresh `World`; runtime entities are regenerated by `systems/spawns.js` from the seed + restored world progress (sealed breaches stay sealed, claimed territory stays claimed). If the DB is empty, `World.create(seed, origin)` builds a virgin world. Boot is idempotent: same DB → same world.
- **Reconnection:** on `join`, the server mints a `sessionToken` (random) bound to the `characterId` and returns it in `hello`. The client stores it (in-memory + `localStorage`) and, on socket drop, reconnects with exponential backoff (0.5s→8s cap) sending `resume{ sessionToken }`. The server rebinds the existing `Character` to the new `Connection`, replays a full `snapshot`, and the player continues — GPS drift/tunnel disconnects read as seamless. Tokens live for the process lifetime plus are persisted on the character row so a resume survives a server restart. If a token is unknown, the server replies `err{ code: "SESSION_UNKNOWN" }` and the client falls back to the join screen (name is remembered).
- **Character continuity:** a returning player who joins with the same **name** (no token) is matched to their existing persisted `Character` (trusted-party POC — name is identity). New name → new character.

### 1.6 Fly.io files

**`fly.toml`** (authoritative shape):
```toml
app = "sidequest-poc"
primary_region = "sea"

[build]
  dockerfile = "Dockerfile"

[env]
  PORT = "8080"
  DATA_DIR = "/data"
  TICK_HZ = "10"
  AUTOSAVE_MS = "15000"
  # WORLD_SEED, ORIGIN_LAT, ORIGIN_LNG set via `fly secrets`/deploy args (the forest origin).

[[mounts]]
  source = "sidequest_data"      # persistent volume → the world DB survives restarts/redeploys
  destination = "/data"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = "suspend"  # scale-to-zero when idle; wss reconnect wakes it
  auto_start_machines = true
  min_machines_running = 0

  [[http_service.checks]]
    method = "GET"
    path = "/healthz"
    interval = "15s"
    timeout = "2s"

[[vm]]
  size = "shared-cpu-1x"
  memory = "512mb"
```
Single machine; the WS and static traffic both ride `http_service` on 8080 (Fly proxies WebSocket upgrades transparently). The `sidequest_data` volume holds `world.db` (+ WAL). One region, no clustering — a single authoritative process is required for a single shared world.

**`Dockerfile`:**
```dockerfile
FROM node:22-slim
RUN apt-get update && apt-get install -y python3 build-essential && rm -rf /var/lib/apt/lists/*   # better-sqlite3 native build
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
ENV NODE_ENV=production PORT=8080 DATA_DIR=/data
EXPOSE 8080
CMD ["node", "server/main.js"]
```

### 1.7 Manifest-driven art pipeline (zero code change on new art)

New sprites drop into `assets/sprites/<subject>/<Subject>_<state>.png` and `assets/manifest.json` is rebuilt (existing `pixel_import.py`). `tools/pack-sprites.mjs` consumes that manifest and emits `web/assets/manifest.json` + atlas. `web/js/render/sprites.js` is **fully data-driven off the manifest**: it maps `(subject, state) → {atlasRect, frameSize:[32,32], frames, fps}` and animates by `frames`. Game code references entities by `spriteSubject` string (e.g. `"goblin"`) and an animation `state` string (`idle|walk|attack|quick_attack|cast|hurt|die|cheer|projectile`); adding a new monster = new art + manifest rebuild + a stats row in `shared/tuning.js`. **No renderer or engine code changes.** The 9-state animation vocabulary in the manifest is the fixed contract (§2 `Monster.spriteSubject` / `Character.classId` resolve to it).

### 1.8 Designed for testability (hard requirement)

The sim is **constructable in-process with zero network or browser**:
```js
import { makeWorld } from "test/harness/sim-harness.js";
import { ManualClock } from "test/harness/clock.js";
const clock = new ManualClock();
const world = makeWorld({ seed: "SMOKE", origin: {lat, lng}, clock, rng: seededRng("SMOKE") });
applyCommand(world, botConn, { op: OP.ENGAGE, breachId });
loop.tickManual(world, clock, 100);   // advance one 100ms tick deterministically
assert.equal(world.encounters.get(id).state, "player_turn");
```
Mandated properties, enforced by the module boundaries above:
- **Injectable clock:** `sim/loop.js` never calls `Date.now()`; it takes a clock object (`{ now() }`). Tests use `ManualClock`; prod uses the system clock. All time-based logic (cooldowns, escalation, turret fire) reads the injected clock.
- **Injectable seed/RNG:** all randomness routes through `shared/rng.js` seeded from `WORLD_SEED` (+ per-entity namespacing via `ids.js`). Same seed + same commands + same clock advances ⇒ **bit-identical world**. No `Math.random()` anywhere in `sim/` or `shared/` (enforced by a unit test grepping the tree).
- **No I/O in the sim:** `sim/` and `shared/` import no `node:fs`, `node:http`, `ws`, or DOM. Persistence and net sit strictly outside and call into the sim through `applyCommand` and `world.tick`.
- **Bots speak the real wire (§3):** `test/harness/bot-client.js` connects over `ws` using `shared/protocol.js` — the identical codec the browser uses — so headless integration exercises the true protocol path. Vision tests (`test/harness/vision.js`) drive the real `web/` client in headless Chromium and screenshot the canvas for the vision-critique loop.

---

## 2. Data Model

Canonical schema. **P** = persisted (survives restart), **R** = runtime-only (rebuilt from seed + persisted progress, never written to disk). All world positions are `{ x, y }` in **meters** east/north of the configured origin (§3.5). IDs are strings. Field types are JS/JSON types. Factory defaults live in `shared/entities.js`; balance numbers referenced here (base stats, curves) live in `shared/tuning.js` and are owned by the balance/combat agents — the **fields** are fixed here, the **values** are not.

### 2.1 World — **P** (one row, `world_meta`)
| Field | Type | Notes |
|---|---|---|
| `seed` | string | Immutable. Drives all procgen (map, spawns, ids). |
| `origin` | `{ lat:number, lng:number }` | Real-world anchor for the meter grid. Set at create, immutable. |
| `createdAt` | number (epoch ms) | |
| `convergence` | number | 0..1 global escalation clock (DESIGN "convergence"). Rises with unanswered breaches; scales spawn tier/difficulty. |
| `tick` | number | Monotonic tick counter at last save (resume/debug). |
| `schemaVersion` | integer | Migration guard. |

Runtime `World` also holds the in-memory maps: `characters`, `breaches`, `camps`, `pois`, `monsters(R)`, `projectiles(R)`, `encounters(R)`, `connections(R)`, `party`.

### 2.2 Character / Player — **P** (table `character`)
The persistent avatar. One per player (name = identity in the POC).
| Field | Type | P/R | Notes |
|---|---|---|---|
| `id` | string | P | Stable character id. |
| `name` | string | P | Player-chosen; identity. |
| `classId` | string | P | `"knight" | "ranger"` (→ `spriteSubject`). Extensible via manifest+tuning. |
| `sessionToken` | string\|null | P | Current resume token (§1.5). |
| `level` | integer | P | |
| `xp` | integer | P | Cumulative; curve in `tuning.js`. |
| `hp` | number | P | Current health. |
| `maxHp` | number | P | Derived from level+gear at save; stored for fast load. |
| `stats` | `{ might:number, focus:number, sureHands:number, ... }` | P | Trainable stats (QfG "practice = mastery"). Keys fixed in `tuning.js`. |
| `gold` | integer | P | Merchant currency. |
| `pos` | `{x,y}` | P | Last authoritative world position. |
| `facing` | number | R | Heading radians (render). |
| `animState` | string | R | Current animation (`idle|walk|attack|...`). |
| `gpsAccuracy` | number | R | Meters; drives the accuracy halo. Last reported. |
| `partyId` | string | P | Always the single POC party. |
| `inventory` | `Item[]` | P | Serialized in the character row (JSON). |
| `equipment` | `Equipment` | P | See §2.4. |
| `abilities` | `AbilityRef[]` | P | Learned abilities: `{ abilityId, rank }`. |
| `focusMeter` | number | R | 0..100 in-combat resource (COMBAT-STUDY pattern D). Resets per encounter. |
| `status` | `"alive" | "downed"` | R | `downed` → wake-at-camp flow; not persisted mid-combat. |
| `connId` | string\|null | R | Bound connection, or null if offline. |
| `updatedAt` | number | P | Autosave dirty-tracking. |

### 2.3 Item — **P** (embedded in `character.inventory` / on ground as **R** drop)
| Field | Type | Notes |
|---|---|---|
| `id` | string | Instance id (a specific sword). |
| `defId` | string | Item definition key in `tuning.js` catalog (e.g. `"iron_sword"`). |
| `slot` | `"weapon"|"armor"|"trinket"|"consumable"|"material"|null` | Equip slot or null. |
| `rarity` | `"common"|"uncommon"|"rare"|"epic"` | Drives color/roll. |
| `level` | integer | Upgrade level (loot upgrading). |
| `mods` | `{ [stat]: number }` | Rolled affixes (e.g. `{might:+3}`). |
| `element` | `"none"|"fire"|"frost"|"shock"` | Weakness system (COMBAT-STUDY B). |
| `qty` | integer | Stack count (materials/consumables). |
| `value` | integer | Base merchant sell price. |

`ItemDef` (static, `tuning.js`, not persisted): `{ defId, name, slot, baseStats, spriteRef, tags, basePrice, stackable }`.

### 2.4 Inventory / Equipment — **P** (embedded in Character)
- `inventory: Item[]` — unequipped items + materials + consumables.
- `Equipment`: `{ weapon: Item|null, armor: Item|null, trinket: Item|null }`. Equipped items are moved out of `inventory` into these slots. Derived combat stats are recomputed from `stats + equipment` by `systems/combat.js` (never stored as truth; `maxHp` cached only for load speed).

### 2.5 Ability — definition **static** (`tuning.js`) / learned ref **P** (in Character)
| `AbilityDef` field | Type | Notes |
|---|---|---|
| `abilityId` | string | e.g. `"cleave"`, `"aimed_shot"`, `"veil_breach"`. |
| `name` | string | |
| `classId` | string\|`"any"` | Gating. |
| `kind` | `"attack"|"buff"|"heal"|"special"` | |
| `element` | `"none"|"fire"|"frost"|"shock"` | |
| `power` | number | Base coefficient. |
| `focusCost` | number | Focus-meter cost (0 for basics). |
| `cooldownTurns` | integer | |
| `animState` | string | Which sprite state to play (`attack|cast|quick_attack`). |
| `targeting` | `"enemy"|"self"|"aoe"` | |

`AbilityRef` (persisted on character): `{ abilityId, rank }`. Runtime combat tracks `cooldownRemaining` on the encounter combatant, not persisted.

### 2.6 Monster / Enemy instance — **R** (never persisted)
Spawned deterministically by `systems/spawns.js` from seed + breach; regenerated on boot.
| Field | Type | Notes |
|---|---|---|
| `id` | string | Runtime id (seed-namespaced so it's stable within a boot). |
| `defId` | string | `MonsterDef` key. |
| `spriteSubject` | string | `"goblin"|"skeleton"|"slime"|"wraith"` (→ manifest). |
| `tier` | integer | Difficulty band (Elder→Massive), scaled by `convergence`. |
| `hp` / `maxHp` | number | |
| `pos` | `{x,y}` | World meters (overworld monsters roam; encounter monsters are abstract). |
| `homeBreachId` | string\|null | Owning breach. |
| `behavior` | `"guard"|"roam"|"pursue"|"flee"` | Drives `systems/movement.js`: low-HP monsters flee (GPS chase), some pursue/chase the player. |
| `aggroRange` | number | Meters. |
| `element` / `weakness` / `resist` | `"none"|"fire"|"frost"|"shock"` | Press-turn/Breach system. |
| `stats` | `{...}` | From `MonsterDef` × tier. |
| `telegraph` | `{ abilityId, estDamage }|null` | Visible-intent (COMBAT-STUDY C). |
| `animState` | string | Render. |

`MonsterDef` (static): `{ defId, spriteSubject, baseStats, behavior, element, lootTable, xp, tags }`.

### 2.7 Breach / Incursion — **P** (table `breach`)
The core objective: a rift overlaid on the map.
| Field | Type | P/R | Notes |
|---|---|---|---|
| `id` | string | P | Deterministic from seed+cell (so the same forest spot = same breach). |
| `pos` | `{x,y}` | P | World-meter center. |
| `tier` | integer | P | Elder(1)…Massive(5); how far torn open. |
| `state` | `"dormant"|"active"|"contested"|"sealed"` | P | Persisted so sealed stays sealed across restarts. |
| `radius` | number | P | Engage/interaction radius (meters) — **generous** for GPS drift. |
| `hp` | number | R | Seal progress pool while contested. |
| `escalation` | number | R | Rises if unanswered (feeds `convergence`). |
| `monsterIds` | string[] | R | Spawned defenders (runtime). |
| `spawnSeed` | number | P | Sub-seed for its monster roster (deterministic respawn). |
| `sealedBy` | string[]\|null | P | Character ids credited. |
| `sealedAt` | number\|null | P | |
| `territoryId` | string\|null | P | Territory cell this breach gates (§2.8). |

### 2.8 Camp / Bastion — **P** (table `camp`) + Territory
One shared party camp in the POC (co-op). Territory = claimed map cells.
| `Camp` field | Type | P/R | Notes |
|---|---|---|---|
| `id` | string | P | |
| `partyId` | string | P | |
| `pos` | `{x,y}` | P | Player-placed anchor (wake-at-camp point). |
| `level` | integer | P | Bastion tier. |
| `structures` | `Structure[]` | P | e.g. auto-turret, workshop, wall. |
| `stockpile` | `{ [materialDefId]: qty }` | P | Materials gathered for upgrades. |
| `craftQueue` | `CraftJob[]` | P | Away-time crafting: `{ jobId, recipeId, finishAt }`. |

`Structure`: `{ id, type:"turret"|"workshop"|"wall"|..., level, pos:{x,y}, cooldownRemaining(R) }`. The auto-turret is a runtime shooter: `systems/camp.js` targets nearby monsters and emits projectiles each tick.

`Territory` — **P** (rows in `poi_state` namespace or dedicated `territory` table): `{ cellId, ownerPartyId, claimedAt, contested:boolean(R), holdStrength:number }`. Claimed by sealing the breach that gates the cell; held against escalating incursions.

### 2.9 POI / Location — definition **static** (procgen/seed) / state **P** (table `poi_state`)
Fixed visitable places (merchant, quest hut, NPCs, chests).
| `POIDef` (deterministic from seed) | Type | Notes |
|---|---|---|
| `id` | string | seed+cell derived. |
| `type` | `"merchant"|"quest_hut"|"npc"|"chest"|"landmark"` | |
| `pos` | `{x,y}` | World meters. |
| `interactRadius` | number | Generous (GPS drift). |
| `spriteRef` | string | e.g. `"chest"`. |
| `data` | object | Type-specific (merchant inventory seed, NPC dialogueId, chest lootSeed). |

`POIState` — **P**: `{ poiId, looted:boolean, cooldownUntil:number, questFlags:{...}, merchantRestockAt:number }`. Only *state that must persist* (a chest stays looted, a quest stays completed) is stored; the POI's existence/position is regenerated from seed.

### 2.10 Party — **P** (single party in POC, `world_meta`)
| Field | Type | Notes |
|---|---|---|
| `id` | string | The one trusted party (the kids). |
| `memberIds` | string[] | Character ids. |
| `campId` | string | Shared camp. |
| `sharedSeed` | string | = world seed (all see the same world). |

### 2.11 Session / Connection — **R** (never persisted)
| Field | Type | Notes |
|---|---|---|
| `connId` | string | Per-socket runtime id. |
| `socket` | WebSocket | `ws` server socket. |
| `characterId` | string\|null | Bound after `join`/`resume`. |
| `sessionToken` | string | Mirror of the character's token. |
| `lastSeenTick` | number | For relevance/heartbeat. |
| `lastPong` | number | Heartbeat liveness (clock). |
| `sendBuffer` | queue | Outbound delta accumulation. |
| `interestPos` | `{x,y}` | Center of relevance filtering (= character pos). |

### 2.12 Projectile — **R** (never persisted)
Runtime only, for turret/monster ranged visuals + hit resolution: `{ id, spriteRef, from:{x,y}, to:{x,y}, ownerId, damage, element, spawnTick, ttl }`. Purely transient; broadcast in deltas, resolved and discarded within a few ticks.

---

## 3. Network Protocol & Server Simulation Loop

### 3.1 Transport & framing

- One WebSocket per client at `wss://<host>/ws`. **Text frames, JSON codec** for the POC (`shared/protocol.js` `encode`/`decode`) — human-readable for debugging, trivially spoken by bots; a binary codec is a later optimization behind the same interface.
- Every message: `{ "op": <int opcode>, "t": <clientOrServerTimeMs>, ...payload }`. Opcodes are the `OP` enum in `shared/protocol.js` (the numeric values below are the contract; names are for readability).
- **Server is authoritative.** Clients send *intents*; the server validates against world state, applies via `applyCommand`, and the resulting state change is only real once it comes back in a `snapshot`/`delta`/event. The client's `store.js` is a display mirror and never a source of truth. Malformed/again-illegal messages get an `err` frame and are otherwise ignored (no disconnect — trusted POC).
- **Heartbeat:** server sends `ping` (opcode) every 10 s; client replies `pong`. Two missed pongs → server unbinds the connection (character goes offline, resumable). WS-level ping/pong is also enabled as a backstop.

### 3.2 Client → Server messages

| Op | Name | Trigger | Payload |
|---|---|---|---|
| 1 | `join` | Join screen submit | `{ name:string, classId:"knight"|"ranger" }` |
| 2 | `resume` | Reconnect w/ stored token | `{ sessionToken:string }` |
| 3 | `gps` | `watchPosition` update (throttled ≤2 Hz) | `{ lat, lng, accuracy }` — server projects to `{x,y}` (§3.5) |
| 4 | `move` | (debug/no-GPS mode) direct move intent | `{ x, y }` world meters |
| 5 | `engage` | Tap a breach within radius | `{ breachId }` → opens encounter |
| 6 | `flee` | Tap flee in combat | `{ encounterId }` |
| 7 | `attack` | Basic attack / timed-hit resolve | `{ encounterId, targetId, timing:0..1 }` (timing = tap accuracy, COMBAT-STUDY A) |
| 8 | `useAbility` | Use an ability | `{ encounterId, abilityId, targetId, timing }` |
| 9 | `guard` | Timed guard on enemy strike | `{ encounterId, timing }` |
| 10 | `loot` | Tap a chest/drop within radius | `{ sourceId }` (chest poiId or drop id) |
| 11 | `sealBreach` | Deliver seal (breach hp depleted) | `{ breachId }` |
| 12 | `campAction` | Place/upgrade/craft at camp | `{ action:"place"|"upgrade"|"craft"|"placeStructure", ... }` |
| 13 | `merchant` | Buy/sell | `{ poiId, action:"buy"|"sell", itemId?, defId?, qty }` |
| 14 | `interact` | POI/NPC talk / dialogue choice | `{ poiId, choiceId? }` |
| 15 | `equip` | Equip/unequip item | `{ itemId, slot, equip:boolean }` |
| 16 | `requestSnapshot` | Client wants a full resync | `{}` |
| 17 | `pong` | Heartbeat reply | `{}` |

### 3.3 Server → Client messages

| Op | Name | Trigger | Payload |
|---|---|---|---|
| 100 | `hello` | After `join`/`resume` accepted | `{ characterId, sessionToken, origin:{lat,lng}, seed, tickHz, self:Character }` |
| 101 | `snapshot` | On join/resume/`requestSnapshot` | `{ tick, self:Character, players:Character[], breaches:Breach[], monsters:Monster[], pois:POI[], camp:Camp, projectiles:Projectile[], party:Party, convergence }` — everything in the relevance window. |
| 102 | `delta` | Each broadcast frame (§3.4) | `{ tick, upserts:{ players?, monsters?, breaches?, projectiles?, camp? }, removes:{ [kind]:id[] } }` — only changed entities in-range. |
| 103 | `playerMoved` | Another player's GPS update | `{ id, x, y, accuracy, tServer }` — client interpolates (§3.6). (May be folded into `delta.upserts.players`.) |
| 104 | `encounterOpen` | `engage` accepted | `{ encounterId, breachId, combatants:Combatant[], turn:"player"|"enemy", order:[] }` |
| 105 | `encounterUpdate` | Any combat state change | `{ encounterId, events:CombatEvent[], combatants, turn, focusMeter }` — CombatEvent covers hit/miss/crit/telegraph/status/breach-proc. |
| 106 | `encounterEnd` | Fight resolved | `{ encounterId, result:"win"|"flee"|"downed", loot:Item[], xpGained, levelUp? }` |
| 107 | `lootResult` | `loot` resolved | `{ sourceId, items:Item[], gold }` |
| 108 | `breachUpdate` | Breach state changed | `{ breachId, state, hp, tier, sealedBy?, territoryId? }` |
| 109 | `campUpdate` | Camp/territory changed | `{ camp:Camp, territory?:Territory[] }` |
| 110 | `merchantResult` | Buy/sell resolved | `{ poiId, gold, inventory:Item[], stock:Item[] }` |
| 111 | `dialogue` | `interact` with NPC/quest | `{ poiId, speaker, lines:string[], choices:[{id,text}] }` |
| 112 | `inventoryUpdate` | Any inventory/equipment change | `{ inventory:Item[], equipment:Equipment, stats, maxHp }` |
| 113 | `partyUpdate` | Member joined/left/moved-far | `{ party:Party, members:{id,name,classId,pos,hp,level}[] }` |
| 114 | `err` | Any rejected/invalid message | `{ code:string, message:string, refOp?:int }` (codes: `SESSION_UNKNOWN`, `OUT_OF_RANGE`, `NOT_YOUR_TURN`, `BAD_REQUEST`, `INSUFFICIENT_GOLD`, `ILLEGAL_STATE`) |
| 115 | `ping` | Heartbeat | `{ tServer }` |

### 3.4 Tick model

- **Fixed simulation tick at `TICK_HZ` = 10 (100 ms).** `sim/loop.js` uses an accumulator so simulation is deterministic regardless of wall-clock jitter; `world.tick(100)` runs all `systems/*` in a fixed order: `movement → spawns → breach → combat → camp → loot`. Turn-based combat is event-driven *within* this tick cadence (an `attack` command resolves immediately into `encounterUpdate`; the fiction of "command latency across the veil" is presentation, not a server stall).
- **Broadcast cadence: 5 Hz (every 2nd tick).** Continuous state (positions, monster movement, projectiles, breach hp) goes out as **`delta`** — only entities that changed *and* fall within a connection's relevance window (default **200 m** radius around the character, generous for a 40-acre forest). Discrete outcomes (combat events, loot, level-up, dialogue, merchant, camp) are sent **immediately** as their typed event, not batched.
- **Full `snapshot`** is sent only on join, resume, and explicit `requestSnapshot`. Everything else is delta. This keeps the shared world consistent while bandwidth stays tiny.
- **GPS ingestion:** clients throttle `gps` to ≤2 Hz. The server applies **position smoothing** (exponential smoothing / clamp to a max plausible speed) in `systems/movement.js` so canopy drift (10–20 m) does not teleport the avatar; the reported `accuracy` is stored and rebroadcast so every client can draw the **accuracy halo** ("the veil is fuzzy"). Interaction radii (§2 `radius`/`interactRadius`) are deliberately generous to absorb drift.

### 3.5 Server authority & the coordinate contract

- **World coordinates are meters:** `x` = meters **east**, `y` = meters **north**, relative to `World.origin` (`{lat,lng}`). All sim math, distances, and radii are in meters via `shared/geo.js` (`dist`, `within`). The sim never knows about lat/lng.
- **Projection lives at the edges, not in the sim.** The client projects `watchPosition` lat/lng → world meters (and back for rendering the map) in `web/js/geo-projection.js`; the server projects incoming `gps` lat/lng → meters on receipt. **The exact projection math (equirectangular/local-tangent-plane at the origin, and the fantasy-overlay transform) is deferred to §6, owned by the map/procgen agent.** The contract §6 must honor: it is a pure, deterministic, invertible function `project(origin, {lat,lng}) → {x,y}` and `unproject(origin, {x,y}) → {lat,lng}`, defined in `shared/geo.js` (or a `shared/proj.js` it adds) so server and client agree exactly. Until §6 lands, a placeholder equirectangular projection at `origin` is used; swapping it changes no sim or protocol code.
- **Authority rule:** the server owns every position, hp, inventory, breach state, and RNG outcome. Client `move`/`gps`/`attack.timing` are *inputs*; the server decides results. There is no client-side prediction of authoritative state beyond cosmetic interpolation (§3.6).

### 3.6 Client interpolation of other players

Other players' positions arrive at ≤5 Hz via `delta`/`playerMoved`. `web/js/store.js` keeps a small (2–3 sample) buffer per remote entity and renders at `now − renderDelay` (≈150 ms) by linear interpolation between the last two authoritative positions, so movement is smooth despite the low update rate and GPS jitter. The **self** avatar renders from the server-confirmed position (optionally lightly lerped toward it) — never from raw local GPS — so what you see matches the shared truth.

### 3.7 Reconnect / resume flow (wire)

```
client socket drops → backoff → open → send resume{sessionToken}
  server: token→character? 
    yes → rebind conn, send hello, then snapshot (full, in-range) → resume seamless
    no  → send err{SESSION_UNKNOWN} → client shows join (name prefilled) → join{name,class}
          server matches persisted character by name (trusted POC) or creates new → hello → snapshot
```

### 3.8 How bot / test clients speak this protocol

`test/harness/bot-client.js` is a headless `ws` client importing the **same** `shared/protocol.js`. It exposes an async API that maps 1:1 to §3.2 (`bot.join(name,class)`, `bot.gps(lat,lng,acc)`, `bot.engage(breachId)`, `bot.attack(encId,targetId,timing)`, `bot.useAbility(...)`, `bot.loot(...)`, `bot.sealBreach(...)`, `bot.merchant(...)`, `bot.campAction(...)`, `bot.interact(...)`) and resolves on the corresponding S→C reply, so scripted play, multi-bot party-sync tests, and Monte-Carlo balance runs all drive the identical wire path a real phone uses. Deterministic-seed integration tests instead skip the socket entirely and call `applyCommand(world, botConn, cmd)` directly against an in-process `World` (§1.8) for speed and bit-exact reproducibility; the two paths share the same command reducers, so a behavior verified in-process is guaranteed to hold over the wire. Vision tests drive the real client in headless Chromium and screenshot the canvas.

---

**Contract invariants every other agent must preserve:** (1) the sim (`sim/` + `shared/`) stays I/O-free, clock-injected, and seed-deterministic; (2) all mutation flows through `applyCommand`; (3) coordinates are origin-relative meters, projection at the edges only; (4) the wire is the `OP` enum in `shared/protocol.js`; (5) art is manifest-driven — new sprites need no engine code; (6) persistent vs runtime split in §2 is fixed — runtime entities are always seed-reconstructable.

I have everything I need. Note: the task says to conform to the "FOUNDATION CONTRACT below," but no contract text was included in my prompt (it appears to have been dropped from the orchestrator's message). I'll write Section 4 against a clearly-labeled assumed contract interface — naming every shared identifier I consume up front so the orchestrator can reconcile — and ground everything in the docs and the actual sprite states on disk (idle/walk/attack/quick_attack/cast/projectile/hurt/die/cheer).

Here is the deliverable.

---

## 4. Combat & Monsters

> **Contract note.** The FOUNDATION CONTRACT text was not present in my brief, so this section is written against the **assumed shared identifiers listed in §4.0**. Every field and protocol message I consume is namespaced there; if the real contract spells one differently, rename at those anchor points only — the formulas and flow below are agnostic to the spelling. Cross-section concepts (`loot`, `xpReward`, `endurance`, `recovery`, proximity bands, apprentice actions, rift depth) are **referenced, not redefined**.

### 4.0 Contract interface consumed by this section

**Data-model entities/fields assumed from FOUNDATION CONTRACT:**

- `Combatant { id, side, name, kind, level, hp, maxHp, atk, def, spd, acc, eva, critChance, focus, maxFocus, statuses[], cooldowns{}, spriteSet, worldPos }`
  - `side ∈ {"party","breach"}`; `kind ∈ {"hero","apprentice","goblin","skeleton","slime","wraith",...}`.
- `Party { id, members: heroId[], sharedSeed }` — party HP is **per-member** (see §4.6), never a shared pool.
- `Encounter { id, seed, breachTier, tierIndex, round, phase, combatants: Combatant[], aggro: {monsterId: {heroId: threat}}, proximityBand }`
  - `breachTier` is the enum; `tierIndex ∈ 1..5` is its ordinal (§4.3). `proximityBand ∈ {"far","mid","close"}` — owned by the map/proximity section; combat only reads it.
- `Ability { id, class, coeff, element, resource, cost, cooldown, range, spriteState, telegraphable }`
- `Status { id, kind, magnitude, ttlRounds }` — e.g. `bleed`, `stagger`, `frost`, `shield`, `mark`.

**Protocol messages assumed from FOUNDATION CONTRACT** (server-authoritative; §4.7 gives the wire order):
`EncounterStart`, `TurnBegin`, `ActionSubmit`, `ActionResolved`, `CombatantDowned`, `CombatantRevived`, `EncounterEnd`, plus the world-space pursuit messages `MonsterFled`, `PursuitTick`, `MonsterEscaped`, `ChaseBegin`, `ChaseTick`, `ChaseCaught`, `ChaseConsequence`.

All randomness flows through one server PRNG seeded by `Encounter.seed` (§4.7). No client rolls dice.

---

### 4.1 Combat model — **DECISION: turn-based command-relay, with an optional timed-tap execution layer**

**Recommendation (decisive): turn-based command-relay is the spine.** Real-time tap is rejected as the base model. The optional timing minigame from COMBAT-STUDY pattern A is bolted on *as a skill garnish that always has an auto-resolve fallback*, so the reflex layer is never load-bearing.

#### Why command-relay wins on this game's exact constraints

| Constraint | Turn-based command-relay | Real-time tap |
| --- | --- | --- |
| **Tome/avatar fiction** (DESIGN §"tome and the avatar") | *Is* the mechanic: you **relay orders across the veil**, they take a beat, a report comes back. Turn latency = portal latency, diegetic. | Contradicts the fiction — you're not physically there to react frame-by-frame. |
| **One-handed mobile, standing outside** | Glanceable. Decide, pocket the phone, look up at traffic, come back. No frame you can miss. | Punishes looking away; unsafe next to a road (the exact thing the safety design forbids). |
| **Co-op with kids** | A 6-year-old can pick "attack the skeleton" and win. Deadline + auto-resolve means a slow child never stalls the party. | Kids lose the reflex race; frustration, or carry-by-parent. |
| **The bus test** (RIFT-BRIEF) | Interruptible between rounds; state is a clean snapshot; abandonable with no penalty. | A tap fight abandoned mid-swing is a lost fight. |
| **Walking mode / auto-battle** | Auto-battle just picks the scripted action each round at trained-stat rates. | Auto-battling a reflex game is a contradiction. |

So: **the brain always drives; the hands are invited but never required.** That is exactly the COMBAT-STUDY core insight ("hands and brain on different problems") minus the fatigue pitfall, because the hands can always sit out.

#### Exact flow — one round

A round is three phases. Timings are `CONST` (§4.3) so the balance sim can sweep them.

```
ROUND N
 ├─ (a) TELEGRAPH + COMMAND WINDOW   [deadline: CMD_WINDOW_MS = 12000, walking/auto: 0]
 │      • Each living monster shows its INTENT for this round (visible-intent, pattern C):
 │        icon + number, e.g. "Goblin ⚔ ~9"  /  "Wraith ✦ Curse (mark)".
 │        Telegraph is emitted in TurnBegin; a frost/stagger status can BLANK a telegraph.
 │      • Each living hero picks ONE action: {Attack | Ability | Item | Guard | Move-band | Flee}.
 │        In co-op, all heroes submit simultaneously into the same window.
 │      • Auto-battle / walking mode: server fills unsubmitted heroes with their script.
 ├─ (b) RESOLUTION                     [scripted animation clock, ~RESOLVE_STEP_MS = 700 per action]
 │      • Server sorts all submitted actions + monster intents by initiative = spd + rng(0..SPD_JITTER).
 │      • Executes each in order → emits ActionResolved events (damage, status, sprite state,
 │        floating text, focus deltas). Clients just play the events; they compute nothing.
 │      • BREACH! extra-action rule (pattern B) fires here (below).
 └─ (c) END-OF-ROUND                   • tick statuses (bleed/frost/shield ttl), regen focus,
        decrement cooldowns, check win/lose, advance to ROUND N+1 or EncounterEnd.
```

Typical wild fight = **3–5 rounds**, 30–90s (RIFT-BRIEF wild layer). Elites/bosses run longer.

#### The optional execution layer — **Strike Window** (pattern A, made safe)

When a hero action resolves, if **Assist Timing** is on (default on for solo adults, default *off* / auto for kids and walking), a ~`STRIKE_WINDOW_MS = 900` sweep bar appears with a moving cursor and a sweet spot whose half-width = `strikeHalfWidth(hero)` (widened by the *Sure Hands* trained stat — practice-makes-mastery made tangible, per COMBAT-STUDY):

- **Perfect tap** (inside inner band): forces a crit **and** `timingMult = PERFECT_MULT`, and grants `+FOCUS_ON_PERFECT` Focus.
- **Good tap** (inside window): `timingMult = 1.0`, `+FOCUS_ON_GOOD`.
- **Miss / no tap** (auto path): `timingMult = GRAZE_MULT` and no Focus — **but never a total whiff**, so a kid who taps nothing still meaningfully hits.

Defense half: when a monster intent lands on a hero, a `GUARD_WINDOW_MS = 500` tap shaves `GUARD_MITIGATE` off the incoming hit (kills the dead-air of the enemy phase). Auto/kids: `Guard` chosen as the round action gives a *flat* block with no timing needed.

Design rule from COMBAT-STUDY anti-goals honored verbatim: **no gestures/glyphs, no energy cost on basic attack, never a mandatory reflex.**

#### Focus meter & Breach! (patterns B + D)

- **Focus** (`Combatant.focus`, cap `maxFocus`) charges from good/perfect Strike taps and from landing weakness hits. Spent on class specials (§4.2).
- **Breach!** — landing an attack the target is *weak* to (`weaknessMult = WEAK_MULT`) both deals ×1.5 **and** grants the attacker **one immediate free follow-up action** this round (press-turn-lite). Fiction: you tore a gap in their guard *through the veil*. Capped at `MAX_BREACH_CHAINS` per hero per round so it can't runaway.

#### What makes it feel cool

The relay fantasy + hi-bit juice (ART-DIRECTION "hi-bit polish path"): crunchy 32px sprites with modern glow/particles/shake over them. The arc of a fight is **open → build Focus on good taps → cash out a special → Breach chain for the kill**, all one-thumb, all pausable for the bus. The telegraph-with-numbers turns each round into a small informed gamble (block the 14, or race to kill first).

---

### 4.2 Action set

**Resources:** `hp` (per-combatant), `focus` (0..`maxFocus`, charges in-fight), and per-ability `cooldowns` (in rounds). Basic attack costs nothing (anti-goal honored). Specials cost Focus; some class abilities cost cooldown only.

#### Basic attack (all classes)
`{ id:"attack", coeff: ATK_COEFF_BASIC=1.0, resource:"none", cooldown:0, spriteState:"attack" }`. Melee range at `close`, reduced coeff at `mid/far` unless the class/weapon is ranged (proximity is read from `Encounter.proximityBand`; ranged classes ignore the penalty — the safety layer from RIFT-BRIEF).

#### Knight (melee bruiser — stagger, guard, burst)

| Level unlock | Ability | Effect (coeff / status) | Resource | CD | `spriteState` |
| --- | --- | --- | --- | --- | --- |
| 1 | **Slash** (basic) | `1.0×`, single target | none | 0 | `attack` |
| 1 | **Guard** | Take `GUARD_STANCE_MITIGATE` less until next round; refunds a little Focus | none | 1 | `idle` (shield glow overlay) |
| 3 | **Heavy Strike** | `1.6×` + apply `stagger` (blanks target's next telegraph) | 25 Focus | 2 | `attack` (heavy) |
| 4 | **Quick Jab** | `0.6×` **twice**, fast — Focus battery / Breach fishing | none | 1 | `quick_attack` |
| 6 | **Bulwark Shout** | Party-wide `shield` (absorbs `SHIELD_HP`) — co-op keystone | 40 Focus | 3 | `cast` |
| 8 | **Sunder** (special) | `2.4×` + `def_break` (−`SUNDER_DEF` for 2 rounds); guaranteed crit if cast at full Focus | full Focus | 3 | `attack` (finisher) |

Knight identity: front-line, converts being-hit into value (Guard/Bulwark), best at *sealing* (RIFT-BRIEF melee role — fast stagger/finishers).

#### Ranger (projectile skirmisher — range-safe, marks, multi-hit)

| Level unlock | Ability | Effect | Resource | CD | `spriteState` |
| --- | --- | --- | --- | --- | --- |
| 1 | **Shot** (basic) | `0.9×`, **no proximity penalty** (the safety default per RIFT-BRIEF) | none | 0 | `attack` → `projectile` |
| 1 | **Roll** | Dodge: `EVA_ROLL` bonus vs next incoming intent | none | 1 | `quick_attack` (evade) |
| 3 | **Twin Shot** | `0.55×` to **two** targets | 20 Focus | 1 | `quick_attack` → `projectile` |
| 4 | **Hunter's Mark** | Apply `mark` (+`MARK_DMG` taken; lets party hit it from a farther band) | none | 2 | `cast` |
| 6 | **Volley** | `0.7×` to **all** enemies | 45 Focus | 3 | `cast` → `projectile` |
| 8 | **Called Shot** (special) | `2.2×`, ignores `def`, +auto-crit vs `mark`ed | full Focus | 3 | `attack` → `projectile` (charged) |

Ranger identity: opens from `far/mid`, sets up (`mark`) so melee/apprentice cash in, strong vs the fliers/casters that are dangerous to approach (wraith).

#### Wizard (elemental mage — weakness-nuker, control, squishy)

The **itch-art flagship class** (detailed ~190² sprite). Ranged like the Ranger (no proximity penalty), lower `def`, richest Focus economy; leans on **element variety to trigger Breach!** (§4.1) harder than any other class. The wizard sprite has no dedicated `cast`/`projectile` state, so spells play its `attack`/`quick_attack` and spawn the matching **imported FX effect** (`fire_small_*`, `sparkle_*`, `explosion_burst`, `spark_burst`) as the bolt/impact — art already on disk.

| Level unlock | Ability | Effect | Resource | CD | `spriteState` + FX |
| --- | --- | --- | --- | --- | --- |
| 1 | **Arcane Bolt** (basic) | `0.9×`, no proximity penalty | none | 0 | `attack` + `sparkle` bolt |
| 1 | **Blink** | Dodge: `EVA_ROLL` bonus vs next intent; small Focus refund | none | 1 | `jump`/`fall` |
| 3 | **Firebolt** | `1.5×` **fire** — big Breach! vs fire-weak | 25 Focus | 1 | `quick_attack` + `fire_small_hot` |
| 4 | **Frost Nova** | `0.7×` **frost** to **all** + `slow` (−spd) | 35 Focus | 2 | `attack` + `fire_small_ice` (AoE) |
| 6 | **Arcane Barrier** | Party `shield` (absorbs `SHIELD_HP`) — co-op keystone (mirrors Bulwark) | 40 Focus | 3 | `attack` + `sparkle_yellow` |
| 8 | **Meteor** (special) | `2.6×` **fire** AoE + `stagger`; guaranteed crit at full Focus | full Focus | 3 | `attack` + `explosion_burst` |

Wizard identity: the elemental damage-dealer — carries the party's Breach! economy by matching element to weakness, and pays for it with low durability (wants Knight soak / Ranger peel).

**Class roster & art status (reconciled to the art on disk).** Three playable classes — **Knight** (melee guardian), **Ranger** (ranged hunter), **Wizard** (elemental mage) — **all three ship in the POC using the art we have now.** Wizard is itch-scale (~190²); **Knight & Ranger are the legacy 32²** sprites and will read smaller beside the ~150² itch mobs. That visual mismatch is an **accepted, temporary** state — we'll re-art Knight/Ranger to itch scale later (an art follow-up, not a blocker). All three appear in character-create (§8.2.1), **including the first forest test**. The kits above are canonical regardless of art.

#### Ability visual → sprite-state mapping (grounded in files on disk)

Every `Ability.spriteState` maps to a real sprite folder state (`assets/sprites/<char>/…`): `idle, walk, attack, quick_attack, cast, projectile, hurt, die, cheer`. Rules:

- **Melee ability** → `attack` (or `quick_attack` for fast multi-hits like Quick Jab / Twin Shot / Roll).
- **Spell/buff/debuff** (Bulwark, Mark, Volley) → `cast`; ranger/goblin/slime/wraith casts that launch a bolt then play the `projectile` state on the traveling shot. The **Wizard** is the exception — no `cast`/`projectile` state, so its spells play `attack`/`quick_attack` and spawn an imported **FX effect** (fire/ice/sparkle/explosion) as the bolt/impact.
- **Getting hit** → `hurt` on the target the instant `ActionResolved.damage>0`; **lethal** → `die` (the 6-frame collapse) then despawn.
- **Win** → surviving party plays `cheer` on `EncounterEnd{outcome:"win"}`.

**Sprite-state event contract (client just plays what the server names):**
```
ActionResolved.spriteEvents = [
  { combatantId, state:"attack", frames:7, atMs:0 },
  { combatantId: target, state:"hurt", frames:2, atMs: IMPACT_MS },   // synced to the swing's contact frame
  { projectileId, state:"projectile", fromPos, toPos, atMs:0 }        // ranged only
]
```

**Floating combat text + juice** (attached to each `ActionResolved`):
- Number pops: white = normal, **yellow + bigger + shake** = crit/perfect, `WEAK!`/**Breach!** cyan pop on weakness, grey small = graze, `RESIST` on ×0.5, `BLOCK`/`MISS` on guard/evade, green `+HP` on heal.
- Juice budget: `SCREEN_SHAKE_CRIT`, hit-flash white 60ms on `hurt`, particle burst keyed to `Ability.element`, hitstop `HITSTOP_MS` on crit. All cosmetic; the sim/bots ignore them.

---

### 4.3 Damage / defense math + **tunable constants (single source of truth)**

All balance-sweepable numbers live in **one** block so a headless balance simulator can sweep them without touching logic.

```js
// SQ_COMBAT_CONSTANTS — the ONLY place a balance sim needs to touch.
const C = {
  // ---- hero base scaling (per level) ----
  BASE_HP: 40,  HP_PER_LEVEL: 8,
  BASE_ATK: 10, ATK_PER_LEVEL: 2,
  BASE_DEF: 4,  DEF_PER_LEVEL: 1,
  BASE_SPD: 10, BASE_ACC: 90, BASE_EVA: 5, BASE_CRIT: 0.05, MAX_FOCUS: 100,

  // ---- damage pipeline ----
  ATK_COEFF_BASIC: 1.0,
  DEF_K: 50,                 // armor softness: mitig = DEF_K/(DEF_K+def)
  VARIANCE: 0.10,            // ±10% roll on every hit
  CRIT_MULT: 1.5,
  WEAK_MULT: 1.5, RESIST_MULT: 0.5, NEUTRAL_MULT: 1.0,
  MIN_DAMAGE: 1,

  // ---- hit / evade ----
  HIT_BASE: 0.90, ACC_SCALE: 0.01, HIT_MIN: 0.50, HIT_MAX: 0.99,

  // ---- timed-tap (Strike/Guard) ----
  STRIKE_WINDOW_MS: 900, GUARD_WINDOW_MS: 500,
  PERFECT_MULT: 1.25, GRAZE_MULT: 0.5,           // "graze" = the no-tap floor
  GUARD_MITIGATE: 0.40, GUARD_STANCE_MITIGATE: 0.30,
  STRIKE_HALFWIDTH_BASE: 0.14, STRIKE_HALFWIDTH_PER_SUREHANDS: 0.01, // fraction of bar
  FOCUS_ON_GOOD: 8, FOCUS_ON_PERFECT: 16, FOCUS_ON_WEAK: 10,
  FOCUS_REGEN_PER_ROUND: 5,

  // ---- press-turn / breach ----
  MAX_BREACH_CHAINS: 2,

  // ---- round timing ----
  CMD_WINDOW_MS: 12000, RESOLVE_STEP_MS: 700, IMPACT_MS: 300,
  SPD_JITTER: 4, HITSTOP_MS: 90, SCREEN_SHAKE_CRIT: 6,

  // ---- breach-tier multipliers (Elder → Massive), applied to MONSTER hp & atk ----
  //   tierIndex:            1(Elder) 2       3       4       5(Massive)
  TIER_HP_MULT:   [null, 0.8,   1.0,    1.35,   1.8,    2.6],
  TIER_ATK_MULT:  [null, 0.85,  1.0,    1.25,   1.55,   2.0],
  TIER_XP_MULT:   [null, 0.7,   1.0,    1.5,    2.2,    3.5],   // referenced by loot/xp section
  TIER_ELITE_CHANCE:[null,0.02, 0.05,   0.12,   0.25,   0.5],

  // ---- world-space behaviors (§4.5) ----
  FLEE_HP_FRAC: 0.20, FLEE_STEP_M: 8, FLEE_ESCAPE_M: 60, PURSUIT_REBIND_M: 15,
  CHASE_TRIGGER: ["wraith_elite"], CHASE_SPEED_MPS: 1.2, CHASE_CATCH_M: 12,
  CHASE_GRACE_S: 20,
};
```

**Breach-tier ladder.** `tierIndex 1..5`, endpoints named by the brief: **1 = Elder** (a thin, faded tear — weakest), **5 = Massive** (rift near collapse — DESIGN table). Intermediate names (2–4) are placeholders to reconcile with the map/rift section; combat only depends on `tierIndex`. Tier multiplies **monster** stats via `TIER_HP_MULT/TIER_ATK_MULT`; heroes scale only by `level`.

**Damage pipeline (server, per hit):**
```
power        = attacker.atk * ability.coeff
mitig        = C.DEF_K / (C.DEF_K + effectiveDef(target))   // def_break/sunder lowers effectiveDef
variance     = 1 + rng.uniform(-C.VARIANCE, +C.VARIANCE)    // seeded PRNG
elementMult  = weakness(ability.element, target) ? C.WEAK_MULT
             : resist(ability.element, target)   ? C.RESIST_MULT : C.NEUTRAL_MULT
crit         = isCrit(attacker, timing)                      // perfect-tap OR rng < critChance
critMult     = crit ? C.CRIT_MULT : 1
timingMult   = {perfect: C.PERFECT_MULT, good: 1.0, graze: C.GRAZE_MULT}[timingBand]
markMult     = target.has("mark") ? (1 + C.MARK_DMG) : 1

raw          = power * mitig * variance * elementMult * critMult * timingMult * markMult
damage       = max(C.MIN_DAMAGE, round(raw))
```

**Hit chance** (used only on the *auto* path / walking mode; a landed Strike tap is a guaranteed hit by definition — a missed timing window is self-evidently fair, per COMBAT-STUDY pattern G):
```
hitChance = clamp(C.HIT_BASE + (attacker.acc - target.eva)*C.ACC_SCALE, C.HIT_MIN, C.HIT_MAX)
```

**Hero stat by level:** `maxHp = BASE_HP + HP_PER_LEVEL*(lvl-1)`, likewise `atk`, `def`. Worked example — a **level-1 Knight Heavy Strike** on a **tier-2 goblin** (def 3), good timing, non-crit, no weakness:
`power = 10*1.6 = 16; mitig = 50/53 = 0.943; ≈ round(16*0.943) = 15` before variance → goblin (tier-2 hp ≈ 18) takes ~15, near-dead in one Heavy Strike. Same strike on a **tier-5 (Massive) goblin** (hp `TIER_HP_MULT[5]=2.6× → ~47`) needs 3–4 hits — the tier ladder is doing the work, not new math.

---

### 4.4 Monster roster (from the art on disk)

The mob roster is the **itch-imported art in `assets/sprites/`** (mixed ~150²), plus two **legacy 32²** breeds kept until re-arted. Base stats are **tier-2 (index 2 = the 1.0× reference tier)**, level-1 equivalent; scale by `TIER_*_MULT`, rift depth, and the §6.5.5 party/density knobs. `element` drives weakness/Breach. **Stats are provisional — the §9.6 balance sim owns the final numbers.**

| Breed | Role | `hp` | `atk` | `def` | `spd` | Element / weak | Personality & telegraph | Sprite states (`assets/sprites/…`) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Goblin** | Melee skirmisher (throws) | 18 | 8 | 3 | 12 | phys / weak:fire | Cowardly opportunist; **flees at low HP** (§4.5); lobs a bomb when kited. Telegraph `⚔ ~9` / `🗡 bomb`. | `idle, run, attack, quick_attack, projectile, hurt, die` |
| **Skeleton** | Shielded melee bruiser | 26 | 11 | 6 | 8 | phys / weak:blunt, resist:pierce | Relentless, never flees; **`block`** raises a shield to mitigate a telegraphed hit; throws a sword. Telegraph `⚔ ~13` / `🛡 guard`. | `idle, walk, attack, quick_attack, block, projectile, hurt, die` |
| **Flying Eye** | Aerial ranged kiter — **the FLEE-able elite & world-chaser** (§4.5) | 20 | 12 | 4 | 15 | air/shadow / weak:light | The frightener: hovers, keeps distance, rains a `projectile`; high eva → the natural elite you flee, or that hunts you. Telegraph `✶ gaze` / `● bolt`. | `fly, attack, quick_attack, projectile, hurt, die` (rests on `fly`, no idle) |
| **Mushroom** | Rooted spore caster (control) | 22 | 7 | 2 | 6 | spore/nature / weak:fire | Stationary lobber; spore `projectile` applies `def_break`/poison; bursts spores on death (AoE tick). Telegraph `✷ spore`. | `idle, run, attack, quick_attack, projectile, hurt, die` |
| **Demon (imp)** | Elemental imp — 16 flavors | 16 | 10 | 3 | 11 | elemental *(per-variant)* / weak:varies | A lesser demon; the 16 skins map to elements (fire/shadow/…) so a pack teaches weakness/Breach. **Static art** (single-frame `variant_*`) — fine for the POC: a variant frame is its idle/portrait, no animation needed. Telegraph `🔥/🌑` by element. | `variant_a1…variant_b8` (static, 64²) |

**Legacy 32² breeds** (still in `assets/sprites/`, kept until upscaled to the itch style — retire or re-art later): **Slime** (acid caster; on death **splits** into two half-HP slimes) and **Wraith** (shadow projectile/caster). Both keep the full 32² vocabulary (`idle/walk/attack/cast/projectile/hurt/die/cheer`).

Role → default AI intent each round:
- **melee** (goblin, skeleton, demon): approach the nearest low-threat hero and `attack`; goblin swaps to bomb `projectile` when kited to `far`; skeleton `block`s a big incoming telegraph.
- **aerial kiter** (flying eye): keep distance, `projectile` the highest-threat hero — feeds the §4.5 flee/chase.
- **rooted/ranged caster** (mushroom; legacy slime/wraith): `projectile`/`cast` a debuff on the un-debuffed target; mushroom never repositions.

Elites (`TIER_ELITE_CHANCE`) are a base breed with an **elite kit**: +HP/+atk, a signature status, a name, and — for the **flying eye** (or a legacy wraith) — the §4.5 world-space chase trigger.

---

### 4.5 World-space behaviors (specced concretely for GPS)

These are the three behaviors the brief demands. Each is defined so a **headless fixture can drive it with a mocked GPS track** — behavior reads `hero.worldPos` / `monster.worldPos` (lat/lng → local meters), never real hardware.

#### (A) Scary elites you may FLEE *from*
A **flying-eye elite** (or any `breachTier ≥ 4` marked encounter) surfaces on the map with a threat readout (DESIGN: Massive = rift near collapse). The **player** may decline: choosing `Flee` in the command window ends the encounter with no loss (the bus test — abandonable, no penalty). Fiction: your apprentice refuses to let you cross for it (DESIGN safety fiction). Server emits `EncounterEnd{outcome:"fled_by_party"}`. The elite persists on the map for a re-approach and, if left, contributes to the convergence clock (referenced, other section).

#### (B) Monsters that FLEE when low → you must PURSUE across the map
The **goblin** (and any breed with `flee` trait) at `hp < FLEE_HP_FRAC*maxHp` and not `stagger`ed rolls to break combat. On success:
1. Server plays `quick_attack` (scramble) and emits **`MonsterFled{ monsterId, fleeAnchor: worldPos, escapeRadiusM: FLEE_ESCAPE_M, hpFrozen }`** — combat *suspends*, HP is frozen at its fled value.
2. The monster becomes a **map mark** drifting away from the party at `FLEE_STEP_M` per `PursuitTick` along a seeded heading. Each tick: **`PursuitTick{ monsterId, worldPos, distanceM }`**.
3. **Pursuit = the player physically closes distance.** When `distance(hero, monster) ≤ PURSUIT_REBIND_M`, server emits `EncounterStart` again for the *same* `monsterId` with `hp = hpFrozen` — the fight **resumes wounded**, so the chase paid off.
4. If `distance ≥ FLEE_ESCAPE_M` for `MonsterEscaped.graceTicks`, server emits **`MonsterEscaped`**: it's gone (keeps partial XP knowledge — DESIGN "bosses flee and reappear elsewhere"). This is the diegetic reason to *walk*, tying combat to `endurance` (referenced).

> Accessibility path (RIFT-BRIEF safety): a player who can't give chase sends the **apprentice `Lure`/`Fetch`** action to drag the fled monster back into `PURSUIT_REBIND_M`, or `Rescue` for partial loot — pursuit is never a hard wall.

#### (C) Monsters that CHASE the player in world-space
Breeds in `C.CHASE_TRIGGER` (the **flying-eye** elite; or a legacy wraith) that the player *disengages from without killing* flip to **hunter state**. "Being chased" is concrete:
1. Server emits **`ChaseBegin{ monsterId, hunterPos, speedMps: CHASE_SPEED_MPS, catchRadiusM: CHASE_CATCH_M, graceS: CHASE_GRACE_S }`**. A pursuit banner + a blip that tracks *toward* `hero.worldPos` appear on the map.
2. Each **`ChaseTick`** the blip advances `CHASE_SPEED_MPS × dt` along the bearing to the (possibly moving) hero.
3. **The consequence, on catch** (`distance ≤ CHASE_CATCH_M`): **`ChaseCaught`** force-starts an ambush encounter — `proximityBand:"close"`, the elite gets a free opening `projectile`, and the party begins one round staggered. So ignoring a scary elite has teeth; you either lose it (outrun/break line-of-sight past `graceS` with distance climbing → **`ChaseConsequence{ resolved:"lost" }`**) or get jumped.
4. Never punishing beyond the ambush; there is no world HP loss while walking (safety). The apprentice `Ward` action can force `ChaseConsequence{resolved:"warded"}` to end a chase — the accessibility valve again.

All three read/write only `worldPos` + the pursuit messages, so a fixture feeds a scripted `[t, lat, lng]` track and asserts the exact `PursuitTick/ChaseTick` sequence deterministically.

> **Stalking is a load-bearing pillar, not a garnish** (product direction). Chase/hunt (C) and fled-pursuit (B) are core to the outdoor feel and must be built **and tested** for **solo *and* party**. Stalkers spawn and persist more in high-`localPressure`, **unclaimed** cells (§6.5.5) and are **shed by claimed territory / camp** (§6.5.4) — so *holding ground* is the diegetic counter to being hunted, which is why territory claim matters as much as the fights.

---

### 4.6 Co-op combat (party vs one breach)

- **HP is per-member, never shared.** Each hero is its own `Combatant` with `hp/maxHp`. A shared pool would let one reckless kid drain the parent — rejected.
- **One shared `Encounter`, simultaneous command-lock turn order.** All living heroes submit into the *same* `CMD_WINDOW_MS`; resolution interleaves heroes + monsters by initiative (`spd + rng`). Nobody waits on a slow player: at the deadline the server auto-fills missing submissions with each hero's script. This is what makes co-op-with-kids work — the fight has a heartbeat independent of the slowest thumb.
- **Aggro** (`Encounter.aggro`): each monster tracks per-hero `threat`; melee/Heavy Strike/damage add threat, `Guard`/Bulwark/taunt spike it, `Hunter's Mark` redirects. Monster intent targets its highest-threat living hero → the Knight can *soak* for the party (front-line fiction).
- **Downed & revive.** At `hp ≤ 0` a hero is **downed** (not dead): server emits **`CombatantDowned{ heroId }`**, the hero plays `hurt`→kneel (not `die`), can't act, and stops drawing aggro. A living ally spends an action **`Rally`** (Knight innate; anyone with a Revive item) within `REVIVE_RANGE` → **`CombatantRevived{ heroId, hp: round(REVIVE_HP_FRAC*maxHp) }`**. Fiction: you steady their avatar across the veil.
- **Death → wake-at-camp.** If **all** party members are downed simultaneously → `EncounterEnd{ outcome:"party_wipe" }`; each hero plays `die`, then the party **wakes at camp** — literal in the tome fiction (avatars retreat, "wounded, not lost", DESIGN). Penalty is loot-side (unstable loot lost, RIFT-BRIEF), not HP debt; no real-world stakes.
- **Solo → N is one code path (mandatory).** A party of **1** is the same `Encounter` with a single `Combatant`; every co-op rule above degrades cleanly to N=1 (a downed solo has no ally to `Rally` → immediate `party_wipe` → wake-at-camp). All of combat, aggro, turn order, revive, and loot attribution handle **1..`PARTY_MAX`**. **The garrison scales to the engaging party** (§6.5.5): solo faces `baseGroup`; larger parties face proportionally more monsters (and, past a threshold, a higher `encounterTier`), so **per-hero** challenge stays ~flat — the field auto-balances to headcount instead of trivializing in a crowd or overwhelming a lone player.

---

### 4.7 Server-authoritative resolution & headless testability

**Authority:** the server owns `Encounter`, the single seeded PRNG, and all math in §4.3. Clients render `ActionResolved` events and submit intents; **clients never roll**. This is the DESIGN connectivity posture (server-authoritative online).

**Wire order for one round:**
```
Server → clients : EncounterStart { encounterId, seed, breachTier, tierIndex,
                                    combatants[], party, proximityBand }
loop each round:
  Server → clients : TurnBegin { round, deadlineMs: CMD_WINDOW_MS,
                                 telegraphs:[{monsterId, intent, estDamage}] }
  clients → Server : ActionSubmit { encounterId, round, actorId,
                                    action:{type, abilityId, targetId,
                                            timingSample /* 0..1 tap pos, or "auto" */} }
  Server → clients : ActionResolved { round, seq, events:[            // ordered by initiative
                       { actorId, abilityId, targets:[{id, damage, crit, band, statusApplied}],
                         focusDelta, breach:bool, spriteEvents:[…],
                         floatingText:[…], rngCursor } ] }
  Server → clients : CombatantDowned / CombatantRevived   (as they occur)
Server → clients : EncounterEnd { outcome, loot, xpReward, focusCarry:false }
```
World-space (§4.5) rides the same channel: `MonsterFled → PursuitTick* → (EncounterStart|MonsterEscaped)` and `ChaseBegin → ChaseTick* → (ChaseCaught|ChaseConsequence)`.

**Determinism contract (what a bot client relies on):**
1. Given identical `seed`, breed/tier/level tables, and an identical **ordered** list of `ActionSubmit` (including each `timingSample`), the server produces a **byte-identical** `ActionResolved` stream. `rngCursor` is emitted on every event so a test can pin the exact PRNG draw count.
2. `timingSample` fully determines the Strike/Guard band — no wall-clock reads in resolution. `"auto"` uses the hit-chance path (§4.3) off the same PRNG. So a bot can force *perfect / good / graze / miss* deterministically.
3. Resolution order is a pure function of `(spd, seed, round)` — no arrival-time ordering.

**How a bot client drives & asserts:**
```python
# Deterministic combat fixture (no human input, no GPS hardware, no wall clock)
enc = server.start_encounter(seed=1337, party=[knight_l1, ranger_l1],
                             monster="wraith", tierIndex=4)
assert enc.combatants["wraith"].maxHp == round(20 * C.TIER_HP_MULT[4])   # 36

# Round 1: knight Heavy Strike (perfect), ranger Hunter's Mark, force order via seed
r1 = server.submit_round(enc, [
        ("knight",  {"type":"ability","abilityId":"heavy_strike","targetId":"wraith","timingSample":0.5}),  # perfect
        ("ranger",  {"type":"ability","abilityId":"mark","targetId":"wraith","timingSample":"auto"}),
     ])
hit = r1.event("knight","heavy_strike").targets[0]
assert hit.crit is True and hit.band == "perfect"
assert hit.damage == expected_damage(power=16, defK=50, targetDef=4, tier=4,
                                     critMult=1.5, timingMult=C.PERFECT_MULT, seed_cursor=r1.rngCursor)
assert enc.combatants["knight"].focus == C.FOCUS_ON_PERFECT

# Assert a world-space behavior deterministically off a scripted GPS track
gob = server.start_encounter(seed=7, party=[knight_l1], monster="goblin", tierIndex=2)
server.damage(gob, "goblin", to_hp=3)                         # below FLEE_HP_FRAC
fled = server.submit_round(gob, [("knight", GUARD)])          # goblin flees
assert fled.message == "MonsterFled" and fled.hpFrozen == 3
track = [(0,LAT,LNG),(5, LAT+ d_meters(20)),(10, LAT+ d_meters(5))]  # walk toward it
ticks = server.play_gps_track(gob, "goblin", track)
assert any(t.distanceM <= C.PURSUIT_REBIND_M for t in ticks)  # rebind fired
assert server.encounter_for("goblin").combatants["goblin"].hp == 3  # resumed wounded
```

A **balance simulator** reuses the same entry points: sweep `SQ_COMBAT_CONSTANTS`, run N seeded auto-battles per `(class, breed, tierIndex, level)` cell, and read win-rate / rounds-to-kill / damage-taken off `EncounterEnd` + `ActionResolved` — no rendering, no human, no clock. Because Strike taps have an `"auto"` path resolved by the same PRNG, walking-mode and kid-mode balance fall out of the identical simulation.

---

**Files read to ground this section:** `/home/user/SideQuestAppV2/docs/COMBAT-STUDY.md`, `/home/user/SideQuestAppV2/docs/DESIGN.md`, `/home/user/SideQuestAppV2/docs/RIFT-BRIEF.md`, `/home/user/SideQuestAppV2/docs/ART-DIRECTION.md`, `/home/user/SideQuestAppV2/assets/manifest.json`, and the sprite-state inventory under `/home/user/SideQuestAppV2/assets/sprites/{goblin,skeleton,slime,wraith,knight,ranger}/`.

**One flag for the orchestrator:** the FOUNDATION CONTRACT body was not included in my brief. I wrote against the assumed interface enumerated in **§4.0**; reconcile the exact spellings of `Combatant`/`Encounter` fields, the `breachTier` enum names for tiers 2–4, and the protocol message names there — the rest of the section is spelling-agnostic and will not need edits.

Now I have a complete picture of the de-facto contract (the prototype sim's data model) plus all design docs. I'll write section 5 to extend those exact field names and reference the sibling sections. Here is the deliverable.

---

## 5. Progression, Loot, Items & Economy

> **Conformance.** This section extends the Foundation Contract data model (the `Item`, `Hero`, `Enemy` records and the client↔server message envelope) and the Combat spec (§4, which owns all *effects* — damage math, procs, the Breach! press-turn and Focus meter from `COMBAT-STUDY`). Visuals (sprites, chest frames, rarity glow) belong to §8. Camp (§ Camp) owns the away-time/bastion sinks this section feeds materials into. Field names in `code font` are the contract's and are reused verbatim from the current sim (`prototype/index.html`): `Item{name, slot, for, atk, dmg, fx, magic, tier, value, def, hp, dodge, id}`, `Hero{cls, level, xp, xpNext, hp, gold, mats, potions, bonusAtk, bonusHp, ep, dp, walked, train, bastion, craft, equip, bag}`, `Enemy{name, hp, atk, def, xp, gold, weak, resist}`. New fields introduced here are marked **§5-new** and are additive (old saves migrate — see 5.13).
>
> **Determinism law.** Everything in this section is a pure function of an explicit seed. No `Math.random()`. The server owns the RNG (server-authoritative per `NORTH-STAR`); the client replays the same stream for prediction. Every loot/forge/merchant roll draws from a *named substream* `rng(seed, tag)` so a headless fixture can reproduce or assert on any single draw (see 5.18). Convention used below: `R = rng(seed, "loot")`, with `R.chance(p)`, `R.int(a,b)`, `R.pick(arr)`, `R.weighted([[v,w]…])`, all deterministic.

---

### 5.1 Character stats

The character sheet is thin on purpose — four base stats plus derived combat values. Base stats come from **class + level + permanent bonuses + gear + EP-training**; nothing here is a hidden roll (`COMBAT-STUDY` "legible" law).

| Stat | Field | Formula (derived, read-only) | Feeds |
| --- | --- | --- | --- |
| Max HP | `heroMaxHp()` | `class.hp + (level-1)*HP_PER_LVL + bonusHp + Σgear.hp + train.vigor*VIGOR_HP` | §4 survivability |
| Attack | `atkOf(slot)` | `weaponBase[slot] + bonusAtk + train.power + weapon.atk` | §4 damage |
| Defense | `heroDef()` | `class.def + floor((level-1)/2) + Σgear.def` | §4 mitigation |
| Dodge | `dodgeBonus()` | `Σgear.dodge + train.dodge*DODGE_PER_RANK` | §4 avoid |
| Accuracy | `hitChance(slot,kind)` | `baseAcc(w) − offClassPenalty + levelAcc + train.acc*ACC_PER_RANK − swingPenalty` | §4 hit roll |

`weaponBase[slot]`: `ranged→5`, `melee→ (cls==='knight'?6:2)` (existing). Off-class weapons take `−0.32` accuracy (existing). These are the numbers §4 reads for damage/hit; this section only *sets* them via progression and gear.

**Permanent vs. run-temporary.** Per `RIFT-BRIEF`, permanent progression (this section: levels, `train`, gear, `bonusAtk`/`bonusHp`, relic slots, bastion) *broadens options*; run-temporary progression (boons/curses/mutations inside a breach — owned by the Rift/Combat spec) *creates build variety*. This section never grants a temporary boon; it grants the durable floor those boons build on.

---

### 5.2 XP curve, leveling, stat growth

Reuses `xp`, `xpNext`. On kill, `addXp(x)` accumulates and rolls levels:

```js
function addXp(x){
  const h = S.hero; h.xp += x; let leveled = 0;
  while (h.xp >= h.xpNext){
    h.xp -= h.xpNext; h.level++; leveled = h.level;
    h.xpNext   = Math.round(h.xpNext * XP_GROWTH);   // geometric curve
    h.bonusAtk += CLASSES[h.cls].atkGrow;            // knights grow faster
    h.hp        = heroMaxHp();                        // ding = full heal
    unlockAbilities(h);                              // 5.4 ladder gate
  }
  return leveled;
}
```

**Curve.** `xpNext(1)=XP_BASE=20`, `xpNext(L)=round(XP_BASE · XP_GROWTHᴸ⁻¹)`. The prototype ships `XP_GROWTH=1.6`; that is too steep past L8 (L20 ≈ 250k, a grind wall). **Recommended retune: `XP_GROWTH=1.45`.** Table (per-level / cumulative, `1.45`):

| L | to next | cumulative | L | to next | cumulative |
|---|---|---|---|---|---|
| 1→2 | 20 | 20 | 8→9 | 179 | 585 |
| 2→3 | 29 | 49 | 10→11 | 376 | 1 230 |
| 3→4 | 42 | 91 | 12→13 | 790 | 2 590 |
| 4→5 | 61 | 152 | 15→16 | 2 470 | 8 050 |
| 5→6 | 88 | 240 | 20→21 | 15 300 | 50 900 |

Enemy XP payout (existing `Enemy.xp`: slime 8, goblin 14, skeleton 18, wraith 26) scaled by breach tier `⌈xp · (1 + 0.35·(tier-1))⌉`. Early game (L1→5, the `RIFT-BRIEF` unlock sequence) is deliberately fast: ~a dozen wild kills to L5 so the apprentice/merchant/spec/boss unlocks all fire in the first sessions.

**Stat growth per level:** `+HP_PER_LVL(8)` max HP, `+1 def` every 2 levels, `+atkGrow` attack (knight 2 / ranger 1). Growth is intentionally shallow — the `bonusAtk` term routes level growth onto *whatever weapon is equipped* so a ranger's bow benefits from levels (existing fix, preserved).

---

### 5.3 Class identity

Two classes ship; the schema is open (`CLASSES[key]`) for the `RIFT-BRIEF` mage/summoner later. Identity lives in starting stats, growth rate, engage band, and which weapon slots feel native.

| | **Ranger** | **Knight** |
| --- | --- | --- |
| `hp` / `def` (L1) | 30 / 2 | 38 / 3 |
| `engage` band | 40 (far/mid, safe default) | 20 (close, commits) |
| `atkGrow` | 1 | 2 |
| Native weapon | `ranged` (bow, skill weapon, 0.88 acc) | `melee` (blade, arm weapon) |
| Signature `fx` | `crit`, `frost`, `poison` (precision/control) | `cleave`, `lifesteal` (sustain/AoE) |
| Fantasy | patrols the border from range; marks & kites | holds the line; staggers & seals fast |

This maps onto §4's proximity design (`RIFT-BRIEF`: *closer = more options, higher commitment*): the knight's low `engage` and cleave reward closing; the ranger's high `engage` and crit reward safe distance — so class identity and the safety/accessibility pillar reinforce each other rather than fight.

---

### 5.4 Ability unlock ladder (per class)

Two unlock axes; **all numeric effects are owned by §4** — this section only gates *when* an ability becomes available and *what it costs*.

**Axis A — Level ladder (permanent, free at level-up).** Pinned to the `RIFT-BRIEF` early-game sequence so meta systems come online early:

| Level | Universal | Ranger | Knight | Effect owner |
| --- | --- | --- | --- | --- |
| 1 | Basic + Power/Aim attack, Block, Dodge, Potion | Aimed Shot | Heavy Strike (stagger) | §4 |
| 2 | Apprentice joins; 1 downtime slot | Scout synergy (mark→apprentice) | — | § Apprentice |
| 3 | Merchant whistle; **relic/`trinket1` slot unlocks** | — | — | 5.6 |
| 4 | First class spec | Hunter's Mark (ranged follow-up) | Cleave upgrade / Shield Wall | §4 |
| 5 | First rift boss; **Focus meter** unlocks; `trinket2` slot | Volley (multi-hit) | Bulwark (Focus spend) | §4 (Focus = `COMBAT-STUDY` D) |

**Axis B — EP training ladder (permanent, bought with 🥾 Endurance).** The QfG spine (`DESIGN.md`: *the skills you walk for grow*). Reuses `train{acc,dodge,power,vigor}`, `TRAIN_META`, `TRAIN_MAX=5`, `trainCost(r)=(r+1)*20` → **20/40/60/80/100 EP** per rank (300 EP to max one line).

| Line | Field | Per rank | Native to |
| --- | --- | --- | --- |
| 🎯 Sure Hands | `train.acc` | +2% hit (also widens the §4 timed-tap window) | both |
| 💨 Fleet Foot | `train.dodge` | +2% dodge | ranger |
| 💪 Iron Arms | `train.power` | +1 attack | knight |
| ❤️ Vigor | `train.vigor` | +5 max HP | both |

Training is *strictly additive power gated behind real-world movement*, never a wall — per `RIFT-BRIEF`'s currency warning, a fully-untrained hero still clears T1–T2 content. Bots/fixtures reach any training state by directly setting `train` + `ep` (no walking required in headless mode).

---

### 5.5 Item schema (extends contract `Item`)

The contract `Item` gains the following **§5-new** fields (all optional; absence = sensible default). Every item minted goes through `mkItem(base, seed)` which stamps a stable `id` and, for rolled items, records its `seed` so any drop is reproducible.

```ts
Item {
  // --- contract base (unchanged) ---
  id:      string          // 'i'+counter (existing)
  name:    string
  slot:    Slot            // see 5.6
  for?:    'ranger'|'knight'|null   // class-lock; null = neutral (armor)
  atk?:    number
  dmg?:    'phys'|'fire'|'cold'|'shock'|'acid'   // §4 damage type
  fx?:     'crit'|'frost'|'poison'|'cleave'|'lifesteal'  // §4 proc key
  magic?:  string          // human flavor of the proc ('Frostshot — cold…')
  def?:    number
  hp?:     number
  dodge?:  number
  tier:    1|2|3|4|5        // breach tier that gates when it can drop
  value:   number          // gold worth — now DERIVED (5.9), authored = floor

  // --- §5-new ---
  cat:     'weapon'|'armor'|'trinket'|'consumable'|'material'  // category
  rarity:  0|1|2|3|4        // 5.7
  affixes?: Affix[]         // 5.8 (rolled prefixes/suffixes)
  up?:     number           // temper level 0..5 (5.12)
  power?:  number           // item power score (5.9, cached)
  cursed?: boolean          // fae-bargain flag (5.7)
  curse?:  string           // curse effect key → §4
  seed?:   number           // roll seed (reproducibility)
  stack?:  number           // consumables/materials: current qty
  bound?:  false|'equip'|'account'  // co-op binding (5.11)
  identified?: boolean      // false = affixes hidden until appraised (5.15)
}

Affix { key: string; tier: 1..3; roll: number; stat: StatKey; value: number }
```

The existing hand-authored `ITEMS[]` catalog (bows, blades, armor) becomes the **base-item table**: each entry is a `rarity:0, cat, affixes:[]` template. Rarer drops = a base entry + rolled `rarity`/`affixes`/`up`. Nothing in the catalog is deleted; it is the deterministic spine loot rolls decorate.

---

### 5.6 Categories & equipment slots

**Categories** (`cat`): `weapon` · `armor` · `trinket` · `consumable` · `material`. Only `weapon`/`armor`/`trinket` are equippable; `consumable`/`material` live in their own pouches (5.13).

**Equipment slots** — extends the existing `SLOTS` with relic/trinket slots (the `RIFT-BRIEF` "relic slots"):

```js
const SLOTS = ['melee','ranged','helmet','armor','legs','shield','boots',
               'trinket1','trinket2'];   // trinket1@L3, trinket2@L5
```

Rules (reuse existing `equip`/`unequip`, `gearSum`, `gearList`):
- **Two weapon slots always** (`melee` + `ranged`); the melee slot can never be emptied (`unequip` guard preserved) — a hero is never weaponless.
- `for`-locked weapons equip off-class but suffer the `−0.32` accuracy grip penalty (existing); armor/trinkets are class-neutral.
- Trinkets carry `hp`/`dodge`/affixes/`fx` but **no `atk`/base weapon role** — they're relics, not weapons. Gated: `trinket1` at L3, `trinket2` at L5 (5.4).
- `SLOT_META[slot]` (icon+label, existing) extended with the two trinket entries for §8.

---

### 5.7 Rarity tiers

Five tiers, QfG-warm naming (the apprentice/merchant appraises loot; the register is adventure-with-a-wink, `NORTH-STAR`). In-fiction, rarity = how much veil-power an item holds. Rarity sets **affix count**, an **item-power multiplier**, and **glow** (→ §8).

| `rarity` | Name (prefix) | Color | Affixes | `RARITY_POWER` | Fiction / apprentice line |
| --- | --- | --- | --- | --- | --- |
| 0 | **Wayfarer's** (plain) | grey | 0 | ×1.00 | *"Honest gear. Won't embarrass you."* |
| 1 | **Trueforged** | green | 1 | ×1.15 | *"Someone who knew their craft made this."* |
| 2 | **Warden-Blessed** | blue | 2 | ×1.35 | *"There's a Warden's mark on it — lucky you."* |
| 3 | **Veil-Touched** | purple | 3 (+may roll an `fx`) | ×1.60 | *"This one's been to the other side and came back strange."* |
| 4 | **Riftforged** (named unique) | gold | curated fixed kit | ×1.90 | *"…I've only heard of these in stories."* |

Legendaries (`rarity:4`) are **curated, not rolled** — a small hand-authored table of named uniques with fixed signature `fx`/`magic` (e.g. *Riftforged* bows/blades), so the top tier reads as authored moments, not stat soup. They still respect `for`/`slot`/§4 effects.

**Curses (orthogonal, not a tier).** From the `RIFT-BRIEF` fae-bargain / cursed-gear fiction: any rarity ≥1 drop from a Fae/shrine source (or a merchant "cursed bargain") may roll `cursed:true` with a `curse` key. Cursed items get **+1 effective rarity of stats** but attach a §4 downside (e.g. corruption buildup, reduced healing). Merchant `identify`/apprentice Arcanist can *reveal* a curse before you equip; removing one is a Recovery-point (Camp) job. This gives push-your-luck to loot itself and a real reason to visit the merchant.

---

### 5.8 Affixes & stat rolls

Affixes are rolled prefixes/suffixes drawn from a class-and-slot-aware pool, deterministic from the item `seed`. Each affix picks a `stat`, an affix `tier` (1–3, magnitude band), and a `roll` (position in that band, `0..1`) that fixes the final `value`.

```js
const AFFIX_POOL = {
  // stat, per-affix-tier value ranges [min,max], slot restriction
  keen:    {stat:'atk',   slot:'weapon', bands:[[1,2],[2,4],[4,6]]},
  guarded: {stat:'def',   slot:'armor',  bands:[[1,1],[2,3],[3,4]]},
  hale:    {stat:'hp',    slot:'any',    bands:[[4,6],[7,10],[11,16]]},
  fleet:   {stat:'dodge', slot:'any',    bands:[[.02,.03],[.04,.06],[.07,.10]]},
  cruel:   {stat:'crit',  slot:'weapon', bands:[[.03,.05],[.06,.09],[.10,.14]]}, // →§4
  sure:    {stat:'acc',   slot:'weapon', bands:[[.02,.03],[.04,.05],[.06,.08]]}, // →§4
  // elemental "of Ember/Rime/Storm/Venom": adds bonus dmg of a type → §4
  emberish:{stat:'edmg',  dmg:'fire',  slot:'weapon', bands:[[2,3],[4,5],[6,8]]},
};

function rollAffixes(base, rarity, seed){
  const A = rng(seed,'affix'); const n = RARITY_AFFIX_COUNT[rarity]; // [0,1,2,3,3]
  const cands = affixesLegalFor(base);           // slot/cat/class filter
  const out = [];
  for (let k=0; k<n; k++){
    const def = A.weighted(cands.map(c=>[c, c.weight]));
    const t   = A.weighted(AFFIX_TIER_WEIGHTS[rarity]); // higher rarity → higher tiers
    const [lo,hi] = def.bands[t-1]; const r = A.float();
    out.push({key:def.key, tier:t, roll:r, stat:def.stat,
              value: round(lo + (hi-lo)*r, def.stat==='dodge'?2:0)});
    cands.splice(cands.indexOf(def),1);          // no duplicate stat lines
  }
  return out;
}
```

Affix `stat` values fold into the same `gearSum(stat)` the character sheet already reads — new stat keys `crit`, `acc`, `edmg` are consumed by §4 (crit chance, hit chance, bonus elemental damage). Naming for display composes as **`<prefix> <base> <suffix>`** (e.g. *Keen Recurve Bow of the Hale*), an easy QfG-flavored string with no extra art.

---

### 5.9 Item power & value

**Item power** — one scalar for upgrade-arrows, drop gating, and pricing:

```js
function itemPower(it){
  const s = (it.atk||0)*W_ATK + (it.def||0)*W_DEF + (it.hp||0)*W_HP
          + (it.dodge||0)*100*W_DODGE
          + (it.affixes||[]).reduce((a,x)=>a + affixPower(x),0)
          + (it.fx ? FX_POWER : 0);
  return round((s + it.tier*TIER_POWER) * RARITY_POWER[it.rarity] * (1 + (it.up||0)*UP_POWER));
}
```
`W_ATK 1.6 · W_DEF 2.2 · W_HP 0.5 · W_DODGE 1.4 · FX_POWER 8 · TIER_POWER 3 · UP_POWER 0.08`. Calibration target: a Wayfarer's T1 weapon ≈ 18–25 power; a Riftforged T4 ≈ 110–140.

**Value** (gold, replaces hand-authored `value` as source of truth; authored numbers become the *floor* so quest/starter items keep sane prices):

```js
value = max(authoredFloor, round(itemPower(it) * GOLD_PER_POWER
             * CAT_VALUE[it.cat] * (it.cursed ? CURSE_VALUE : 1)));
```
`GOLD_PER_POWER 1.8 · CAT_VALUE{weapon 1.0, armor 0.9, trinket 1.2, consumable —, material —} · CURSE_VALUE 0.7` (cursed gear sells cheap; the merchant knows). Sanity check vs. existing authored: Long Bow (atk9,T1) → power≈14+3≈17 → value≈31 (authored 30 ✓); Greatsword (atk15,T4,cleave) → power≈24+8+12≈44 → value≈79… authored 105, so the floor holds legendaries/high-fx items up — acceptable, the balance sim (5.17/5.18) tunes the weights.

---

### 5.10 Loot — drop tables, breach tiers, chests, unstable loot

On any kill or chest open, the server resolves loot with `resolveDrop(ctx, seed)` — a pure function. `ctx = {enemy|chest, breachTier, depth, magicFind, playerId, dropIndex}`.

**Per-kill payout (baseline, extends existing `finishCombat` rewards):**
- **Gold**: existing `Enemy.gold=[min,max]`, rolled, ×breach mult `(1 + 0.25·(tier-1))`.
- **Materials**: existing `mats += 1 + enemy.tier`, now typed → `materials.salvage` (5.14); plus an **essence** roll: if the enemy has an elemental affinity (`weak`/signature `dmg`), `ESSENCE_CHANCE(=0.20)` to drop 1 matching essence.
- **Gear**: gear-drop chance `GEAR_CHANCE_BASE(=0.18)` for trash, `0.55` for elites, `1.0` (guaranteed) for bosses, ×`(1+magicFind)`.
- **Rare currency (Veilshard)**: elites `0.10`, bosses `0.5–1`, T5 overdepth kills `0.05` baseline.

**Rarity odds by breach tier** (the roll that runs *only if* a gear drop happens). Deeper tears hold more veil-power (`DESIGN.md`):

| Breach tier | Common | Uncommon | Rare | Epic | Legendary |
| --- | --- | --- | --- | --- | --- |
| T1 (minor) | 78% | 18% | 3.5% | 0.5% | 0% |
| T2 (standard) | 62% | 28% | 8% | 1.7% | 0.3% |
| T3 (elite) | 45% | 33% | 16% | 5% | 1% |
| T4 (boss) | 30% | 34% | 24% | 9% | 3% |
| T5 (overdepth) | 18% | 32% | 28% | 15% | 7% |

`magicFind` (from apprentice Scout, boons, events, `RIFT-BRIEF` push-your-luck) shifts weight from Common → higher tiers by `+magicFind` reallocated proportionally to rare+.

**Push-your-luck / unstable loot** (the `RIFT-BRIEF` heart). Loot picked up at depth ≥2 is minted `bound:false` **and flagged unstable**: it only *banks* on a successful **Seal/Extract**; **dying mid-floor forfeits unstable loot** (keeps XP/knowledge — the `RIFT-BRIEF` "Fail Extraction" outcome). Each extra depth applies a **depth loot bonus**: rarity table shifts up one row equivalent per `DEPTH_RARITY_STEP(=1 tier per 2 depths)`, and adds `+DEPTH_GOLD(0.15)`/depth. This makes "extract now vs push" a real EV decision the balance sim can chart.

**The chest prop** (`assets/props/chests.png`; the For-the-King "pure loot room"). A no-combat floor granting a **guaranteed roll at +1 effective breach tier**, plus the trapped-chest push-your-luck mini-game:

```js
// pry: keep going for a better roll, or the trap snaps
function pryChest(chest, seed){
  const P = rng(seed,'pry'); let mf = 0, pryCount = 0;
  while (true){
    const yield_ = rollGear({breachTier: chest.tier+1, magicFind: mf}, seed, pryCount);
    if (playerStops()) return bank(yield_);           // take it
    if (P.chance(SNAP_BASE + pryCount*SNAP_STEP))      // 0.15 + 0.12/pry
        return snap(yield_);                           // trap: lose this roll, minor dmg
    mf += 0.25; pryCount++;                             // each pry: +magic find, +snap risk
  }
}
```
`SNAP_BASE 0.15 · SNAP_STEP 0.12`. Chest tiers (`Battered / Warden's / Rift-Sealed`) set base tier and max pries. Bots resolve `pryChest` by a policy fn (`stopAtPry:n`) so fixtures can sweep the EV curve.

---

### 5.11 Co-op loot rules (instanced vs shared)

Fairness is retention, not just ethics (`MONETIZATION`: *the rich kid wins and everyone else quits*), and rung-1 is a **friend group of 13-year-olds** (`NORTH-STAR`). Therefore:

- **Gear & gold: fully instanced (personal).** Each player gets their own deterministic roll `seed_player = hash(runSeed, playerId, dropIndex)`. No shared pile, no ninja-looting, no "you took my drop." Server-authoritative, so no client can inflate its own roll.
- **Materials from shared objectives: shared-pool, split evenly**, rounded up so no one gets zero (`salvage` from a co-op boss). Personal-kill materials stay personal.
- **Completion rewards: shared/identical.** The sealed-tear bonus, first-clear tokens, and world-state (§ Persistent World) are granted equally to all participants — group content pays the group.
- **Binding to stop funneling.** Any dropped gear is `bound:false` and **tradeable within the party for a short window** (`TRADE_WINDOW=10min`); the moment it's equipped it becomes `bound:'equip'`. This lets friends hand off an off-class drop ("that bow's useless to me, take it") without enabling a high-level player to farm and gift best-in-slot gear to a low-level friend (the pay-to-win-by-proxy hole). Legendaries and Veilshard are `bound:'account'` — never tradeable.

All co-op resolution is seed-driven: a fixture spins N bot clients with fixed `playerId`s through one `runSeed` and asserts each gets its own reproducible loot and identical completion rewards (5.18).

---

### 5.12 Gear upgrading — forge, merchant ops & sinks

Two upgrade venues. **Forge lives at Camp** and consumes **materials** (this section supplies them; § Camp owns the forge UI/screen). **Merchant** offers gold-priced services when in town.

**Forge operations** (extends the existing `craft(kind)`; existing generic sinks preserved):

| Op | Cost | Effect | Cap |
| --- | --- | --- | --- |
| **Sharpen** (existing `atk`) | 8 salvage | `bonusAtk +1` | soft — cost scales |
| **Fortify** (existing `hp`) | 10 salvage | `bonusHp +6` | soft |
| **Brew** (existing `potion`) | 5 salvage | `potions +1` | — |
| **Temper** *(§5-new)* | `TEMPER_COST(up)= 6 + up*6` salvage `+ up` essence | item `up += 1`, +8% power/level | `up ≤ TEMPER_CAP[rarity]` = `[2,3,4,5,5]` |
| **Reforge** *(§5-new)* | 12 salvage + 1 matching essence | re-roll all `affixes` (new `seed`) | rarity ≥1 |
| **Enchant** *(§5-new)* | 2 essence of a type | add an elemental `fx`/`edmg` affix | one elemental line |
| **Ascend** *(§5-new)* | 1 **Veilshard** + 15 salvage + a same-slot item to consume | `rarity += 1`, roll the new affix slot | up to `rarity 3` (4 is drop-only) |

Temper cost escalates so it's a *sink*, not a treadmill; Ascend is the rare-currency sink that makes Veilshard meaningful. **Repair/durability is intentionally OUT** — the `RIFT-BRIEF` warns against punitive systems and repair-as-gold-sink smells like the WU energy gate; gear doesn't degrade.

**Merchant services** (gold, 5.15): **Identify** an unidentified drop (reveals hidden affixes/curse), **Buy** consumables/materials, **Sell** gear, **Cursed bargain** (buy a discounted cursed item sight-unseen). Apprentice **Broker** spec improves prices; **Arcanist** identifies for free.

**Sink ledger** (so faucets have drains — 5.16): salvage → forge temper/reforge/enchant + Camp bastion + crafting jobs; essence → reforge/enchant/temper; Veilshard → Ascend + legendary recipes; gold → merchant goods, identify, potion restock, relic-slot unlock, apprentice gear (future).

---

### 5.13 Inventory — capacity, stacking, materials bag

Three containers on the `Hero`:

1. **`bag[]` — gear** (existing). Non-stacking (every gear item is unique: `id`+affixes). Capacity `BAG_CAP` (default **40**). This is the `MONETIZATION` "proven workhorse" lever: **free space is comfortable, paid space is for hoarders** — the default 40 must not pinch a normal player; storage upgrades (an in-game/season reward, never pay-to-win) raise it. At cap, a new drop triggers a **non-destructive prompt** — auto-offer to sell for gold or salvage on the spot (kid-friendly: *never silently lose loot*; the apprentice quips *"boss, I'm out of hands — sell it or drop it?"*).
2. **`consumables{}` — stackable** *(§5-new; generalizes the scalar `potions`)*. `{potion: n, antidote: n, lure: n, whistle: 1, …}`, each stack ≤ `STACK_MAX(99)`. `potions` remains a live alias for `consumables.potion` for back-compat with §4's potion action.
3. **`materials{}` — the materials pouch** *(§5-new; generalizes the scalar `mats`)*. Typed stacks, **not counted against `BAG_CAP`** (materials never cause inventory pressure — that pressure is a *gear* monetization lever, and gating crafting mats would be punitive). `{salvage, ember, rime, storm, venom, iron, veilshard}`.

**Migration** (old saves have scalar `mats`, `potions`): `materials = {salvage: oldMats}`, `consumables = {potion: oldPotions}`. All existing reads (`h.mats`, `h.potions`) are shimmed to `materials.salvage` / `consumables.potion` so no §-Camp/§4 code breaks in the same commit.

---

### 5.14 Currencies & materials taxonomy (earn/spend map)

Six resource types. **Meta currencies (EP/DP) never gate baseline play** (`RIFT-BRIEF` law) — they buy *optional* power/prep.

| Resource | Icon | Kind | Earned by | Spent on |
| --- | --- | --- | --- | --- |
| **Gold** | 💰 | soft currency | kills, sells, quests, trinket crafting, away-report | merchant buys, identify, potion restock, relic-slot unlock |
| **Salvage** | 🔩 | common material | every kill (`1+tier`), away-time trickle, dismantling gear | forge (sharpen/fortify/brew/temper/reforge), Camp bastion, crafting jobs |
| **Essence** (ember/rime/storm/venom/iron) | ✨ | typed material | elemental-affinity kills, matching-realm breaches | reforge, enchant, temper (elemental gear) |
| **Veilshard** | 🔷 | rare material | elites/bosses, T5 overdepth, sealed-tear bonus | **Ascend** rarity, legendary recipes (`bound:'account'`) |
| **Endurance (EP)** | 🥾 | meta (walking) | real-world movement (`10 m = 1 EP`, daily-capped, effort-banded) | `train{acc,dodge,power,vigor}` ability ranks (5.4) |
| **Downtime (DP)** | ⏳ | meta (rest) | sleep/rest, away-time settle | Camp: bastion tiers, away-time crafting jobs (§ Camp) |

Faucets (kills, walking, resting, away-time) and sinks (forge, merchant, Camp, ascension) are enumerated so 5.16's balance sim can prove no resource is a dead-end hoard or a starvation gate.

---

### 5.15 Merchant economy

**Formulas** (extends existing `SELL_RATE=0.5`, `sellPrice`, `buyItem`, `rollMerchantStock`):

- **Buy** = `item.value` (5.9). **Negotiate** (apprentice Broker rank `b`): `value·(1 − 0.03·b)`, floored at `0.7·value`.
- **Sell** = `max(1, floor(item.value · SELL_RATE))`, `SELL_RATE=0.5` (existing). Cursed/unidentified gear sells at `0.35`.
- **Identify** = `IDENTIFY_COST = 5 + 4·rarity` gold (free with Arcanist apprentice).
- **Potion restock** = `POTION_PRICE = 20` gold (existing).

**Stock roll** (deterministic per appearance): 5 slots (existing), seed = `hash(day, playerId, merchantId)`, biased to player `level`/`cls` and the merchant's specialty table. `rollMerchantStock` already filters by class/tier; extend to weight by the visiting merchant's inventory bias below. Fresh stock each appearance; ~55% spawn chance per scout (existing `maybeSpawnMerchant`).

**Wandering-merchant fiction & tone** (`RIFT-BRIEF` + `NORTH-STAR` QfG register — *snark lives in characters, not UI*). The whistle opens a pocket stall (`RIFT-BRIEF`); the roster rotates among named border-walkers, each a stock-bias + a voice, so shopping is an *encounter*, not a grid:

| Merchant | Stock bias | Register (one line) |
| --- | --- | --- |
| **Grimble & Sons** | general gear, honest prices | *"My sons picked these. …I don't have sons. Buy the sword."* |
| **Mott, the Rat-Cartographer** | map marks, rift rumors, cheap trinkets | *"This map's mostly true. The lying bits are clearly labelled. Mostly."* |
| **Saint Candle** | potions, wards, remove-curse | *"I remember every time you died here. Here — take two draughts."* |
| **The Three-Faced Pawnbroker** | cursed bargains, high-rarity, monster teeth | *"Cursed? 'Cursed' is such a strong word. 'Motivated' gear, I'd say."* |

Cursed bargains are the Pawnbroker's push-your-luck loot (5.7). **No real money anywhere** — every price is in-game gold (task scope; `MONETIZATION` real-money is a separate, later, non-power spine).

---

### 5.16 Economy balance — faucets vs sinks

Design intent, verified by the sim (5.18): at every stage a player should be *mildly* material-constrained (choices matter) but never gold-starved out of baseline play. Rough per-hour targets at mid-game (L8, T2–T3):

| Faucet | ≈ per hour | Sink | ≈ per hour |
| --- | --- | --- | --- |
| Gold (kills+sells+quests) | 400–700 | Merchant goods + identify + restock | 300–600 |
| Salvage | 60–100 | Forge temper/reforge | 50–90 |
| Essence | 6–12 | Enchant/reforge elemental | 4–10 |
| Veilshard | 0.5–2 | Ascend (1/ascension) | 0.5–1 |

Net gold trends slightly positive (players save toward the occasional big buy / relic-slot unlock) — a deliberate small surplus, not runaway inflation. The sim's job is to keep the **positive-but-bounded** shape as content scales.

---

### 5.17 CONSTANTS — single tunables block

One object; the balance simulator imports this and nothing else. Everything above references these names.

```js
const BALANCE = {
  // --- progression ---
  XP_BASE: 20, XP_GROWTH: 1.45,
  HP_PER_LVL: 8, DEF_PER_2LVL: 1,
  CLASS: { ranger:{hp:30,def:2,engage:40,atkGrow:1},
           knight:{hp:38,def:3,engage:20,atkGrow:2} },
  WEAPON_BASE: { ranged:5, melee_knight:6, melee_ranger:2 },
  OFFCLASS_ACC: -0.32, LVL_ACC_CAP: 0.06, LVL_ACC_PER: 0.012,

  // --- EP training ---
  TRAIN_MAX: 5, TRAIN_COST: r => (r+1)*20,          // 20/40/60/80/100
  ACC_PER_RANK: 0.02, DODGE_PER_RANK: 0.02, POWER_PER_RANK: 1, VIGOR_HP: 5,
  METERS_PER_EP: 10,

  // --- item power / value ---
  W_ATK:1.6, W_DEF:2.2, W_HP:0.5, W_DODGE:1.4, FX_POWER:8, TIER_POWER:3, UP_POWER:0.08,
  GOLD_PER_POWER:1.8, CAT_VALUE:{weapon:1.0,armor:0.9,trinket:1.2}, CURSE_VALUE:0.7,

  // --- rarity ---
  RARITY_POWER:      [1.00,1.15,1.35,1.60,1.90],
  RARITY_AFFIX_COUNT:[0,1,2,3,3],
  AFFIX_TIER_WEIGHTS:{0:[], 1:[[1,1]], 2:[[1,2],[2,1]], 3:[[1,1],[2,2],[3,1]], 4:[[2,1],[3,2]]},

  // --- loot ---
  RARITY_ODDS: {                                    // by breach tier, gear roll only
    1:[78,18,3.5,0.5,0], 2:[62,28,8,1.7,0.3], 3:[45,33,16,5,1],
    4:[30,34,24,9,3],    5:[18,32,28,15,7] },
  GEAR_CHANCE_BASE:0.18, GEAR_CHANCE_ELITE:0.55, GEAR_CHANCE_BOSS:1.0,
  ESSENCE_CHANCE:0.20, VEILSHARD:{elite:0.10, boss:0.75, overdepth:0.05},
  GOLD_TIER_MULT: t => 1 + 0.25*(t-1), XP_TIER_MULT: t => 1 + 0.35*(t-1),
  MATS_PER_KILL: t => 1 + t,
  DEPTH_RARITY_STEP:0.5, DEPTH_GOLD:0.15,           // per depth level
  SNAP_BASE:0.15, SNAP_STEP:0.12, CHEST_TIER_BONUS:1, PRY_MF_STEP:0.25,

  // --- forge ---
  TEMPER_COST: up => ({salvage:6+up*6, essence:up}),
  TEMPER_CAP: [2,3,4,5,5], REFORGE_COST:{salvage:12,essence:1},
  ENCHANT_COST:{essence:2}, ASCEND_COST:{veilshard:1,salvage:15,consume:1},
  FORGE_ATK:{salvage:8,d:1}, FORGE_HP:{salvage:10,d:6}, FORGE_POTION:{salvage:5,d:1},

  // --- inventory ---
  BAG_CAP:40, STACK_MAX:99,

  // --- merchant / co-op ---
  SELL_RATE:0.5, SELL_RATE_CURSED:0.35, IDENTIFY_COST: r => 5+4*r,
  POTION_PRICE:20, NEGOTIATE_PER_RANK:0.03, NEGOTIATE_FLOOR:0.7,
  MERCHANT_SPAWN:0.55, STOCK_SLOTS:5,
  TRADE_WINDOW_MIN:10,

  // --- Camp cross-refs (owned by §Camp, listed for the sim) ---
  BASTION_COST: t => (t+1)*8, BASTION_MAX:3,
  CRAFT: { potions:{mins:10,dp:2,salvage:4}, gear:{mins:30,dp:4,salvage:10},
           trinkets:{mins:20,dp:3,salvage:6} },
};
```

---

### 5.18 Headless fixtures & bot hooks

Every system above is exercised without a human, seed-first. Server-authoritative means all of these run server-side and the client only mirrors.

**Protocol messages** (extend the contract envelope; payloads are §5-specific):
- `KillResolved{ enemyId, breachTier, depth, seed } → LootGranted{ gold, materials{}, items[], currencies{}, unstable:bool }`
- `ChestOpen{ chestId, pryPolicy } → LootGranted{…}` (server drives `pryChest` with the client's policy)
- `EquipReq{ itemId, slot } → InventoryDelta{ equip, bag, bound:'equip' }`
- `ForgeReq{ op:'temper'|'reforge'|'enchant'|'ascend'|'atk'|'hp'|'potion', itemId, spend{} } → ForgeResult{ item, materials{} }`
- `TradeReq{ kind:'buy'|'sell'|'identify'|'negotiate', merchantId, itemId } → TradeResult{ gold, bag, item }`
- `TradeParty{ fromId, toId, itemId } → InventoryDelta` (enforces `TRADE_WINDOW`, `bound` rules)

**Determinism fixtures:**
- `loot_distribution.spec`: run `resolveDrop` over 100k seeds per breach tier; assert observed rarity histogram matches `RARITY_ODDS` within ±0.3%. Regression-guards any drop-table edit.
- `same_seed_same_loot.spec`: identical `(runSeed, playerId, dropIndex)` → byte-identical item (name, affixes, rolls). Client/server parity.
- `coop_instancing.spec`: N bots, one `runSeed`; assert per-player loot differs (own seed), completion rewards identical, and a low-level bot cannot receive an equipped/`bound` item via `TradeParty`.
- `economy_balance.spec`: a bot plays a scripted L1→L15 arc; assert gold stays positive-bounded, no material hits zero-then-blocks-baseline, every sink is reachable, no negative-currency state ever (`assert all resources ≥ 0` invariant after every message).
- `pry_ev.spec`: sweep `stopAtPry ∈ [0..maxPry]`; assert EV curve is single-peaked (there's a real optimal stop) so the push-your-luck decision is genuine, not dominated.
- `power_monotonic.spec`: for each base item, `itemPower` strictly increases with rarity and `up`; upgrade-arrows never lie.

**Bot policy hooks** (deterministic decision fns injected in place of human choice): `pryPolicy(chest)→stop|continue`, `extractPolicy(depth,loot)→extract|push`, `shopPolicy(stock,gold)→buys[]`, `forgePolicy(bag,materials)→ops[]`, `trainPolicy(ep,train)→line`. Each is a pure fn of state, so a fixture pins a strategy and replays it identically across runs — the whole progression/economy loop is machine-checkable end to end.

---

**Cross-references.** §4 Combat consumes the stats this section sets (`atkOf`, `heroDef`, `dodgeBonus`, `hitChance`, affix `crit`/`acc`/`edmg`, `fx`/`curse` proc keys) and owns the Breach!/Focus effects the L4–L5 ladder unlocks. § Camp owns the forge/bastion/crafting *screens* and the DP economy; this section supplies the materials (`salvage`, `essence`, `veilshard`) those sinks consume and defines their earn rates. §8 owns rarity glow, slot icons, and the chest-prop frames referenced in 5.7/5.10.

The FOUNDATION CONTRACT text wasn't inlined in my prompt (it's the shared spec other agents in this workflow are co-writing). I've grounded my section in the repo's established fiction (DESIGN.md veil/Breach/Warden/Camp, the `TIER_PREFIX` Elder→Massive ladder, `metersToLatLng`/`haversine`/`makeRng` in the prototype sim) and I declare every contract field I depend on up top so it stays consistent with the Combat and Camp sections. Here is the section.

---

## 6. World, Procgen, Geo & Breaches

> Domain owner: **WORLD / PROCGEN / GEO / BREACHES.** This section defines the coordinate system, the deterministic procedural world, the Breach lifecycle, and the GPS tolerance layer. It is written to be exercised entirely by **headless, seed-driven fixtures** — no human, no live GPS, no map render required to assert correctness.

### 6.0 Contract references (fields this section relies on, owned elsewhere)

To avoid redefining shared state, this section reads/writes the following contract entities by field. Where a field is **owned here**, it is marked `[W]`.

| Entity | Fields consumed | Fields owned here |
|---|---|---|
| `Player` | `player.id`, `player.shardId` | `player.origin {lat,lng}` `[W]`, `player.anchor {lat,lng}` `[W]`, `player.fix` (see §6.7) `[W]` |
| `Shard` (§ World-state / server) | `shard.id`, `shard.worldSeed` (uint32), `shard.genesisT` (epoch ms), `shard.convergence` (see §6.5) | `shard.convergence.C` scalar `[W]` |
| `Breach` `[W]` | — | full schema, §6.4 |
| `WorldPOI` `[W]` | — | full schema, §6.6 |
| `Enemy` / garrison (§ Combat) | `Enemy` schema, `mkEnemy(key,tier,groupSize,isMain)`, `groupSize(tier)`, `ENEMY_ORDER`, `TIER_PREFIX = {1:'',2:'Elder',3:'Giant',4:'Massive'}` | `breach.garrison` binding, §6.4.3 |
| `Camp` (§ Camp) | `camp.pos {lat,lng}`, `camp.claim` | camp registers a permanent fog **claim**, §6.5 |

Protocol messages this section defines (all others referenced by name): `world.snapshot`, `breach.state`, `breach.seal`, `geo.fix`, `world.tick`. Envelope, auth, and transport are the server section's; payloads are below.

Terminology reconciliation with the fiction (DESIGN.md): a **Breach** is a tear in the veil — the world object players fight at. "Rift"/"tear" are flavor synonyms; **The Breach** (capital, faction) is the antagonist. Breach **size tiers** reuse Combat's `TIER_PREFIX` ladder verbatim: T1 *Fracture* (no prefix) → T2 *Elder* → T3 *Giant* → T4 *Massive*. A Massive breach is "a rift near collapse."

---

### 6.1 Geo math — lat/lng ↔ local meters

The world uses **two coordinate frames**, and keeping them separate is the whole trick:

1. **Global angular frame** — raw WGS84 `(lat, lng)` in degrees. **All procgen keys off this frame** so the world is identical for every player on Earth with zero shared anchor negotiation (§6.3).
2. **Local ENU meters** — an East/North tangent plane around a per-player **origin**, used only for rendering, distance, and interaction (§6.7). Origin choice never affects what the world *contains*, only how it's drawn.

#### 6.1.1 Equirectangular projection with cos(lat) correction

Given origin `O = (lat0, lng0)` and a point `P = (lat, lng)`, both in degrees, with `R = 6_378_137 m` (WGS84 equatorial radius — the same constant the prototype's `metersToLatLng` already uses):

```
DEG = π / 180
east  (x, m) = R · (lng − lng0)·DEG · cos(lat0)
north (y, m) = R · (lat − lat0)·DEG
```

Inverse (`x` east, `y` north metres → degrees):

```
lat = lat0 + (y / R)·(180/π)
lng = lng0 + (x / (R·cos(lat0)))·(180/π)
```

The correction factor `cos(lat0)` is evaluated **once at the origin**, not per point. That is the equirectangular simplification: it treats the play area as a flat tangent plane whose east scale is frozen at the origin's parallel.

Distance between two nearby points is Euclidean in the local frame:

```
dist(P1, P2) = hypot(east(P1)−east(P2), north(P1)−north(P2))
```

For fixture cross-checks against a "true" great-circle distance, keep the prototype's `haversine(a1,o1,a2,o2)` (R = 6_371_000 mean radius) as the reference oracle.

#### 6.1.2 Why the simplification is safe here — error budget

Freezing `cos(lat0)` introduces east-scale error that grows with north-distance `Δlat` from the origin. Fractional east error ≈ `1 − cos(lat)/cos(lat0) ≈ tan(lat0)·(Δlat in rad)`. Over the play radius (§6.2, ~227 m ⇒ Δlat ≤ 0.00204°= 3.6e-5 rad) at a temperate `lat0 = 45°` (`tan = 1.0`):

```
max fractional east error ≈ 1.0 × 3.6e-5 = 3.6e-5
absolute error at 227 m   ≈ 227 m × 3.6e-5 ≈ 8 mm
```

**Sub-centimetre across the entire 40-acre bubble.** Interaction radii are tens of metres; the projection is effectively exact. (Beyond ~2 km the error reaches metres — irrelevant, because rendering re-origins per player and the play bubble is small.) Fixtures assert this: §6.8 `assertGeoRoundTrip`.

#### 6.1.3 World bounds

- **Play bubble** (what a client renders / simulates at once): a **circle of radius `PLAY_R = 227 m`** around `player.anchor` ≈ **40 acres** (`π·227² = 161 874 m² = 40.00 ac`). Equivalently a `402 m × 402 m` square (`SNAPSHOT_HALF = 226 m`). Snapshots (§6.4.4) are requested for the bounding box of this bubble.
- **Interaction ceiling**: `ENGAGE_FAR = 150 m` (§6.7) — nothing outside `PLAY_R` is ever interactable, so `PLAY_R > ENGAGE_FAR + halo` by design.
- **Global bounds**: the angular frame is valid `lat ∈ (−85°, 85°)` (excludes poles where `cos(lat)→0` and the lng grid degenerates). Playtest regions are mid-latitude; the exclusion is a guard, not a limit.

#### 6.1.4 Setting the origin — config vs first fix

`player.origin` is set once per session and then **frozen** (re-origining mid-session would jump every rendered position):

- **Live play**: origin = **first accepted GPS fix** (§6.7 acceptance gate). Persisted as `player.origin` so a returning player re-anchors to the same plane. `player.anchor` then tracks the smoothed live position; `origin` stays put.
- **Fixtures / bots**: origin = **config** (`fixture.origin`), deterministic, no GPS needed. The scripted track (§6.8) supplies `anchor` updates directly.
- **Couch mode** (NORTH-STAR "walking accelerates, never gates"): origin = `player.camp.pos` if no fix is available. The player can still see and play their camp's neighbourhood.

Origin is a **rendering/interaction** anchor only. It is **never** an input to procgen — swapping origins must not change one tile of terrain or one breach id. §6.8 `assertOriginIndependence` enforces this.

---

### 6.2 The play bubble & tiling hierarchy

Everything procedural is a hash of an **integer global cell index**. Cells are defined by *tiles-per-degree* (TPD) constants — powers of two so index math is a shift and hashing is clean. A cell index is derived directly from raw lat/lng:

```
cellX(lng, TPD) = floor(lng · TPD)      // global, signed integer
cellY(lat, TPD) = floor(lat · TPD)
```

Because the index comes straight from absolute degrees, **two players standing in the same place compute the same cell**, with no shared origin, no negotiation, no server round-trip.

| Layer | Const (TPD, /°) | Cell size N/S | Role |
|---|---|---|---|
| **Terrain tile** | `TPD_T = 32768` (2¹⁵) | 3.40 m | tint bucket, micro-props, fantasy dressing |
| **Biome cell** | `TPD_BIOME = 256` | 435 m | procgen biome fallback, blended with OSM tags |
| **Breach cell** | `TPD_BREACH = 1024` (2¹⁰) | 108.7 m | one candidate breach per cell (§6.4) |
| **Service POI cell** | `TPD_POI = 128` | 870 m | merchant / haven / shrine lattice (§6.6) |

Cell size N/S is constant (`(1/TPD)·111 320 m`); E/W is `× cos(lat)` (e.g. ×0.71 at 45°), so cells are slightly non-square away from the equator. This is invisible in a fantasy tint and cheap to reason about; it is the price of a globally-consistent integer grid with no shared anchor. (Alternative equal-area meters-grid around a baked region anchor is documented in §6.9 but not used — it trades global consistency for square cells.)

---

### 6.3 Deterministic procgen — zero per-tile server state

**Invariant:** terrain, tint, props, biome tint, and the *candidate* breach/POI lattice are a **pure function of `(shard.worldSeed, cellIndex)`**. The server stores **nothing** per tile. The client draws the world by hashing the cells in view. Every player in a shard sees the identical forest at the identical park (shared-world ready). Changing `worldSeed` reshuffles the entire world — that is how a season resets.

#### 6.3.1 The hash

A 32-bit integer mix (Wang/murmur-style finalizer). Deterministic across languages (client JS, server, fixtures) because it uses only `uint32` ops:

```
function mix32(h) {            // h: uint32
  h = (h ^ (h >>> 16)) * 0x7feb352d >>> 0
  h = (h ^ (h >>> 15)) * 0x846ca68b >>> 0
  return (h ^ (h >>> 16)) >>> 0
}

function hashCell(worldSeed, layer, cx, cy) {     // → uint32
  let h = worldSeed >>> 0
  h = mix32(h ^ (layer      >>> 0))
  h = mix32(h ^ (cx | 0)    >>> 0)
  h = mix32(h ^ (cy | 0)    >>> 0)
  return h
}
```

`layer` is an enum (`L_TERRAIN=1, L_BIOME=2, L_BREACH=3, L_BREACH_TIER=4, L_POI=5, L_JITTER=6, …`) so different layers over the same cell are independent. The 32-bit word is a **field of independent random bits**: slice low bits for one decision, higher bits for the next. Where a cell needs a *stream* of values, seed the prototype's existing `makeRng(seed)` with the hash: `rng = makeRng(hashCell(...))` — reusing the sim's xorshift keeps client and native identical.

#### 6.3.2 How the client draws a tile (no fetch)

For each terrain tile `(tx, ty)` in view:

```
h    = hashCell(worldSeed, L_TERRAIN, tx, ty)
biome = biomeAt(tx, ty)                       // §6.3.3 (OSM ⊕ procgen)
tint = biome.palette[ h % biome.palette.length ]          // ground tint
if ((h >>> 8) & 0xFFFF) / 0x10000 < biome.propDensity {   // prop roll
  prop  = biome.props[ (h >>> 24) % biome.props.length ]  // which prop
  // sub-tile jitter so props don't snap to a grid:
  jx = ((hashCell(worldSeed, L_JITTER, tx, ty)      ) & 0xFF)/255   // 0..1
  jy = ((hashCell(worldSeed, L_JITTER, tx, ty) >>> 8) & 0xFF)/255
  place(prop, tileCenter + (jx,jy)·tileSize)              // enchanted grove, standing stone, ruin…
}
```

This is exactly the MAP-DATA.md "hybrid layer": OSM supplies geometry, `hashCell` scatters the fantasy dressing (which grove is enchanted, where standing stones sit). Deterministic ⇒ shared world ⇒ zero server state.

#### 6.3.3 Biome & fantasy overlay

`biomeAt(tx,ty)` blends two sources, OSM winning where present:

1. **OSM tag** at the tile (water/park/cemetery/building/path) → hard biome (parchment sea, haunted forest, graveyard, hamlet, dirt trail). This is the game-data gift MAP-DATA.md calls out: water monsters at real rivers, wraiths at real graveyards — and it feeds the **breach biome** and thus the garrison species (§6.4.3).
2. **Procgen fallback** where OSM is thin (rural): `hashCell(worldSeed, L_BIOME, cx_biome, cy_biome) % nBiomes`, smoothed by bilinear blend of the four neighbouring biome-cell hashes so biome edges aren't hard-stepped.

Biome is itself deterministic and server-free; the garrison and breach flavour read `breach.biome = biomeAt(breach cell)`.

---

#### 6.3.4 Rendering: the tileset & the "not a radar" mandate (POC)

**Mandate:** the exploration canvas must read as a **lush top-down overworld**, never a coloured grid / radar. The flat per-tile `tint` in §6.3.2 is only a *fallback*; the POC renders real tiles.

**Tileset (vendored, swappable).** **Kenney "Roguelike/RPG" pack — CC0**, vendored at `assets/tiles/roguelike_sheet_16x16.png` (+ `roguelike_LICENSE.txt`). One 968×526 sheet, **16×16 tiles, 1px margin** (57×31 = 1767 tiles): grass/dirt/water/road terrain, forests, rocks, flowers, fences, buildings, tents + campfire (camp), graveyard, market stall, signposts — everything the world, breaches, POIs, and camp need. CC0 ⇒ no attribution obligation (keep the license file anyway). Source: `https://kenney.nl/assets/roguelike-rpg-pack`. It's bright base art — **colour-graded to Glory veil tones at render** (§8.0) so it reads as *the Other realm*, not a cheerful daytime map. Swappable: a moodier CC0 pack (e.g. 0x72 **µFantasy**) or a detailed set can replace it without touching procgen.

**Deterministic render layers** (all pure functions of `(worldSeed, cell)` — shared world, zero server state; drawn by §8.3):
1. **Base terrain** — `biomeAt` (§6.3.3) → a base tile *index into the sheet* (grass / forest-floor / dirt / water / rock), not a flat colour.
2. **Auto-tiling** — biome **edges** use the sheet's transition tiles via a Wang/blob rule keyed on the 4/8 neighbour biomes, so grass↔water shorelines, path borders, and forest edges are organic. *This is the single biggest "crafted vs radar" lever.*
3. **Water, rivers & paths** — low-frequency / ridged `hashCell` fields carve lakes, streams, and dirt paths → structure and landmarks instead of uniform ground.
4. **Prop scatter** — the §6.3.2 roll places trees (clustered by a density field into real forests), rocks, flowers, ruins, standing stones, plus camp/market props at POIs — sub-tile jittered so nothing snaps to a grid.
5. **Veil pass** — the Glory colour-grade + fog-of-war (§6.5.4) + animated **rift shimmer** at breaches (§8.3): the mood layer that makes it feel magical, not utilitarian.

**Swappable world-source (keeps OSM non-throwaway).** All of the above sits behind one interface — `worldSource.terrainAt(cell)` / `worldSource.decorationAt(cell)`. The POC's source is **procgen** (this section); the *later* in-town source is **OSM + MapLibre** (MAP-DATA) — and the **decoration layer (4) is shared between both**, so the procgen work is the rural/wilderness renderer production needs anyway, not a throwaway. For the POC, `biomeAt` uses the **procgen fallback only** (OSM isn't wired yet — same code path; §6.3.3 step 1 simply returns null).

---

### 6.4 Breach system

Breaches are the map's marked destinations — the "Gym tier" of RIFT-BRIEF's wild/gym split. A breach spawns monsters (Combat), can be **sealed**, **escalates** if ignored, and when sealed **claims territory** and **clears fog**.

#### 6.4.1 Spawn lattice — density & spacing across 40 acres

**One candidate breach per breach-cell** (`TPD_BREACH = 1024`, cell ≈ 108.7 m N/S). A cell hosts a breach iff a seeded roll clears `BREACH_SPAWN_P`:

```
function breachCandidate(worldSeed, cx, cy) {
  const h = hashCell(worldSeed, L_BREACH, cx, cy)
  if ((h & 0xFFFF)/0x10000 >= BREACH_SPAWN_P) return null      // empty cell
  // jitter position inside the cell so breaches aren't grid-aligned:
  const jx = ((h >>> 16) & 0xFF)/255, jy = ((h >>> 24) & 0xFF)/255
  const lat = (cy + jy)/TPD_BREACH,  lng = (cx + jx)/TPD_BREACH
  const id  = breachId(worldSeed, cx, cy)                       // stable, §6.4.2
  const tierBase = weightedTier(hashCell(worldSeed, L_BREACH_TIER, cx, cy))
  return { id, cx, cy, lat, lng, tierBase, biome: biomeAt(lat,lng), seed: h }
}
```

Density arithmetic (target **8–12 visible breaches**, the count that reads as "there's always somewhere to go" without clutter):

```
cell area  ≈ 108.7 m × 108.7·cos(45°) m ≈ 108.7 × 76.9 ≈ 8 359 m²
cells in 40-acre bubble ≈ 161 874 / 8 359 ≈ 19.4
BREACH_SPAWN_P = 0.55  ⇒  ~10.7 candidate breaches in view      ✅
```

**Minimum spacing** (Poisson-disk feel, deterministic): after generating candidates for the view + a one-cell margin, drop any breach that lies within `MIN_SEP = 55 m` of another, keeping the one with the **lower `id`** (stable tie-break). Because every client runs the same rejection over the same candidates, they agree without coordination. This guarantees walkable separation while `SPAWN_P` controls raw density.

#### 6.4.2 Deterministic seeds vs server-managed persistent spawns

This is the crux of "zero server state" for a *stateful* object:

- **The candidate lattice is 100% deterministic** — id, position, base tier, biome, garrison seed all come from `hashCell`. An **untouched** breach has **no server row**; its live state is *implied* by the deterministic default plus the world clock (§6.5). The server persists a breach **only once a player touches it** (deals seal damage, or it escalates past a threshold). Stored state is a **delta** over the deterministic default:

```
breachId(worldSeed, cx, cy) = "b_" + hashCell(worldSeed, L_BREACH, cx, cy).toString(36)
```

- **Escalation children are server-managed persistent spawns** (§6.5.3): when an ignored breach *spreads*, the child depends on the *history* of that branch (did the parent get sealed? when?) — not derivable from seed alone — so it gets a real server row with `parentId` and `spawnT`. These are the **only** breaches that exist off-lattice.

So: base world = deterministic & free; consequences of play = a small persisted delta set. `assertPersistenceMinimal` (§6.8) asserts `store.rowCount == touchedBreachCount`.

#### 6.4.3 Breach schema & garrison (→ Combat)

```
Breach {
  id: string                 // stable, §6.4.2
  lat, lng: number           // deterministic position
  cx, cy: int                // breach cell
  biome: BiomeId             // → garrison species table
  tierBase: 1..4             // Fracture/Elder/Giant/Massive, from weightedTier
  seed: uint32               // garrison RNG seed = hashCell(...,L_BREACH,...)
  // ---- dynamic (server delta; default-derived if absent) ----
  state: 'open'|'sealing'|'sealed'|'dormant'   // default 'open'
  escalation: 0..E_MAX       // default derived from clock, §6.5
  veilHP: number             // current seal HP, §6.4.5
  sealedBy?: playerId, lastSealT?: epochMs, spawnT?: epochMs (children only)
  parentId?: string          // escalation child only
}
```

`weightedTier(h)` — base tier distribution (escalation raises it later, §6.5.1):

```
r = (h & 0xFFFF)/0x10000
r < 0.55 → 1 (Fracture)   r < 0.83 → 2 (Elder)
r < 0.96 → 3 (Giant)      else     → 4 (Massive)
```

**Garrison generation (owned by Combat, seeded here):** when a player engages, build the monster group deterministically from the breach seed + effective tier so every player fights the same garrison:

```
tierEff = effectiveTier(breach)                         // §6.5.1
rng     = makeRng(breach.seed ^ (tierEff * 0x9E37))
count   = groupSize(tierEff)                             // Combat
mainKey = pickSpeciesForBiome(breach.biome, rng)         // biome→species table
garrison = [ mkEnemy(mainKey, tierEff, count, true),
             ...for i in 1..count-1:
               mkEnemy(ENEMY_ORDER[rint(0, tierEff-1)], tierEff, count, false) ]
```

`mkEnemy`, `groupSize`, `ENEMY_ORDER`, `TIER_PREFIX` are Combat's. The main enemy's on-screen name is `TIER_PREFIX[tierEff] + species` (e.g. "Massive Bone Knight"). Biome→species is where OSM pays off: graveyard biome → undead table, water biome → drowned table.

#### 6.4.4 `world.snapshot` — the only breach read

```
→ world.snapshot { shardId, bbox:{minLat,minLng,maxLat,maxLng}, sinceT? }
← world.snapshot.ok {
    worldSeed,                              // client verifies its cached seed
    convergenceC,                           // §6.5 global escalation offset
    breachDeltas: [ {id, state, escalation, veilHP, sealedBy, lastSealT} ],  // touched only
    children:     [ Breach ],               // escalation-spawned, full rows
    clock: serverT
  }
```

The client generates the **candidate lattice locally** from `worldSeed + bbox`, then applies `breachDeltas` over it and appends `children`. The payload carries only what deviates from determinism — typically a handful of rows even in a busy neighbourhood. `sinceT` enables incremental deltas.

#### 6.4.5 Breach HP & the seal mechanic

A breach's resistance to sealing is `veilHP`. Default (unpersisted) value:

```
SEAL_BASE = 20
veilHP0(breach) = SEAL_BASE · tierEff · (1 + 0.35 · escalation)
   // T1 e0 = 20 ; Elder(T2) e0 = 40 ; Massive(T4) e2 ≈ 136
```

**Sealing** happens *through combat* (RIFT-BRIEF: "melee = faster sealing"). Every point of damage the player lands on the garrison also chips `veilHP`, scaled by engagement style (ties directly to Combat's range roles and the safety design):

```
sealChip(dmg, band) = dmg · SEAL_MUL[band]
SEAL_MUL = { close: 1.5, mid: 1.0, far: 0.6 }     // melee seals fastest; ranged is the safe, slower path
```

`state` transitions: `open → sealing` on first chip; `sealing → sealed` when the garrison is defeated **and** `veilHP ≤ 0`. Reaching `veilHP ≤ 0` with monsters still alive holds at `sealing` (you must clear the tear). This makes **melee at close range genuinely faster to seal** without making ranged invalid — exactly the RIFT-BRIEF balance guardrail. Sealing is server-validated (`breach.seal`), because the shared world must agree who sealed what.

```
→ breach.seal { breachId, finalVeilHP:0, garrisonCleared:true, band, runToken }
← breach.seal.ok { breachId, state:'sealed', sealedBy, lastSealT, claim: {…} }   // §6.5
← breach.seal.reject { reason:'garrison-alive'|'veilHP-remaining'|'stale-run' }
```

**Harvest vs Seal vs Stabilize** (RIFT-BRIEF rift outcomes) map onto `breach.seal` variants: harvest = defeat garrison but leave `state:'open'` (loot, but the breach keeps escalating and darkening); stabilize = `state:'dormant'` with a longer reopen timer and a social-portal flag. Seal is the world-improving choice.

---

### 6.5 Respawn, escalation & convergence pressure

Ignored breaches get worse — the diegetic convergence clock (DESIGN.md) that grows world-state without hand-built live-ops.

#### 6.5.1 Escalation over time

Escalation is a **deterministic function of the clock**, so client and server compute the same value from persisted timestamps — no per-tick server writes:

```
ESC_PERIOD = 6 h,  E_MAX = 5
t_ref(breach) = breach.lastSealT ?? breach.spawnT ?? shard.genesisT
escalation(breach, now) = min( E_MAX,
    floor( (now − t_ref) / ESC_PERIOD ) + shard.convergence.C )
effectiveTier(breach)   = min( 4, breach.tierBase + floor(escalation/2) )
```

- `shard.convergence.C` is the **global** convergence offset — a shared world-state scalar (server-owned, slow) that raises *everyone's* baseline escalation as the season progresses. This is the shared-vs-local decision DESIGN.md flags, resolved as **shared** (matches NORTH-STAR "shared, persistent world is core").
- Each `+1` escalation adds garrison depth (via `effectiveTier` and `groupSize`), raises `veilHP0`, and widens the fog/darken radius (§6.5.4).

Because escalation is a pure function, the client predicts it perfectly while offline/dead-zone (NORTH-STAR courtesy) and reconciles trivially on reconnect. `assertEscalationFormula` (§6.8) asserts client == server at boundary ticks.

#### 6.5.2 Respawn (sealed breaches don't stay dead)

A sealed breach keeps the world from going quiet:

```
RESPAWN_COOLDOWN = 24 h
reopenT(breach) = breach.lastSealT + RESPAWN_COOLDOWN
```

`sealed → dormant → open`: on seal it's `sealed` (fully claimed, fog cleared). After `RESPAWN_COOLDOWN` it flips to `open` with `t_ref` reset, escalation 0 — a fresh tear at the same place. This is a **deterministic** transition (no server row change needed beyond the existing `lastSealT`), so it self-heals into the lattice.

#### 6.5.3 Spread (the persistent-spawn exception)

At `escalation ≥ 3` a breach **spreads** — RIFT-BRIEF's rifts "multiply, then link and merge." It seeds a child into an empty neighbouring breach-cell:

```
if escalation(b, now) ≥ 3 and not b.hasSpawnedChild:
  neighbours = 8 breach-cells around (b.cx,b.cy) with no candidate
  pick = neighbours[ hashCell(worldSeed, L_BREACH, b.cx, b.cy) % neighbours.length ]
  child = new Breach { parentId:b.id, spawnT:now, tierBase:b.tierBase, cx,cy:pick, … }
  persist(child); persist(b.hasSpawnedChild = true)     // server-managed rows
```

Children are persisted because they depend on branch history, not seed. Sealing the parent stops further spread; sealing a child removes it. This is the map-visible "convergence" — clusters of breaches blooming around an ignored one.

#### 6.5.4 Territory claim & fog of war

The veil's darkness *is* the fog. Fog at a tile is a **deterministic function of nearby breach states + claims**, so it's client-computable from the same `breachDeltas` — no fog is ever stored per tile.

```
fog(tile) = clamp01( Σ_breaches darkness(b, tile) − Σ_claims clear(c, tile) )

DARK_RADIUS(e) = 40 + 25·e   metres
darkness(b, tile) = (b.state=='sealed'||'dormant') ? 0
                   : D0 · escalation(b) · falloff(dist(tile,b), DARK_RADIUS(escalation(b)))
CLEAR_RADIUS = 90 m
clear(c, tile) = C0 · falloff(dist(tile,c.pos), CLEAR_RADIUS)
falloff(d, R) = max(0, 1 − d/R)          // linear; D0=0.25, C0=1.0
```

- **Sealing claims territory.** `breach.seal.ok` returns a `claim {breachId, pos, sealedBy, radius:CLEAR_RADIUS}`, persisted alongside the sealed breach. It contributes a `clear` term → the neighbourhood brightens and reads as "yours" (`sealedBy`).
- **Unattended breaches spread & darken.** As `escalation` climbs, `DARK_RADIUS` grows (40→165 m across e0→e5) and `darkness` deepens, so an ignored tear visibly stains its surroundings — the convergence pressure the player *sees*.
- **Camp is a permanent claim.** The Camp section registers `camp.claim` at `camp.pos` (persistent `clear` term), which is why a camp always sits in a bright, safe pocket of the veil (DESIGN.md "a place where the veil is calm; your anchor on this side"). Wake-at-camp (Combat death) sets `player.anchor = camp.pos`.

---

#### 6.5.5 Party-size & regional-density auto-scaling

Challenge tracks **headcount**, so the loop self-balances from solo to a full party with no per-size hand-tuning. Two server-authoritative knobs, both pure functions of their inputs (a fixture sets party size + presence explicitly — no wall-clock):

**Knob 1 — encounter scaling (per engaging party).** `partyN` = living heroes in the `Encounter` (`1..PARTY_MAX`):

```
groupSize(breach, partyN) = clamp( ceil( baseGroup(effectiveTier) · (1 + DENSITY_MOB·(partyN−1)) ), 1, GARRISON_MAX )
tierBump(partyN)          = min( TIER_BUMP_MAX, floor( (partyN−1) / TIER_PER_N ) )
encounterTier             = min( 4, effectiveTier(breach) + tierBump(partyN) )
```

Solo (`partyN=1`) → `baseGroup`, no bump. A duo/trio faces proportionally more monsters (and, past `TIER_PER_N`, meatier ones), so **per-hero** load stays ~flat — a crowd doesn't trivialize the field, a lone player isn't swamped.

**Knob 2 — regional spawn pressure (per density cell).** Region = an `L_DENSITY` cell (~250 m). `presence(cell)` = distinct PCs active in the cell within `DENSITY_WINDOW` (~10 min) — live server runtime state, not long-term persisted:

```
localPressure(cell) = min( P_MAX, DENSITY_ESC · max(0, presence(cell) − 1) )
```

`localPressure` adds to `escalation()` for breaches in the cell and raises the §6.4 spawn-odds gate, so **busy areas surface more and stronger tears to share** (fiction: presence thins the veil). It decays with the window, so an emptied region calms.

**Interaction with territory & stalkers.** A claimed / camp-clear region (§6.5.4) **suppresses** `localPressure` — holding ground is what turns a hot area calm. Stalkers/hunters (§4.5-C) spawn and persist more in high-`localPressure`, unclaimed cells and are **shed by claimed territory** — claiming ground is the counter to being hunted.

**Determinism & test.** `presence`/`partyN` are live inputs, but every derived value is pure. `assertDensityScaling` (§6.8): same seed, `partyN∈{1,4}` → `groupSize`/`encounterTier` follow the formula and **per-hero TTK** stays within the §9.6 band; `presence∈{1,3}` → `localPressure`/spawn-odds scale and decay as specified. Constants live in the tuning namespace (§4.3): `baseGroup, DENSITY_MOB, GARRISON_MAX, TIER_PER_N, TIER_BUMP_MAX, PARTY_MAX, L_DENSITY, DENSITY_WINDOW, DENSITY_ESC, P_MAX`.

---

### 6.6 Fixed visitable locations / POIs

Beyond breaches, the world has stable, revisitable places — placed deterministically so every player finds the merchant and the landmark at the same spot.

- **Landmarks** (enchanted grove, standing stones, ruin, shrine): **snapped to OSM features** where present (MAP-DATA.md), with fantasy identity assigned by hash — `landmarkKind = LANDMARK_TABLE[ hashCell(worldSeed, L_POI, feature.cx, feature.cy) % n ]`. Where OSM is thin, fall back to the procgen `L_POI` lattice at `TPD_POI = 128` (≈870 m) so rural regions still have anchors. Landmarks are visual + occasional quest/clue anchors; they carry **no server state** (pure procgen).
- **Service POIs** (traveling merchant pin, Warden **Hut**/quest-giver, safe haven): one per `TPD_POI` service cell, gated by a seeded roll, snapped to the nearest OSM POI if one exists:

```
service(worldSeed, cx, cy):
  h = hashCell(worldSeed, L_POI, cx, cy)
  if (h & 0xFF)/256 >= 0.45 return null
  kind = ['merchant','haven','shrine','hut'][ (h>>8) % 4 ]
  pos  = nearestOSMPoi(cx,cy) ?? jitteredCenter(cx,cy,h)
  return { id:'poi_'+h.toString(36), kind, pos }
```

The **traveling merchant** (RIFT-BRIEF: summoned via whistle) is *also* a mobile encounter, but its resident world-pin uses this lattice with a time-window schedule (`open` for `MERCH_WINDOW` on a seeded rota) so "there's a merchant at the crossroads today" is shared and deterministic. **Camp** is the player's own POI (`camp.pos`), placed by the Camp section, not the lattice — but it lives in the same geo frame and casts the fog claim above.

`WorldPOI` schema: `{ id, kind, lat, lng, osmRef?, scheduleWindow? }`. Deterministic ⇒ absent from `world.snapshot` except for merchant open/close windows (a tiny delta).

---

### 6.7 GPS canopy tolerance

The play-outside reality: tree canopy, urban canyons, pockets, and cheap phone GPS give jittery, drifting, sometimes-stale fixes. The rule (RIFT-BRIEF, DESIGN.md): **never make the player stand on a pin, never punish a bad fix.** All of this is a filter over the raw fix; the sim downstream sees a clean `player.anchor`.

#### 6.7.1 Fix acceptance & anti-jitter gate

Raw fix `{lat, lng, acc (m), t}` is accepted only if plausible:

```
ACC_MAX     = 60 m     // reject fixes worse than this (too vague to use)
MAX_SPEED   = 12 m/s   // reject teleports faster than a sprint (≈27 mph)
JITTER_DEAD = 3 m      // ignore sub-jitter wobble

accept(fix, prev):
  if fix.acc > ACC_MAX: return REJECT_VAGUE
  d = dist(prev.pos, fix.pos)                       // §6.1 local metres
  dt = (fix.t - prev.t)/1000
  if d / dt > MAX_SPEED and fix.acc < prev.acc·2: return REJECT_JUMP  // GPS spike
  if d < JITTER_DEAD and fix.acc ≈ prev.acc: return HOLD              // dead-band: keep prev anchor
  return ACCEPT
```

#### 6.7.2 Smoothing — One-Euro filter

Accepted fixes feed a **One-Euro filter** (adaptive low-pass: smooth when still, responsive when moving) on `east`/`north` metres, then invert to lat/lng for `player.anchor`:

```
MINCUT = 1.0 Hz, BETA = 0.007, DCUT = 1.0 Hz    // walking-tuned
oneEuro(x, t):
  dx   = (x - xPrev)/dt
  edx  = ema(dx, alpha(DCUT))
  cutoff = MINCUT + BETA·|edx|
  return ema(x, alpha(cutoff))
alpha(fc) = 1/(1 + (1/(2π·fc·dt)))
```

Between accepted fixes (or during a `HOLD`/stale window) the anchor **dead-reckons** briefly from last velocity, capped at `DR_MAX = 2 s`, so the avatar doesn't freeze on every wobble.

#### 6.7.3 Accuracy halo & generous interaction radii

The client renders an **accuracy halo** of radius `min(fix.acc, 40 m)` around the avatar. Interaction is **halo-forgiving**: an object is interactable if it's within the band radius *plus* the current accuracy — you never lose an interaction to GPS vagueness, you only gain reach when the fix is poor.

```
reach(band) = BAND[band] + min(fix.acc, ACC_CAP=30)
BAND (from RIFT-BRIEF proximity bands):
  close (melee, +seal, +loot mods)     0 – 15 m
  mid   (spells, traps, normal reward) 15 – 50 m
  far   (ranged, scout, apprentice)    50 – 150 m     // ENGAGE_FAR
INTERACT (concrete effective radii, halo included):
  breach engage      ≤ 150 m + halo   (far band; seal-speed bonus only inside 15 m)
  merchant / hut     ≤ 40 m  + halo
  camp               ≤ 40 m  + halo
  landmark / clue    ≤ 40 m  + halo
```

So a breach across a busy street (DESIGN.md's rejected-unsafe case) is fought from the far band with ranged/apprentice — never by crossing the road. **Band hysteresis** stops flapping at boundaries: the current band only changes after **2 consecutive** fixes past the boundary ± a `5 m` margin.

#### 6.7.4 Stale / lost fix handling

```
STALE_MS = 8 000    // fix older than this → stale
LOST_MS  = 20 000   // no fix this long → lost

age > STALE_MS:  freeze anchor at last good; widen halo to last acc × 1.5;
                 keep current fight playable from cache (finish + queue result, NORTH-STAR courtesy);
                 suppress *new* breach spawns entering interact range.
age > LOST_MS:   show "reconnecting"; pause new engagements;
                 offer couch-mode fallback (anchor = camp.pos) so play never hard-stops.
recover:         next accepted fix re-seeds the One-Euro filter (no snap-jump: cross-fade over 500 ms).
```

Dead-zone tolerance is a **courtesy, not architecture** (NORTH-STAR): the world stays server-authoritative; the client just degrades gracefully and reconciles on reconnect.

---

### 6.8 Headless harness — seeding a fixture world & asserting determinism + persistence

The entire section is exercised with **no browser, no GPS, no human**. A fixture supplies a seed, an origin, a scripted GPS track, and a scripted clock; bot clients drive it.

```
Fixture {
  worldSeed: 0xC0FFEE,
  origin:    { lat: 45.0000, lng: -93.0000 },     // config origin (§6.1.4)
  genesisT:  1_700_000_000_000,
  track:     [ {t:0, lat, lng, acc:8}, {t:1000, …}, … ],   // scripted fixes
  clock:     StepClock(genesisT),                 // advance()able
}
```

Bot loop: `for fix in track: geo.pushFix(fix); tick(); assert(...)`. Determinism/persistence assertions the harness runs:

1. **`assertProcgenDeterminism`** — two fresh world instances, same `worldSeed`, same bbox ⇒ **byte-equal** `worldSnapshot(seed,bbox)` (terrain tint stream, prop placements, candidate breach ids+positions+tiers, POI lattice). Different seed ⇒ different (guards against a stuck hash).
2. **`assertCrossPlayerIdentity`** — two bots with **different `origin`s** but same `shardId`, overlapping bbox ⇒ identical set of `breachId`s and identical `breach.lat/lng/tierBase` in the overlap. (Origin must not touch procgen.)
3. **`assertOriginIndependence`** — re-run bot A with a shifted origin; assert every breach id/position and every tile hash is unchanged.
4. **`assertGeoRoundTrip`** — for 10⁴ random points in the bubble, `metersToLatLng(latLngToMeters(p)) ≈ p` within `ε = 1e-6°` (~0.1 m); and local `dist` vs `haversine` agree within the §6.1.2 error budget.
5. **`assertPersistenceMinimal`** — bot seals breach `X`; a **new** session (fresh client, same shard) reads `X.state=='sealed'` via `world.snapshot`; **untouched** breaches carry no row (`store.rowCount == touchedCount`). Fog around `X` brightens (claim applied); fog around an ignored high-`e` breach darkens.
6. **`assertEscalationFormula`** — advance `clock` across `ESC_PERIOD` boundaries; assert `escalation`/`effectiveTier`/`veilHP0` follow §6.5.1 exactly, and **client prediction == server value** at each boundary. Advance past `RESPAWN_COOLDOWN`; assert a sealed breach reopens with `e=0`. Force `e≥3`; assert exactly one persisted **child** appears in an empty neighbour cell, deterministically placed.
7. **`assertGarrisonDeterminism`** — same breach engaged by two bots ⇒ identical garrison (species, count, `TIER_PREFIX` name) from `breach.seed` + `effectiveTier`.
8. **`assertGpsTolerance`** — feed a jittery track (±10 m wobble): assert the anchor's path length is ≤ 1.3× the true path (One-Euro is smoothing), the interaction **band does not flap** (hysteresis), a `MAX_SPEED`-violating spike is rejected, and a `>STALE_MS` gap freezes the anchor + keeps a mid-fight run playable + queues its result.

These fixtures are the acceptance gate for this section: procgen is **reproducible**, the geo projection is **lossless at play scale**, breach state is **persistent but minimal**, escalation is **formula-exact and shared**, and the GPS layer is **robust and non-flapping** — all without a human in the loop.

---

### 6.9 Notes & deferred decisions

- **Alternative equal-area grid** (§6.2): a meters-grid keyed to a baked per-region anchor gives square cells but sacrifices anchor-free global consistency. Kept in reserve for a region where non-square tiles ever become visible (they won't in a tinted fantasy skin).
- **Poles**: the angular grid degenerates as `cos(lat)→0`; guarded by the `lat ∈ (−85°,85°)` bound (§6.1.3). Playtest regions are mid-latitude.
- **Season reset** = new `worldSeed` (whole world reshuffles) + `convergence.C` reset — the deterministic design makes a season swap a one-scalar change, no world migration.
- **OSM dependency**: biome quality tracks OSM coverage (MAP-DATA.md caveat). The procgen fallback (`L_BIOME`, `L_POI` lattices) guarantees a non-empty, deterministic world even with zero OSM data — important for rural playtesters and for headless fixtures that run without any tile source.

I have everything I need. The FOUNDATION CONTRACT text wasn't actually inlined in my prompt, but the prototype's `<script>` sim *is* the de-facto contract (field names like `hero.ep/dp/mats/bastion/craft`, `applyAway()`, `S.lastPlay`, `TIER_PREFIX`, `creditWalk`), and DESIGN.md fixes the fiction. I'll conform to those names, hang everything off a party-scoped `bastion`, and cross-reference §5 (items/materials) and §6 (world) by field rather than redefining. Here is Section 7.

---

## 7. Camp / Bastion & Meta-Progression

> **Owns:** the player's anchor in the world (Camp, Bastion), its upgrade ladder, the emplaced **Auto-Turret**, the missions/gathering that feed upgrades, the **downtime / away-progress** resolver, **territory holding** against incursions, and the **shared co-op** rules for all of the above.
>
> **Conformance note.** The literal FOUNDATION CONTRACT block was not delivered in this agent's prompt, so this section conforms to the *de-facto* contract already encoded in `prototype/index.html` (the sim reducers) and adopts its naming: `camelCase`, integer/float fields, `doneAt`-style wall-clock stamps, and the single `applyAway()` settle-point. Everything new here is additive to that model. Fields owned by other sections are **referenced, never redefined** — see the field map in §7.11. Where I name a §5 or §6 field I mark it `§5:` / `§6:` so sibling authors can reconcile.

---

### 7.0 Determinism contract (why every rule below is a pure reducer)

Nothing in this section may read a real clock, `Math.random()`, or device state directly. All of it is exercised **headlessly** by seed-driven fixtures and scripted bot clients. Two injectables make that possible:

```js
// Injected everywhere instead of Date.now() / Math.random().
// The live app passes the system clock + a per-party PRNG; the harness passes
// a virtual clock it can jump and a fixed seed.
const ctx = {
  now:  () => number,          // ms since epoch (virtual in tests)
  rng:  mulberry32(seed),      // seeded PRNG stream (see §7.10)
};
```

**Canonical rule:** every away/turret/downtime outcome is produced by a **pure function of `(priorState, fromTs, toTs, seed, worldSchedule)`**. Same inputs ⇒ byte-identical outputs on server and client, this run and next run. This is what lets §7.10's harness fast-forward the clock a week in milliseconds and assert exact numbers.

---

### 7.1 Two objects, one code path: **Camp** (personal) vs **Bastion** (party)

Decision for this co-op POC — stated once, load-bearing for the rest of the section:

| Object | Scope | Mutability | What it is |
| --- | --- | --- | --- |
| **Camp** | **per-player**, always exists | free to move | Your bedroll. Tier-0 wake point + the origin for solo proximity bands (§ combat). No upgrades, no turrets, no downtime. |
| **Bastion** | **one per party** | placed once, moved on cooldown | The fortress. *All* upgrades, turret slots, downtime/crafting slots, territory, and away-defense hang off it. |

**The simplification that kills the per-player-vs-per-party branch:** a solo player *is a party of one*. There is no `if (solo)` anywhere — every meta system reads `party.bastion`. A lone 13-year-old and his four friends run the identical reducer; the friends just share one `party.bastion` instead of each owning a copy.

This migrates the prototype's `hero.bastion` (integer 0–3) to `party.bastion.tier`. Fiction (DESIGN.md): *Camp = a bedroll where the veil happens to be quiet; Bastion = a fortified anchor you and your friends raise together where the veil is calmest.*

```js
// New shared object. Persisted server-side (NORTH-STAR: fly.io + SQLite).
Party = {
  id: 'p_xxxx',
  members: ['u_a', 'u_b'],       // 1..5 (raid parties later)
  leader: 'u_a',
  bastion: Bastion,              // exactly one, may be null before first placement
  stash: { gold:0, mats:0, veilEssence:0 },   // shared spoils (see §7.9)
};

Bastion = {
  tile: '§6:tileId', latLng:{lat,lng},         // placement (§7.2)
  anchoredAt: 0,                                // ms; move cooldown baseline (§7.3)
  tier: 0,                                      // 0..5 (§7.4)
  progress: { dp:0, mats:0, keystones:{} },     // banked toward next tier (§7.5)
  turrets: [Turret, ...],                       // len ≤ turretSlots(tier) (§7.7)
  crafts:  [CraftSlot|null, ...],               // len = craftSlots(tier) (§7.6)
  defenseCursor: 0,                             // ms resolved-through; idempotency (§7.9)
  territory: { hold:100, incursionSeed:'…' },   // 0..100 hold meter (§7.8)
};

Hero.camp = { tile:'§6:tileId', latLng:{lat,lng} }; // personal, trivial
```

---

### 7.2 Placing the anchor (choosing a real spot; fiction = anchoring where the veil is calm)

Placement is **server-authoritative** and **deterministic**: given a candidate point and the §6 world snapshot, the score is fixed, so a bot fixture placing at the same lat/lng always gets the same accept/reject.

**Candidate = the player's current real position** (snapped to the enclosing `§6:tile`). The player taps *Raise Bastion*; the client sends:

```
C→S  bastion/place { tile, latLng }
S→C  bastion/state { … }            // on accept
S→C  error { code:'PLACE_REJECTED', reason }   // on reject
```

**Acceptance predicate** (all must hold — reuses §6 fields, never re-derives geography):

```js
function canPlace(tile, latLng, world /*§6 snapshot*/) {
  if (world.safety(latLng) !== 'ok')        return reject('unsafe');   // §6 safety flag: private/road/water
  if (world.veilPressure(tile) > 0.6)       return reject('too_torn'); // §6: 0..1; must anchor where veil is CALM
  if (world.nearestRiftM(latLng) < 80)      return reject('too_close_to_rift');
  if (world.nearestBastionM(latLng, notMe) < 120) return reject('claim_overlap'); // other parties' claims
  return accept();
}
```

**Fiction mapping:** you can only raise a Bastion where **`veilPressure` is low** — a calm seam. High-pressure tiles (near rifts, active incursions) reject with *"the veil won't hold an anchor here — it's tearing."* This is the DESIGN.md line "Camp = a place where the veil is calm" turned into a check.

**Deterministic placement score** (used to auto-suggest a spot and to let bots pick without a human):

```
placementScore(tile) =
    (1 - veilPressure)          * 40        // calmer is better
  + biomeAnchorBonus(§6:biome)  * 20        // parks/greens/landmarks anchor well; roads poorly
  + poiAnchorBonus(§6:poiId)    * 15        // a real landmark = a stronger anchor
  - min(1, nearestRiftM/300)    * 15 (inv)  // some proximity to action is good, not too much
```

Bots call `world.bestPlacementWithin(radius, seed)` which returns the top-scoring legal tile — no human judgment, fully reproducible.

---

### 7.3 Moving the anchor (the reanchor ritual)

You'll want to move: the neighborhood's incursions escalated past your hold (§7.8), your friend group's center of gravity shifted, or a better landmark opened up.

- **Cooldown:** `moveCooldownMs = 24h`, measured from `bastion.anchoredAt`. Enforced server-side.
- **Cost:** `moveCost = 15·(tier+1) DP` from `party.stash`-adjacent DP pool + a `§5: veilEssence` sink, so moving is a real decision, not a free teleport.
- **Preserved across a move:** `tier`, `turrets` (they redeploy), `crafts` in flight, `stash`. **Reset on move:** `territory.hold → 100` (fresh ground), `defenseCursor → now` (no retroactive defense on the new tile), `anchoredAt → now`.
- **Permissions (co-op):** move requires the party **leader** or a **majority vote** (§7.9). A single griefing kid can't uproot the shared base.

```
C→S  bastion/move { tile, latLng }
     → same canPlace() predicate + cooldown + cost checks, server-authoritative
```

Fiction: *pulling the anchor-stone and re-driving it — the veil resents being re-seamed, so it costs essence and won't tolerate it more than once a day.*

---

### 7.4 Upgrade tiers & unlocks

Six tiers. Each unlocks capacity (turret slots, craft slots, downtime task slots), scales the passive **trickle multiplier** `T×` (the prototype's `1 + 0.5·bastion`, generalized), and widens **territory hold radius** in world-meters.

| Tier | Name | Turret slots | Craft slots | Downtime tasks | Trickle `T×` | Hold radius | Unlocks |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | Bivouac | 0 | 0 | 0 | 1.0 | — | wake point only |
| 1 | Waystone | 1 | 1 | 1 | 1.2 | 60 m | first turret; basic downtime |
| 2 | Redoubt | 2 | 2 | 2 | 1.5 | 90 m | 2nd craft slot; turret refuel automation |
| 3 | Bastion | 3 | 2 | 3 | 1.9 | 120 m | **Turret Tier-2**; forward picket (1 remote turret) |
| 4 | Citadel | 4 | 3 | 3 | 2.4 | 160 m | **Turret Tier-3**; +essence reserve; incursion resist |
| 5 | Bulwark of the Veil | 5 | 3 | 4 | 3.0 | 200 m | passive tile-seal; raid-anchor (20+ min public incursions) |

**Cost to go from tier `T-1 → T`** (pooled from the whole party):

```
dpCost(T)       = 24 · T²                     //  24, 96, 216, 384, 600  DP
matsCost(T)     = 20 · T                       //  §5: generic mats
keystone(T)     = { id:'§5:keystone_T', qty:1 } // a tier-gated material (drops from tier-T rifts, §5/§6)
missionGate(T)  = MISSIONS[T]                   // one mission must be complete (§7.5)
```

`keystone` + `missionGate` make tiers **content-gated, not just grind-gated** (GENRE-LESSONS law 4: progressive unlock — you can't buy tier 5 on day one; you have to have cleared tier-appropriate rifts).

```
C→S  bastion/upgrade {}
     server checks: party pooled dp ≥ dpCost, mats ≥ matsCost,
                    progress.keystones[T] present, missionGate(T).done
     → tier++, deduct, broadcast bastion/state to all members
```

---

### 7.5 Missions & gathering that feed upgrades

Upgrades are fed by three streams, all of which already exist or extend existing prototype systems:

1. **Downtime Points (`dp`)** — earned by resting/away (§7.6) and by *territory holding* (§7.8). The primary tier currency.
2. **Materials (`§5: mats` + keystones)** — the away trickle, rift loot, and **turret kills** (§7.7) deposit `mats` and `§5: veilEssence`. Keystones drop only from tier-`T` rifts (§6 spawn tables).
3. **Missions** — one authored mission gates each tier. These are the RIFT-BRIEF "downtime tasks / gathering" reframed as camp objectives:

```js
MISSIONS = {
  1: { id:'raise_the_first_stone', need:{ ripSealed:1 },              flavor:'Seal one tear near the anchor.' },
  2: { id:'stock_the_larder',      need:{ mats:60, craftsDone:2 },    flavor:'Gather residue; run the workshop twice.' },
  3: { id:'hold_the_line',         need:{ defenseKills:25 },          flavor:'Let the turret cull 25 breach-things.' },
  4: { id:'break_a_named',         need:{ namedSlain:1 },             flavor:'Put down a Breach lieutenant nearby.' },
  5: { id:'the_convergence',       need:{ raidCleared:1 },            flavor:'Close a merged rift with your party.' },
};
```

`need` counters are plain accumulators on the party ledger, incremented by other sections' events (`ripSealed` from §6 seal outcomes, `defenseKills` from §7.7). Deterministic and trivially assertable in fixtures.

---

### 7.6 Downtime / away-progress (crafting queues + passive trickle)

This extends the prototype's `applyAway()` from one settle-block to a **multi-slot, party-shared, turret-aware** resolver — but keeps the exact same shape (compute a `sum`, apply it, render an authored "while you were away" report).

**Fiction (tome variant, DESIGN.md):** the tome is shut, but *the other realm keeps running* — Warden artisans finish your commissions on their own clock, residue settles on the calm seam, and the turret keeps watch. The report is the tome catching you up when you re-open it.

**7.6.1 Passive trickle** — generalizes the prototype's formula with the tier `T×` multiplier and a per-member share:

```
mats  = min(50,  floor(Δmin))            · T×
dp    = min(30,  floor(Δmin / 2))        · T×
gold  = min(90,  floor(Δmin / 3))        · T×
luckyFind: if Δmin ≥ 5 and rng() < 0.35  → one of {gold purse, potion, veil-washed item}  (unchanged)
```

Trickle is **capped per return** (the prototype's `min(50/30/90, …)`) precisely so AFK isn't a dominant strategy (GENRE-LESSONS: walking accelerates, it never gates — and the inverse, *idling* can't out-earn *playing*).

**7.6.2 Crafting queues** — the prototype's single `hero.craft` becomes `bastion.crafts[]`, length = `craftSlots(tier)`. Each slot is independent, finishes on wall-clock, and yields a **masterwork** roll on collect (unchanged 25%). Jobs are the prototype's `CRAFT_JOBS` (potions/gear/trinkets) plus §5-driven material recipes.

```js
CraftSlot = { jobId, startedAt, doneAt, by:'u_a' };   // `by` = who gets personal output (§7.9)

C→S  craft/enqueue { slot, jobId }   // dp+mats deducted from party pool at enqueue
C→S  craft/collect { slot }          // routes output to `by`; masterwork roll uses seeded rng
```

**7.6.3 The single settle-point.** On any member re-opening the tome:

```
C→S  session/resume {}
S    resolveAway(party, from = bastion.defenseCursor, to = ctx.now(), seed):
        1. collect finished crafts across all slots        (each: job.out + masterwork roll)
        2. run resolveDefense(from → to)                   (§7.7 — turret kills, essence, hold Δ)
        3. apply passive trickle for Δ                     (§7.6.1)
        4. advance bastion.defenseCursor = to              (idempotency, §7.9)
S→C  away/report { crafts[], defense{kills,fuelLeft,holdΔ}, trickle{mats,dp,gold}, lucky }
```

The report struct is the prototype's `sum` object with a `defense` block added — `showAwayReport()` gets one new row: *"Your turret cut down 12 breach-things; the line held."* or *"The turret ran dry at 03:10 — the eastern seam is contested."*

---

### 7.7 The Auto-Turret (emplaced defense) — the centerpiece

An emplaced defense the party builds at a Bastion turret slot. It **auto-fights breach monsters** (§6 spawns) inside the territory, whether or not anyone is watching. Fiction (DESIGN.md): a **warded ballista / sigil-engine** — a Warden war-machine bolted to your anchor, powered by veil-essence, that looses bolts at anything crossing the seam.

**7.7.1 Data model**

```js
Turret = {
  id, slot, kind:'ballista'|'sigil'|'lance', tier:1|2|3,
  damage, dmgType:'phys'|'fire'|'cold'|'shock',   // §5 damage/resist model
  rangeM,          // world-meters (real geography, §6 distance)
  cooldownMs,      // between shots
  cooldownReadyAt, // ms; next allowed shot (persisted so offline math is exact)
  fuel, fuelMax,   // charges; 1 shot = 1 charge; refuel with §5:veilEssence
  targeting:'nearest'|'threat'|'secure',
  dormant:false,   // true when fuel==0
};

TURRET_KINDS = {
  ballista: { tier:1, damage:8,  rangeM:45,  cooldownMs:3000, fuelMax:200, dmgType:'phys'  }, // 20 shots/min
  sigil:    { tier:2, damage:12, rangeM:70,  cooldownMs:2400, fuelMax:300, dmgType:'fire'  }, // 25 shots/min
  lance:    { tier:3, damage:18, rangeM:100, cooldownMs:2000, fuelMax:400, dmgType:'shock' }, // 30 shots/min
};
```

Ranges sit in the § combat proximity bands deliberately: a Tier-1 ballista (45 m) reaches into **Mid** range; a Tier-3 lance (100 m) into **Far**. The turret is a *ranged safety layer that never sleeps* — it covers exactly the band a cautious player fights from.

**7.7.2 Targeting** (deterministic — no ties left to chance):

```js
function pickTarget(turret, monsters /*§6 live/scheduled spawns in-tile*/) {
  const inRange = monsters.filter(m => !m.dead && distM(turret.latLng, m.latLng) <= turret.rangeM);
  if (!inRange.length) return null;
  const key = {
    nearest: m => [ distM(turret, m),  -m.tier,  m.spawnSeq ],  // closest, then biggest, then oldest
    threat:  m => [ -m.tier, distM(turret, m),   m.spawnSeq ],  // biggest first (stop elites)
    secure:  m => [ m.hp,    distM(turret, m),   m.spawnSeq ],  // lowest HP first (guarantee kills)
  }[turret.targeting];
  return inRange.sort(byTuple(key))[0];   // total order ⇒ deterministic
}
```

`spawnSeq` (a monotonic per-tile spawn index from §6) is the final tiebreak so the order is **total** — two identical monsters never resolve randomly.

**7.7.3 Firing & damage** — reuses §5's resist/weakness model exactly as player weapons do:

```js
function fire(turret, target, world) {
  const mult = resistMult(turret.dmgType, target /*§5: resist/weakness*/); // e.g. fire ×1.5 vs undead
  const dealt = Math.max(1, Math.round(turret.damage * mult) - (target.def||0));
  target.hp -= dealt;
  turret.fuel -= 1;
  turret.cooldownReadyAt = ctx.now() + turret.cooldownMs;
  if (turret.fuel <= 0) turret.dormant = true;
  if (target.hp <= 0) onTurretKill(turret, target);   // bank essence/mats, ++defenseKills, loot→party.stash
}
```

**7.7.4 Behavior while players are NEAR vs AWAY** — this is the design's whole point:

| | **Near** (a party member's tome is open in-territory) | **Away** (tome shut) |
| --- | --- | --- |
| Clock | live: `dt` = real seconds since last frame | virtual: `dt` = `now − defenseCursor` |
| Role | **covering fire** — softens/kills trash and *tags* what it hits (apprentice-tag synergy), letting the player focus elites. Does **not** steal boss/elite loot — turret kills on `tier ≥ 3` yield essence only, drop rolls go to the player who lands the finisher. | **sole defender** — the only thing standing between the seam and your unattended anchor. |
| Loot | shared trash → `party.stash`; elite finishers → player | all → `party.stash`, collected in the away report |
| Fuel | drains live; player can hot-refuel from stash | drains until empty → **dormant** → territory undefended (§7.8) |
| Sealing | turret DPS counts toward a live territory-defense event's seal bar | n/a |

**The critical constraint that makes "away" a real economy, not idle-farming:** the turret runs on **finite fuel**. `fuelMax` (200–400 charges) at 20–30 shots/min covers only tens of minutes of heavy defense. Once it's dry it goes **dormant** and the seam starts leaking. So the loop is: *walk out → fight → come home → refuel the turret from the essence you gathered → leave it holding the line → come back before it runs dry.* That's the RIFT-BRIEF "check back" hook made mechanical, and it's why an AFK player can't out-earn an active one.

```
C→S  turret/build   { slot, kind }      // costs dp+mats+keystone; ≤ turretSlots(tier)
C→S  turret/upgrade { turretId }        // ballista→sigil→lance, gated by bastion tier
C→S  turret/refuel  { turretId, essenceQty }  // §5:veilEssence → charges (1 essence = 10 charges)
S→C  defense/tick   { turretId, kills, fuel, hold }   // live, while near
```

**7.7.5 One resolver, two clocks (the determinism keystone).** Live combat and offline defense are the **same pure event-stepped function**. It advances an event queue of §6 spawn events + turret cooldown events in time order — **not** a per-second loop — so fast-forwarding a week costs O(spawns + shots), a few thousand steps, milliseconds:

```js
// Canonical resolver — used BOTH by the live tick (to→now each frame)
// AND by resolveAway (defenseCursor→now). Identical inputs ⇒ identical output.
function resolveDefense(bastion, fromTs, toTs, seed, world) {
  const rng = mulberry32(hash(bastion.tile, epochBucket(fromTs), seed));
  const spawns = world.spawnSchedule(bastion.tile, fromTs, toTs, rng); // §6: seeded arrival events
  const events = merge(spawns, /* + collapses, retreats */).sort(byTime);
  let live = [], kills = 0, essence = 0;
  for (const ev of events) {
    advanceTurrets(bastion.turrets, ev.t);      // fire on cooldowns against current `live` set
    if (ev.type === 'spawn') live.push(ev.monster);
    reap(live, m => { if (m.dead) { kills++; essence += essenceDrop(m, rng); } });
    updateHold(bastion.territory, live, bastion.turrets); // §7.8
    if (allTurretsDormant(bastion) ) { /* seam leaks for the remainder — see §7.8 */ }
  }
  return { kills, essence, holdΔ, fuelLeft };
}
```

A property test (§7.10) asserts `liveStep-sum == resolveDefense` over the same window — the online path and offline path can never silently diverge.

---

### 7.8 Territory holding (camp + turrets vs escalating incursions — ref §6)

The Bastion **claims a tile and a `holdRadius`** (§7.4). Inside it, §6's incursion system escalates: `§6: incursionLevel` (0..n) raises the spawn rate `r(monsters/min)` and the spawn tier mix. The turrets + player defend a **hold meter**.

```js
territory = { hold:100, ... };   // 0..100
// per resolveDefense window:
holdΔ = (turretThroughput − incursionPressure) · k       // pressure from §6, throughput from §7.7
hold  = clamp(hold + holdΔ, 0, 100)
```

- **`turretThroughput ≥ incursionPressure`** → hold regenerates toward 100; surplus essence banked; keystones occasionally wash up (mission fuel, §7.5).
- **turrets dormant / outmatched** → `hold` falls. At **`hold == 0`** the tile becomes **contested**: `§6: incursionLevel += 1` (corruption spreads — the DESIGN.md persistent-world consequence), the turret takes a fuel/into-disrepair penalty, and the away report warns the party. The Bastion is **never destroyed** in this POC (no rage-quit from losing your base) — it degrades and demands attention. You re-hold by showing up, refueling, sealing nearby rifts (lowers `§6: veilPressure`, §7.2), or **moving** (§7.3).
- **Tier-5 Bulwark** flips the sign: it can **passively seal** its tile, pinning `incursionLevel` down while fueled — the end-state "your neighborhood is safe because your party holds it."

This is the concrete tie between the meta layer and §6's convergence clock: **unattended neighborhoods degrade; held ones stay clean.** A friend group that keeps its turrets fueled owns a visibly calmer patch of the shared map.

---

### 7.9 Shared camp in co-op

One `party.bastion`, many hands. Rules that keep it deterministic and grief-resistant:

**Contribution & ownership**
- **DP/mats for upgrades** are pooled from a shared pool; the **contribution ledger** (`bastion.progress.by[userId]`) records who fed what, for a post-hoc "who built this" and future reward-splitting — but upgrades never *require* equal contribution (a keener kid can carry the base).
- **Away spoils** (trickle, turret essence, territory rewards) → `party.stash` (shared). **Personal crafts** → the enqueuer (`CraftSlot.by`). This keeps the "I brewed *my* potions" feeling while the fortress economy is communal.

**Permissions**

| Action | Who |
| --- | --- |
| enqueue/collect craft, build/refuel/retarget turret, upgrade tier | **any member** |
| **move** the Bastion, **disband**/leave | **leader**, or party **majority vote** |

**Determinism across clients (the hard part).** Away-resolution must not double-count when two friends re-open the tome after the same night away:

- `bastion.defenseCursor` = the timestamp resolved **through**. `resolveAway` runs on the **server**, serialized per party. The **first** member to `session/resume` advances the cursor `[cursor → now]` and applies the result; the **second** member's resume finds `cursor == now` and gets a **no-op** report ("nothing new since your friend checked in"). **Idempotent by construction.**
- Because `resolveDefense` is seeded by `(tile, epochBucket, partySeed)` — not by *who* triggered it — the outcome is identical regardless of which member connects first. A bot test with two clients racing `session/resume` asserts the pooled stash is credited **exactly once**.

**Live co-op defense.** When several members are simultaneously near, the turret still runs one authoritative simulation on the server; each client renders `defense/tick`. Members' own attacks and the turret's shots feed the same `live` monster set — no client-side divergence, because clients never simulate defense, they only display server ticks.

---

### 7.10 Persistence & the headless harness (fast-forwarding the clock)

Everything above was built to be driven with **no human input**. The harness needs three seams, all already specified as injectables:

1. **Virtual clock** — `ctx.now()` is a settable variable. The harness places a Bastion, enqueues crafts, builds+fuels a turret, then does `clock.advance(6*3600_000)` and calls `session/resume`. Because crafts finish on `doneAt` and defense is event-stepped over `[defenseCursor → now]`, a 6-hour jump resolves instantly and exactly.
2. **Seeded RNG** — `mulberry32(seed)` for every roll (masterwork, lucky find, essence drops, spawn schedule). A fixture pins `seed` and asserts golden outputs.
3. **World stub** — a fake `§6` `world` object returning a scripted `spawnSchedule`, `veilPressure`, `incursionLevel`, `safety`. Lets §7 be tested without §6 shipped, and lets fixtures stage exact incursions.

**Bot-client fixture (illustrative):**

```js
test('turret holds a light incursion, runs dry under a heavy one', () => {
  const w = fakeWorld({ tile:'t1', veilPressure:0.2, spawnRate: 1/min /*monsters*/, tierMix:[1] });
  const clk = virtualClock(0), rng = mulberry32(1234);
  const party = placeBastion(botParty(['u_a']), 't1', ll, w, clk, rng);     // §7.2
  upgradeTo(party, 1, clk); buildTurret(party, 'ballista', clk);            // §7.4/§7.7
  refuel(party.bastion.turrets[0], 20 /*essence → 200 charges*/);

  clk.advance(hours(3)); const r1 = resolveAway(party, w, clk, rng);        // §7.6/§7.7
  assert.equal(r1.defense.kills, 180);          // 1/min · 180min, all killed (fuel & DPS suffice)
  assert.equal(party.bastion.territory.hold, 100);
  assert.equal(party.stash.veilEssence, 180 * essencePerKill);

  // heavier wave outlasts a 200-charge reserve:
  const w2 = fakeWorld({ tile:'t1', spawnRate: 4/min, tierMix:[1,2,3] });
  refuel(party.bastion.turrets[0], 20); clk.advance(hours(2));
  const r2 = resolveAway(party, w2, clk, rng);
  assert.ok(party.bastion.turrets[0].dormant);   // ran dry
  assert.ok(party.bastion.territory.hold < 100);  // seam leaked after fuel-out
  assert.equal(w2.tile('t1').incursionLevel, 1);  // contested → §6 corruption ticked up
});

test('two co-op members racing resume credit spoils exactly once', () => {
  // …advance clock, fire session/resume from u_a and u_b concurrently…
  assert.equal(party.stash.mats, expectedOnce);   // defenseCursor idempotency (§7.9)
});

test('live tick and offline resolve agree', () => {          // the determinism keystone
  const off = resolveDefense(b, 0, hours(1), seed, w);
  const on  = sumOverFrames(() => liveTick(b, dt, seed, w), 0, hours(1));
  assert.deepEqual(on, off);                                  // §7.7.5
});
```

**Persistence** is just serialize/deserialize of `Party` + `Bastion` (plain JSON, no closures) to SQLite (NORTH-STAR). A round-trip test asserts `deserialize(serialize(state))` is identical, and that a resolve computed *after* a save/reload matches one computed without — proving the away math depends only on persisted fields (`defenseCursor`, `cooldownReadyAt`, `fuel`, `doneAt`), never on in-memory timers.

---

### 7.11 Field & message map (for sibling-section reconciliation)

**Introduced by §7** (adopt these names): `party.bastion`, `party.stash`, `bastion.{tile,tier,progress,turrets,crafts,defenseCursor,territory}`, `bastion.territory.{hold}`, `Turret.{kind,tier,damage,dmgType,rangeM,cooldownMs,cooldownReadyAt,fuel,fuelMax,targeting,dormant}`, `CraftSlot.{jobId,startedAt,doneAt,by}`, `hero.camp`.
Messages: `bastion/place|move|upgrade|state`, `turret/build|upgrade|refuel`, `craft/enqueue|collect`, `session/resume`, `away/report`, `defense/tick`, `territory/state`, `mission/claim`.

**Referenced from §5 (Items/materials)** — *not redefined here:* `mats` (generic material count), `veilEssence` (turret fuel + upgrade sink), tier keystone materials (`§5:keystone_T`), the damage-type resist/weakness model (`resistMult`), and loot/drop tables (`lootFor`, `essenceDrop`).

**Referenced from §6 (World)** — *not redefined here:* `tileId`, `latLng`, `biome`, `poiId`, `safety(latLng)`, `veilPressure(tile)`, `incursionLevel`, `spawnSchedule(tile, from, to, rng)`, `spawnSeq`, `nearestRiftM`, `nearestBastionM`, the convergence clock, and rift-seal outcomes (`ripSealed`).

**Reconciled from the prototype (de-facto contract):** `hero.{ep,dp,mats,walked,craft}`, `TIER_PREFIX`, `CRAFT_JOBS`, `applyAway()`/`showAwayReport()` shape, `creditWalk` (10 m = 1 EP), trickle caps `min(50/30/90,…)`. `hero.bastion:int` **migrates** to `party.bastion.tier`.

> **Open item flagged for the orchestrator:** if the real FOUNDATION CONTRACT defines different names for the §5/§6 fields above (e.g. a different envelope than `{t, …}`, or `essence` vs `veilEssence`), only §7.11's identifiers need a find-replace — no logic changes, because every rule is expressed against those names, not their values.

Now I have the full picture. Here is the deliverable — the client/rendering/art-pipeline section of the design bible. This is my return value.

---

## 8. Client UX, Rendering & Art Pipeline

> **Owner:** Client UX, Rendering & Art Pipeline.
> **Conforms to** the Foundation Contract: reuses the §2 data-model field names and the §3 protocol messages verbatim, and consumes the §6 procgen decoration functions rather than reinventing them. Where this section names a message (e.g. `combat.event`) or a field (e.g. `accuracy_m`), it is the §3/§2 name, not a new one.
> **Prime directive:** every screen and every animation is exercised by **headless, seed-driven fixtures** — no human input, no live GPS, no wall clock. If a behavior can't be driven and asserted by a bot client, it isn't done. §8.9 is the contract that makes this true; read it alongside each screen.

### 8.0 Platform envelope & non-negotiables

| Concern | Target |
| --- | --- |
| Form factor | Mobile-first portrait, 360×640 css-px floor (iPhone SE / low Android), thumb-reachable. Landscape is letterboxed, not re-laid-out. |
| Renderer | **React** chrome (the Glory kit — §8.0/§1.0) over a single **imperative `<canvas>` island** for the world (§8.4); the `<GameCanvas>` rAF loop is *outside* React's render cycle. HUD, panels, combat, shops = React components; the canvas is only per-pixel art + camera. |
| Frame budget | 16.6 ms (60 fps) on the map with ≤40 visible entities; hard floor 30 fps. Combat is DOM+CSS-anim, effectively free. |
| Pixel rule | **Integer scaling only**, `imageSmoothingEnabled=false` everywhere — never draw a sprite at a non-integer multiple. Frame size is **per-subject, read from the manifest**: the imported art is mixed-resolution (monsters ≈150², wizard ≈190², effects 16²/100²), not one 32² grid. Keep each subject native; scale by integer factors. See §8.0 *Art scale & map pins*. |
| Art transport | PNGs **served as files** from the Node server (see §8.6.3), sliced client-side per manifest. Base64 inlining is the *prototype-only* fallback the CLAUDE.md workflow needs for Scry; the native/served client does not inline. |
| Determinism | All non-authoritative visuals (juice jitter, idle phase, procgen props) derive from a seeded RNG keyed on stable ids, never `Math.random()` or raw `Date.now()`. See §8.8, §8.9. |

The client is a **thin, server-authoritative view** (per NORTH-STAR: PoGO posture). It renders §3 messages and emits §3 intents; it never decides combat math, loot, or world state. That is what makes it deterministically testable — given the same message tape, it must produce the same pixels.

---

### 8.0 UI design language — the "Glory" system

**The UI is built to a committed design system.** The binding source of truth is **`docs/DESIGN-SYSTEM.md`** (the "Glory" system — the `:root` token block, material recipes, the chamfered-plate primitive, and the component kit) with **`docs/ART-DIRECTION.md`** as the taste layer (the intent behind the tokens) and its **reference style-guide HTML** as the match target. Any sub-agent building a screen treats those as law: use the `:root` tokens verbatim, build from the `.cpanel / .ppanel / .prpanel / .wpanel / .dpanel` panel primitives, and pass the ART-DIRECTION.md acceptance checklist before a screen is "done." This §8.0 only states how that system sits against the rest of the plan.

**Two layers, one world.** The **world layer** (canvas) is pixel art — integer-scaled, `imageSmoothingEnabled=false`. The **UI layer** (DOM/CSS over the canvas) is the Glory system: *illustrated chrome with opinions* — carved brass/wood/parchment plates, hand-set Cinzel/Alegreya type, warm jewel palette with **arcane teal reserved for the veil/rift**. It is explicitly **not** a pixel UI and **not** a web app in a fantasy skin. The hero sprite steps *free* of the chrome (unframed, feet on the floor); the 32px sprites are the item/monster icons; functional icons are **Material Symbols Rounded** (never hand-drawn SVG, never emoji).

**Where Glory meets the engine (reconciliations):**
- **Fonts:** DESIGN-SYSTEM.md specifies Cinzel / Cinzel Decorative / Alegreya / Barlow Semi Condensed + Material Symbols via Google Fonts. Because this game is outdoor + dead-zone-prone and is screenshot-tested headlessly, **self-host the `.woff2`** in `web/assets/fonts/` (same exact faces) so play and the §9.8 vision harness never depend on the network. `data-ready` (§8.1) gates on font load.
- **Rarity is one 5-step ladder:** the plan's fiction names (§5.5 / §11.19 — Wayfarer's→Riftforged, integer `rarity 0..4`) map 1:1 onto the design system's gem colors `--gem-common → --gem-legendary`. **Fiction name from §5.5, color token from DESIGN-SYSTEM.md.**
- **Combat input** is the design system's **command panel** (chamfered ability bar: icon + name + damage + cost pips), *not* a radial dial — this refines §8.2.3.
- **Nav** is the chamfered wood tab bar (Map / Camp / Hero / Party) from DESIGN-SYSTEM.md §10, wrapping the §8.1 router.

**Token plumbing.** `web/css/tokens.css` holds the DESIGN-SYSTEM.md `:root` block **verbatim** (single source of truth); `web/css/kit.css` holds the panel/button/meter/slot recipes; `web/css/app.css` may only *use* tokens, never define raw values. Building this is sub-issue **M-UI**, which lands before/with M4 so every screen is built on the plates.

**Enforced, not vibes.** The §9.8 vision-critique loop's **Craft & cohesion** axis grades each screen directly against the ART-DIRECTION.md acceptance checklist (every container a chamfered plate; one panel language; teal only on magic; hand-set type; hero unframed; Material Symbols; on-token colors; no filler). The judge *catches* drift from the system; the system itself is the human-authored art direction (per §11.18).

**Party size 1..`PARTY_MAX` is first-class in the UI.** Every screen renders correctly for a **solo** player *and* for a full party: the HUD party strip, the map's other-member sprites/dots + name labels (§8.3), the combat hero row, revive prompts, and loot attribution all handle 1..N — degrading cleanly at **N=1** (no empty party chrome) and at **max N** (no overflow; scroll/condense). The §9.8 screenshot battery captures **solo and party** variants of each screen so both are graded.

**Art scale & the map-pin problem.** The imported sprite set is **mixed-resolution and larger than the retired 32² set** — monsters ≈150², the wizard ≈190², effects 16²–100² (see `assets/manifest.json`). That suits the Glory "hero steps free of the chrome" combat/portrait look, drawn at integer scale from each subject's manifest frame size. But a 150² monster shrunk to a ~28px **map pin** loses the legibility a purpose-built 32² sprite had. So on the map, represent monsters/breaches with **simple, distinct markers or small downscaled icons** (one readable silhouette per breed at pin size) and reserve the detailed sprites for the **combat/encounter and portrait** surfaces where they're seen large. §8.3 (map render) picks the marker/icon; §8.4 (sprite system) draws the full sprite in combat — both read frame size from the manifest.

---

### 8.1 Screen flow & the router

Six screens, one linear spine with two side-trips. The router is a finite state machine; transitions are the only way to change screen, and each is triggerable headlessly via `__sq.goto()` or by the §3 message that naturally causes it.

```
                 join.request↴            combat.start
  [JOIN/CREATE] ───────────▶ [MAP] ◀──────────────▶ [COMBAT]
   name+class    session.        │  ▲                 combat.end→loot
                 welcome         │  │
                       tap camp  │  │ leave
                                 ▼  │
              ┌──────────────[CAMP]─┴───── whistle ───▶ [MERCHANT]
              │                 │                        merchant.open/close
   tap pack   ▼                 │ from anywhere via HUD
        [INVENTORY/CHARACTER]◀──┘
```

Router contract:

```js
const SCREENS = ['join','map','combat','inventory','merchant','camp'];
// state: { screen, prev, params }
// A transition is legal only if listed in TRANSITIONS[from]; illegal goto() throws
// (so a fixture that fat-fingers a jump fails loudly instead of rendering garbage).
const TRANSITIONS = {
  join:      ['map'],
  map:       ['combat','inventory','merchant','camp'],
  combat:    ['map','inventory'],        // inventory reachable mid-fight (consumables)
  inventory: ['map','combat','camp'],    // returns to prev
  merchant:  ['map','camp','inventory'],
  camp:      ['map','inventory','merchant'],
};
```

- **Message-driven transitions** (authoritative): `session.welcome` → `map`; `combat.start` → `combat`; `combat.end` → `map` (via loot overlay); `merchant.open` → `merchant`, `merchant.close` → back to `prev`.
- **User-driven transitions** (intent): HUD buttons emit a §3 intent *and* optimistically switch screen; the server's confirming message reconciles. If reconciliation contradicts the optimistic screen, the router snaps to the server truth and fires a `veil.flicker` toast (§8.7).
- Every screen root is `<div data-screen="NAME" data-ready="0|1">`; exactly one is mounted. `data-ready` flips to `1` after that screen's first paint (fonts + needed sprites loaded). The screenshot harness (§8.9) waits on it.

Layout skeleton shared by all screens:

```
┌─────────────────────────────┐  ← safe-area-inset-top
│  TOP BAR  hp · level · gold  │  40px, always visible except JOIN
├─────────────────────────────┤
│                             │
│        SCREEN BODY          │  flex:1
│   (canvas or panel)         │
│                             │
├─────────────────────────────┤
│  THUMB BAR  primary actions  │  72px, bottom third = thumb zone
└─────────────────────────────┘  ← safe-area-inset-bottom
```

All interactive controls live in the **bottom 45%** of the viewport (thumb reach). Top bar is status only (read, don't tap). Minimum hit target 44×44 css-px (kid thumbs, gloves in the cold — this is an outdoor game).

---

### 8.2 Screen specs

Each screen below is build-ready: purpose, DOM, controls, the §3 messages it consumes/emits, transitions, and the headless hooks that drive it.

#### 8.2.1 JOIN / CHARACTER-CREATE

**Purpose:** get a kid from cold-open to the map in under 20 seconds, with a name and a class. No account walls in the prototype (NORTH-STAR: the friend-group is the unit; identity comes later).

**Body layout (single column, centered):**
- Title crest (hero art from ART-DIRECTION's "hero pieces" budget — one commissioned title image).
- Name field: `<input data-testid="name" maxlength=12 autocapitalize=words>`. Placeholder "Your name, Warden". Defaults to a seeded fantasy name (`nameFor(seed)`) so a bot can submit empty and still get a valid name.
- **Class picker: three cards** (Knight, Ranger, Wizard), side by side, each ≥140×180 css-px — all three playable now; Knight/Ranger use legacy 32² art for the moment (upgrade to itch scale later — §4.2 roster):

  | | Knight | Ranger |
  | --- | --- | --- |
  | Sprite | `knight/idle` looping | `ranger/idle` looping |
  | One line | "Stand in the breach. Hit hard up close." | "Loose arrows from safety. Never has to cross the road." |
  | Fiction hook (Ranger) | — | maps to RIFT-BRIEF's safety-first ranged path — the class you pick when the monster is across a busy street. |
  | `data-testid` | `cls-knight` | `cls-ranger` |

  Tapping a card sets `aria-pressed=true`, shows a 1-shot `cheer` animation on that class's sprite (juice, seeded), and enables the CTA.
- **CTA (thumb zone):** `<button data-testid="enter">Cross the veil</button>`.

**Controls / flow:**
1. Pick class → 2. (optional) edit name → 3. tap CTA.
2. Emits `join.request { name, cls }` (§3). `cls ∈ {'knight','ranger'}` — the §2 `player.cls` enum.
3. Awaits `session.welcome { player, world_seed, server_time }`. On receipt: seed the client RNG with `world_seed` (§8.8/§8.9), store `player.id`, transition → `map`.
4. Timeout / offline: show "the veil is slow to part…" spinner; retry with backoff (§8.7). Prototype offline-fallback: synthesize a local `session.welcome` so the screen is never a dead end.

**Headless:** `__sq.input({screen:'join', name:'Bot', cls:'ranger'})` fills + submits in one call. `__sq.snapshot().join` returns `{name, cls, ctaEnabled}` for assertion. This is the first screenshot in the design-critique set.

#### 8.2.2 MAP (home screen)

The map is the game's face; §8.4 is its full renderer spec. Here: the UX shell around the canvas.

**Body:** full-bleed `<canvas id="sq-map">` filling the body, DOM HUD floating over it.

**Persistent HUD over the canvas:**
- **Top bar:** HP pip bar, level badge (`Lv 4`), gold (`💰 128`), EP/RP micro-meters (Endurance/Recovery from RIFT-BRIEF), connection dot (§8.7).
- **Recenter button** (top-right, above thumb zone): snaps camera back onto player; auto-hides when already centered.
- **Compass / accuracy readout** (small, top-left): shows `accuracy_m` as "signal: strong/faint" — never a raw number to a kid.
- **Thumb bar (bottom):** four large buttons — **Camp** 🏕️, **Pack** 🎒 (inventory), **Whistle** 📯 (summon merchant), and a context **Engage** button that appears only when a mark/rift/monster is within its proximity band (§8.4 rift markers).
- **Selected-mark card** (slides up from bottom when a map entity is tapped): sprite thumbnail, name, `tier`, threat line, distance, collapse timer if a rift, and band-appropriate actions (Fire from range / Approach / Send apprentice — the RIFT-BRIEF safety options). Actions emit `intent.move` or `combat.action` (§3).

**Controls:**
- **Pan:** one-finger drag moves the camera; releasing near player re-arms auto-follow after 4 s idle.
- **Zoom:** pinch, clamped (§8.4). Double-tap = zoom in one step toward tap point.
- **Tap entity:** selects it → mark card. Tap empty map → deselect.
- **Engage:** if selected entity is a monster/rift in range, emits the intent that yields `combat.start`.

**Consumes (§3):** `state.snapshot` (initial world), `map.marks` (nearby rifts/merchants/marks by proximity), `entity.upsert`/`entity.remove` (spawns/despawns), `player.move` (other party members — interpolated, §8.7), `progress.update` (HUD numbers), `veil.flicker` (connection).
**Emits (§3):** `gps.update { lat, lng, accuracy_m, ts }` on movement (or synthesized by `__sq.gps`), `intent.move`, `combat.action` (engage).

**Transitions:** → combat (engage), → inventory (Pack), → merchant (Whistle → `merchant.open`), → camp (Camp button or walking onto camp tile).

#### 8.2.3 COMBAT

Turn-based, server-authoritative, DOM+CSS-animated (the prototype already proves this shape). Diegetically the "latency of relaying commands across the veil" (DESIGN.md tome variant) — which is *why* it's turn-based and why a slight delay between action and result reads as fiction, not lag.

**Layout (portrait, fixed arena):**
```
┌─────────────────────────────┐
│  ENEMY  name·tier    ❤▓▓▓░░  │  enemy HP bar + intent telegraph
│                             │
│              [enemy sprite]  │  right, faces left, integer-scaled (§8.5)
│                             │
│   proximity band: MID 32m    │  band indicator (Far/Mid/Close, RIFT-BRIEF)
│                             │
│  [hero sprite]               │  left, faces right
│                             │
│  YOU  ❤▓▓▓▓▓░   🧪x2         │  hero HP + consumables
├─────────────────────────────┤
│  ⚔ Strike  🏹 Loose  ✨ Cast │  ability row (thumb zone), 2–4 abilities
│  🛡 Guard   🧪 Potion  🏃 Flee │  from §2 hero.abilities + class kit
└─────────────────────────────┘
```

**Controls:** one tap per turn — pick an ability button → emits `combat.action { ability, target, band }` (§3). Buttons disable during the enemy's turn (a between-turns state that reads as "their move," not a freeze — the prototype already does this and it matters). Band is set by real proximity (from `gps.update`) but overridable by "approach/back off" chips for accessibility (a kid at a bus stop can't literally walk closer).

**Animation ↔ protocol mapping** (this is the heart of §8.5's state machine):

| §3 `combat.event.kind` | Actor sprite state | Juice |
| --- | --- | --- |
| `attack` (melee) | `attack` (1-shot) + lunge toward target | screen shake (light), hit flash on target at impact frame |
| `attack` (ranged) | `quick_attack`/`attack` + spawn `projectile` sprite tweened to target | trail, impact flash |
| `cast` | `cast` (1-shot) | glow ramp on caster, particle burst at frame N |
| `hurt` | target → `hurt` | red flash, HP bar drains, floating damage number (`DMG`) |
| `heal` | `cast` on healer | green float, HP bar fills |
| `miss` / `dodge` | target → tiny hop | "miss" floating text, no flash |
| `die` | target → `die` (1-shot, holds last frame) | fade, loot sparkle |
| `win` | hero → `cheer` | level-up flourish if `progress.update.leveled` |

Every event carries the actor/target `id` and an intended `duration_ms`; the client plays the matching manifest state (§8.5) and does **not** advance the turn UI until the animation's authoritative resolution arrives. In deterministic mode animations are stepped by injected ticks, so a fixture sees exactly the same frames every run.

**Consumes:** `combat.start` (arena setup: `you`, `enemy`, `band`), `combat.turn` (whose turn), `combat.event[]` (the animation script), `combat.end { outcome }`, `progress.update`.
**Emits:** `combat.action`.
**Transitions:** → map on `combat.end` (through the loot overlay, §8.8), → inventory (potion/gear mid-fight).

#### 8.2.4 INVENTORY / CHARACTER

Two tabs in one screen (kids conflate "my stuff" and "me").

**Tab A — Character:** paper-doll of the hero sprite at the center (large integer scale, idle loop), equip slots ringed around it (`SLOTS` = melee, ranged, helmet, armor, legs, shield, boots — reuse the prototype's set). Stat block below: HP, ATK, DEF, dodge, plus **Endurance** and **Recovery** meters (RIFT-BRIEF currencies) and the training ranks they buy. Tapping a slot opens a chooser from the bag.

**Tab B — Bag:** scrollable grid of item cards (icon, name, tier color, one-line effect). Tap = detail + actions (Equip / Use / Sell-if-merchant-open / Drop). Long-press = compare-to-equipped.

**Controls:** thumb-zone tab switch; grid scroll; big Equip/Use buttons in detail. All mutations emit §3 intents (`intent.equip`, `intent.use`) and reconcile on `state.snapshot`/`progress.update`.

**Consumes:** `state.snapshot` (bag/equip), `progress.update`. **Emits:** equip/use/sell intents.
**Transitions:** back to `prev` (map/combat/camp/merchant) via a persistent Back affordance.

**Headless:** `__sq.snapshot().inventory` returns `{equip, bag[], stats}` so a fixture can assert "picked up sword → ATK went up" without pixel-reading. Stable `data-testid="item-<id>"` on every card.

#### 8.2.5 MERCHANT

Summoned by the Whistle (📯) — "a crooked door unfolds in the air" (RIFT-BRIEF). A timed pocket shop; the timer is a first-class UI element (scarcity is the design point).

**Layout:** merchant hero sprite top-center (idle/`cheer`), a **speech ribbon** for snark (NORTH-STAR: snark lives in characters, and merchants are a primary vehicle — Grimble & Sons register), a **countdown** ("stall closes in 6:12"), then two columns: **Buy** (merchant stock) and **Sell** (your bag). Gold shown large in the top bar.

**Controls:** tap item → confirm buy/sell with a haggle beat (apprentice "Negotiate" can appear as a one-tap discount if unlocked — RIFT-BRIEF broker spec). Buttons in thumb zone.

**Consumes:** `merchant.open { merchant_id, sprite, stock[], closes_at }`, `merchant.stock` (live updates), `progress.update` (gold), `merchant.close`.
**Emits:** `merchant.buy { item_id }`, `merchant.sell { item_id }`.
**Transitions:** `merchant.close` (timer or leave) → `prev`.

The countdown is driven by `closes_at` minus the **client clock abstraction** (§8.9), not `Date.now()` directly, so a fixture can fast-forward the timer deterministically to screenshot the "closing soon" and "closed" states.

#### 8.2.6 CAMP

Your anchor on this side of the veil (DESIGN.md). It's the downtime and self-improvement hub, and it's also a *place on the map* (§8.4 renders the camp + turret sprite at its world position).

**Layout:** a small canvas or DOM diorama of the camp — tent, campfire, **turret/Bastion** structure — with the hero and apprentice sprites idling. Panels below:
- **Downtime queue** (RIFT-BRIEF): assignable task slots (Craft / Farm / Repair / Research / Train apprentice). Each shows progress bar + `finishes_at`. "While you were away" report renders here on return.
- **Bastion / turret upgrade:** spend Downtime/Recovery to raise tiers; the turret sprite visibly upgrades (a manifest state or a distinct subject).
- **Training:** spend Endurance/Recovery on the training ranks (QfG "you improve what you practice").
- **Rest:** a Recovery tick action.

**Controls:** tap a slot → assign task chooser; tap turret → upgrade sheet. Thumb-zone Back to map.

**Consumes:** `camp.state { slots[], bastion_tier, apprentice, away_report }`, `progress.update`.
**Emits:** `camp.command { assign|upgrade|train|rest, ... }`.
**Transitions:** → map, → inventory, → merchant.

---

### 8.3 Canvas map renderer

The one place we truly paint. Everything below is designed to be stepped deterministically (§8.9): given a camera, a seed, and an entity list, `renderMap()` is a pure function of its inputs plus the injected clock.

#### 8.3.1 Projection & camera

Local ENU (east-north-up) tangent-plane projection around a per-session origin (the player's first fix). Cheap, accurate at neighborhood scale, and matches OSM/MapLibre coordinates (MAP-DATA) so the fantasy-skinned tiles and our overlay agree.

```js
const R_LAT = 110540, R_LNG = 111320;           // meters per degree
function toMeters(pos, origin){                  // {lat,lng} -> {x:east, y:north} meters
  return { x:(pos.lng-origin.lng)*R_LNG*Math.cos(origin.lat*Math.PI/180),
           y:(pos.lat-origin.lat)*R_LAT };
}
// camera: { center:{lat,lng}, zoom }  zoom∈[0.5,3], default 1
const PX_PER_M0 = 4;                              // px/meter at zoom 1, DPR 1 (street level)
function worldToScreen(pos, cam, view){
  const m = toMeters(pos, cam.origin), c = toMeters(cam.center, cam.origin);
  const s = PX_PER_M0 * cam.zoom;
  return { x: view.w/2 + (m.x - c.x)*s,
           y: view.h/2 - (m.y - c.y)*s };         // north is up → invert y
}
const metersPerPixel = cam => 1/(PX_PER_M0*cam.zoom);
```

- **Follow mode:** `cam.center` eased toward `player.pos` each frame (`center += (target-center)*0.15`), critically damped so GPS jitter doesn't whip the camera. Manual pan disables follow for 4 s.
- **Zoom clamp:** 0.5 (neighborhood, ~8 m/px) to 3.0 (street, ~0.83 m/px). Pinch multiplies `cam.zoom`, then clamp.
- **DPR:** backing store = `view.w*dpr × view.h*dpr`; context pre-scaled by `dpr`. Sprite integer-scale accounts for `dpr` (§8.5) so pixels stay crisp at DPR 2/3.

#### 8.3.2 Layer order (painter's algorithm)

```
1. Parchment base fill              (fantasy "sea"/ground under everything)
2. OSM fantasy-skin tiles           (MapLibre-style, or in web proto: a flat skin)
3. §6 procgen decoration overlay    (deterministic props: groves, standing stones, ruins)
4. Fog of war                       (unrevealed veil)
5. World entities (y-sorted):
      marks · resource nodes · rifts(rift markers) · merchants
      camp + turret
      apprentice · party members(dots/sprites+labels) · monsters
      PLAYER (always drawn last among ground entities)
6. GPS accuracy halo                (under the player sprite, additive glow)
7. Selection ring / range bands     (Far/Mid/Close radii around selected target)
8. Weather / veil shimmer FX        (ART-DIRECTION "hi-bit" glow, cheap, optional)
```

**§6 procgen overlay:** the renderer *calls into* the §6 deterministic decoration functions — it does not roll its own. For each visible tile it asks §6 `decorateTile(tileX, tileY, world_seed)` → a list of `{prop, x, y, variant}`; props are drawn from `assets/props/` (§8.5) or prop-sprites. Because §6 is a seeded hash of tile coords, every player sees the same enchanted grove at the same park (MAP-DATA), and a fixture with a fixed `world_seed` renders byte-identical decoration.

**Fog of war:** a coarse visited-tile grid (persisted per player). Reveal radius `R_reveal = 60 m` around the player; visited tiles stay dimly revealed (`alpha 0.35`), never-visited are opaque veil (`alpha 0.85`, tinted). Fog reads diegetically as "the veil not yet parted here."

```js
fogAlpha(tile){ if(tile.visible) return 0; if(tile.visited) return 0.35; return 0.85; }
```

#### 8.3.3 Rift markers, entities, party, player

Entities come from §2 (`{id, kind, sprite, state, pos, name, tier, hp, maxHp, band}`) via `entity.upsert`/`map.marks`. Rendering rules by `kind`:

- **rift** → a **rift marker**: an animated tear glyph whose size/intensity scales with `tier` (1→4, TIER_PREFIX Elder/Giant/Massive). Draw a pulsing vertical rift sprite + particle motes; ring color encodes threat. If a rift is a *breach* (monsters can cross to our side — DESIGN.md), add an outer red pulse. Collapse timer, if present, draws as a thinning ring.
- **monster** → 32-px sprite, `idle`/`walk` state, name+`tier` label above, small HP pip if engaged.
- **merchant** → merchant sprite + 📯 glyph; only present while a pocket stall is open.
- **mark / resource node** → prop or icon sprite; RIFT-BRIEF wild-encounter texture.
- **camp + turret** → the camp diorama footprint at its world pos; turret sprite drawn on top, its variant = `bastion_tier`.
- **party member (other player)** → sprite if within `R_reveal` and zoom ≥ 1.5, else a **colored dot** with a **name label** (the integer-scale floor means we can't shrink a 32-px sprite gracefully; dots are the honest degrade). Position is **interpolated** (§8.7). Party membership + labels come from §2 `player.name`.
- **apprentice** → a small companion sprite trailing the player (the snark vehicle made visible).
- **player (you)** → your class sprite, `walk` while GPS is moving (§8.5), `idle` otherwise, always centered under follow mode, drawn above other ground entities, with the accuracy halo beneath.

**GPS accuracy halo:** a translucent disc under the player whose radius is the real positional uncertainty, so a kid intuitively learns "big fuzzy circle = don't trust the exact dot."

```js
haloRadiusPx = clamp(player.accuracy_m / metersPerPixel(cam), 12, 140);
// gentle breathing: alpha = 0.18 + 0.06*sin(clock*2π/2.4s)   (clock = injected, deterministic)
```

**Proximity band rings:** when a monster/rift is selected, draw the RIFT-BRIEF bands as concentric rings centered on it: Close 0–15 m, Mid 15–50 m, Far 50–150 m, with the player's current band highlighted. This teaches the safety system spatially and shows *why* "Fire from range" is offered when the target is across a street.

#### 8.3.4 Performance

- **Cull** to viewport + 1-tile margin before drawing; typical visible set ≤40 entities.
- **Cache** the base+skin+procgen layers to an offscreen canvas keyed by `(tileRange, zoomBucket, world_seed)`; only redraw when the camera crosses a tile boundary or zoom bucket. Entities/halo/FX repaint every frame; static world does not.
- **Sprite atlas:** slice each manifest strip once into an offscreen frame array (§8.5); `drawImage` from the cache, never re-slice per frame.
- **RAF loop** with a fixed-timestep accumulator so animation speed is clock-driven, not frame-rate-driven (and thus reproducible under injected clocks). Budget: ≤6 ms world (mostly cached), ≤6 ms entities, ≤4 ms FX.
- Degrade path on jank: drop veil-shimmer FX first, then party sprites→dots, then lower halo detail. Never drop entity legibility.

---

### 8.4 Sprite & animation system

Manifest-driven, zero-config, integer-scaled. The manifest (`assets/manifest.json`, produced by the pixel importer) is the single source of truth; the renderer reads it and asks no questions.

#### 8.4.1 Loading & slicing

For each `assets[]` entry the manifest already gives us everything: `path`, `subject`, `state`, `frame_size [w,h]`, `frames`, `is_sheet`, `image_size`. We load the PNG (as a file, §8.6.3), then slice:

```js
// Manifest entry -> ready-to-draw clip
async function loadClip(entry){
  const img = await loadImage(assetURL(entry.path));       // <img> or ImageBitmap
  const [fw,fh] = entry.frame_size, n = entry.frames;
  const perRow = Math.floor(entry.image_size[0]/fw);       // strips: n×1; sheets: grid
  const frames = [];
  for(let i=0;i<n;i++){
    const col = i%perRow, row = Math.floor(i/perRow);
    frames.push({img, sx:col*fw, sy:row*fh, sw:fw, sh:fh});
  }
  return { frames, fw, fh };
}
// Index: SPRITES[subject][state] = clip.   state===null  -> 'portrait' (single frame).
```

A single top-level walk of `manifest.assets` builds `SPRITES[subject][state]`. **No per-sprite code, no registry, no switch.** Adding a monster is adding files + rebuilding the manifest (§8.6).

#### 8.4.2 Frame timing

Per-state default frame durations (ms), overridable by an optional `fps` field in the manifest if art ever needs it:

```
idle: 160ms/frame, loop        walk: 90ms/frame, loop
attack/quick_attack: 70ms, 1-shot   cast: 80ms, 1-shot
hurt: 90ms, 1-shot             die: 110ms, 1-shot, HOLD last frame
cheer: 120ms, loop (or 1-shot in menus)   projectile: static, tweened by code
```

Frame index is a pure function of the **injected clock**, so it's reproducible:

```js
function frameIndex(clip, state, startedAt, clock){
  const dur = FRAME_MS[state] ?? 100, n = clip.frames.length;
  const t = clock - startedAt, i = Math.floor(t/dur);
  return LOOP.has(state) ? i % n : Math.min(i, n-1);   // 1-shots hold last frame
}
```

#### 8.4.3 Integer-scaled draw

The ART-DIRECTION law: scale is always an integer, accounting for DPR so *device* pixels are whole.

```js
function drawSprite(ctx, subject, state, screen, ctx_scale, dpr, flip){
  const clip = (SPRITES[subject]||{})[state] || SPRITES[subject].idle;
  const f = clip.frames[frameIndex(...)];
  // choose the largest integer scale that fits the target, min 1
  const k = Math.max(1, Math.floor(ctx_scale));       // e.g. map=1, combat=3..6
  const dw = f.sw*k, dh = f.sh*k;
  ctx.imageSmoothingEnabled = false;                  // crunch, not blur
  ctx.save();
  ctx.translate(Math.round(screen.x), Math.round(screen.y)); // snap to whole px
  if(flip) ctx.scale(-1,1);
  ctx.drawImage(f.img, f.sx,f.sy,f.sw,f.sh, -dw/2, -dh, dw, dh); // anchored feet-center
  ctx.restore();
}
```

Context scales:
- **Map entities:** `k=1` (32 css-px). Below 1 we do **not** shrink — we switch to dot+label (§8.3.3).
- **Combat:** `k = clamp(floor(arenaTargetPx/32), 3, 6)` → 96–192 px hero/enemy.
- **Menus/paper-doll:** fixed `k=3` or `4`.
- **DPR:** since the canvas is pre-scaled by `dpr`, `k` is in css-px multiples; on integer DPR (2,3 — the vast majority of phones) device pixels stay whole. On fractional DPR we snap `translate` to whole device px to avoid shimmer.

#### 8.4.4 Animation state machine (protocol-driven)

Each rendered actor holds `{subject, state, startedAt, flip}`. State changes are driven **only** by §3 messages or local movement, never guessed:

```
default              → idle (loop)
gps.update moved      → walk (loop) on the player; stops → idle after 400ms still
combat.event.attack   → attack | quick_attack (1-shot) → back to idle on resolve
combat.event.cast     → cast (1-shot) → idle
combat.event.hurt     → hurt (1-shot) → idle
combat.event.die      → die (1-shot, HOLD)  [terminal until entity.remove]
combat.end.win        → cheer (hero)
```

`setState(actor, state, clock)` sets `startedAt=clock`; for 1-shots the caller may await `stateDone(actor, clock)` before advancing UI. All timing flows through the injected clock so the whole fight is frame-reproducible in deterministic mode. `flip` is derived from facing (hero faces the enemy; on the map, faces movement heading).

**Missing-state fallback:** if a `combat.event` names a state a subject lacks (e.g. a new monster with no `cast` strip yet), fall back `cast→attack→idle`. Art can therefore ship incrementally without crashing the client — a core requirement of the zero-code pipeline.

---

### 8.5 Art pipeline for incoming art

**Goal (stated as a hard requirement):** adding new art is **zero code changes** — drop files, rebuild the manifest, ship. The client already reads the manifest generically (§8.4.1), so new subjects/states appear automatically.

#### 8.5.1 Naming & state convention

The importer already enforces this; the client depends on it:

```
assets/sprites/<subject>/<Subject>[_<state>][_<WxH>].png
  <subject>   lowercase dir + subject field (goblin, wraith, knight, ranger, slime…)
  <state>     null(portrait) | idle | walk | attack | quick_attack | cast |
              hurt | die | cheer | projectile | <custom>
  strips are N×1 (frames laid horizontally); frame_size in manifest is authoritative
props: assets/props/<name>.png   (single images or grids; manifest carries frame_size)
```

Contract with the manifest: the client trusts `frame_size`, `frames`, `is_sheet`, and `image_size` — it never infers geometry from filenames. The `_32x32` suffix in some filenames (e.g. knight) is cosmetic; the manifest's `frame_size` wins. New **states** need no client change (they slice generically); new **subjects** need no client change (indexed by `subject`); a genuinely new *animation category* only needs a `FRAME_MS`/`LOOP` default, and even then the fallback (§8.4.4) keeps it working.

#### 8.5.2 How the importer feeds the manifest

The existing **`import-pixel-art` skill / `pixel_import.py`** is the pipeline's front door and stays the only writer of `assets/manifest.json`:

1. Artist drops raw files into `assets/inbox/`.
2. The skill detects resolution, splits sprite sheets into per-state strips, uses vision to identify subject + animation state, renames to the convention above, and files them under `assets/sprites/<subject>/` or `assets/props/`.
3. It rebuilds `assets/manifest.json` (`generated_by: "pixel_import.py build"`) with `frame_size`, `frames`, `is_sheet`, `sha1`, `desc`, `tags`, and regenerates `assets/gallery.html` (a visual index) + `tags.json`.
4. The `sha1` per asset is the cache-busting key the client appends to asset URLs (§8.6.3), so a re-imported sprite invalidates cleanly with no manual versioning.

The client's only obligation: on boot, fetch the manifest, build `SPRITES`. Everything downstream is data.

#### 8.5.3 Serve PNGs as files — recommendation

**Recommendation: the Node server serves the sprite PNGs as static files; the client fetches and slices them. Do not base64-inline in the served/native client.** Rationale:

- **Caching & bandwidth:** PNGs get `Cache-Control: immutable` keyed by `sha1`; a returning kid re-downloads nothing. Base64 bloats payload ~33% and defeats HTTP caching.
- **Zero-code art adds:** new files + rebuilt manifest → served immediately; no client rebuild, no re-inlining step.
- **Decode path:** the browser/SpriteKit decodes real PNGs efficiently (and `createImageBitmap` gives GPU-ready frames); base64 forces a data-URI decode on the main thread.
- **iOS carry-over:** files map straight to SpriteKit texture atlases (ART-DIRECTION's "carries to iOS untouched" claim); base64 does not.

Concretely:

```
GET /assets/manifest.json                       → the manifest
GET /assets/sprites/goblin/Goblin_walk.png?v=<sha1>  → the strip, immutable-cached
assetURL(path) = `${ASSET_BASE}/${path}?v=${entry.sha1.slice(0,8)}`
```

**Exception (unchanged):** the throwaway web prototype in `prototype/index.html` stays a single self-contained file with base64-inlined sprites, because Scry serves static single files with no charset/CSP guarantees (CLAUDE.md). That is a prototype hosting constraint, **not** the architecture — the served client and the native build use files. The importer can emit both: files for the server, an inlined bundle for the Scry prototype.

---

### 8.6 Real-time feel

The game is server-authoritative and outdoors, where signal is imperfect (NORTH-STAR: dead-zone tolerance as a courtesy). The client's job is to make an intermittently-connected, latency-laden link feel alive — and to make every one of those states screenshot-able.

#### 8.6.1 Interpolating other players

Remote `player.move` messages (§3) arrive at ~1–4 Hz and jittery. We render them in the past to interpolate smoothly:

```js
// Per remote player: ring buffer of {t, pos}. Render at renderTime = clock - 120ms.
function interpPos(buf, renderTime){
  let a,b; for(let i=buf.length-1;i>0;i--){ if(buf[i-1].t<=renderTime && buf[i].t>=renderTime){a=buf[i-1];b=buf[i];break;} }
  if(!a) return buf[buf.length-1].pos;                 // extrapolate-hold if starved
  const u = (renderTime-a.t)/(b.t-a.t);
  return { lat:a.pos.lat+(b.pos.lat-a.pos.lat)*u, lng:a.pos.lng+(b.pos.lng-a.pos.lng)*u };
}
```

- **Interpolation delay** 120 ms (2–4× the fastest update interval) buys smooth motion at the cost of showing friends slightly in the past — invisible for a walking-speed game.
- **Facing/walk state** derived from the interpolated velocity: moving → `walk`, still → `idle`.
- The *local* player is **never** interpolated — it tracks raw (smoothed) GPS immediately, so you always feel responsive even when friends lag.

#### 8.6.2 Connection status & reconnection

A single **connection dot** in the top bar with three states, plus a full-screen treatment only for hard offline:

| State | Trigger | UI |
| --- | --- | --- |
| Connected | heartbeat < 5 s | green dot, silent |
| Weak | 1 missed heartbeat (5–15 s) | amber dot + subtle toast: *"the veil flickers…"* |
| Offline | ≥15 s / socket closed | red dot + banner: *"the veil has closed — you can still finish what's in front of you"* |

Reconnection: exponential backoff `0.5, 1, 2, 4, 8` s (cap 10 s), with jitter. On reconnect the client sends its last-known state cursor and the server replies with a `state.snapshot` to resync; the UI cross-fades rather than hard-cutting. **Graceful degradation, not a wall:** an in-progress combat finishes from cached state and queues its result (NORTH-STAR posture — the server is a sync layer, never a gatekeeper in the moment).

#### 8.6.3 Dead-zone messaging ("the veil flickers")

Two distinct failure modes, two fictions, never a raw error:

- **No network** (server unreachable): "the veil flickers / has closed" (above). Map still pans over cached tiles; you can open Pack, Camp, read your stuff.
- **No GPS / poor fix** (`accuracy_m` huge or stale): the accuracy halo swells and desaturates; toast: *"your scrying blurs — move to open sky."* Engage buttons that need a band fall back to the "approach/back off" chips so play never dead-ends (RIFT-BRIEF accessibility).

Both are diegetic (the lens/tome fiction absorbs the technical failure — DESIGN.md), and both are **explicit render states** with `data-testid` markers so the fixture set includes screenshots of "weak signal," "offline," and "blurry GPS."

---

### 8.7 Juice

The ART-DIRECTION "hi-bit" path: crunchy 32-px sprites with smooth modern effects over them — a big perceived-quality lift for near-zero cost. **Every effect is seeded and clock-driven** so it's identical across runs (a screenshot fixture must be able to catch a hit-flash mid-frame reliably).

| Effect | Trigger (§3) | Spec |
| --- | --- | --- |
| **Floating combat text** | `combat.event` damage/heal/miss | number rises `−40 px` over 700 ms, fades last 200 ms; crit = bigger + shake; color per `DMG` map; horizontal offset from seeded `rng(id,eventSeq)` |
| **Hit flash** | `hurt`/impact frame | target sprite tinted white for 60 ms via a pre-baked white-silhouette pass (composite `source-atop`), then red 80 ms |
| **HP bar drain** | HP change | two-layer bar: instant red "damage ghost," then eased green catch-up over 300 ms |
| **Loot popup** | `loot.grant` | item cards slide up stacked, tier-colored, tap-to-collect; rarity sparkle from ART-DIRECTION glow |
| **Level-up flourish** | `progress.update.leveled` | radial light burst behind hero + `cheer` state + "Level N!" banner; heavier particle count, all seeded |
| **Screen shake** | melee `attack`, `die`, level-up | camera/DOM translate by `A·sin(clock·ω)·e^(−clock/τ)`, `A≤6 px`, `τ≈180 ms`; **light** — never nauseating, and **disabled in `reduced-motion`** and in deterministic mode by default (toggleable) |
| **Rift shimmer** | ambient | breathing glow + motes on rift markers, phase seeded per rift `id` |

Reduced-motion (`prefers-reduced-motion` / a settings toggle) collapses shake and heavy particles to instant states — accessibility, and it doubles as a clean screenshot mode.

---

### 8.8 Headless drivability (the testability contract)

**This is a first-class feature, not an afterthought.** The client must be fully drivable by headless Chromium (playwright-core, per CLAUDE.md's smoke-test workflow) with fake GPS, scripted input, a virtual clock, and stable selectors, so we can screenshot every screen/state for vision-based design critique — the loop that lets art and layout iterate without a human on a phone in a park.

#### 8.8.1 The `window.__sq` debug hook

Present when `?debug=1`, `localStorage.sqDebug`, or a build flag is set (always on in fixtures, gated off in production):

```ts
window.__sq = {
  version: string,
  ready: Promise<void>,                    // resolves after boot: manifest+sprites loaded, router mounted

  // ── determinism ────────────────────────────────
  seed(n: number): void,                   // reseed all client RNG (procgen, juice jitter, names)
  clock: {                                 // the injected clock ALL animation/timers read
    now(): number,
    set(ms: number): void,                 // jump virtual time
    tick(ms: number): void,                // advance N ms, stepping animations deterministically
    mode: 'live' | 'virtual',
  },
  render: {
    mode: 'live' | 'deterministic',        // deterministic: virtual clock, no wall-time, shake off
    paused: boolean,
    frame(): Promise<void>,                // render exactly one frame; resolves after paint
  },

  // ── input: feed the world ──────────────────────
  inject(msg: object): void,               // push a §3 SERVER→client message as if from the socket
  gps(lat: number, lng: number, accuracy_m?: number): void,  // synthesize a GPS fix
  route(points, opts): void,               // scripted GPS path: walk a polyline at v m/s (drives WALK anim, EP)

  // ── input: drive the UI ────────────────────────
  goto(screen: string, params?): void,     // legal router transition (throws if illegal, §8.1)
  input(cmd: object): void,                // scripted UI action, e.g.
     // {screen:'join', name:'Bot', cls:'ranger'}
     // {screen:'combat', action:'ability', id:'strike'}
     // {screen:'merchant', action:'buy', item_id:'i7'}
  tap(testid: string): void,               // low-level: dispatch a tap on a data-testid element

  // ── output: assert without pixels ──────────────
  snapshot(): object,                      // serializable UI state per screen (see below)
  camera(): {center, zoom, follow},        // map camera introspection
  entities(): Array<Entity>,               // what the map currently believes exists
  waitFor(pred: () => boolean, timeoutMs?): Promise<void>,
};
```

`snapshot()` returns a stable, serializable projection of the current screen — e.g. `{screen:'combat', you:{hp,maxHp}, enemy:{name,tier,hp}, band:'mid', turn:'you', abilities:[...], lastEvents:[...]}`. Fixtures assert on this JSON (fast, robust) and screenshot for the *visual* critique — two independent checks.

#### 8.8.2 Deterministic render mode

`render.mode='deterministic'` guarantees: (a) the clock is virtual and only advances via `clock.tick`/`render.frame`; (b) all RNG derives from `seed()` keyed on entity ids + event sequence (never `Math.random`/`Date.now`); (c) §6 procgen uses the injected `world_seed`; (d) screen shake and non-essential particle jitter are off (or seeded and phase-locked); (e) sprite frame indices are pure functions of the virtual clock (§8.4.2). Result: the same message tape + same seed → **byte-identical canvas** run to run. This is what makes vision-based design critique meaningful (differences are real, not noise) and what lets us diff renders across commits.

#### 8.8.3 Stable DOM/canvas states for screenshotting

- Each screen root: `data-screen="<name>" data-ready="0|1"`; `data-ready=1` only after fonts + required sprites loaded + first paint. Harness waits on it — no arbitrary sleeps.
- Every interactive/asserted element carries a `data-testid` (`cls-knight`, `enter`, `item-<id>`, `ability-strike`, `merchant-buy-<id>`, `conn-dot`, `veil-toast`…).
- The map canvas exposes `render.frame()` so the harness can force-and-await a paint before capturing (canvas has no "load" event).
- A global `document.documentElement.dataset.sqBoot="ready"` flips once `__sq.ready` resolves — the single signal a fixture polls before doing anything.

#### 8.8.4 The screenshot / critique harness

The fixture set walks the whole spine deterministically and captures each state. Sketch (playwright-core, matching the repo's headless-Chromium smoke test):

```js
const url = `${base}/prototype/index.html?debug=1&seed=1337`;
await page.goto(url);
await page.waitForFunction(() => document.documentElement.dataset.sqBoot === 'ready');
await page.evaluate(() => { __sq.seed(1337); __sq.render.mode = 'deterministic'; });

const shots = [];
async function shoot(name){ await page.evaluate(()=>__sq.render.frame());
  await page.waitForSelector('[data-screen][data-ready="1"]');
  shots.push([name, await page.screenshot({path:`out/${name}.png`})]); }

// JOIN
await page.evaluate(() => __sq.input({screen:'join', name:'Bot', cls:'ranger'})); await shoot('01-join');
// MAP (fake position + injected marks/rift)
await page.evaluate(() => { __sq.gps(37.77,-122.41,12);
  __sq.inject({type:'map.marks', marks:[/* rift tier2, merchant, monster */]}); });
await shoot('02-map');
// WALK anim + fog reveal
await page.evaluate(() => __sq.route([[37.77,-122.41],[37.771,-122.409]], {v:1.4}));
await page.evaluate(() => __sq.clock.tick(3000)); await shoot('03-map-walking');
// COMBAT: inject a scripted event tape, step the clock, catch a hit-flash frame
await page.evaluate(() => __sq.inject({type:'combat.start', you:{...}, enemy:{...}, band:'mid'}));
await page.evaluate(() => __sq.input({screen:'combat', action:'ability', id:'loose'}));
await page.evaluate(() => __sq.inject({type:'combat.event', kind:'hurt', target:'e1', dmg:12}));
await page.evaluate(() => __sq.clock.tick(30)); await shoot('04-combat-hit');   // mid-flash
// INVENTORY, MERCHANT (fast-forward the closing timer), CAMP, plus the sad-path states:
await page.evaluate(() => __sq.inject({type:'veil.flicker', level:'offline'})); await shoot('09-offline');
```

Those PNGs are the input to vision-based design critique: an art/UX reviewer (or Claude with vision) looks at `01-join…09-offline` and flags layout, contrast, thumb-reach, and pixel-scaling problems, and the same tape reruns each iteration to confirm fixes. Because the mode is deterministic, a visual diff between commits is signal, not shimmer.

---

### 8.9 Protocol → UI update map (§3 messages this client renders)

The exhaustive routing table — every §3 server→client message and the screen/render change it drives. (Names are the §3 names; if §3 renames one, this table is the client's rename list.)

| §3 message | Screen(s) | Client effect |
| --- | --- | --- |
| `session.welcome` | join→map | store `player.id`, seed RNG from `world_seed`, set clock origin, transition to map |
| `state.snapshot` | any | full resync of the current screen's model (used on boot + reconnect) |
| `map.marks` | map | upsert nearby rifts/merchants/marks/nodes as entities (proximity-filtered) |
| `entity.upsert` | map/camp | add/update an entity `{id,kind,sprite,state,pos,name,tier,hp,band}`; drives spawn + state changes |
| `entity.remove` | map | despawn (with die/fade if it was a monster) |
| `player.move` | map | push to interpolation buffer for a party member (§8.7) |
| `progress.update` | all (top bar) | HP/level/xp/EP/RP/gold; `leveled` flag → level-up flourish |
| `combat.start` | →combat | build arena (you/enemy/band), transition |
| `combat.turn` | combat | enable/disable ability row; render "their turn" between-state |
| `combat.event` | combat | play attack/cast/hurt/heal/miss/die animation + juice (§8.7) keyed by actor/target id |
| `combat.end` | combat→map | outcome; win→`cheer`; route to loot overlay then map |
| `loot.grant` | combat/map | loot popup cards (§8.7); add to bag on collect |
| `merchant.open` | →merchant | mount merchant with stock + `closes_at`; transition |
| `merchant.stock` | merchant | live stock/price update |
| `merchant.close` | merchant→prev | close pocket, transition back |
| `camp.state` | camp | downtime slots, bastion/turret tier (drives turret sprite variant), away report |
| `veil.flicker` | all (overlay) | connection/GPS degrade states (§8.7.2/8.7.3) — amber/red dot, toasts, halo swell |
| `error` | all | diegetic toast; never a raw stack to a kid |

Client→server intents it emits (§3): `join.request`, `gps.update`, `intent.move`, `intent.equip`/`intent.use`, `combat.action`, `merchant.buy`/`merchant.sell`, `camp.command`, `ping`. Each is also invokable via `__sq.input`/`__sq.inject` so a bot client exercises the full duplex loop headlessly.

---

**Cross-references:** projection & entity rendering consume the §2 data model (`pos`, `accuracy_m`, `tier`, `band`, `cls`) and the §6 procgen decoration API unchanged; all UI updates are driven by the §3 messages tabulated in §8.9. Art geometry is owned entirely by `assets/manifest.json` (§8.5); the client contains no hard-coded sprite dimensions, frame counts, or subject lists — which is what makes "drop art, rebuild manifest, ship" a zero-code operation and what keeps the whole surface headlessly reproducible.

---

Notes for the orchestrator: this section is self-contained and slots in after §7. It assumes the Foundation Contract's §2 (data model), §3 (protocol), and §6 (procgen) exist and reuses their names; if those sections finalize different names for the messages/fields I referenced (e.g. `combat.event`, `accuracy_m`, `world_seed`, `player.cls`), the §8.9 table and §8.6/§8.4 code are the rename surface. Source inputs I conformed to: `docs/ART-DIRECTION.md` (32×32, one palette, integer scaling, hi-bit polish, PNG→SpriteKit), `assets/manifest.json` (6 subjects × ~10 states, 32×32 horizontal strips, `frame_size`/`frames`/`is_sheet`/`sha1`), `docs/DESIGN.md` + `docs/NORTH-STAR.md` (veil/tome fiction, server-authoritative, kid audience, snark-in-characters), `docs/MAP-DATA.md` (OSM + MapLibre + deterministic procgen), `docs/RIFT-BRIEF.md` (proximity bands, apprentice safety, merchants, downtime, camp/Bastion).

I have enough grounding in the project's fiction and vocabulary. No literal "Foundation Contract" text was included in my prompt (it's owned by sibling sections), so I synthesize a self-consistent contract vocabulary from the design docs (EP/RP/DP, Breach tiers Elder→Massive, classes, monsters, camp/Bastion, POI/NPC/merchant, fog/territory, turrets, downtime) and reference it by field. Here is the deliverable.

---

## 9. Testing, Fixtures & Autonomous Iteration

> **Status: implementation spec.** This section is a first-class deliverable, not a wishlist. Every capability here must be exercisable with **no human in the loop**: deterministic, seed-driven, and runnable from a single command surface. The organizing goal is that an automated build agent can change *any* system in the game, run a graded battery, and know — from data, not vibes — whether the change is good.

### 9.0 Contract symbols referenced (from earlier sections)

This section does not redefine the data model or protocol; it consumes them. Symbols used below and the section that owns them:

- **Data model (§2):** `World`, `WorldState`, `Character`, `Camp` (a.k.a. `Bastion`), `Breach` (a rift/encounter instance), `Monster`, `Item`, `Inventory`, `LootTable`, `POI`, `NPC`, `TerritoryCell` (fog/territory grid), `Turret`, `DowntimeJob`. Character carries `class ∈ {knight, ranger, mage}`, `level`, `hp/hpMax`, `ep` (Endurance), `rp` (Recovery), `dp` (Downtime), `stats{str,dex,mag,vit,sureHands}`, `gear`, `abilities`, `resist{fire,frost,shock,…}`.
- **Breach model (§2/§4):** `Breach.tier ∈ {1:Elder, 2:Lesser, 3:Greater, 4:Dire, 5:Massive}`, `Breach.depth` (floor index), `Breach.wave`, `Breach.state ∈ {sealed,open,collapsing}`.
- **WS protocol (§3):** client→server `c:hello, c:move, c:engage, c:action, c:loot, c:sell, c:buy, c:upgrade, c:downtime, c:extract`; server→client `s:welcome, s:snapshot, s:delta, s:combat, s:loot, s:error`. Envelope `{t, seq, ts, sid, ...}`, monotonically increasing `seq`.
- **Tunables (§4 combat, §5 economy):** the frozen tables `COMBAT.*` (e.g. `COMBAT.weakMult=1.5`, `COMBAT.resistMult=0.5`, `COMBAT.timedHitWindowMs`, `COMBAT.critMult`, `COMBAT.focusPerGoodHit`) and `ECON.*` (e.g. `ECON.goldPerTierClear[tier]`, `ECON.epPerKm`, `ECON.rpPerSleepHr`, `ECON.craftMs[recipe]`). These are the knobs the balance sim sweeps.

**Hard rule the whole game obeys, so testing is possible at all:** the server **sim** (state + pure reducers) is **DOM-free, GPS-free, wall-clock-free, and network-free** — per `CLAUDE.md`, it is the part carried to native. All nondeterminism enters through exactly two injected ports: a **`Clock`** and an **`Rng`**. If a reducer reaches for `Date.now()` or `Math.random()` directly, that is a test-harness bug and CI fails it (lint rule, §9.10).

---

### 9.1 Tooling & repository layout

**Stack (all pre-installable, no exotic deps):**

| Concern | Tool | Why |
| --- | --- | --- |
| Test runner | **Vitest** (TS-native; unit + integration) | Runs the `shared/` + `server/sim/` TS directly, plays with Vite/React, watch-mode + coverage built in. Test bodies stay framework-light so a bot/sim test reads like a unit test. |
| Assertions | `node:assert/strict` | Built-in. |
| Coverage | **Vitest coverage (v8)** | Gates in CI (≥85% on `server/sim` + `shared`). |
| WebSocket client (bots) | **`ws`** | The bots speak the real §3 protocol over a real socket. |
| Browser / vision capture | **`playwright-core`** (Chromium pre-installed, per `CLAUDE.md`) | Loads `prototype/index.html` with injected fake GPS + scripted state, screenshots. |
| Vision judge | **Claude Messages API**, image content block; model via `VISION_MODEL` env (default a Claude vision model) | Grades screenshots against a rubric (§9.9). Swappable. |
| Report output | plain CSV + JSON to `test/reports/` | Machine-readable so balance is tuned from data. |

**File layout under `/test` (and the sim it drives under `/src`):**

```
src/
  sim/                     # THE thing under test — pure, portable, no I/O
    world.js               # createWorld(), applyTick(), reducers
    combat.js              # resolveAction(), timed-hit/crit/weakness math (§4)
    economy.js             # loot rolls, gold, EP/RP/DP flows (§5)
    downtime.js            # DowntimeJob resolution
    territory.js           # fog reveal, TerritoryCell ownership, turrets
    ports.js               # Clock, Rng interfaces (the ONLY nondeterminism)
    codec.js               # (de)serialize WorldState  <-> save blob (§7 persistence)
  server/
    gameServer.js          # WS §3 endpoint; wraps sim; injectable ports for tests
test/
  harness/
    sim.js                 # SimHarness: in-process world + clock + rng + asserts
    server.js              # in-process ws server on ephemeral port for bot tests
    clock.js               # ManualClock (tick/advance)
    rng.js                 # SeededRng (splitmix64/xoshiro) + fork()
    bot.js                 # BotClient: scriptable agent over real ws
    vision.js              # Playwright capture + Claude rubric grader
    assertions.js          # game-specific matchers (assertLootDrop, assertTTK…)
  fixtures/
    registry.js            # fixture registry: request known states by id
    seeds.js               # canonical named seeds
    worlds/                # world blueprints (JSON)
    characters/            # per class × level presets
    encounters/            # Breach/monster-wave presets
    loot/                  # LootTable presets + expected-distribution goldens
    inventories/           # starting bags
    camps/                 # Bastion tiers
    pois/                  # POIs + NPC/merchant definitions
  unit/                    # fast, pure-sim tests (§9.3, §9.8)
    combat.test.js  economy.test.js  downtime.test.js  territory.test.js …
  integration/             # bot-over-ws tests (§9.5, §9.8)
    single-run.test.js  coop-two-bot.test.js  merchant.test.js …
  persistence/             # save→restart→load round-trips (§9.7)
    roundtrip.test.js  migration.test.js
  balance/                 # Monte-Carlo sweeps (§9.6) — SLOW tier
    knight-vs-tier3.bench.js  economy-flow.bench.js  runner.js
  vision/                  # Playwright + vision rubric (§9.9) — SLOW tier
    capture.js  screens.vision.js  rubric.md
  reports/                 # generated CSV/JSON (gitignored except goldens)
  golden/                  # committed expected distributions / snapshots
```

---

### 9.2 Headless sim harness

The harness runs the **server sim in-process** — no browser, no real socket, no real time. It is the fast inner loop; a full unit test completes in microseconds because nothing is async.

**Injected ports (`src/sim/ports.js`):**

```js
// Clock: the ONLY source of "now" and the tick counter.
export class ManualClock {
  constructor(startMs = 0) { this._ms = startMs; this._tick = 0; }
  now() { return this._ms; }                 // ms since epoch (fixed)
  tick() { return this._tick; }
  advance(ms) { this._ms += ms; }            // move wall time
  advanceTicks(n, tickMs = SIM.TICK_MS) {    // move sim time
    for (let i = 0; i < n; i++) { this._ms += tickMs; this._tick++; }
  }
}

// Rng: seeded, deterministic, FORKABLE so parallel subsystems don't
// perturb each other's stream (fork per Breach, per loot roll, per bot).
export class SeededRng {
  constructor(seed) { this.s = splitmix64_init(seed); }
  next() { return xoshiro256ss(this.s); }    // uint53 -> [0,1)
  int(nExclusive) { return Math.floor(this.float() * nExclusive); }
  float() { return this.next(); }
  pick(arr) { return arr[this.int(arr.length)]; }
  roll(chance) { return this.float() < chance; }
  fork(label) { return new SeededRng(hash64(this.seedTag, label)); } // named substream
}
```

**Why `fork`:** determinism must be *stable under refactor*. If loot and combat both draw from one global stream, adding a single combat roll shifts every downstream loot result and every golden test breaks spuriously. Each subsystem gets a **named substream** derived from `(worldSeed, label)`, so combat changes never move loot goldens and vice-versa. Fixtures pin the seed → the world is byte-reproducible.

**`SimHarness` API (`test/harness/sim.js`):**

```js
const h = SimHarness.create({
  seed: SEEDS.GREENFIELD,        // canonical named seed
  world: 'starter_grid_3x3',     // fixture id (§9.4)
  now:   Date.parse('2026-07-06T09:00:00Z'),
});

h.spawn.character('knight_L5');  // fixture id -> Character in world
h.spawn.breach('tier3_skeleton_wave', { at: [gx, gy] });

h.advanceTicks(20);              // drive sim time forward
h.dispatch('c:engage', { breachId, charId });   // apply a protocol intent
h.dispatch('c:action', { move: 'timed_attack', tapMs: 120 });

h.state();                       // deep-frozen WorldState snapshot for asserts
h.log();                         // ordered list of emitted s:* events
h.metrics();                     // derived: ttkRounds, potionsUsed, dmgDealt…
```

`dispatch` runs the **same reducer path** the real server (§9.5) uses — the WS layer is a thin transport over `applyIntent(state, intent, ports) -> {state, events}`. That guarantees unit tests and bot tests exercise identical game logic; only the transport differs.

**Assertion helpers (`test/harness/assertions.js`)** give tests domain vocabulary instead of poking raw state:

```js
assertTTK(h, { charId, breachId }, { maxRounds: 6 });
assertPotionsUsed(h, charId, { atMost: 2 });
assertLootContains(h.log(), { rarity: 'rare' });
assertResists(h.state(), monsterId, { frost: 1.5 /* weak */ });
assertGoldDelta(h, charId, ECON.goldPerTierClear[3]);
assertFogRevealed(h.state(), charId, { radiusCells: 2 });
```

---

### 9.3 Fixtures & the fixture registry

**Principle:** every test asks for a *known* state by id; no test hand-builds a world inline. The registry is the single source of canonical states, so a balance sweep, a bot integration test, and a persistence round-trip can all stand on `knight_L5` and mean the same thing.

**Canonical seeds (`test/fixtures/seeds.js`):**

```js
export const SEEDS = {
  GREENFIELD: 0xC0FFEE,   // empty-ish world, sunny path, for happy-path tests
  DENSE_URBAN:0xBADCAFE,  // many POIs, overlapping breaches, fog contested
  UNLUCKY:    0x000DEAD,  // rng tuned so loot/crit rolls sit low (worst case)
  LUCKY:      0x600DF00D, // high rolls (best case / drop-ceiling tests)
  COOP:       0x2B07,     // two-player start, shared breach
};
```

**Fixture families** (each a JSON blueprint + a loader that instantiates into `WorldState`):

- **Worlds** (`fixtures/worlds/*.json`): a `TerritoryCell` grid, seeded POIs/NPCs, spawn tables. `starter_grid_3x3`, `urban_dense`, `coop_shared_breach`, `convergence_late` (many linked breaches, per §Design convergence arc).
- **Characters** (`fixtures/characters/*.json`): the **cross-product `class × level`** at meaningful breakpoints — `{knight,ranger,mage} × {1,5,10,20,30}` — plus a few narrative presets (`knight_L5_full_potions`, `mage_L10_frost_build`, `ranger_L20_glass_cannon`). Each fixes `stats`, `gear`, `abilities`, `inventory`.
- **Encounters** (`fixtures/encounters/*.json`): `Breach` + monster waves keyed by tier and breed. `tier3_skeleton_wave`, `tier5_massive_mixed`, `tier1_slime_trio`, plus a **luck mini-game** encounter `trapped_chest` and a `fae_bargain` (per RIFT-BRIEF non-combat encounters).
- **Loot tables** (`fixtures/loot/*.json`): drop tables + a committed **golden distribution** (expected rarity histogram over N rolls) so a table edit that changes odds is caught (§9.6).
- **Inventories / camps** (`fixtures/inventories`, `fixtures/camps`): starting bags; `Bastion` at tiers 0–3 with their downtime-slot counts and turret loadouts.
- **POIs / NPCs** (`fixtures/pois`): a Warden Hut quest-giver, a wandering Merchant with a fixed stock+price list, a shrine (fae bargain).

**Registry API (`test/fixtures/registry.js`):**

```js
Registry.world('urban_dense');            // -> WorldState blueprint
Registry.character('mage_L10_frost_build');
Registry.encounter('tier3_skeleton_wave');
Registry.loot('breach_tier3');            // -> {table, golden}
Registry.list('characters');              // discoverability for param'd tests
```

Fixtures are **content, not code**: authored as JSON, validated on load against the §2 schema (a test `fixtures/_schema.test.js` asserts every fixture parses and round-trips through `codec.js`), so a data typo fails fast rather than mid-run.

---

### 9.4 Bot clients (real-protocol integration & multiplayer)

Bots are scriptable agents that connect to an **in-process real WS server** (`test/harness/server.js` boots `gameServer.js` on an ephemeral port with `ManualClock`+`SeededRng` injected) and play the game **only through §3 messages** — no reaching into sim state. This is the layer that proves the *protocol* and *multiplayer* work, not just the reducers.

**`BotClient` (`test/harness/bot.js`):**

```js
const bot = await BotClient.connect(serverUrl, { charId: 'knight_L5', seed });

// A bot is a scripted plan of protocol intents + awaited server events.
await bot.walkPath([[gx,gy], …], { speedMps: 1.4 }); // emits c:move ticks along a GPS polyline
await bot.engage(breachId);                            // c:engage, awaits s:combat
await bot.autoBattle({ strategy: 'timed', target: 'weakness' }); // loops c:action until s:combat end
await bot.lootAll();                                   // c:loot on each drop in s:loot
await bot.returnToCamp();
await bot.sell({ keep: ['relic'] });                   // c:sell to merchant NPC
await bot.upgradeCamp('turret_arrow');                 // c:upgrade
await bot.queueDowntime('brew_potion');                // c:downtime

bot.transcript();  // ordered {sent, recv} with seq — the assertion surface
```

**Design notes that make bots deterministic:**

- Bots never sleep on real time. `walkPath` emits `c:move` messages tied to `ManualClock` ticks; the test drives `clock.advanceTicks()` and the server processes queued moves per tick. GPS is **injected** (a polyline of lat/lng), never read from a device.
- Bot decisions (which target, whether to push deeper, block vs dodge) draw from the bot's **own forked Rng substream**, so a two-bot test is reproducible regardless of socket scheduling. The server tags each inbound intent with its `seq`; the sim applies intents in a **deterministic order** (`(tick, sid, seq)`), so message-arrival jitter can't change outcomes.
- **`strategy` presets** let one bot body cover many playstyles: `aggressive` (never blocks, always push depth), `cautious` (extract at 50% hp), `optimal_timed` (hits the `COMBAT.timedHitWindowMs` center), `kid_mode` (auto-battle, random taps — proves the "auto-battle always has a path" pillar).

**Two-bot co-op test (`integration/coop-two-bot.test.js`):** both bots connect to `coop_shared_breach`, walk to the same `Breach`, `c:engage` it jointly; the test asserts:
- both receive consistent `s:snapshot`/`s:delta` (shared world state converges — no split-brain),
- aggro/turn interleaving matches spec, kill credit and **loot are distributed per §5 rules** (no dup, no loss),
- one bot extracting mid-fight (`c:extract`) leaves the other in a valid solo state,
- the convergence/seal event fires once and only once (idempotent `s:combat:sealed`).

**The party-size matrix is mandatory.** Because solo *and* N-player are first-class, every combat/loot/map/UI behavior is exercised at **solo (1 bot)** *and* **party (2 and `PARTY_MAX` bots)**: `SimHarness`/`BotClient` take a `partyN`, and the integration + balance suites parametrize over `{1,2,4}`. This is where the §6.5.5 density scaler is proven — same seed, `partyN∈{1,4}` → garrison/`encounterTier` scale per formula and **per-hero** TTK holds within the §9.6 band, so auto-balance is a *tested guarantee*, not a hope.

---

### 9.5 System integration tests

Explicit, named coverage per subsystem. Fast ones run in-process on `SimHarness` (§9.2); protocol-facing ones run through `BotClient` (§9.4). Each row is a committed test.

| Subsystem | Test file | What it proves |
| --- | --- | --- |
| **POI interaction** | `integration/poi.test.js` | Walking within `POI.radius` fires `s:delta` reveal; interacting starts the right encounter/quest; out-of-range or `unsafe/inaccessible` POIs correctly offer only ranged/apprentice paths (safety pillar). |
| **NPC / merchant** | `integration/merchant.test.js` | `c:buy`/`c:sell` respect `ECON` prices, stock limits, and gold balance; buying with insufficient gold returns `s:error` and mutates nothing; Warden Hut hands out and completes a quest; the dice/three-card luck game resolves from seeded rng. |
| **Inventory ops** | `unit/inventory.test.js` | equip/unequip updates derived stats; stack merge/split; capacity limits; drop/destroy; craft consumes inputs and produces output; no item duplication under concurrent ops. |
| **Combat outcomes** | `unit/combat.test.js` | weakness → `×1.5` and **Breach! extra action** (§4 pattern B); resist → `×0.5`; crit on centered timed tap; Focus meter charge/spend; frozen enemy drops telegraph; death → wake-at-camp with the §5 penalty; auto-battle resolves at trained `sureHands` rate. |
| **Territory / fog** | `unit/territory.test.js` | movement reveals `TerritoryCell`s within radius; fog persists across save/load; territory ownership flips on breach-seal; contested cells in `urban_dense`. |
| **Turret behavior** | `unit/turret.test.js` | camp `Turret` auto-fires at in-range monsters on tick, respects cooldown/ammo, prioritizes per spec, and defends camp during an assault event; upgraded turret changes rate/damage per `ECON`. |
| **Downtime resolution** | `unit/downtime.test.js` | `DowntimeJob` completes only after `ECON.craftMs` of **sim** time elapses (drive `advanceTicks`), yields the right output + RP/DP, respects `Bastion` slot count, and **resolves correctly across an app-closed gap** (advance clock by hours, then reconnect — the away-progress path). |

Every integration test asserts on **emitted events + resulting state**, never internal timers, so they stay valid as internals change.

---

### 9.6 Balance simulation (Monte-Carlo, data-out)

The point of balance sims: **tune `COMBAT.*`/`ECON.*` from data, headlessly.** Each sweep runs thousands of seeded fights/economy-cycles on `SimHarness` (fast, in-process, no socket) and emits CSV+JSON to `test/reports/`.

**Runner shape (`test/balance/runner.js`):**

```js
export function sweep({ name, trials, seedBase, setup, play, measure }) {
  const rows = [];
  for (let i = 0; i < trials; i++) {
    const h = SimHarness.create({ seed: seedBase ^ i, ...setup() });
    play(h);                          // scripted engagement
    rows.push(measure(h));            // -> {win, ttkRounds, potions, dmgTaken, goldOut}
  }
  writeCsv(`reports/${name}.csv`, rows);
  writeJson(`reports/${name}.summary.json`, summarize(rows)); // mean, p50/p90, winRate
  return summarize(rows);
}
```

**Flagship scenario — "L5 knight vs Tier-3 breach" (`balance/knight-vs-tier3.bench.js`):**

```js
const s = sweep({
  name: 'knight_L5_vs_tier3',
  trials: 5000,
  seedBase: SEEDS.GREENFIELD,
  setup: () => ({ world: 'starter_grid_3x3' }),
  play: (h) => {
    h.spawn.character('knight_L5');
    h.spawn.breach('tier3_skeleton_wave');
    h.autoResolveCombat({ strategy: 'optimal_timed' });
  },
  measure: (h) => {
    const m = h.metrics();
    return { win: m.win, ttkRounds: m.ttkRounds, potions: m.potionsUsed,
             dmgTaken: m.dmgTaken, focusSpends: m.focusSpends };
  },
});
// Emits e.g.: winRate 0.83, ttk p50 4 / p90 7 rounds, potions mean 1.4
```

**Balance targets are asserted as guardrails**, so a tuning change that pushes a matchup out of band **fails CI** — the sim is both a report generator and a regression gate:

```js
assert(s.winRate  >= 0.75 && s.winRate <= 0.90, 'tier3 should be tense-but-winnable for L5');
assert(s.ttk.p90  <= 8,   'fights must stay in the 3–5 round band, tail ≤ 8');   // COMBAT-STUDY constraint
assert(s.potions.mean <= 2.0, 'not a potion-attrition slog');
```

**Standard sweep matrix** (a build agent runs the whole grid after any `COMBAT`/`ECON` edit):

- **Combat:** every `class × level` fixture vs every `tier` **× party size {1,2,4}** → win-rate / TTK / potions surface. Both `UNLUCKY` and `LUCKY` seeds to bound variance. Guardrail: the §6.5.5 density scaler must keep **per-hero** TTK in band across party sizes (auto-balance holds solo→group).
- **Economy flow (`balance/economy-flow.bench.js`):** simulate N days of the core loop (walk→EP, sleep→RP, downtime→craft, run→gold/loot, spend) and report **currency inflation/starvation** — does gold/EP/RP trend to a healthy band or run away? Emits `econ_flow.csv` (per-day balances).
- **Loot distribution:** roll each `LootTable` 100k times, diff the rarity histogram against the committed **golden** (`test/golden/loot/*.json`); fail on drift beyond a tolerance (chi-square). This is how a stealth odds change gets caught.
- **Push-your-luck curve:** simulate extract-vs-push decisions across depths to check the greed curve (per RIFT-BRIEF "just one more floor") produces the intended risk/reward slope.

Reports are the artifact a human (or the agent) reads to *decide* a tune; the guardrail asserts stop bad tunes from merging.

---

### 9.7 Persistence tests (save → restart → load)

Proves world/character/camp survive a process restart, and that saves tolerate schema evolution.

**Round-trip (`persistence/roundtrip.test.js`):**

```js
const h1 = SimHarness.create({ seed: SEEDS.DENSE_URBAN, world: 'urban_dense' });
h1.spawn.character('ranger_L20_glass_cannon');
h1.spawn.breach('tier5_massive_mixed');
h1.advanceTicks(200);
h1.dispatch('c:engage', …); h1.dispatch('c:loot', …);
h1.queueDowntime('brew_potion');            // an in-flight timed job

const blob = codec.serialize(h1.state());   // the on-disk save (§7 format)

// Simulate a full restart: brand-new process, nothing shared but the blob.
const h2 = SimHarness.fromSave(blob, { clock: h1.clock, rng: h1.rng });

assert.deepEqual(codec.serialize(h2.state()), blob);      // byte-stable round-trip
assertFogRevealed(h2.state(), charId, /* preserved */);
assertInventoryEqual(h1.state(), h2.state());
// Advance the RESTORED world; the in-flight DowntimeJob must still complete correctly:
h2.advanceTicks(ECON.craftMs.brew_potion / SIM.TICK_MS);
assertItemGained(h2.state(), charId, 'potion');
```

Asserted invariants: **character** (stats/gear/abilities/EP/RP/DP), **camp/Bastion** (tier, turrets, downtime queue with elapsed time preserved), **world** (fog/territory ownership, active breaches with `depth`/`wave`/`state`, POI/quest progress), and **rng position** (so post-load rolls continue the same stream, not reset — otherwise loot becomes save-scummable).

**Migration tolerance (`persistence/migration.test.js`):**

- Saves carry a `schemaVersion`. `codec.deserialize` runs an ordered chain of `migrate_vN_to_vN+1` functions. The test loads **committed old-version fixture saves** (`test/golden/saves/v1.json`, `v2.json`, …) and asserts they upgrade to current without loss and without throwing.
- Forward-compat rule (documented, tested): unknown fields are **preserved**, not dropped, so a save written by a newer client survives a round-trip through an older one where possible; a `schemaVersion` newer than the code refuses with a clear error rather than corrupting.
- Every schema change to §2 **must** add a migration + a golden save, enforced by a test that fails if `schemaVersion` bumped without a new `golden/saves/vN.json` and a `migrate_` fn.

---

### 9.8 Vision-based design feedback loop

Numbers don't tell you if a screen is *readable at phone size* or if the pixel art reads at map-pin scale. This loop closes that gap **without a human**: drive the client headlessly, screenshot every surface, and have a **vision model** grade each shot against a rubric. It runs in the SLOW tier (§9.10).

**Capture (`test/harness/vision.js`, Playwright/Chromium):**

```js
const cap = await VisionCapture.launch({
  file: 'prototype/index.html',
  viewport: { width: 390, height: 844, deviceScaleFactor: 3 }, // iPhone-class, real DPR
});

// Inject determinism the same way the sim does: fake GPS + scripted state.
await cap.injectGPS([37.77, -122.41]);
await cap.injectState(Registry.character('knight_L5'),
                      Registry.world('urban_dense'),
                      { seed: SEEDS.DENSE_URBAN });

for (const screen of ['map','breach-approach','combat-round','combat-crit',
                       'inventory','merchant','camp','downtime','loot-reward']) {
  await cap.goto(screen);                 // drives the client to that view via injected state
  await cap.screenshot(`reports/vision/${screen}.png`);
  // A second shot at map-pin scale to test pixel-art legibility when tiny:
  if (screen === 'map') await cap.screenshotRegion('pin', `reports/vision/pin-scale.png`);
}
await cap.captureThumbHeatmap('reports/vision/reach.png'); // overlays a thumb-reach arc
```

Injection reuses the sim's port trick: the client reads state and GPS from injectable globals, so a scripted `WorldState` + a fixed seed produces the **exact same frame every run** — screenshots are reproducible, diffable, and gradeable.

**The rubric (`test/vision/rubric.md`)** — each screen scored 1–5 per axis, with an explicit fail floor:

| Axis | What the judge checks | Fail if |
| --- | --- | --- |
| **Readability @ phone size** | Core numbers (HP, tier, gold, damage) legible at 390px without zoom | Any load-bearing text unreadable |
| **Thumb reach** | Primary actions inside the bottom-third reachable arc; no critical tap in the top corners | A primary action out of one-thumb reach |
| **Pixel-art legibility @ pin scale** | Monster/POI sprite distinguishable at map-pin size (~24–32px) | Two breeds indistinguishable when tiny |
| **Juice / feedback** | Hits, crits, loot have visible feedback (flash, pop, "Breach!") | A key action has no visual response |
| **Tone** | Reads as the intended fantasy-veil aesthetic, kid-friendly, not sterile/hostile | Off-tone (clinical, grimdark, corporate) |
| **Contrast / a11y** | Text-on-background contrast adequate; not color-only signaling | Fails contrast or color-only weakness cue |
| **Craft & cohesion (Glory system)** | Passes the ART-DIRECTION.md checklist: every container a chamfered plate with a hairline, **one** panel language, arcane teal only on magic/veil, hand-set Cinzel/Alegreya type (no sans/system body), hero sprite unframed, Material Symbols icons, colors only from the DESIGN-SYSTEM.md tokens | Plain rounded "web" cards, a second panel style, teal as a default accent, sans/system body font, a boxed hero portrait, emoji/SVG icons, or off-token colors |

**Grading call (Claude Messages API, image block):** each screenshot is sent with the rubric and the screen's *intent* ("this is the combat crit frame; the crit must feel rewarding") to `VISION_MODEL`. The model returns **structured JSON**, not prose:

```json
{ "screen": "combat-crit", "scores": {"readability":5,"thumbReach":4,
  "pixelLegibility":3,"juice":2,"tone":4,"contrast":5,"cohesion":4},
  "fails": ["juice"], "notes": "Crit lands with no screen-shake or damage-pop; reads identical to a normal hit." }
```

**Pass/fail signal:** the vision suite **fails** if any axis on any screen scores `< 3` *or* returns a `fails[]` entry. Non-fatal `notes` are aggregated into `reports/vision/findings.md`.

**How findings feed iteration:** the run emits (a) the `findings.md` digest and (b) a machine-readable `reports/vision/scores.json`. A build agent treats a vision fail as a **blocking finding with a concrete fix target** ("add crit screen-shake + damage-pop to `combat-crit`"), applies a change, and re-runs the single failing screen (`--screen=combat-crit`) for a tight loop. Scores are trended over commits (`reports/vision/history.csv`) so regressions in "juice" or "legibility" are visible, and a **golden score baseline** prevents silent visual decay. Because grading is deterministic-input (fixed seed/state) but model-judged, we keep a small human-audited calibration set to catch judge drift, but no human is in the per-run loop.

---

### 9.9 CI / dev loop & definition-of-done gates

**Command surface (`package.json` scripts):**

```jsonc
{
  "scripts": {
    "dev":             "concurrently \"tsx watch server/main.ts\" \"vite\"",  // server + client dev
    "build":           "tsc -p tsconfig.json && vite build",                  // server typecheck + client bundle
    "start":           "tsx server/main.ts",                                  // prod: Hono serves web-assets + WS
    "test":            "vitest run test/unit test/persistence",               // FAST: pure sim
    "test:unit":       "vitest run test/unit",
    "test:persist":    "vitest run test/persistence",
    "test:integration":"vitest run test/integration",                        // MED: bots over ws
    "test:coverage":   "vitest run --coverage",                              // v8 coverage, gate in vitest.config
    "balance":         "tsx test/balance/runner.ts --all",                   // SLOW: Monte-Carlo
    "balance:quick":   "tsx test/balance/runner.ts --trials 500",            // smoke of the sweep
    "vision":          "tsx test/vision/screens.vision.ts",                  // SLOW: Playwright + judge
    "lint:purity":     "tsx tools/check-sim-purity.ts",                      // no Date.now/Math.random in server/sim
    "ci:fast":         "npm run lint:purity && npm run test && npm run test:integration",
    "ci:full":         "npm run ci:fast && npm run test:coverage && npm run balance && npm run vision"
  }
}
```

**Fast vs slow tiers:**

- **Fast (seconds):** `lint:purity`, `test` (unit + persistence), `test:integration`. Pure in-process sim and in-process ws; no browser, no network, no model. Run on **every commit / pre-push**.
- **Slow (minutes):** `balance` (thousands of trials) and `vision` (Chromium launch + model calls). Run on **PR / nightly** and after any `COMBAT`/`ECON`/UI change.

**`lint:purity` (`tools/check-sim-purity.js`):** greps `src/sim/**` for `Date.now`, `Date(`, `Math.random`, `performance.now`, `setTimeout`, `WebSocket`, `fetch`. Any hit fails the build — this is what *keeps the game testable* over time and is the cheapest, first gate.

**Definition-of-done gates an automated build agent must pass to merge a change:**

1. `lint:purity` clean — sim stayed deterministic.
2. `test` + `test:integration` green — no behavior/protocol/persistence regression.
3. `test:coverage` ≥ 85% lines on `src/sim` (the carried-to-native core).
4. If `COMBAT.*`/`ECON.*`/loot tables changed → `balance` within all guardrail bands (§9.6) and loot goldens within tolerance.
5. If any client/UI/art changed → `vision` has no axis `< 3` and no `fails[]` (§9.8).
6. Reports (`test/reports/*`) attached to the change so the tune is auditable.

An agent's inner loop is therefore: **edit → `ci:fast` (seconds) → if touching balance/UI, targeted `balance:quick` / `vision --screen=X` → full `ci:full` before merge.** With the fixture registry, seeded RNG, injectable clock, bot clients, data-out balance sweeps, and the vision judge all in place, the developer (human or agent) can iterate on the *entire* game — combat math, economy, protocol, persistence, and even visual feel — with **no human in the loop** and a clear, data-backed definition of done.

---

**Key files for the reader/implementer (all absolute):**
- Harness: `/home/user/SideQuestAppV2/test/harness/{sim,server,clock,rng,bot,vision,assertions}.js`
- Fixtures + registry: `/home/user/SideQuestAppV2/test/fixtures/`
- Sim under test (must stay pure): `/home/user/SideQuestAppV2/src/sim/`
- Balance sweeps + reports: `/home/user/SideQuestAppV2/test/balance/`, `/home/user/SideQuestAppV2/test/reports/`
- Vision rubric: `/home/user/SideQuestAppV2/test/vision/rubric.md`

## 10. Implementation Roadmap (build order)

> **Owner: DELIVERY LEAD.** This section sequences the whole build (§1–§9) into milestones that each map 1:1 to a GitHub sub-issue with a binary pass/fail. The ordering law is **spine first, then depth fastest-to-kids** — every milestone is a thin *vertical slice* that leaves `main` deployable and demoable, never a horizontal layer (no "build all of persistence," no "build all of combat"). Each milestone names the headless fixture and/or vision check that closes it, and flags whether it can be proven **HEADLESS** (bot/sim/CI, no phone) or needs **ON-DEVICE** GPS in the forest.
>
> **Convention.** `[HEADLESS]` = provable in CI with no human, no phone. `[DEVICE]` = requires a real phone with GPS outdoors (the only human-in-loop gate). `[VISION]` = provable by the §9.8 screenshot-critique loop. Milestones marked **∥ PARALLEL** can be built by an independent agent against the frozen §1–§3 contract simultaneously with their siblings; **→ SEQUENTIAL** must land after their stated dependency.

---

### 10.0 The dependency spine (read this first)

Everything hangs off three frozen artifacts that must exist before any depth work starts: the **§1–§3 contract** (module tree, data model, protocol), the **`shared/` sim core** (I/O-free, clock+seed injected), and the **test harness** (`SimHarness`, `BotClient`, `ManualClock`, `SeededRng`). M0 delivers all three. Until M0 is green, **no other milestone may start** — they would build against an unfrozen contract and churn.

```
M0 scaffold+boot+deploy+harness  ──► FROZEN CONTRACT (§1–§3) + green CI
      │
      ▼
M1 shared GPS map (two clients see each other move)      ◄── FIRST FOREST TEST floor begins
      │
      ▼
M2 breaches + co-op combat + seal + persistence          ◄── FIRST FOREST TEST cut line
      │
      ▼
M3 loot + XP + level-up
      │
      ├──► M4 inventory + merchant        ∥
      ├──► M5 class abilities + Focus/Breach   ∥   (all M4–M9 are parallelizable
      ├──► M6 monster flee/chase (GPS)    ∥         once M3 lands — they touch
      ├──► M7 camp + auto-turret + downtime ∥        disjoint systems/ files
      ├──► M8 territory + escalation/convergence ∥    behind the frozen contract)
      ├──► M9 POI/NPC/dialogue            ∥
      └──► M-ART manifest art pipeline    ∥  (can start at M0; blocks nothing)
                        │
                        ▼
              M10 vision polish + juice pass  (last; needs the screens to exist)
```

---

### 10.1 M0 — Scaffold, boot, deploy, harness green

**Goal:** the empty machine works end-to-end — server boots on Fly, a client connects over `wss`, the headless harness runs green — so every later milestone builds on a proven, deterministic, deployable base.

**Scope**
- Repo skeleton exactly per §1.2 (`server/ shared/ web/ tools/ test/`), `package.json` (`type:module`, `engines.node>=22`, deps `ws`, `better-sqlite3`; dev `playwright-core`, `prettier`).
- `server/main.js` boot chain (§1.3): `config → db(open+migrate) → World.create(seed,origin) → loop → http → gateway → listen → autosave → SIGTERM save`. World can be empty; the loop just ticks.
- `shared/`: `protocol.js` (OP enum + JSON `encode/decode`), `rng.js` (seeded mulberry32 + `hashSeed`), `geo.js` (meter helpers + placeholder equirectangular `project/unproject`), `constants.js`, `entities.js` factory stubs, `tuning.js` stub.
- `server/http.js` static server + `GET /healthz`; `server/net/gateway.js` WS upgrade on `/ws` with `join`→`hello`→`snapshot` (snapshot may be near-empty) and ping/pong heartbeat.
- `web/index.html` + `js/main.js` + `js/net.js`: join screen (name + class), connect, receive `hello`, draw "connected" on canvas. No map yet.
- `Dockerfile` + `fly.toml` + volume (§1.6); first `fly deploy`.
- Harness: `test/harness/{sim-harness,clock,bot-client}.js`; `test/fixtures/seeds.js`; `tools/check-sim-purity.ts` (lint: no `Date.now`/`Math.random` in `sim/`+`shared/`); **Vitest** wired; `npm run ci:fast`.

**Files touched:** the whole §1.2 tree (stubs), heavy on `server/main.js`, `shared/protocol.js`, `test/harness/*`, `Dockerfile`, `fly.toml`.

**Dependencies:** none. **This is the root. → SEQUENTIAL (blocks all).**

**Definition of done (pass/fail)**
- `[HEADLESS]` `test/integration/boot.test.js`: `SimHarness.create({seed:SMOKE})` builds a World; `loop.tickManual` advances the tick counter deterministically; two runs with the same seed produce byte-identical `world.serialize()`.
- `[HEADLESS]` `test/integration/connect.test.js`: `BotClient` connects to an in-process gateway, sends `join`, receives `hello{characterId,seed,origin,tickHz}` then `snapshot`; heartbeat `ping`→`pong` round-trips.
- `[HEADLESS]` `npm run lint:purity` green (sim purity enforced from commit 1).
- `[DEVICE-lite]` `curl https://sidequest-poc.fly.dev/healthz` → 200; a phone browser loads the join screen and reaches "connected". (No GPS needed — this is just reachability.)
- CI (`ci:fast`) green on `main`.

---

### 10.2 M1 — Shared GPS map: two clients see each other move in real time

**Goal:** two phones in the same world watch each other's avatars move across the procedural map in real time — the shared-world "we're in the same place" proof.

**Scope**
- Client `geo-projection.js`: `watchPosition` → throttle ≤2 Hz → `gps{lat,lng,accuracy}`; render self from server-confirmed pos (§3.6), never raw GPS.
- Server `systems/movement.js` (player half only): project `gps`→meters, exponential smoothing + max-speed clamp; store `pos`, `gpsAccuracy`.
- Broadcast: `delta` at 5 Hz with in-range `players` upserts (§3.4); `store.js` interpolation buffer (§3.6) for remote players; accuracy halo render.
- `render/camera.js` + `render/map.js`: minimal procgen fantasy overlay (§6 `hashCell` terrain tint + a few props) so movement has a legible ground; follow-cam.
- Real projection from §6 swapped in behind `shared/geo.js` (placeholder retired) — sim/protocol unchanged.

**Files touched:** `web/js/{geo-projection,store,render/camera,render/map,render/hud}.js`, `server/sim/systems/movement.js`, `server/net/outbound.js`, `shared/geo.js`.

**Dependencies:** M0. **→ SEQUENTIAL** (first slice on the spine). Procgen depth (§6 biomes/POI lattice) can proceed **∥** as M-ART/M9 feed it, but M1 only needs terrain tint.

**Definition of done**
- `[HEADLESS]` `test/integration/two-bot-move.test.js`: two `BotClient`s join `TWO_PLAYER` seed; bot A feeds a scripted lat/lng track; assert bot B receives A's `delta` position updates, smoothed (path length ≤1.3× true, §6.8 `assertGpsTolerance`), within the 200 m relevance window.
- `[HEADLESS]` `assertGeoRoundTrip` + `assertOriginIndependence` (§6.8): projection lossless at play scale; origin never perturbs procgen.
- `[VISION]` map screenshot at phone size: self avatar + accuracy halo + one remote avatar legible (§9.8 `02-map`).
- `[DEVICE]` **Forest check (the real one):** two phones in the 40-acre forest, each sees the other's avatar move as they walk apart and back, with the fuzzy halo reading as "the veil is fuzzy," not broken. This is the only step that *requires* the woods.

---

### 10.3 M2 — Breaches + co-op combat + seal + persistence

**Goal:** the two kids find a breach, fight its monsters together, seal it, and that sealed state survives a server restart — the full co-op spine in one slice.

**Scope**
- `systems/spawns.js`: deterministic breach lattice from `WORLD_SEED` (§6.4), garrison spawn on engage.
- `systems/breach.js`: `engage` (in-radius) → `encounterOpen`; seal HP depletion via combat; `state: open→sealing→sealed`; `sealBreach`.
- `systems/combat.js`: **minimum viable** turn-based command-relay (§4.1) — basic attack + guard + flee, simultaneous submit + auto-fill at deadline, initiative order, `encounterUpdate`/`encounterEnd`. (Abilities/Focus/Breach deferred to M5; keep the flow, stub the depth.)
- Co-op: shared `Encounter`, per-member HP, downed/`party_wipe`→wake-at-camp stub (§4.6).
- Persistence: `persistence/{db,schema.sql,repo}.js` — save/load `world_meta`, `character`, `breach`; autosave + forced save on seal; load-on-boot rehydrates sealed breaches; runtime monsters respawn from seed.

**Files touched:** `server/sim/systems/{spawns,breach,combat}.js`, `server/sim/commands.js`, `server/persistence/*`, `web/js/render/hud.js` (combat UI), `web/js/input.js`, `shared/tuning.js` (combat + spawn numbers).

**Dependencies:** M1. **→ SEQUENTIAL.** Combat-rule depth (§4) and procgen breach-lattice tuning (§6) are frozen-interface, so a combat agent and a world agent can co-develop the internals **∥** as long as `encounter*`/`breach*` message shapes hold.

**Definition of done**
- `[HEADLESS]` `test/integration/coop-seal.test.js`: two bots engage one breach on `TWO_PLAYER` seed, both submit attacks each round, garrison dies, `veilHP≤0` → `breachUpdate{state:'sealed'}` fires **once** (idempotent); both bots credited.
- `[HEADLESS]` `test/persistence/roundtrip.test.js`: seal breach → `repo.save` → `SimHarness.fromSave(blob)` → sealed breach still sealed, character HP/pos preserved, RNG cursor continues (not save-scummable); untouched breaches carry no DB row (`assertPersistenceMinimal`, §6.4.2).
- `[HEADLESS]` `assertGarrisonDeterminism`: same breach → identical garrison for both bots.
- `[DEVICE]` **Forest check:** both kids walk to a breach, fight it together on their phones, see it seal; developer restarts the Fly machine (`fly apps restart`); kids reload — the breach is still sealed and their characters intact.

---

### 10.4 M3 — Loot, XP, level-up

**Goal:** sealing a breach and killing monsters pays out — loot drops, XP accrues, characters level up — so the core reward loop closes and every later depth system has something to hang on.

**Scope**
- `systems/loot.js`: per-kill gold/materials/gear rolls (§5.10) via seeded substream; `lootResult`/`encounterEnd.loot`; chest POI loot (basic, no pry-game yet).
- XP + level: `addXp`, geometric curve `XP_GROWTH=1.45` (§5.2); `encounterEnd.levelUp`; stat growth per level; full-heal on ding.
- Item schema (§5.5) minted with stable ids + roll seed; rarity roll by breach tier (§5.10 table); `inventoryUpdate` on drop.
- Persistence extended: `character.inventory/xp/level/gold` saved.

**Files touched:** `server/sim/systems/loot.js`, `server/sim/commands.js`, `shared/{entities,tuning}.js`, `web/js/render/hud.js` (XP bar, loot popup), `server/persistence/repo.js`.

**Dependencies:** M2. **→ SEQUENTIAL** (depth systems M4–M9 all consume Item/XP shapes minted here). After M3, **the tree fans out.**

**Definition of done**
- `[HEADLESS]` `test/balance/loot-distribution.spec`: roll each tier's table 100k times; rarity histogram matches §5.17 `RARITY_ODDS` within ±0.3% vs committed golden.
- `[HEADLESS]` `same_seed_same_loot.spec`: identical `(runSeed,playerId,dropIndex)` → byte-identical item.
- `[HEADLESS]` `test/unit/xp.test.js`: kill payouts advance level per the curve; `power_monotonic.spec` (item power rises with rarity/upgrade — arrows never lie).
- `[VISION]` loot-reward + level-up screens score ≥3 on all axes (§9.8).

---

### 10.5 M4–M9 — Depth (all ∥ PARALLEL after M3)

> These six milestones touch **disjoint `systems/` files and disjoint client panels** behind the frozen §1–§3 contract, so six independent agents can build them concurrently. Shared touch-points (`tuning.js`, `commands.js` dispatch table, `schema.sql`) are append-only — coordinate via additive PRs, never rewrites. Ordering *within* the fan-out is by kids-fun payoff: M4 (spend gold) and M6 (chase — the visceral GPS thrill) first; M5, M7, M8, M9 as capacity allows.

#### M4 — Inventory & merchant `∥`
**Goal:** kids manage their pack and buy/sell with a wandering merchant.
**Scope:** `ui/inventory` + `ui/merchant` panels; `equip`/`merchant` intents; `systems/loot.js` merchant transactions (§5.15); merchant POI spawn + stock roll; forge basics (sharpen/fortify) deferred-linked to M7 camp.
**Files:** `web/js/ui/{inventory,merchant}.js`, `server/sim/systems/loot.js`, `shared/tuning.js` (item/price catalog).
**DoD:** `[HEADLESS]` `test/integration/merchant.test.js` — bot buys (gold debits, insufficient-gold → `err`, no mutation), sells at `SELL_RATE`, equips (stats change); `economy_balance.spec` gold stays positive-bounded over an L1→L15 bot arc. `[VISION]` merchant + inventory screens ≥3.

#### M5 — Class abilities + Focus/Breach `∥`
**Goal:** Knight/Ranger kits that look and feel cool (the "annoyed it's not the full game" lever).
**Scope:** full §4.2 ability ladders, Focus meter, Breach! extra-action (§4.1), timed-tap Strike/Guard with auto-fallback; `useAbility`; ability→sprite-state mapping (§8.4.4).
**Files:** `server/sim/systems/combat.js`, `shared/tuning.js` (`SQ_COMBAT_CONSTANTS`), `web/js/render/hud.js` + `input.js`.
**DoD:** `[HEADLESS]` `test/unit/combat.test.js` — weakness→×1.5+Breach chain (capped), perfect tap→crit+Focus, auto path deterministic off PRNG; `test/balance/knight-vs-tier3.bench.js` win-rate 0.75–0.90, TTK p90 ≤8 rounds (guardrails fail CI if breached). `[VISION]` combat-crit frame shows juice (fails if crit reads identical to normal hit).

#### M6 — Monster flee/chase (GPS) `∥`
**Goal:** monsters that flee when low (you physically pursue) and scary elites that chase you — the outdoor-movement thrill.
**Scope:** `systems/movement.js` monster steering (approach/flee/pursue); §4.5 wire messages (`MonsterFled/PursuitTick/MonsterEscaped`, `ChaseBegin/ChaseTick/ChaseCaught/ChaseConsequence`); map blips.
**Files:** `server/sim/systems/movement.js`, `web/js/render/map.js`, `shared/tuning.js` (flee/chase constants).
**DoD:** `[HEADLESS]` `test/integration/pursuit.test.js` — scripted GPS track drives a low-HP goblin to flee, bot walks into `PURSUIT_REBIND_M`, encounter resumes at frozen HP; wraith-elite chase catches a stationary bot → ambush; deterministic tick sequence. `[DEVICE]` **Forest check:** a kid physically chases a fleeing monster across the woods and re-corners it; a chasing wraith forces an ambush if ignored.

#### M7 — Camp + auto-turret + downtime `∥`
**Goal:** the party raises a Bastion, an auto-turret defends it while they're away, downtime jobs craft overnight.
**Scope:** §7 Party/Bastion model; `campAction` (place/upgrade/build/refuel); `systems/camp.js` turret targeting/fire (event-stepped, one resolver for live+away, §7.7.5); downtime queue + `resolveAway` single settle-point; wake-at-camp anchor.
**Files:** `server/sim/systems/camp.js`, `server/persistence/{schema.sql,repo.js}` (camp table), `web/js/ui/camp.js`, `shared/tuning.js`.
**DoD:** `[HEADLESS]` `test/unit/turret.test.js` — advance virtual clock hours; turret culls a light incursion (hold=100), runs dry under a heavy one (dormant, hold<100, `incursionLevel++`); `test('live tick == offline resolve')` (§7.10 determinism keystone); two bots racing `session/resume` credit spoils exactly once (idempotent cursor). `[VISION]` camp diorama + turret variant ≥3.

#### M8 — Territory + escalation/convergence `∥`
**Goal:** sealing claims territory and clears fog; ignored breaches escalate and darken the map — visible shared-world consequence.
**Scope:** §6.5 escalation-as-clock-function, respawn, spread (persistent children), fog/claim math; global `convergence.C`; `world.snapshot` breach deltas.
**Files:** `server/sim/systems/{breach,spawns}.js`, `web/js/render/map.js` (fog/darken), `shared/tuning.js`.
**DoD:** `[HEADLESS]` `assertEscalationFormula` (§6.8) — client prediction == server at `ESC_PERIOD` boundaries; sealed breach reopens after `RESPAWN_COOLDOWN` at e0; forcing e≥3 spawns exactly one deterministically-placed child; sealed breach brightens fog, ignored high-e breach darkens it.

#### M9 — POI/NPC/dialogue `∥`
**Goal:** fixed visitable places with snarky NPCs, quest-givers, and chest push-your-luck.
**Scope:** §6.6 POI lattice + `POIState`; `interact`/`dialogue`; Warden Hut quest flags; §5.10 `pryChest` trapped-chest mini-game.
**Files:** `server/sim/systems/{spawns,loot}.js`, `web/js/ui/` (dialogue overlay), `shared/tuning.js` (dialogue tables, chest tiers).
**DoD:** `[HEADLESS]` `test/integration/poi.test.js` — bot enters `interactRadius` → `dialogue`; quest completes and persists across reload; `pry_ev.spec` — pry EV curve is single-peaked (a real optimal stop exists). `[VISION]` dialogue screen tone check (snark reads warm, not grimdark/corporate).

#### M-ART — Manifest art pipeline `∥` (can start at M0)
**Goal:** new sprites slot in with zero code changes.
**Scope:** §1.7/§8.5 — `tools/pack-sprites.mjs` (manifest→`web/assets`); `render/sprites.js` fully manifest-driven; 9-state vocabulary + missing-state fallback (`cast→attack→idle`); PNGs served as files with `sha1` cache-bust.
**Files:** `tools/pack-sprites.mjs`, `web/js/render/sprites.js`, `server/http.js` (asset MIME + cache headers).
**Dependencies:** none beyond M0's tree — **blocks nothing, unblocks polish.** **∥ from the start.**
**DoD:** `[HEADLESS]` `test/unit/sprites.test.js` — drop a new subject dir + rebuild manifest → `SPRITES[newSubject]` indexed with no code diff; a `combat.event` naming an absent state falls back without throwing. `[VISION]` all sprite states render integer-scaled, crisp, at combat and map-pin scale.

---

### 10.6 M10 — Vision-based polish & juice pass (last)

**Goal:** the whole game *feels* good on a phone — readability, thumb-reach, juice, tone — graded by the §9.8 vision loop and fixed until every screen passes.

**Scope:** run the full screenshot battery (`01-join`…`09-offline` + combat-crit + loot + level-up + camp + merchant + dialogue) through the Claude-vision rubric; fix every axis scoring <3 or in `fails[]`: hit-flash, floating damage, screen-shake (reduced-motion aware), HP-drain ghosting, rarity glow, level-up flourish, rift shimmer, connection/GPS degrade states ("the veil flickers").

**Files:** `web/js/render/*`, `web/css/app.css`, `web/js/ui/*` — presentation only; **no sim changes** (juice is cosmetic, bots ignore it).

**Dependencies:** needs the screens to exist → runs **after** M4–M9 land (or per-screen as each lands). **→ SEQUENTIAL (tail).** Individual screen fixes are **∥**.

**Definition of done**
- `[VISION]` `npm run vision` — no screen scores <3 on any rubric axis, no `fails[]`; `reports/vision/history.csv` shows no regression vs the golden baseline.
- `[HEADLESS]` reduced-motion mode collapses shake/particles to instant states (a11y + clean-screenshot mode) — asserted in `SimHarness` render mode.

---

### 10.7 FIRST FOREST TEST cut line (hand two kids phones *this week*)

**Ship = M0 → M1 → M2.** That is the minimum that proves the brief's core claim: *two kids, each on their own phone, in one shared persistent world, see each other move (GPS), cooperatively fight a breach, seal it, and it survives a restart.*

| In the cut | Deferred (explicitly not this week) |
|---|---|
| M0 boot/deploy/harness | Loot/XP/level (M3) — fights just resolve; reward text is a stub |
| M1 shared GPS map + see-each-other-move | Inventory/merchant (M4), abilities/Focus (M5) — combat is attack/guard/flee only |
| M2 breach + co-op fight + seal + persistence | Flee/chase (M6), camp/turret (M7), territory/escalation (M8), POI/NPC (M9) |
| Wake-at-camp **stub** on wipe | Art polish/juice (M10) — placeholder sprites, no shake/glow |

**Why this cut is safe to ship raw:** M0–M2 exercise all three top risks (netcode, GPS, persistence) end-to-end; everything deferred is *additive depth* behind the frozen contract and cannot invalidate the spine. If the kids are annoyed there's no loot — good, that's M3, and it's one sequential milestone away. The forest test's job is to surface the risks money can't buy back: does GPS-under-canopy read as "fuzzy veil" or "broken," and does two-phone real-time sync actually feel shared. Those are **[DEVICE]**-only and gate everything.

---

### 10.8 Risks & de-risking order

Ordered by "kills the project if wrong," addressed earliest-possible per the spine.

1. **Netcode / shared-world consistency (highest).** If two clients can desync, nothing above matters. **De-risked in M0–M2:** server-authoritative from commit 1, `BotClient` speaks the real wire, `two-bot-move` (M1) and `coop-seal` (M2) assert convergence and idempotent seals in CI *before* any depth. Retire risk headlessly first, confirm on two phones at the M1/M2 forest checks.
2. **GPS under canopy (highest, DEVICE-only).** The one risk no harness can fully retire — 10–20 m drift must read as fiction, not failure. **De-risked in M1:** smoothing + max-speed clamp + accuracy halo + generous radii land *in the first map slice*, and `assertGpsTolerance` proves the filter headlessly; the **M1 forest check is scheduled first** precisely because if drift feels broken, every interaction radius in §2/§6 needs retuning and we want to know in week 1, not month 2.
3. **Persistence / restart durability (high).** "Survives restarts" is the whole point of a persistent world. **De-risked in M2:** better-sqlite3 WAL (torn-write safe), `roundtrip.test.js` + `assertPersistenceMinimal` in CI, and a **live `fly apps restart`** in the M2 forest check — not a simulated one. Migration goldens (§9.7) enforced from the first schema change.
4. **Combat balance (medium).** Fun, not fatal — a bad tune is a number change, not an architecture change. **De-risked in M5:** the balance sweep (§9.6) gates `COMBAT.*` edits with win-rate/TTK guardrails; safe to iterate post-forest-test.
5. **Determinism drift over time (medium, insidious).** If the sim quietly gains a `Date.now()`, all headless testing rots. **De-risked in M0 and permanently:** `lint:purity` fails CI on any `Date.now`/`Math.random` in `sim/`+`shared/` from commit 1; forked RNG substreams (§9.2) keep goldens stable under refactor.
6. **Fly cold-start / wss wake (low).** `auto_stop_machines=suspend` + reconnect backoff; the M0 `/healthz` check and M2 reconnect flow cover it. A dropped socket mid-forest reads as "the veil flickers" and resumes — already in the M2 slice.

**One-line delivery-lead call:** freeze §1–§3 with M0, ship the M0–M2 spine to the forest *this week* to retire GPS + netcode + persistence on real phones, then fan out M4–M9 across parallel agents and finish on the M10 vision pass.

## 11. Resolutions, Open Questions & Decisions Deferred

Sections 4–9 were each drafted against an *assumed* interface because the final §1–§3 Foundation Contract text was not inlined into their prompts. Each flagged this honestly, so the divergences are localized to naming and a few genuine design forks — not deep logic conflicts. This section is the **editorial tie-breaker of record**: for every punch-list item it either states the binding decision (**RESOLVED**) or logs an explicit open question with a recommendation and a decision deadline (**OPEN**). The governing rule: **§1–§3 win on contract surface (wire, schema, coordinates, code tree); the domain sections win on domain internals.** Where a rename is all that's needed, the downstream section's identifiers — not its logic — are the edit surface.

Three cross-cutting principles drive most resolutions:
- **§3 is the one wire.** Every §4–§9 message name is an alias to be rewritten to a §3 opcode; no new opcodes exist until added to the §3.2/§3.3 tables.
- **One shared world origin** (single server config value) makes meters and lat/lng globally bijective, which quietly dissolves several geo conflicts.
- **One `shared/tuning.js`** holds all balance constants under agreed namespaces; sections reference, never redefine.

---

### 11.1 Contract propagation — five wire vocabularies → one *(RESOLVED)*
**Area:** Contract propagation (§4–§9 vs §1–§3). **Decision:** **§3.2/§3.3 opcodes are the binding wire.** §4's `EncounterStart/TurnBegin/ActionSubmit/ActionResolved/EncounterEnd`, §6's `world.snapshot/breach.seal/geo.fix`, §7's `bastion/place|turret/build|session/resume`, §8's `session.welcome/combat.start/combat.event/merchant.open`, and §9's `c:/s:` prefixes are all **aliases** to be rewritten to the §3 `OP` enum before any handler is built. Reconciliation is a **mechanical rename pass**, not a redesign — every author declared the identifiers they consumed, so the map is well-defined. **Action for implementers:** a single `docs/wire-map.md` table (owned by the §3 author) lists every §4–§9 message → its §3 opcode; §3 is extended only where a genuinely new message is needed (see §11.14, §11.16). Until that table exists, no networked feature is implementable — this is the **top-priority pre-M2 task**, and it gates the M0 "freeze §1–§3" milestone.

### 11.2 Origin model — one shared origin, first-fix demoted *(RESOLVED)*
**Area:** Origin model (§2.1/§1.6 vs §6.1.4/§8.3.1). **Decision:** **One world-wide server origin** (`World.origin`, set at world-create from `ORIGIN_LAT/LNG`, immutable — §2.1/§1.6) is authoritative. All `{x,y}` meter positions and interaction radii are relative to it, so every client's meter grid means the same thing — the shared world holds. §6.1.4's and §8.3.1's "origin = player's first GPS fix" is **demoted to a render-only camera anchor** (`player.cameraAnchor`) that never enters position math or procgen. §6.8's `assertOriginIndependence` already asserts exactly this, so the fixture stays valid. **Consequence for §6:** its "no shared anchor needed" claim is now moot (there *is* a shared origin) but its cell-lattice math is unaffected — see §11.11.

### 11.3 Breach tier ladder — one 5-tier scale *(RESOLVED)*
**Area:** Breach tier numbering (§2.7/§4.3 vs §6.0/§6.4). **Decision:** **One 5-tier ladder, ordinals 1..5, defined once in `shared/tuning.js`** as `tuning.TIERS`. Canonical names: **1 Fracture · 2 Elder · 3 Giant · 4 Massive · 5 Cataclysm** (folding §6's 4-name `TIER_PREFIX` into the 5-length scale rather than the reverse, because §4's `TIER_HP_MULT/ATK_MULT/XP_MULT/ELITE_CHANCE` arrays and §5's `RARITY_ODDS` loot gating are already length-5 and index 1..5). §6 rewrites its 4-entry `TIER_PREFIX={1:'',2:'Elder',3:'Giant',4:'Massive'}` to the shared 5-entry table and clamps `effectiveTier` to `1..5` (its escalation cap `min(4,…)` becomes `min(5,…)`). **Combat depends only on `tierIndex`;** the fiction names are display-only. This removes the Elder/Massive ordinal swap and the array-overflow risk.

### 11.4 Player entity — one Character, Hero retired, Combatant derived *(RESOLVED)*
**Area:** Player entity: Character (§2.2) vs Hero (§5). **Decision:** **§2.2 `Character` is the one canonical persisted schema.** §5's prototype-verbatim `Hero{cls,train,mats,potions,bonusAtk,…}` is a **legacy alias to migrate**, not a second entity: `cls→classId`, `bag→inventory`, scalar `mats→materials{}`, `potions→consumables{}`, and `train{acc,dodge,power,vigor}` becomes the trainable side of `stats` (the §2.2 `stats` key-set is extended to carry training ranks — one stat block, one key-set). §4's `Combatant{atk,def,spd,acc,eva,critChance,…}` is a **documented in-encounter derivation** computed by `systems/combat.js` from `Character.stats + equipment`, never persisted. §5's field-shim plan (5.13) already anticipates this migration and is the implementation path. **The stat→combat→loot pipeline wires against `Character` + derived `Combatant` only.**

### 11.5 Damage-type enum — one frozen set, "frost" wins *(RESOLVED)*
**Area:** Element/damage-type enum divergence. **Decision:** **One enum in `shared/constants.js`:** `phys · fire · frost · shock · blunt · pierce · shadow · light · acid`. **`frost` is canonical; `cold` is deleted** (§5's `cold`→`frost`). §2's `none` becomes `phys` (a neutral physical hit is `phys`, not a null element). §4 (skeleton weak:blunt/resist:pierce, wraith shadow/light), §5 (adds acid), and §7's turret types all reference this enum verbatim. Weakness/resist lookups now share one key space, closing the silent-miss bug. Not every monster must use every type — the enum is the superset; species pick from it.

### 11.6 Combat turn structure — §4's round/phase model wins *(RESOLVED)*
**Area:** Combat turn structure (§3.3 vs §4.1/§4.6). **Decision:** **§4's simultaneous command-lock round model is the one combat state machine.** §3.3's `turn:"player"|"enemy"` field is **replaced** by §4's `{round, phase, deadlineMs}` (phase ∈ telegraph/command / resolution / end-of-round). §3.3's `encounterOpen/encounterUpdate` payloads carry `round`+`phase` instead of `turn`. **§1.8's test example is corrected**: `world.encounters.get(id).state==="player_turn"` becomes an assertion on `phase==="command"` (there is no `player_turn` state). This is a §3 payload edit folded into the §11.1 wire-map pass.

### 11.7 Camp vs Bastion — §7's Party/Bastion split wins *(RESOLVED)*
**Area:** Camp vs Bastion double-definition (§2.8 vs §7.1). **Decision:** **Adopt §7's split:** per-player `Camp` (bedroll/wake-point, no upgrades) + per-party `Bastion` (tier, turrets, crafts, defenseCursor, territory, stash). **§2.8's unified `Camp` entity and the `camp` table are replaced** by §7's schema; `schema.sql` gains a `bastion` table (party-scoped) and `camp` shrinks to the per-player anchor. §2's data model and §1.4's table list are updated to match §7.1/§7.11. The prototype's `hero.bastion:int` migrates to `party.bastion.tier`, as §7 specifies. **Persistence targets the §7 shapes only.**

### 11.8 Recovery Points (RP) — fold into DP *(RESOLVED, with a rename)*
**Area:** Recovery Points currency undefined. **Decision:** **RP is collapsed into DP (Downtime Points).** §5.14's six-currency taxonomy (gold, salvage, essence, veilshard, EP, DP) is authoritative and complete; a seventh "Recovery" currency adds no distinct economic role — §7 spends it on rest/Bastion/training, which are exactly DP/EP sinks. **All `rp`/Recovery references in §7, §8, §9.0 are rewritten:** rest and Bastion/downtime sinks → **DP**; training-line purchases → **EP** (walking currency, per §5.4). §8's "EP/RP micro-meters" becomes "EP/DP micro-meters." This keeps §5 as the single currency owner. *(If playtesting later shows rest and downtime want separate faucets, RP can be re-added to §5.14 with its own earn/cap — but not for the POC.)*

### 11.9 Apprentice entity — model minimally, gate to M6 *(OPEN → recommendation)*
**Area:** Apprentice entity unmodeled. **Status:** genuinely unspecified — §2 has no entity, §3 no opcode, no acquisition/stats. The apprentice is the **accessibility valve** §4.5 leans on (Lure/Fetch/Rescue/Ward make pursuit/chase non-blocking). **Recommendation (log, decide before M6 chase ships):** add a **minimal** `Apprentice` to §2 (`{id, ownerId, level, actions[]}` — companion, not a second combatant), one §3 opcode `apprenticeAction{encounterOrChaseId, action, targetId}`, and a thin §5/§7 progression (joins at L2 per §5.4, one training line at camp). **It is NOT in the M0–M2 forest-test cut**, so this can be decided during the M4–M9 fan-out. **Fallback if descoped:** cut the apprentice entirely and remove §4.5's accessibility dependency on it, replacing Lure/Fetch/Rescue/Ward with player-only "give up chase, no penalty" — acceptable for the POC but weaker on the safety pillar. **Recommend the minimal-model path**; the safety pillar is load-bearing for the kid audience.

### 11.10 Code tree — §1.2 `server/`+`shared/` wins; §9's `src/` rewritten *(RESOLVED)*
**Area:** Harness/code paths: src/ (§9) vs server/+shared/ (§1.2). **Decision:** **§1.2's tree is canonical:** sim under `server/sim/*`, portable core in `shared/*`, tests in `test/*`. **§9's `src/sim/*` and `src/server/gameServer.js` are rewritten** to `server/sim/*` and `server/net/` + `server/sim/`; §9's coverage target `--lines 85 src/sim` → `server/sim`; the purity-lint glob `src/sim/**` → **`server/sim/** shared/**`** (it must cover `shared/`, which also holds sim logic — rng, geo, entities, tuning). §9's fixture/harness import paths already match §1.2's `test/` layout; only the under-test globs move.

### 11.11 lat/lng in sim — sim knows the *origin*, not the *device* *(RESOLVED)*
**Area:** lat/lng in sim vs meters-only sim (§3.5 vs §6). **Decision:** Given the single shared origin (§11.2), meters-from-origin and absolute lat/lng are a **pure bijection** via `shared/geo.js`. We **soften §3.5** from "the sim never knows about lat/lng" to the precise, still-strong invariant: **the sim never touches device GPS or per-connection projection; it holds only the immutable `World.origin` and derives any lat/lng it needs through the pure `project/unproject` in `shared/geo.js`.** **Breach/POI procgen keys off the global lat/lng cell lattice** (§6's `hashCell(cellX=floor(lng·TPD),…)`), computed inside `server/sim/systems/spawns.js` by unprojecting a breach's meter position through the world origin. One derivation scheme, one breach-id function (§6.4.2), no contradiction: projection *math* lives in `shared/geo.js` (usable by sim and client alike); projection of *live device fixes* stays strictly at the network edge (`gps` ingestion in `net/inbound.js`). §6's global-degree lattice survives unchanged; §3.5's "projection at the edges only" now means *device* projection, which is what it was protecting.

### 11.12 Tuning namespaces — one `shared/tuning.js`, two namespaces *(RESOLVED)*
**Area:** Tuning namespaces (§4 C / §5 BALANCE / §9 COMBAT+ECON). **Decision:** **All balance constants live in `shared/tuning.js` under `tuning.COMBAT` and `tuning.ECON`.** §4's `C.*`/`SQ_COMBAT_CONSTANTS` → `tuning.COMBAT.*` (e.g. `C.WEAK_MULT`→`tuning.COMBAT.weakMult`); §5's `BALANCE.*` splits by domain (progression/combat-adjacent → `tuning.COMBAT`, loot/economy → `tuning.ECON`); §7's inline turret/bastion numbers move into `tuning.ECON`. §9's balance runner imports **only** `shared/tuning.js` and sweeps `tuning.COMBAT.*`/`tuning.ECON.*`, so its `COMBAT.weakMult`/`ECON.goldPerTierClear` references now resolve. A one-time `docs/tuning-map.md` (like the wire-map) records old-name→new-name so §4/§5/§9 prose can be find-replaced without hunting.

### 11.13 Class roster — drop mage from POC fixtures *(RESOLVED)*
**Area:** Class roster: knight|ranger (§2/§3) vs +mage (§9). **Decision:** **Two classes ship: `knight`, `ranger`.** §5 already defers mage; §2.2/§3.2 validate only these two. **§9's fixture matrix drops mage** — remove `mage_L10_frost_build`, `mage` from the `class × level` cross-product, and `class ∈ {knight,ranger,mage}` in §9.0 becomes `{knight,ranger}`. Fixtures must reference only shipped classes, or they fail to load against the data model. The `CLASSES[key]` schema stays open so mage can be added post-POC without a migration.

### 11.14 Intent ordering — tick-aligned total order, define `sid` *(RESOLVED — the multiplayer linchpin)*
**Area:** Intent ordering guarantee (§3 vs §9.4). **Decision:** **Amend §3** to specify deterministic multiplayer, since §9.4's byte-identical two-bot outcome depends on it: (1) `sid` is defined as the **session id** (= `Connection.connId`, stable per socket); (2) inbound intents are **queued, not applied on arrival** — the sim drains the queue at each tick boundary and applies intents in **total order `(tick, sid, seq)`**; (3) §3.4's "combat actions resolve immediately" is corrected to **"resolve at the next tick boundary"** — the *fiction* of instant relay is presentation, the *sim* is tick-aligned. This makes two co-op bots submitting in the same window resolve in a defined order regardless of socket scheduling, so §9's deterministic co-op tests are guaranteed by spec. Folded into the §11.1 wire-map / §3 edit.

### 11.15 Persistence API — dirty-set for prod, codec for tests, one table set *(RESOLVED)*
**Area:** Persistence: dirty-set (§1.4) vs whole-state blob (§9.7/§7.10). **Decision:** **One storage substrate (the §2/§1.4 normalized tables), two access paths over it.** Production uses §1.4's **dirty-set `repo.save(world)`/`repo.load(db)`** (incremental, crash-safe). Tests get a **thin whole-world `codec.serialize(state)`/`codec.deserialize(blob)`** that reads/writes **the same tables/columns** (it is `repo` driving a fresh in-memory SQLite, not a parallel blob format). §9.7's `SimHarness.fromSave(blob)` round-trip and §7.10's Party+Bastion JSON round-trip both target `codec`, which is defined as "serialize every persistent entity via the same field set `repo` persists." No monolithic whole-world snapshot file is introduced (§1.4's rejection stands); the flagship round-trip test asserts `codec.deserialize(codec.serialize(s))` **and** that a `repo.save`→`repo.load` cycle yields an equal state — proving the two paths agree.

### 11.16 Auto/walking timing — extend §3 timing field *(RESOLVED)*
**Area:** Auto/walking mode not expressible in §3 protocol. **Decision:** **Extend §3.2 op7 `attack.timing` and op8 `useAbility.timing` to accept `0..1 | "auto"`** (equivalently, a nullable timing where null/absent = auto). Add the server-side auto-fill rule to §3/§4: at the `CMD_WINDOW_MS` deadline, unsubmitted heroes are filled with their script and resolved via the `"auto"` hit-chance path (§4.3). This makes walking-mode and kid-mode — a core pillar — expressible on the wire. Small, additive §3 edit; folded into the §11.1 pass.

### 11.17 §4 damage constants — add the missing knobs *(RESOLVED, values proposed)*
**Area:** §4 damage pipeline references undefined constants. **Decision:** **Add every referenced constant to `tuning.COMBAT`** (the §4 `SQ_COMBAT_CONSTANTS` block) so no implementer invents numbers and the balance sim can sweep them. Proposed starting values (tunable): `MARK_DMG: 0.20` (Hunter's Mark +20% taken), `SHIELD_HP: 20` (Bulwark absorb), `SUNDER_DEF: 6` (Sunder def-break), `EVA_ROLL: 0.35` (Roll evade bonus vs next intent), `REVIVE_RANGE: 1` (encounter-abstract, any ally), `REVIVE_HP_FRAC: 0.35` (Rally revive fraction). These are first-guess balance numbers, explicitly owned by the §5/balance sweep to retune — the point is they now *exist* in the one constants object.

### 11.18 Vision gate — add deterministic pixel-diff, judge advisory *(RESOLVED)*
**Area:** Vision loop non-deterministic + human-calibrated. **Decision:** **Split the UI gate into two layers.** (1) A **deterministic golden-PNG pixel-diff** becomes the hard CI merge gate: because §8.8.2 render mode is byte-deterministic (virtual clock, seeded RNG, shake off), commit a golden PNG per screen and fail CI on exact/threshold diff. (2) The **Claude-vision rubric judge is demoted to advisory** — it produces findings and trend data (§9.8 `findings.md`/`scores.json`) but does **not** hard-block merge. **We state plainly:** visual-taste sign-off is **human/model-assisted, not fully autonomous** — the "no human in the loop" claim holds for correctness/balance/persistence (deterministic) and for *catching* visual regressions (pixel-diff), but *judging* whether new art is good remains model-assisted with a periodically human-audited calibration set. §9's DoD gate #5 is reworded accordingly: "pixel-diff clean (blocking) + no vision-judge axis <3 (advisory review)."

### 11.19 Item rarity — 5-value numeric wins *(RESOLVED)*
**Area:** Item rarity type mismatch (§2.3 vs §5.5). **Decision:** **Adopt §5.5's numeric `rarity: 0|1|2|3|4`** (Wayfarer's/Trueforged/Warden-Blessed/Veil-Touched/Riftforged), since §5.17's `RARITY_*` arrays are length-5 and the loot pipeline is built on it. **§2.3's string 4-value `"common"|…|"epic"` is replaced** by the numeric type, and **§8's rarity-glow map keys off the 0..4 integer.** Loot output, persistence, and the client glow now agree on type and cardinality (5, including legendary).

### 11.20 Relevance window — derive from PLAY_R in one place *(RESOLVED)*
**Area:** Relevance-window / play-radius constants disagree. **Decision:** **One derived constant in `shared/constants.js`:** `RELEVANCE_R = PLAY_R + RELEVANCE_MARGIN` with `PLAY_R = 227 m` (§6.1.3) and `RELEVANCE_MARGIN = 25 m` → **252 m**, replacing §3.4's independent hard-coded `200 m`. Both the delta broadcaster (§3.4) and the geo/interest layer (§6) reference `RELEVANCE_R`, so an entity that is renderable/engageable (up to `ENGAGE_FAR = 150 m` + halo, well inside `PLAY_R`) is always inside the relevance window — no edge-case pop-in. Low-severity but co-deriving the radii removes the drift. `PLAY_R > ENGAGE_FAR + halo` and `RELEVANCE_R > PLAY_R` both hold by construction.

---

### 11.21 Summary of the reconciliation pass

**Resolved outright (18):** wire vocabulary (§11.1), origin model (§11.2), tier ladder (§11.3), player schema (§11.4), damage enum (§11.5), turn model (§11.6), Camp/Bastion split (§11.7), RP→DP (§11.8), code tree (§11.10), lat/lng-in-sim (§11.11), tuning namespaces (§11.12), class roster (§11.13), intent ordering (§11.14), persistence API (§11.15), auto-timing wire (§11.16), missing combat constants (§11.17), vision gate (§11.18), rarity type (§11.19), relevance window (§11.20).

**Open, recommendation logged (1):** apprentice entity (§11.9) — recommend minimal model, decide before M6; not in the forest-test cut.

**The two blocking pre-M2 chores** that must land during M0's "freeze §1–§3" step: (a) the **wire-map** (`docs/wire-map.md`) rewriting every §4–§9 message to a §3 opcode and applying the §3 edits for turn-model, intent-ordering, and auto-timing (§11.1/§11.6/§11.14/§11.16); (b) the **tuning-map** (`docs/tuning-map.md`) consolidating §4/§5/§7/§9 constants into `shared/tuning.js` (§11.12). Everything else is an in-section find-replace or an additive schema edit that the domain author can land in their own milestone. None of these block the M0–M2 spine's *architecture* — they are naming reconciliations over a fundamentally consistent design, which is the happiest outcome a parallel-authoring pass can produce.