# SideQuest — working agreement

Roguelike RPG in the real world: For the King × real-time combat × Pokémon Go.
Fantasy-reskinned real-world map (OSM/Overture vector tiles), high-accuracy
GPS, 3D (KayKit low-poly), iOS-first. Ground-up redesign — the prototype era
lives in the archived `SideQuestAppV2` repo (reference mine, never copied
wholesale). The stack decision and its rationale:
`docs/REDESIGN-TECH-STACK.md`.

## Status: pre-spike scaffold

Nothing is built yet. First work is the two kill-criterion spikes from
REDESIGN-TECH-STACK.md, in order:

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
- `game/assets/models/` — KayKit GLBs (characters, weapons, hex/forest
  props) carried over from the prototype; licenses alongside.
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
  in spike phase and record it here). CI on Linux; iOS archive/TestFlight
  on a macOS runner.
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
