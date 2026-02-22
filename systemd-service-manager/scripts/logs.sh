#!/bin/bash
# View logs for a systemd service
set -euo pipefail

SERVICE="${1:?Usage: bash logs.sh <service-name> [--lines N] [--follow] [--since TIME] [--priority LEVEL]}"
shift

ARGS=("-u" "$SERVICE" "--no-pager")

while [[ $# -gt 0 ]]; do
  case $1 in
    --lines|-n) ARGS+=("-n" "$2"); shift 2 ;;
    --follow|-f) ARGS+=("-f"); shift ;;
    --since) ARGS+=("--since" "$2"); shift 2 ;;
    --priority) ARGS+=("-p" "$2"); shift 2 ;;
    --reverse) ARGS+=("-r"); shift ;;
    --output) ARGS+=("-o" "$2"); shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Default to last 50 lines if no lines/follow specified
if ! printf '%s\n' "${ARGS[@]}" | grep -qE '^(-n|-f)$'; then
  ARGS+=("-n" "50")
fi

journalctl "${ARGS[@]}"
