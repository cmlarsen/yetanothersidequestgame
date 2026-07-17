# tools (stub)

Planned occupants, per docs/REDESIGN-TECH-STACK.md:

- **Tile pipeline** — planetiler/tilemaker: OSM/Overture extract → a single
  `.pmtiles` file on object storage (R2 or Tigris-on-Fly).
- **Protocol codegen** — server Zod schemas → GDScript types/validators.
- **Build/release scripts** — headless Godot export + macOS-runner
  archive → TestFlight.
