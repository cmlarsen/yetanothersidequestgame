# React Native conversion plan

**Goal:** convert the client to a native iOS-first React Native app with
high-fidelity GPS, top-quality 3D graphics, and OTA updates — while keeping the
"commit → push → deploy → walk outside" loop drivable entirely from Claude Code
cloud (no Mac, no local Xcode).

Ecosystem facts below are as of July 2026 (Expo SDK 56 / RN 0.85 / three r17x).
Re-verify versions at execution time.

---

## 0. What this conversion actually is (and isn't)

The architecture was built for exactly this move. Per POC-PLAN §1.0/§8.0, the
web client is a *disposable §3 consumer*: all game logic, GPS projection, and
determinism live in `shared/` + `server/sim/` behind the frozen JSON WebSocket
protocol (`shared/protocol.ts`, ProtocolVersion 2).

**Zero changes:** `server/`, `shared/`, the protocol, the Fly deployment, and
every sim/unit/integration/golden test — they never touch the client.

**Ports nearly verbatim (plain TS, no DOM):**

| Module | Why it carries |
|---|---|
| `web/src/store/store.ts` (545 ln) | Zustand 5 works in RN; includes the §3.6 interp buffers |
| `web/src/net/gameSocket.ts` (217 ln) | RN has a global `WebSocket`; reconnect/backoff/heartbeat logic is platform-free |
| `web/src/net/geoProjection.ts` (70 ln) | already has a pluggable position source (`setPositionSource('manual')`) — swap the hardware watch, keep the rest |
| `web/src/render/actorAssets.ts`, `render/procgen.ts` | pure data / pure hash (must stay byte-identical to server procgen) |

**The real work — four surfaces:**

1. The ~980-line hand-rolled three.js renderer (`web/src/render/persp3d.ts`) +
   `heroPreview.ts` → an RN 3D stack (§2).
2. The DOM/CSS "Glory" UI (`App.tsx` 1,560 ln + `ui/kit/` + ~1,300 ln CSS) →
   RN components (§5).
3. Browser APIs → native: geolocation, compass, pointer/wheel gestures,
   `requestAnimationFrame`, the `window` CustomEvent bus (§3, §5).
4. The Playwright vision harness → a native-viable verification story (§7).

Net-new: Expo/EAS scaffolding, OTA pipeline, TestFlight distribution (§4, §6).

---

## 1. Platform baseline: Expo SDK 56, CNG, dev client

- **Expo SDK 56** (RN 0.85, React 19.2 — matches our React 19), New
  Architecture (mandatory since SDK 55), **Hermes v1**.
- **Continuous Native Generation (prebuild)** — no checked-in `ios/` dir.
  Native config lives in `app.json` + config plugins; native builds happen on
  EAS servers. This is what keeps the whole loop Mac-free and Claude-drivable.
- **expo-dev-client** development builds: a custom binary with our native
  module set baked in; all iteration after that is JS, delivered over the wire
  (dev server in the field via tunnel, EAS Update otherwise).
- **EAS Build** (remote macOS fleet) + **EAS Submit** (App Store Connect API
  key → TestFlight, no Mac ever). Free tier: 15 iOS builds/mo — enough, since
  binaries are rare by design (§4). Paid tiers exist if we outgrow it.

New top-level directory: **`mobile/`** — the Expo app. Portable client modules
(store, net, actorAssets, procgen, and the new renderer core) are extracted to
**`client-core/`**, imported by both `web/` and `mobile/` the same way
everything already imports `shared/` (relative paths, one tsconfig). The purity
lint doesn't apply to it, but the same discipline does: `client-core/` is
DOM-free and RN-API-free; platform glue stays in `web/src` / `mobile/src`.

---

## 2. 3D: three.js on WebGPU (primary), Filament (hedge) — decided by a spike gate

The 2026 field, ranked for our constraints (top quality + OTA-updatable
gameplay + 980 lines of existing three.js):

| Option | Verdict |
|---|---|
| **react-native-webgpu + three.js `WebGPURenderer`** | **Primary bet.** wcandillon's Dawn-backed WebGPU (v0.5.x, active, July 2026 releases); three.js runs out of the box since r168, and `WebGPURenderer` has been production-ready on web since r171. TSL shaders compile to WGSL *and* GLSL. `react-native-webgpu-worklets` (Software Mansion) renders off the JS thread. Our entire renderer — GLTF loading, `SkeletonUtils` clip retargeting, the procedural melee swing, lazy hex terrain, occlusion fade — stays three.js and stays OTA-updatable JS. Risk: 0.x, no official production-ready claim. |
| **react-native-filament (Margelo)** | **Hedge.** Google Filament, Metal-backed, PBR — highest proven mobile fidelity ("production apps with millions of users", v1.11 May 2026). GLB loading, skeletal animation, runs on its own threads. Cost: a different scene API — persp3d.ts is a rewrite, and our custom bits (clip retargeting across rigs, procedural bone animation, CanvasTexture territory decal) need Filament equivalents that may not exist. Scene logic is still JS → still OTA-updatable. |
| r3f v9 + expo-gl | **Avoid for new work.** pmndrs themselves hit "significant performance issues with ExpoGL" and are steering native to WebGPU; expo-three unmaintained since ~2024. |
| Unity-as-a-Library / SceneKit / RealityKit | **Rejected.** Gameplay code compiles into the binary — kills the OTA requirement. |
| react-native-skia | Not a 3D engine. Possible companion for HUD/2D overlay, not required (§5). |

**M0 spike gate (timeboxed ~1 week):** build the *actual* scene on a real
iPhone — KayKit hex terrain radius, 6 skinned heroes + skeletons with
retargeted `anim_movement`/`anim_general` clips, weapon props on hand bones,
the procedural swing, shadow-casting directional light, fog, 20+ animated
mobs. Measure sustained FPS, thermals, memory, and startup.
**Gate (decided 2026-07-11): react-three-fiber + three.js `WebGPURenderer` on
react-native-webgpu is PRIMARY.** r3f v9 is renderer-agnostic pure JS, so the
declarative scene layer rides the WebGPU backend already in the binary — with
proven-on-these-assets cross-rig clip retargeting, procedural bone control,
and `.gltf` loading carried over from the web renderer. Owner-vetoed
alternatives: Filament (rewrite-everything scene API, GLB-only, unproven
retargeting — stays in the binary as fallback-only, no further investment
unless WebGPU disappoints on hardware); expo-gl/expo-three (unmaintained,
known ExpoGL perf ceiling — never; note the dev-client already replaces Expo
Go, so no candidate was ever Go-compatible anyway). The spike now validates
the primary on hardware rather than running a two-way bake-off.

Either way, the winning renderer core lives in `client-core/render/` behind
the existing `Persp3D` interface (`render/project/groundPoint/orbitBy/...`),
which is already renderer-agnostic.

**The quality upgrade** (this is where "top quality" lands, post-parity, §6 M5):
the current web renderer deliberately cut postprocessing for mobile-web GPU
budget. Native + WebGPU/TSL reopens it: bloom on rift glows, SSAO, better
shadow cascades, full-res rendering (drop the 0.7 upscale trick), tone
mapping, and particle FX — each shipped as an OTA update, measured on-device.

**Bonus of the three.js path:** `WebGPURenderer` also runs on web (WebGL2
fallback built in). The ported renderer in `client-core/` can be consumed by
`web/` too — one renderer codebase, and the existing Playwright vision harness
keeps exercising the real scene graph (§7).

---

## 3. High-fidelity GPS

Current pipeline is deliberately dumb on-device: `watchPosition` → 2 Hz
throttle → raw `{lat,lng,accuracy}` over `OP.GPS`; projection and gating are
server-side (`shared/geo.ts`). Upgrading fidelity is **client-only** — no
protocol or sim changes.

1. **Source: `expo-location`**, `Accuracy.BestForNavigation`
   (= `kCLLocationAccuracyBestForNavigation`), `watchPositionAsync` with
   `timeInterval`/`distanceInterval` tuned for on-foot play. Foreground-first:
   gameplay requires the screen anyway (LAUNCH.md's play pattern), so
   While-Using permission suffices at first.
2. **Filter module: `client-core/geo/filter.ts`** — pure TS, deterministic,
   unit-testable like everything else in this repo. Accuracy-gated Kalman (or
   EMA fallback) + stationary/walking/running adaptive thresholds + outlier
   rejection (teleport spikes, accuracy > threshold). Feed it via the existing
   `pushFix` seam; the manual/mock source keeps working, so filter tests run
   on recorded real-walk fix logs (capture these in the first field session).
3. **Heading:** replace the `deviceorientationabsolute`/`webkitCompassHeading`
   hack with `Location.watchHeadingAsync` (true heading, iOS-calibrated) for
   heading-up camera mode.
4. **Background (later, optional):** if we ever want tracking with the phone
   pocketed, `expo-location` `startLocationUpdatesAsync` + `UIBackgroundModes:
   ["location"]`, or upgrade to Transistorsoft `react-native-background-
   geolocation` (motion-based, geofencing; **free on iOS**, license only for
   Android release). Not needed for v0 — decide after field data.
5. **Consider raising `GPS_MAX_HZ`** (currently 2) once the filter exists —
   BestForNavigation delivers ~1 Hz+ high-grade fixes; the constant lives in
   `shared/constants.ts` and the server already rate-tolerates.

iOS backgrounding also suspends the WebSocket — the client already re-JOINs on
reconnect, but wire up `OP.RESUME` (exists in the protocol, unused) so
foregrounding the app doesn't cold-join. Small server + client task, the one
protocol-adjacent item in this plan.

---

## 4. OTA updates: EAS Update

The point: after one TestFlight install, iteration reaches phones without
rebuilds or reinstalls.

- **EAS Update** with the **`fingerprint` runtime version policy** — the
  runtime version is computed from the native code surface, so "does this
  change need a new binary?" is answered mechanically, not by memory.
- **Channels:** `production` (TestFlight builds), `preview` (field-test
  builds). Branches map onto them; percentage rollouts + rollback built in.
- **What ships OTA:** all JS (sim `shared/`, client-core, renderer, UI, tuning)
  **and assets** — the 6.4 MB of KayKit GLBs load via `expo-asset` and ride
  updates (limit is 1,000 assets/update; we're at ~100 files). New art =
  `pack:models` + `eas update`, no rebuild. Hermes bytecode diffing (default in
  SDK 56) keeps downloads small.
- **What forces a binary:** adding/upgrading a native module. Mitigation:
  **freeze the native module set per milestone** — expo-location, expo-sensors,
  react-native-webgpu (or filament), gesture-handler, reanimated, expo-updates,
  expo-dev-client — and batch native changes.
- **Compliance:** App Review Guidelines / DPLA §3.3.1(B) permit downloaded
  interpreted code that doesn't change the app's primary purpose. RN JS OTA via
  EAS Update is the canonical compliant case (CodePush is dead as of March
  2025; EAS Update is the successor default). Don't gate hidden features on
  updates (2.3.1).
- **Session continuity across updates:** the client keeps `sessionToken` in
  memory only and re-JOINs. Persist identity (`characterId` + token) in
  `expo-secure-store` so an OTA restart resumes the same character. (Worth
  doing on web too, eventually.)

**Update cadence in practice:** `eas update` checks on launch; a field tester
kills and reopens the app to pick up a push. That's the new "refresh the page."

---

## 5. UI, input, and the game loop

- **Glory kit → RN components.** `ui/kit/` (Button, Panel, Meter, TabBar,
  LootSlot, Icon…) reimplemented with RN `StyleSheet` + a `tokens.ts` port of
  `tokens.css` (design values from DESIGN-SYSTEM.md). No CSS-in-JS framework —
  matches the repo's plain-CSS ethos and keeps OTA bundles lean. Fonts via
  `expo-font`; Material Symbols icons via the font file already in
  `web/public/fonts`.
- **App.tsx decomposition.** The 1,560-line single file gets split as it's
  ported (screens: Join, MapView; layers: chrome, dock, dialogue, merchant,
  inventory, overlays). The giant `useEffect` untangles into: gesture handlers
  (react-native-gesture-handler: pan/pinch/tap replace pointer+wheel), a
  location subscription (§3), a heading subscription, and the frame loop.
- **Frame loop:** Reanimated 4 `useFrameCallback` (worklet, UI thread) replaces
  RAF; with `react-native-webgpu-worklets` the three.js render runs off the JS
  thread entirely. Store reads stay as-is — the §3.6 interpolation code is
  pure and already separates "sample" from "render".
- **2D overlay canvas (`overlay2d.ts`):** port to the three.js scene itself
  (sprites/HUD quads) or react-native-skia. Decide during M2 by what it still
  does post-3D-pivot — much of it predates the 3D-only client.
- **Event bus:** the `window` CustomEvent bus (`sq:recenter` etc.) → a tiny
  typed emitter in `client-core/` (also usable on web).
- **Debug hook:** re-expose `__sq` (gps/clock/teleport…) via a dev-menu panel +
  a global on the RN runtime so harnesses and field debugging keep working.

---

## 6. Milestones

Each milestone ends deployed-to-phone (dev build or TestFlight + OTA), same
"walk outside and feel it" bar as the web milestones.

- **M0 — Spike + walking skeleton (~1–2 wks).**
  `mobile/` Expo app scaffolded; EAS project + `EXPO_TOKEN` wired; dev build
  on a real iPhone. Renderer bake-off (§2 gate) on-device. Walking skeleton:
  app connects to the Fly server over wss, JOINs, streams real GPS via
  expo-location, hero dot moves on a flat placeholder ground. **Gate: renderer
  chosen; end-to-end loop proven on hardware.**
- **M1 — World parity (~2–3 wks).** persp3d.ts ported to `client-core/render/`
  on the chosen stack: hex terrain, decor, heroes/mobs with animation
  retargeting + procedural swing, weapons, territory decal, GPS halo, rift
  glows, occlusion fade, camera (orbit/pan/dolly/heading-up). procgen
  byte-parity vs web verified by hash tests.
- **M2 — Chrome parity (~2 wks).** Glory kit + all screens/overlays in RN;
  gestures; hero preview turntable; join → play → loot → inventory → merchant
  full loop on device.
- **M3 — GPS fidelity + feel (~1 wk).** Filter module with recorded-walk
  tests, heading, `OP.RESUME` on foreground, tuned intervals, field session
  measuring track quality vs the web client.
- **M4 — OTA + TestFlight (~1 wk).** Production EAS Build → EAS Submit →
  TestFlight; channels/rollouts configured; secure-store identity persistence;
  prove the loop: code change → `eas update` → phones pick it up on relaunch,
  no rebuild.
- **M5 — Quality pass (ongoing, all-OTA).** Postprocessing (bloom/SSAO/tone
  mapping), full-res rendering, shadow upgrades, particles, 60 fps budget
  enforcement on mid-tier hardware — each change an `eas update`.

**Cut line:** M0–M4 is the conversion. M5 is the payoff loop this whole plan
exists to enable. The web client stays alive at least through M4 as the
reference implementation and vision-harness surface; retire it only when the
RN client is strictly better in the field.

---

## 7. Verification on native

- **Carries unchanged:** all sim/unit/integration/golden/persistence tests
  (server-side), `lint:purity`, plus new pure tests for the GPS filter and
  renderer procgen parity — all runnable in Claude Code cloud.
- **Vision harness:** Playwright/Chromium doesn't drive an iOS app. Strategy:
  (a) if three/WebGPU wins §2, the shared `client-core` renderer keeps being
  exercised by the *existing* web vision harness — scene-graph regressions
  caught in CI without a device; (b) add **Maestro** flows (YAML-driven,
  EAS-Workflows-runnable on their macOS fleet) for native smoke: launch, join,
  map renders, overlay opens; (c) keep the `__sq` debug hook so deterministic
  screenshot batteries can be rebuilt natively later.
- **On-device perf telemetry:** fps/memory counters behind `?debug`-equivalent
  dev flag, because Claude can't hold the phone — field reports need numbers,
  not vibes.

---

## 8. The Claude Code cloud loop

Everything below runs headless on Linux with a single `EXPO_TOKEN` secret (a
robot token, set in the Claude Code environment + GitHub Actions). A Mac is
never required — EAS builds iOS remotely, EAS Submit talks to App Store
Connect via API key.

New scripts (post-M0):

```jsonc
"ota":        "npm run ci:fast && eas update --branch preview --auto",   // JS/asset change → phones
"ota:prod":   "npm run ci:fast && eas update --branch production --auto",
"build:ios":  "eas build -p ios --profile production --non-interactive --no-wait",
"submit:ios": "eas submit -p ios --latest",                               // → TestFlight
"deploy":     "npm run ci:fast && flyctl deploy -a sidequest-poc --remote-only"  // server, unchanged
```

The per-turn working agreement (CLAUDE.md) evolves to:

1. Commit to `main`, push (unchanged).
2. Server change → `npm run deploy` (unchanged).
3. Client JS/asset/tuning change → `npm run ota` — phones get it on next
   app relaunch. This is the common case, by design.
4. Native module change (rare, batched) → `build:ios` + `submit:ios`, bump
   handled by the fingerprint runtime policy; testers reinstall from
   TestFlight once per milestone-ish.

Optional hardening: a GitHub Action (`expo/expo-github-action`) that runs
`eas update --auto` on push to `main` when `mobile/`/`client-core/`/`shared/`
changed — then Claude's existing commit+push habit *is* the OTA deploy.

---

## 9. Risks

| Risk | Mitigation |
|---|---|
| react-native-webgpu is 0.x | M0 spike gate with Filament as a real, funded hedge; renderer isolated behind `Persp3D` interface either way |
| Filament path = full renderer rewrite + missing custom features (clip retargeting, procedural bones, CanvasTexture decals) | Spike explicitly tests these, not just a spinning cube |
| DPLA §3.3.1(B) names JavaScriptCore/WebKit; Hermes OTA is industry-standard but textually gray | Accepted, universal practice (every EAS Update app); no feature-gating shenanigans |
| Native-module drift breaks OTA silently | `fingerprint` runtime policy makes it mechanical; freeze module set per milestone |
| iOS suspends sockets/GPS in background | Foreground-first design; `OP.RESUME`; background mode only if field data demands it |
| No native vision harness at first | Shared renderer keeps web harness meaningful; Maestro smoke flows; on-device perf counters |
| EAS free-tier ceilings (15 iOS builds/mo, 1k MAU updates) | Fits the binaries-are-rare design; Starter tier ($19/mo) is the cheap escape hatch |

---

## 10. Decision log

- **Expo (CNG + dev-client) over bare RN** — keeps the loop Mac-free and
  Claude-drivable; bare buys nothing we need.
- **Renderer: r3f + three.js-on-WebGPU primary, Filament fallback-only**
  (final, 2026-07-11). History: plan opened three.js-primary (code carryover)
  → owner OK'd full rewrite, flipping Filament to default → owner's own
  research flagged Filament's implementation complexity, and the Expo Go
  concern was moot (the dev-client model already left Go for every
  candidate), so it flipped back with r3f's declarative layer on top. Both
  libraries remain in the frozen M0 native set so the fallback needs no
  rebuild.
- **expo-location over Transistorsoft for v0** — foreground gameplay doesn't
  need motion-based background tracking; upgrade path stays open (iOS-free
  license).
- **EAS Update over self-hosted expo-updates** — self-hosting on Fly is
  possible (open protocol) but is undifferentiated ops; revisit only if
  pricing or control forces it.
- **Keep the web client through M4** — reference implementation, vision
  harness, and a hedge against native surprises.

---

## 11. Status (2026-07-11)

Landed in this branch:

- **`client-core/` extracted** — store, gameSocket, geoProjection, actorAssets,
  procgen moved out of `web/src` with platform seams injected
  (`configureSocket({url, onNotice})`, `setGeoWatcher(...)`); web re-wired via
  `web/src/net/platform.ts`; root `ci:fast` green.
- **`mobile/` scaffolded** — Expo SDK 57 (RN 0.86, React 19.2), New Arch,
  Hermes. Native set frozen for M0: expo-location, expo-dev-client,
  expo-updates, expo-secure-store, gesture-handler, reanimated,
  **react-native-filament AND react-native-webgpu** (both in one binary for the
  bake-off), three 0.185, zustand.
- **M0 walking skeleton written** — join screen, socket → Fly server,
  expo-location `BestForNavigation` → `OP.GPS`, top-down debug map, plus a
  Filament spike screen (Knight GLB) and a WebGPU spike screen (three.js
  `WebGPURenderer`). Compiles + full Metro iOS export verified headlessly;
  **not yet run on a device**.
- **EAS config** — `eas.json` (development / development-simulator / preview /
  production channels), `app.json` (bundle id `com.risescience.sidequest`,
  location strings, `runtimeVersion: fingerprint`), root scripts `ota`,
  `ota:prod`, `build:ios*`, `submit:ios`, `ci:mobile`.
- **Metro monorepo wiring** (`mobile/metro.config.js`) — three quirks solved,
  documented inline: TS NodeNext `./x.js` → `.ts` fallback; bare-import
  re-anchoring so workspace files never resolve the root's second React;
  `experiments.onDemandFilesystem: "UNSTABLE_ALLOW_ALL"` in app.json because
  Expo's export-time lazy filesystem is otherwise scoped to `mobile/` and
  can't see `../client-core` + `../shared` (expo-doctor's schema check flags
  the string value — known schema lag in @expo/config-types, safe to ignore).

EAS is live (token arrived same day):

- Project `@yetanothersidequest/sidequest` created; `updates.url` + projectId
  committed. **First OTA update published to `preview`** (runtime fingerprint
  `71559110…`) — the headless code→`eas update`→phones loop is proven.
- The publish endpoint rejected `onDemandFilesystem: "UNSTABLE_ALLOW_ALL"` in
  manifests, so it moved from app.json into `app.config.js`, applied only to
  `export`/`export:embed` (bundling) processes.
- Two build failures diagnosed from worker logs and fixed: publish-endpoint
  manifest rejection (→ app.config.js export-only experiment) and a runtime
  fingerprint mismatch (local config evaluated `platforms` with web, workers
  didn't; prebuild-generated `ios/` entering the worker hash →
  `platforms` pinned + `.fingerprintignore`).
- **iOS simulator dev build FINISHED on EAS** with runtime version
  `648d8401…` — exactly matching the published preview update. The full
  pipeline (code → `eas update` → matching binary) is proven end to end,
  entirely from the cloud sandbox.
- **On-device perf verdict (iPhone 12 Pro): 60 fps** at ~1.5×-logical-point
  resolution with the mobile GPU diet (blob shadows, lambert materials, no
  point lights — all renderer options, web keeps full quality). The scene was
  GPU-fragment-bound: full-res+PBR+shadow-maps ran 34 fps. Quality re-buys
  (real shadows at 512², postprocessing) should be measured one at a time
  against this 60 fps floor.

### Quality re-buys against the 60 fps floor (issue #30)

Bought back one measured change at a time; keep whatever holds ≥60 fps.

- **Real shadows — SHIPPED, hero-only.** First attempt (all actors cast,
  512²) measured 40 fps, but that was on a device in Low Power Mode AND with
  every skinned actor casting. The stress lab showed shadow cost scales with
  the number of **skinned casters**, so casting from only the self hero makes
  the extra pass cheap: lab-measured **~52 fps in a deliberately hard config**
  (15 actors, auto-move on, trees off) and ~60 in normal play, on an iPhone 12
  Pro. Shipped in `WorldScreen`: `shadows: true` +
  `setDebug({ shadowCasters: 'self', shadowMapSize: 512 })`, `shadowEvery: 3`.
  The hero gets a real shadow (kills the most visible downgrade); mobs and other
  heroes keep the cheap blob decals. Runtime toggles for all of this live in the
  StressLab debug screen (`persp3d.setDebug`).
- **Real-world sun direction (GPS + clock)** — landed, ~free. `client-core/geo/sun.ts`
  computes the sun's azimuth/elevation from the player's latest GPS fix and the
  wall clock (NOAA solar-position maths, pure + unit-tested), refreshed ~every
  30 s in the frame loop and passed into the renderer as `PerspFrame.sun`. The
  directional light now sits where the actual sun is above the player, and the
  blob shadows lean/lengthen away from it by time of day (elevation floored at
  ~8.6° so the light never dips underground; callers without a fix keep the
  fixed dusk angle). No shadow-map pass, so no fps cost — and it feeds the real
  sun direction straight into shadow maps if/when the cheaper-cast approach lands.
- **Render resolution** (`RENDER_PR` → ~1.75×) — not yet attempted.
- **Material profile** (selective PBR on hero/rift) — not yet attempted.
- **Postprocessing** (bloom / tone mapping / particles) — deferred to M5.

Still blocked on credentials:

1. Apple Developer account (App Store Connect API key in EAS): device dev
   builds + TestFlight. Simulator builds need no Apple credentials.
