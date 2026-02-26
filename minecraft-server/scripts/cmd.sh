#!/bin/bash
# Send command to Minecraft server console
set -euo pipefail

MC_SCREEN="${MC_SCREEN:-minecraft}"

if [[ $# -eq 0 ]]; then
  echo "Usage: cmd.sh <command>"
  echo "Example: cmd.sh 'say Hello everyone!'"
  exit 1
fi

if ! screen -list | grep -q "\.$MC_SCREEN\b"; then
  echo "❌ Server not running"
  exit 1
fi

CMD="$*"
screen -S "$MC_SCREEN" -X stuff "$CMD\n"
echo "✅ Sent: $CMD"
