#!/usr/bin/env bash
set -euo pipefail

if ! command -v systemctl >/dev/null 2>&1; then
  echo "systemctl not found. This skill requires systemd." >&2
  exit 1
fi

if [[ "$(ps -p 1 -o comm= | tr -d ' ')" != "systemd" ]]; then
  echo "PID 1 is not systemd; timers will not work here." >&2
  exit 1
fi

echo "✅ systemd detected"
systemctl --version | head -n 1
