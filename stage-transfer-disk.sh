#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: ./stage-transfer-disk.sh TRANSFER_IMAGE [ROM_PATH]

Copies A2600.HC to the root of a macOS-mountable transfer disk image. When
ROM_PATH is supplied, it is copied as CART.BIN.
EOF
  exit 2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
fi

cd "$(dirname "$0")"

TRANSFER_IMAGE="$1"
ROM_PATH="${2:-}"

if [[ ! -f A2600.HC ]]; then
  echo "Missing A2600.HC next to this script." >&2
  exit 1
fi
if [[ ! -f "$TRANSFER_IMAGE" ]]; then
  echo "Missing transfer image: $TRANSFER_IMAGE" >&2
  exit 1
fi
if [[ -n "$ROM_PATH" && ! -f "$ROM_PATH" ]]; then
  echo "Missing ROM: $ROM_PATH" >&2
  exit 1
fi

MOUNT_DIR="$(mktemp -d /tmp/a2600xfer.XXXXXX)"
ATTACHED=0

cleanup() {
  if [[ $ATTACHED -eq 1 ]]; then
    hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi
  rmdir "$MOUNT_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

hdiutil attach "$TRANSFER_IMAGE" -mountpoint "$MOUNT_DIR" -nobrowse >/dev/null
ATTACHED=1

rm -f "$MOUNT_DIR/A2600.HC" "$MOUNT_DIR/A2600.HC.Z"
COPYFILE_DISABLE=1 cp A2600.HC "$MOUNT_DIR/A2600.HC"

if [[ -n "$ROM_PATH" ]]; then
  rm -f "$MOUNT_DIR/CART.BIN" "$MOUNT_DIR/CART.BIN.Z"
  COPYFILE_DISABLE=1 cp "$ROM_PATH" "$MOUNT_DIR/CART.BIN"
fi

echo "Staged A2600.HC"
if [[ -n "$ROM_PATH" ]]; then
  echo "Staged CART.BIN <= $ROM_PATH"
fi
