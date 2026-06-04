#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PID_FILE="qemu-templeos.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "No TempleOS PID file found."
  exit 0
fi

PID="$(cat "$PID_FILE")"

if ! kill -0 "$PID" 2>/dev/null; then
  echo "TempleOS PID $PID is not running."
  rm -f "$PID_FILE"
  exit 0
fi

kill "$PID"
echo "Stopped TempleOS PID $PID."
