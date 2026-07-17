#!/bin/bash
# Headless smoke gate: instantiates every route in the shell and fails on any
# script/parse error. Usage: tools/dev/check.sh
set -uo pipefail
cd "$(dirname "$0")/../.."
OUT=$(godot --headless --path game -- --smoke 2>&1)
STATUS=$?
echo "$OUT"
if [ $STATUS -ne 0 ] || echo "$OUT" | grep -qE "SCRIPT ERROR|Parse Error|SMOKE FAIL"; then
  echo "CHECK FAIL"
  exit 1
fi
echo "CHECK PASS"
