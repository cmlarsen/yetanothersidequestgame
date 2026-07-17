# Map Data — how the fantasy map gets its geography

> Status: **working decision, lightly held.** Captured 2026-07. Options weighed:
> (1) pure procgen overlay, (2) OpenStreetMap reskinned, (3) hybrid.

## The decision: OSM as ground truth, fantasy skin on top

### Why not pure procgen

- **It breaks the game's one magic trick.** The emotional payload of a location
  game is "that's *my* street — our park is a haunted forest." The veil fiction
  makes real geography a hard requirement: the lens shows the Other world
  *pressed against ours*, so the maps must match or the conceit collapses.
- **Wayfinding.** Players physically navigate to quests. A map without real
  streets and paths fails navigation — and for kids that's a safety problem,
  not just UX.

### Why OSM

- **It's what the genre runs on.** Pokémon GO renders from OSM data (since
  2017); Orna and most indie GPS games are OSM. It's the only map source whose
  license (ODbL, free with attribution) and styling freedom allow a full
  fantasy reskin. Google's styling is shallow and priced for ad-supported
  apps; Apple MapKit can hide POIs but can't reskin water into a parchment sea.
- **OSM tags are game data, not just pixels.** Real water, parks, footpaths,
  cemeteries, and land use feed the biome-spawn system (see GENRE-LESSONS):
  water monsters near actual rivers, wraiths in actual graveyards. Procgen
  can't do that — it's OSM's biggest gift to us.

### The stack

- **Vector tiles + MapLibre** (open-source Mapbox GL fork; solid native iOS
  SDK). The fantasy skin is one style JSON: parks→forest fill,
  buildings→hamlet clusters, roads→dirt trails, water→parchment sea, pixel-art
  sprites as POI icons.
- **No-budget hosting: Protomaps / PMTiles.** Planet (or regional extract)
  compiles to a single static file served from any dumb file host — no tile
  server, no per-request pricing. Fallback: MapTiler / Stadia free tiers cover
  prototype traffic.

### The hybrid layer: deterministic procgen decoration

OSM supplies geometry; a **seeded hash of tile coordinates** scatters the
fantasy dressing — which grove is enchanted, where standing stones sit, which
building cluster reads as "ruins." Deterministic means every player sees the
same forest at the same park (shared-world ready) with zero server state. The
skin gets ~80% of the fantasy feel; the prop layer gets the rest and gives
procgen a job it's actually good at.

## Caveat

OSM quality varies by region — excellent in cities/suburbs, thin in rural
areas. Fine for the playtest radius; remember it if the game travels.

## Cheap on-ramp (when wanted — not now)

MapLibre GL JS drops into the web prototype: a quick parchment style over free
tiles replaces the fake map with the player's actual neighborhood. An
afternoon-scale experiment, standing offer.

## POC map decision (2026-07): procgen now, OSM later, behind one source

The decision above is **sequenced**, not overturned:

- **Now → procgen overlay.** The test venue is a private ~40-acre **forest** —
  exactly where OSM is emptiest (no streets, no buildings, maybe one trail), so
  reskinning it would give a *barer*, more boring map than procgen, not a richer
  one. The POC renders a **deterministic procgen overworld** (POC-PLAN §6.3.4),
  which also looks good anywhere with zero tile hosting.
- **Later → OSM + MapLibre, in town.** The OSM stack above stays the production
  direction, tested where it shines (a mapped neighbourhood), not the forest.
- **One swappable `worldSource` so nothing is throwaway.** Both sit behind
  `terrainAt(cell)` / `decorationAt(cell)`. The **deterministic decoration layer
  is shared** between them (the hybrid layer above), and a procgen wilderness
  renderer is something the OSM future needs anyway (OSM can't render the
  forest) — so the procgen work is the rural half of the real system.

**Chosen POC tileset (downloaded + vendored).** Kenney **Roguelike/RPG** pack —
**CC0** — at `assets/tiles/roguelike_sheet_16x16.png` (+ `roguelike_LICENSE.txt`).
968×526 sheet, 16×16 tiles / 1px margin (1767 tiles): grass/dirt/water/road,
forest, rocks, flowers, fences, buildings, tents+campfire, graveyard, market.
Source: `https://kenney.nl/assets/roguelike-rpg-pack`. Bright base art,
**colour-graded to the Glory veil palette at render**; swappable for a moodier
CC0 pack (e.g. 0x72 µFantasy) or a detailed set later without touching procgen.
