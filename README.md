# SideQuest

A roguelike RPG played in the real world — For the King × real-time combat ×
Pokémon Go. Fantasy-reskinned real-world map, high-accuracy GPS, low-poly 3D.
iOS-first, built with Godot 4.6.

**Status: pre-spike scaffold (2026-07).** This repo starts the ground-up
redesign; the prototype era lives in the archived `SideQuestAppV2` repo.
Read these first:

- `docs/REDESIGN-TECH-STACK.md` — why Godot, the map/GPS architecture, the
  two kill-criterion spikes that gate full commitment, and the fallback.
- `docs/NORTH-STAR.md` — goals, audience, tone.
- `CLAUDE.md` — working agreement and conventions.

## Layout

| Path | What |
|---|---|
| `game/` | Godot 4.6 project (GDScript, Mobile renderer) |
| `game/assets/models/` | KayKit character/prop GLBs (licenses alongside) |
| `server/` | authoritative Node/TS server (stub — architecture per docs) |
| `tools/` | tile pipeline, protocol codegen, build scripts (stub) |
| `docs/` | design bible carried over from the prototype |

## Getting started

Open `game/` in Godot **4.6.x** (pin to one exact version). The main scene
is an empty `Node3D` — first real work is spike 1 (GPS plugin + battery
walk) and spike 2 (vector tile → fantasy geometry), per
`docs/REDESIGN-TECH-STACK.md`.

## Attribution

Map data (once rendering): © OpenStreetMap contributors (ODbL). KayKit
models by Kay Lousberg — see `game/assets/models/LICENSE.txt`.
