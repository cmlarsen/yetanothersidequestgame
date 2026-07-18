# tools

- **Protocol codegen** (`protocol-gen/`) — implemented: emits
  `game/src/net/server_protocol.gd` + `game/src/data/server_tuning.gd` from
  the server's shared TS (`cd server && npx tsx ../tools/protocol-gen/generate.ts`).
- **Dev gate** (`dev/check.sh`) — headless Godot smoke + data-sanity
  cross-checks (includes the Rules ↔ ServerTuning lock-step asserts).

Planned, per docs/REDESIGN-TECH-STACK.md:

- **Tile pipeline** — planetiler/tilemaker: OSM/Overture extract → a single
  `.pmtiles` file on object storage (R2 or Tigris-on-Fly).
- **Build/release scripts** — headless Godot export + macOS-runner
  archive → TestFlight.
