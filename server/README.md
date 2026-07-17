# server — authoritative game server (stub)

Not built yet; the new sim is written fresh against the new rules. The
architecture carries from the prototype (see the archived SideQuestAppV2
repo for reference, not for copying):

- Node/TS, deployed to Fly.io, SQLite state, scale-to-zero posture.
- Server-authoritative: shared world, combat resolution, loot, anti-cheat.
- Versioned JSON WebSocket protocol; Zod schemas here are the single
  source of truth, with GDScript validators generated into `game/` by
  `tools/` codegen.
- Tuning/balance/content live server-side so field iteration is a server
  deploy, not a TestFlight build.
