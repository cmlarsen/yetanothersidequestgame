# yas-server — authoritative YAS v1 game server

Node/TS server for the YAS v1.0 game. Server-authoritative everything: hex
territory, fronts, gloom pressure, mobs and real-time combat, loot, towers,
minions, quests, runs, parties. Rules of record:
`docs/design/yas-v1/GAME-RULES.md` + `DATA-MODEL.md`; the architecture
contract is [`DESIGN.md`](./DESIGN.md). Patterns are reference-mined from the
archived SideQuestAppV2 prototype (see attribution comments in-file), never
copied wholesale.

## Quickstart

```bash
npm install        # node >= 22 (better-sqlite3 ships prebuilds)
npm run dev        # tsx watch main.ts — listens on :8080, ws on /ws
npm test           # vitest (unit + integration + golden), all headless, no sockets*
npm run ci:fast    # lint:purity + typecheck + test — the deploy gate
```

*except `test/integration/gateway.test.ts`, the one deliberate real-ws test
(ephemeral port). A live smoke probe lives at
`test/integration/boot-client.ts` (`PORT=8399 npm start` + `PORT=8399 npx tsx
test/integration/boot-client.ts` — joins, walks, exits 0 on the first hex-claim
beat).

There is no build step: everything runs as TypeScript via **tsx**. Strict mode,
ESM (`NodeNext` + `.js` import suffixes).

## Architecture map

| Path | What lives there |
|---|---|
| `main.ts` | Composition root — the ONLY `Date.now`: config → db → world → loop → http → gateway → autosave → SIGTERM save |
| `config.ts` | The ONLY env reader (see table below) |
| `app.ts` | Hono `/healthz` + `/status` on a hand-rolled Node adapter; shares its port with the ws gateway |
| `shared/` | **Pure, I/O-free.** `protocol.ts` (zod wire contract, numeric ops), `tuning.ts` (every GAME-RULES DEFAULT), `catalog.ts` (items/characters/mobs/quests — ids match the Godot shell), `entities.ts`, `hexgrid.ts`, `geo.ts`, `rng.ts` (seeded mulberry32), `constants.ts` |
| `sim/` | **Pure, clock-injected.** `world.ts` (state + serialize/deserialize + tickWorld), `loop.ts` (fixed timestep, injected Clock), `commands*.ts` (the single `applyCommand` reducer + handler registry), `systems/` (movement, territory, fronts, gloom, mobs, combat, chests, loot, towers, minions, shop, quests, party, progression, outbox) |
| `net/` | The I/O edge: `gateway.ts` (ws upgrades, version gate, heartbeat), `outbound.ts` (two-lane pump: outbox events every tick, positional DELTAs at 5 Hz with interest windows) |
| `persistence/` | better-sqlite3 WAL snapshot store: `schema.sql`, `db.ts`, `repo.ts` (save/load of the one canonical serialize() projection; only touched rows persist) |
| `test/` | `harness/` (SimHarness + ManualClock), `unit/`, `integration/` (the end-to-end loop tests), `persistence/`, `golden/` (drift gates, see below) |
| `tools/` | `check-sim-purity.ts` — CI gate: nothing under `sim/**` or `shared/**` touches wall clocks, `Math.random`, fs, or sockets |

**Sim purity is law.** Time arrives as an injected `now`, randomness via
`seededRng(seed, ...namespace)`. `npm run lint:purity` enforces it; tests drive
the real loop with a ManualClock, so a whole gloom-pressure hour runs in
milliseconds.

## Protocol

`shared/protocol.ts` is the single wire source of truth: JSON frames, zod
codec, numeric ops (client 1–39, server 100–139, frozen forever),
`PROTOCOL_VERSION = 1` enforced on JOIN/RESUME (mismatch → ERR
`VERSION_MISMATCH` + close 4400). Malformed frames cost one ERR
`BAD_REQUEST`, never the socket. Join burst: `[HELLO, SNAPSHOT,
INVENTORY_UPDATE]`; reattach with the bearer `sessionToken` via RESUME.

## Golden / drift gates

`test/golden/` pins determinism (pattern from the V2 prototype):

- `save/world.golden.json` — byte-exact `serialize()` of a scripted command
  history; any world-shape/codec/determinism drift fails.
- `loot/rarity-histogram.golden.json` — `rollRarity` proportions per weight
  table; the drift spec re-samples from a different seed and chi-square
  goodness-of-fits against the committed proportions, so a stealth odds edit
  fails while refactors stay quiet.

Intended change moved a golden? `npm run golden:generate` and commit the new
bytes with the change.

## Env vars

| Var | Default | Meaning |
|---|---|---|
| `PORT` | `8080` | HTTP + WS port (one server, one port) |
| `DATA_DIR` | `./data` | Directory for the SQLite file |
| `DB_PATH` | `$DATA_DIR/world.db` | Full DB path override (`:memory:` honored) |
| `WORLD_SEED` | `yas-v1` | World seed — fronts, mob field, loot all derive from it |
| `ORIGIN_LAT` / `ORIGIN_LNG` | `37.7749` / `-122.4194` | Projection origin (the playtest neighborhood) |
| `TICK_HZ` | `10` | Sim tick rate |
| `AUTOSAVE_MS` | `15000` | Autosave interval (milestone beats also force saves) |
| `DAILY_RESET_UTC_H` | `13` | §10 daily-quest reset hour (UTC ≈ "dawn local") |

## Deploy (Fly.io)

App `yas-server` (`fly.toml`): sjc, shared-cpu-1x/512 MB, a volume mounted at
`/data` for `world.db`, `/healthz` checks, scale-to-zero
(`auto_stop_machines = "suspend"` — a wss reconnect wakes it).

```bash
npm run deploy     # ci:fast gate, then flyctl deploy
```

`WORLD_SEED` / `ORIGIN_LAT` / `ORIGIN_LNG` are set via `fly secrets`. SIGTERM
triggers a final save before exit, so deploys never lose progress.

## Tuning ↔ Godot shell

`shared/tuning.ts` + `shared/catalog.ts` are the server-side source of truth
for every DEFAULT number and content id. The Godot shell renders the same ids
and values (`game/src/rules/rules.gd`, `game/src/data/catalog.gd`);
`tools/protocol-gen` (being added next) generates
`game/src/net/server_protocol.gd` + `game/src/data/server_tuning.gd` from
these files, and the shell's data-sanity test asserts equality — so client and
server can never drift on the numbers.
