#!/bin/bash
# Restart Minecraft server
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/stop.sh"
sleep 2
bash "$SCRIPT_DIR/start.sh" "$@"
