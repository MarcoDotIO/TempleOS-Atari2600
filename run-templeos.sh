#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

QEMU_BIN="${QEMU_BIN:-qemu-system-x86_64}"
DISK_IMAGE="${DISK_IMAGE:-templeos-hdd.qcow2}"
TRANSFER_IMAGE="${TRANSFER_IMAGE:-}"
VNC_DISPLAY="${VNC_DISPLAY:-2}"
VNC_PORT=$((5900 + VNC_DISPLAY))
PID_FILE="qemu-templeos.pid"
MONITOR_SOCK="qemu-templeos-monitor.sock"
LOG_FILE="qemu-templeos.log"

if [[ ! -f "$DISK_IMAGE" ]]; then
  echo "Missing $DISK_IMAGE. Install TempleOS first or restore the disk image." >&2
  exit 1
fi

QEMU_ARGS=(
  -name TempleOS
  -machine pc,accel=tcg
  -cpu qemu64
  -m 512M
  -rtc base=localtime
  -boot c
  -drive "file=${DISK_IMAGE},format=qcow2,if=ide,index=0,media=disk"
)
if [[ -n "$TRANSFER_IMAGE" ]]; then
  if [[ ! -f "$TRANSFER_IMAGE" ]]; then
    echo "Missing transfer image $TRANSFER_IMAGE." >&2
    exit 1
  fi
  QEMU_ARGS+=(-drive "file=${TRANSFER_IMAGE},format=raw,if=ide,index=1,media=disk")
fi

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "TempleOS is already running as PID $(cat "$PID_FILE")."
  echo "RealVNC address: 127.0.0.1::${VNC_PORT}"
  exit 0
fi

rm -f "$PID_FILE" "$MONITOR_SOCK" "$LOG_FILE"

"$QEMU_BIN" \
  "${QEMU_ARGS[@]}" \
  -vga std \
  -vnc "127.0.0.1:${VNC_DISPLAY}" \
  -monitor "unix:${MONITOR_SOCK},server,nowait" \
  -pidfile "$PID_FILE" \
  -daemonize \
  -D "$LOG_FILE"

echo "TempleOS started as PID $(cat "$PID_FILE")."
echo "RealVNC address: 127.0.0.1::${VNC_PORT}"
echo "QEMU display syntax: 127.0.0.1:${VNC_DISPLAY}"
