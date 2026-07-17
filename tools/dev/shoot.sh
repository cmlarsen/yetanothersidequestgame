#!/bin/bash
# Screenshot every screen (or a comma-separated subset) to a directory.
# Needs a display (windowed run) — screenshots don't work headless.
# Usage: tools/dev/shoot.sh <output-dir> [route_id,route_id,...]
set -euo pipefail
DIR="${1:?usage: shoot.sh <output-dir> [ids]}"
mkdir -p "$DIR"
DIR="$(cd "$DIR" && pwd)"
cd "$(dirname "$0")/../.."
godot --path game --quit-after 3000 -- --autoshot="$DIR" ${2:+--only="$2"} 2>&1 \
  | grep -vE "^(Godot Engine|Vulkan|Metal|OpenGL)" || true
ls "$DIR"
