# SideQuest — working agreement

Roguelike RPG in the real world: For the King × real-time combat × Pokémon Go.
Fantasy-reskinned real-world map (OSM/Overture vector tiles), high-accuracy
GPS, 3D (KayKit low-poly), iOS-first. Ground-up redesign — the prototype era
lives in the archived `SideQuestAppV2` repo (reference mine, never copied
wholesale). The stack decision and its rationale:
`docs/REDESIGN-TECH-STACK.md`.

## Status: design shell built, spikes pending

The **YAS v1.0 UI shell** exists: all 28 designed screens implemented in
`game/src/ui/` against the handoff in `docs/design/yas-v1/` (the canonical
spec — GAME-RULES.md, SCREENS.md, DATA-MODEL.md, and the `.dc.html` flow
map). It runs desktop-first on fake data (`src/data/game_state.gd`); no
GPS, server, or real 3D yet — 3D regions are dashed placeholders per the
handoff. The two kill-criterion spikes from REDESIGN-TECH-STACK.md remain
the next hard gates, in order:

1. **GPS + battery** — minimal CoreLocation `.gdip` plugin (location +
   heading + authorization signals), trivial 3D scene, Instruments-measured
   walk on a real device.
2. **MVT → fantasy tiles** — PMTiles fetch, decode one zoom-16 vector tile,
   render roads/water/parks as low-poly meshes + KayKit props at frame
   budget on an A12–A13 iPhone.

Full commitment to Godot happens only after both pass.

## Shape of the codebase

- `game/` — the Godot 4.6 project (GDScript, **Mobile renderer**, A12+
  floor). Pin the exact engine version; upgrades are deliberate, tested
  events, never drive-by.
- `game/src/` — the shell: `ui/screens/` (28 code-built screens, one file
  per route), `ui/kit/` (shared components; API contract in its README),
  `ui/tokens.gd` (all design tokens — never inline a tokened color),
  `app/` (router + app shell w/ `--smoke`/`--autoshot` modes),
  `data/` + `rules/` (fake state, content catalog, GAME-RULES constants).
- `game/assets/models/` — KayKit GLBs (characters, weapons, hex/forest
  props) carried over from the prototype; licenses alongside.
  `game/assets/ui/faces/` — face crops from the handoff (stand-ins for
  live renders); `game/assets/fonts/` — Lilita One + Nunito (OFL).
- `server/` — authoritative Node/TS game server (empty stub; architecture
  carries from the prototype: Fly.io, SQLite, versioned JSON WebSocket
  protocol, server-authoritative everything).
- `tools/` — tile pipeline (planetiler/PMTiles), protocol codegen
  (TS/Zod → GDScript validators), build scripts.
- `docs/` — the design bible (NORTH-STAR, MAP-DATA, GENRE-LESSONS,
  RIFT-BRIEF, COMBAT-STUDY, …) carried over; REDESIGN-TECH-STACK is the
  stack decision record.

## Development conventions

- **GDScript with static typing everywhere** (`var x: int`, typed funcs);
  the compiler is a weaker net than tsc — typing + tests make up the gap.
- **Desktop-first loop.** The game must always run on desktop with a fake
  GPS source (recorded/scripted routes) behind a pluggable position
  provider — same pattern as the prototype's `setPositionSource('manual')`.
  Real devices are for verification, not daily work.
- **Keep sim logic platform-free.** Game rules go in plain GDScript
  classes with no Node/scene dependencies where feasible, so they run
  headless under test.
- **Tests run headless**: `godot --headless` + gdUnit4 (or GUT — pick one
  in spike phase and record it here; the shell currently uses two plain
  headless scripts, not a framework). CI on Linux; iOS archive/TestFlight
  on a macOS runner.
- **Launching**: `./play` (deployed server) · `./play local` (boots/reuses a
  local server, world persists in `server/data-dev`) · `./play offline` ·
  `./play walk` (autowalk demo) · `./play screen <id>`. WASD to walk.
- **Shell verification loop**: `tools/dev/check.sh` (headless smoke over
  every route + `game/tests/data_sanity.gd`) must pass before commit;
  `tools/dev/shoot.sh <dir> [route,…]` screenshots screens for visual
  review against `docs/design/yas-v1/` mocks. After adding a script with
  `class_name` or any asset, run `godot --headless --path game --import`
  once to refresh caches.
- **Port, don't invent, the geo layer**: the Kalman filter pipeline
  (`client-core/geo/filter.ts`), heading logic, and WebSocket
  reconnect/backoff design in the old repo are field-tested — translate
  them to GDScript rather than redesigning.
- **Tuning lives server-side** wherever possible — client builds ride
  TestFlight (~half-hour cadence), server deploys are minutes. Design for
  that split from day one.
- **ODbL attribution** ("© OpenStreetMap contributors") ships in the
  splash/credits from the first build that renders map data.

## Default workflow — every turn

Unless told otherwise, after a change: commit to `main` with a clear
message and push. Verify before claiming done (headless tests once they
exist; on-device checks are called out explicitly as not-yet-verified).
