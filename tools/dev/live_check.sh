#!/bin/bash
# End-to-end live gate: boots the YAS server on 127.0.0.1:8399 with a temp
# DATA_DIR, waits for /healthz, then runs the shell headless in --live-check
# mode (JOIN → RUN_START → scripted spiral → ≥6 hexes claimed + front pct
# change → disconnect → RESUME reattach). PASS = exit 0. 60 s watchdog.
# Usage: tools/dev/live_check.sh
set -uo pipefail
cd "$(dirname "$0")/../.."

PORT=8399
URL="ws://127.0.0.1:${PORT}/ws"
DATA_DIR=$(mktemp -d)
LOG="$DATA_DIR/server.log"
SERVER_PID=""
GODOT_PID=""

cleanup() {
  [ -n "$GODOT_PID" ] && kill -9 "$GODOT_PID" 2>/dev/null
  if [ -n "$SERVER_PID" ]; then
    pkill -TERM -P "$SERVER_PID" 2>/dev/null
    kill "$SERVER_PID" 2>/dev/null
  fi
  # npm → sh → node chains can orphan the listener; sweep by port.
  lsof -ti "tcp:${PORT}" 2>/dev/null | xargs kill 2>/dev/null
  rm -rf "$DATA_DIR"
}
trap cleanup EXIT

(cd server && exec env DATA_DIR="$DATA_DIR" PORT="$PORT" npm start >"$LOG" 2>&1) &
SERVER_PID=$!

for _ in $(seq 1 30); do
  curl -sf "http://127.0.0.1:${PORT}/healthz" >/dev/null 2>&1 && break
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "server exited during boot:"; tail -30 "$LOG"
    echo "LIVE CHECK FAIL"; exit 1
  fi
  sleep 0.5
done
if ! curl -sf "http://127.0.0.1:${PORT}/healthz" >/dev/null 2>&1; then
  echo "healthz never came up:"; tail -30 "$LOG"
  echo "LIVE CHECK FAIL"; exit 1
fi

godot --headless --path game -- "--live-check=${URL}" &
GODOT_PID=$!
# 60 s overall watchdog (macOS ships no `timeout`).
for _ in $(seq 1 120); do
  kill -0 "$GODOT_PID" 2>/dev/null || break
  sleep 0.5
done
if kill -0 "$GODOT_PID" 2>/dev/null; then
  kill -9 "$GODOT_PID" 2>/dev/null
  echo "LIVE CHECK FAIL (60 s watchdog)"
  GODOT_PID=""
  exit 1
fi
wait "$GODOT_PID"
STATUS=$?
GODOT_PID=""
exit $STATUS
