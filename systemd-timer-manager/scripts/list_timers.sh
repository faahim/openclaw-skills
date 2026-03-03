#!/usr/bin/env bash
set -euo pipefail
NAME="${1:-}"

if [[ -z "$NAME" ]]; then
  systemctl list-timers --all
  exit 0
fi

echo "=== ${NAME}.timer ==="
systemctl status "${NAME}.timer" --no-pager || true

echo

echo "=== ${NAME}.service recent logs ==="
journalctl -u "${NAME}.service" -n 30 --no-pager || true
