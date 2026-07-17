# Redesign tech stack — decision record

> Status: **recommendation, researched 2026-07-17.** The redesign starts over:
> new gameplay (For the King × real-time combat × Pokémon Go), new rules, 3D
> graphics (KayKit models), real-world geography with high-accuracy GPS and a
> reskinned OSM map. Expo Go / OTA is no longer a requirement. This doc answers:
> what stack, and do we start a fresh codebase?
>
> Research method: three parallel deep-dives (Godot-on-iOS maturity; the
> map/GPS SDK landscape; engine comparison for agentic development), all
> web-verified against 2025–2026 sources. Key links inline.

## TL;DR

**Godot 4.6, GDScript, in a fresh repo.** Keep the server-authoritative
Node/TS architecture (Fly, SQLite, WebSocket protocol). Own the map layer
in-engine: self-hosted PMTiles (OSM/Overture) → vector-tile decode → fantasy
3D geometry. Write our own small CoreLocation GDExtension plugin for GPS.

Two spikes **before** full commitment (≈1 week, both on the true unknowns):

1. **GPS + battery spike** — minimal CoreLocation plugin, walk outside with
   continuous GPS + 3D rendering, measure battery/thermals with Instruments.
2. **Map spike** — decode one MVT tile in Godot and render roads/water/parks
   as low-poly fantasy geometry with KayKit props at 60 fps on an A12 device.

Documented fallback if either spike fails: TypeScript + Three.js on WebGPU
(iOS 26) in a native shell — see [Fallback](#fallback-path).

## What the research found

### 1. Engine & performance (the reason we're moving)

Our core pain — animation speed/quality — is exactly what a real engine
solves: skeletal animation state machines (`AnimationTree`), retargeting,
particles, editor-tuned tooling instead of hand-rolled three.js/RN animation
plumbing.

**Godot's rendering half is ready:**

- Godot 4.4+ ships a **native Metal backend**, default on iOS
  ([PR #88199](https://github.com/godotengine/godot/pull/88199)); current
  stable is 4.6.x. MoltenVK remains a fallback.
- glTF is Godot's first-class format; **KayKit is directly supported** by its
  author, and a worked KayKit character + animation-retargeting example exists
  ([doctor-g/KayKitAnimationInGodot](https://github.com/doctor-g/KayKitAnimationInGodot)).
  Our 12 rigged characters, shared anim libraries, weapons, and 33 hex-terrain
  pieces import with zero conversion.
- Use the **Mobile renderer** (official guidance for iOS); its limits (single
  directional light, no SDFGI/volumetrics) cost nothing for low-poly stylized
  fantasy. iOS Simulator only runs the Compatibility renderer — real-device
  testing required.
- Effective device floor: **A12+** (iPhone XS/XR, 2018) — Godot 4.5.2+
  enforces this itself
  ([4.5.2 release](https://godotengine.org/article/maintenance-release-godot-4-5-2/)).
- Shipped-game evidence: Godot Foundation's
  [Apr 2026 mobile update](https://godotengine.org/article/godot-mobile-update-apr-2026/)
  — paid contractors on mobile, two shipped games' crash rates driven from
  ~4% to <1%, Instruments profiling support, battery/idle fixes upstreamed.
  Translation: iOS gets sustained institutional attention, and only recently
  started getting it. Pin the engine version per release; test before
  upgrading (4.6 introduced an A13/iPhone SE Mobile-renderer regression,
  [#116090](https://github.com/godotengine/godot/issues/116090)).
- Consensus positioning: Godot is competitive with Unity for mid-tier 3D
  mobile — our exact bracket — and behind it at the high end we don't need.

**Godot's native-device half is DIY** — this is where the project is unusual
and where the risk concentrates:

- **No built-in GPS.** No maintained full-featured Godot 4 iOS location
  plugin exists: the best
  ([TheOathMan/Godot-iOS-Location-Plugin](https://github.com/TheOathMan/Godot-iOS-Location-Plugin))
  is lat/long-only, last touched May 2024. Heading, accuracy configuration
  (`kCLLocationAccuracyBestForNavigation`), and background location mean
  **writing our own ObjC++/`.gdip` plugin** (~days; the feature-complete
  Godot 3
  [WolfBearGames plugin](https://github.com/WolfBearGames/Godot-GeolocationPlugin-iOS)
  is a direct porting template). Notably the one purpose-built Godot
  locative-game framework, PraxisMapper, shipped **Android-only**. Nobody has
  published the PoGO-on-Godot-iOS trail; we'd be first, including generating
  the first battery/thermal data for continuous GPS + 3D.
- The official iOS plugin repo
  ([godot-ios-plugins](https://github.com/godot-sdk-integrations/godot-ios-plugins))
  "lacks a maintainer" per a core dev (Jan 2026): push notifications work but
  are stale, IAP is StoreKit 1 (StoreKit 2 plugin in progress via the
  Foundation). Pedometer: nothing — custom CMPedometer plugin when we want it.
  Haptics, keep-screen-on: fine. Budget for owning small native plugins as a
  permanent line item.
- WebSocket client is workable for our authoritative server (wss/TLS via
  `TLSOptions`) with papercuts: TLS 1.2-only
  ([#92101](https://github.com/godotengine/godot/issues/92101)), useless
  connect return codes, manual reconnect/backoff (we already own that logic
  pattern in `client-core/net/gameSocket.ts` — port the design).

**"Closer to the metal" (native Swift) — investigated, not chosen.**
SceneKit was **deprecated at WWDC 2025**
([session 288](https://developer.apple.com/videos/play/wwdc2025/288/)); the
path forward is RealityKit, which is young as a game engine and Apple-only
forever. Agent tooling improved dramatically in 2026 (Xcode 26.3 MCP bridge,
[XcodeBuildMCP](https://www.xcodebuildmcp.com/), Tuist-generated projects),
but the whole loop is chained to **macOS runners** — it breaks the
"drivable entirely from Claude Code cloud" workflow that has carried this
project. GPS/native APIs would be free; everything else gets harder.

### 2. Map & GPS libraries (the crux — and it's now engine-agnostic)

The 2022-era "vendor hands you a game map" category is **dead**:

- Google Maps gaming services: shut down Dec 2022
  ([deprecations](https://developers.google.com/maps/deprecations)).
- Niantic Maps SDK: killed for third parties after the Scopely deal —
  endpoints off Oct 2025
  ([sunset notice](https://www.nianticspatial.com/en/products/maps-sdk-notice)).
- Mapbox Unity SDK: closed-source v2 already end-of-lifed, v3 "in
  development," contact-sales MAU pricing. Unity-only regardless.
- Survivors (Cesium — including a
  [Godot plugin](https://cesium.com/blog/2025/05/01/introducing-3d-tiles-for-godot-by-battle-road/) —
  and Esri) stream photoreal globes, not the semantic roads/parks/buildings we
  need to reskin. Wrong tool.

Anyone who bet on a vendor map SDK got burned three times in four years. The
conclusion writes itself: **own the map layer.** Conveniently, it's the same
architecture MAP-DATA.md already picked, extended from styling to geometry:

- **Data**: OSM (or [Overture](https://overturemaps.org/) — what Pokémon GO
  itself migrated to in 2024) compiled by planetiler/tilemaker into a single
  **PMTiles** file on object storage. ~**$0–15/mo** at small scale on
  Cloudflare R2 ([cost calc](https://docs.protomaps.com/deploy/cost));
  Tigris-on-Fly also works per NORTH-STAR.
- **Rendering**: decode Mapbox Vector Tiles (small protobuf format)
  **in-engine** and generate fantasy 3D geometry — roads as dirt-trail
  ribbons, water as parchment sea, parks as forests scattered with KayKit
  trees, buildings extruded as hamlet clusters. This is the PoGO/Orna
  architecture without a vendor. Godot prior art is thin but real:
  [godot-geo-tile-loader](https://github.com/pka/godot-geo-tile-loader)
  (Rust GDExtension, MVT in Godot 4) and
  [3D-OSM-GODOT](https://github.com/Frataj/3D-OSM-GODOT) built on it.
  Estimated **2–4 weeks** for a solid decoder + tile mesh layer.
- **OSM tags are game data** (GENRE-LESSONS): the same decoded features feed
  biome spawns — water monsters at real rivers, wraiths in real graveyards.
  The server can read the same PMTiles for authoritative placement.
- **The deterministic seeded-decoration layer from MAP-DATA.md survives
  unchanged** — hash of tile coords scatters the enchanted groves; every
  player sees the same world with zero server state.
- **Licensing is clean**: a reskinned map is an ODbL "Produced Work" —
  commercial use fine, visible attribution required ("© OpenStreetMap
  contributors" splash/credits is explicitly acceptable for games; Orna does
  exactly this).
- **GPS quality toolkit** (engine-agnostic): CoreLocation
  `BestForNavigation` + accuracy-threshold rejection + Kalman filtering (our
  `client-core/geo/filter.ts` already encodes field-tested behavior — port
  the algorithm), optional snap-to-OSM-ways; full HMM map-matching
  ([Valhalla Meili](https://valhalla.github.io/valhalla/meili/)) self-hostable
  next to the Node server if trails demand it.

Because we own this layer, **the map no longer constrains the engine choice**
— which is what frees us to pick the engine on the other two axes.

### 3. Agentic development

Ranking from the research (2026 sources, incl. autonomous-pipeline evidence):

| Rank | Stack | Verdict |
|---|---|---|
| 1 | **TypeScript + Three.js/WebGPU** | All-text, best LSP/test loop, Playwright vision on Linux CI, compile-checked protocol sharing. WebGPU shipped in iOS 26 Safari — the old perf objection has genuinely weakened. |
| 2 | **Godot 4 + GDScript** | `.tscn`/`.tres` are diffable text; `godot --headless` imports/exports/tests on Linux CI (GUT/gdUnit4); active MCP ecosystem and the only engine with public end-to-end autonomous Claude pipelines ([godogen](https://github.com/htdt/godogen)). Claude's GDScript is consistently rated strong. Caveats: `--headless` can't render (visual verification needs Xvfb/GPU runner or in-engine capture); C# iOS export still experimental → **GDScript only**; TS→GDScript protocol codegen is hand-rolled. |
| 3 | **Swift + RealityKit** | 2026 tooling is real, but macOS-only runners break the cloud-agent loop; pbxproj is the most agent-hostile artifact (Tuist mitigates); RealityKit young. |
| 4 | **Bevy (Rust)** | Most agent-native on paper; in practice 6-month API churn makes models hallucinate last version's API, and iOS integration is DIY. Highest ship-risk. |
| 5 | **Unity 6** | Best 3D/location ecosystem, worst agent loop: UnityYAML officially not externally editable, everything round-trips a running editor, batchmode domain-reload fragility. Licensing is fine now (free < $200k), but not chosen. |

Godot loses agent points vs TS only where an engine inherently must (visual
verification, one codegen step) — and buys back the entire animation/tooling
problem that motivated the move.

## Decision

**Godot 4.6 (pin exact version), GDScript, Mobile renderer, A12+ floor.**

- **Server stays Node/TS on Fly** — server-authoritative per NORTH-STAR.
  New sim for new rules, but the architecture, deploy pipeline, and the
  WebSocket-protocol discipline carry over. Protocol: JSON messages with a
  small hand-rolled TS→GDScript type/validator generator (or plain
  Dictionaries + server-side Zod as the single source of truth to start).
- **Map layer we own**: PMTiles on R2/Tigris → MVT decode → fantasy tile
  meshes + KayKit props + seeded decoration. Start in GDScript; port hot
  paths to a Rust/C++ GDExtension only if profiling says so (prior art
  exists).
- **GPS plugin we own**: ObjC++ `.gdip` wrapping CLLocationManager —
  location + heading + authorization signals, accuracy config; background
  location only when a design actually needs it (it's an App-Review
  escalation).
- **CI/builds**: Linux runners for tests/headless export prep; GitHub
  Actions **macOS runner** for `xcodebuild` archive → TestFlight (no local
  Mac required; the archived
  [godot4-ios-export action](https://github.com/dulvui/godot4-ios-export)
  is the pattern to fork). Expect Xcode-version churn as a maintenance tax.
- **What we give up, knowingly**: OTA updates (every client change rides a
  TestFlight build, ~tens of minutes — the user-accepted trade), Expo Go
  instant preview, and the compile-checked shared `shared/` package between
  client and server.

### Why not the others (one line each)

- **Unity**: agent-hostile editor round-trip; the Mapbox SDK that was its
  trump card is exactly the vendor-risk category that just died.
- **Native Swift/RealityKit**: breaks the Linux cloud-agent workflow;
  SceneKit deprecated; RealityKit young; locks out Android forever.
- **Bevy**: API churn vs LLMs + DIY iOS plumbing = highest variance for a
  solo ship.
- **Stay on TS/Three.js**: best agent loop and now credible WebGPU perf, but
  it re-signs us up for hand-rolling the exact animation/tooling layer that
  hurt — kept as the fallback, not the plan.

## De-risk spikes (before the fresh repo gets serious)

Both target the only genuinely unproven claims. Timebox ≈1 week total.

1. **GPS + battery**: minimal CoreLocation plugin (location + heading
   signals) into a trivial Godot scene with a KayKit character and continuous
   camera movement; walk the neighborhood; measure with Instruments
   (Foundation added iOS profiling support). **Kill criterion**: battery burn
   or thermals meaningfully worse than the RN prototype on the same walk.
2. **MVT → fantasy tiles**: fetch a PMTiles region, decode one zoom-16 tile,
   render roads/water/parks as meshes with KayKit props, hold 60 fps (or a
   deliberate 30 fps cap) on an A12–A13 device. **Kill criterion**: can't hit
   frame budget with a realistic tile in view, or decode latency makes
   walking-speed tile paging infeasible in GDScript *and* the GDExtension
   escape hatch looks unreasonable.

If both pass → commit fully. If either fails → fallback below, with the spike
results as the evidence.

## Fresh repo: yes

With new rules, new gameplay, a new engine, and a new renderer, the
carry-forward set is **assets + documents + algorithms**, not code:

- **Carries (copy into the new repo)**: `assets/models/**` (KayKit GLBs +
  licenses), the `docs/` design bible (NORTH-STAR, MAP-DATA, GENRE-LESSONS,
  RIFT-BRIEF, COMBAT-STUDY, DESIGN…), art-direction material.
- **Carries as reference (stays here, mined when needed)**: GPS filtering /
  heading / projection logic (`client-core/geo/*`), WebSocket
  reconnect/backoff design (`client-core/net/gameSocket.ts`), server deploy
  scaffolding (`fly.toml`, Dockerfiles), the procgen-determinism discipline.
- **Does not carry**: the sim (`shared/` — old rules), the web client, the RN
  plan, the sprite pipeline (2D-era), the hex-grid combat.

This repo is archived in place as the reference mine — no cruft migrates.
Suggested shape for the new repo: `game/` (Godot project), `server/` (Node,
seeded from patterns here, not copied wholesale), `tools/` (tile pipeline,
protocol codegen), `docs/` (the bible moves in).

## Fallback path

If the spikes kill Godot: **TypeScript + Three.js on WebGPU in a native
shell** ([react-native-wgpu](https://github.com/wcandillon/react-native-webgpu)
runs Three.js without a webview; or WKWebView, pending an on-device WebGPU
check). Keeps the #1 agent loop, compile-checked protocol, and much of
`client-core/` — and re-accepts the hand-rolled animation layer with WebGPU
headroom as the consolation. The map pipeline (PMTiles/MVT/decoration) is
identical in both futures, so spike 2's decoder design should stay
renderer-agnostic where cheap.

## Open items

- [ ] Run spike 1 (GPS plugin + battery walk) — needs a Mac build once + a
      TestFlight profile.
- [ ] Run spike 2 (MVT → fantasy tiles on-device).
- [ ] Pick the exact Godot pin (4.6.x vs 4.5.2 LTS-ish maintenance branch)
      after checking the A13 regression status if pre-A14 devices matter.
- [ ] Name + create the fresh repo; move the design bible; archive this repo's
      README pointer.
- [ ] Protocol codegen sketch: Zod schema in server as source of truth →
      generated GDScript validators.
- [ ] ODbL attribution line in the new app's splash/credits from day one.
