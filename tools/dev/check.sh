#!/bin/bash
# Headless gate: instantiates every route in the shell (fails on any
# script/parse error), then cross-checks the data layer. Usage: tools/dev/check.sh
set -uo pipefail
cd "$(dirname "$0")/../.."
OUT=$(godot --headless --path game -- --smoke 2>&1)
STATUS=$?
echo "$OUT"
if [ $STATUS -ne 0 ] || echo "$OUT" | grep -qE "SCRIPT ERROR|Parse Error|SMOKE FAIL"; then
  echo "CHECK FAIL"
  exit 1
fi
DATA=$(godot --headless --path game --script res://tests/data_sanity.gd 2>&1)
if ! echo "$DATA" | grep -q "DATA SANITY PASS"; then
  echo "$DATA" | tail -20
  echo "CHECK FAIL"
  exit 1
fi
echo "DATA SANITY PASS"
echo "CHECK PASS"
