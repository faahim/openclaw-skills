#!/bin/bash
# Manage Minecraft server players
set -euo pipefail

MC_DIR="${MC_DIR:-$HOME/minecraft-server}"
MC_SCREEN="${MC_SCREEN:-minecraft}"
ACTION=""
PLAYER=""
REASON=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --whitelist) ACTION="whitelist_$2"; shift 2; [[ $# -gt 0 && ! "$1" =~ ^-- ]] && { PLAYER="$1"; shift; } ;;
    --op) ACTION="op"; PLAYER="$2"; shift 2 ;;
    --deop) ACTION="deop"; PLAYER="$2"; shift 2 ;;
    --ban) ACTION="ban"; PLAYER="$2"; shift 2; [[ $# -gt 0 && ! "$1" =~ ^-- ]] && { REASON="$1"; shift; } ;;
    --unban) ACTION="unban"; PLAYER="$2"; shift 2 ;;
    --online) ACTION="online"; shift ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

send_cmd() {
  if ! screen -list | grep -q "\.$MC_SCREEN\b"; then
    echo "❌ Server not running"
    exit 1
  fi
  screen -S "$MC_SCREEN" -X stuff "$1\n"
}

cd "$MC_DIR"

case "$ACTION" in
  whitelist_add)
    [[ -z "$PLAYER" ]] && { echo "❌ Usage: --whitelist add <player>"; exit 1; }
    send_cmd "whitelist add $PLAYER"
    echo "✅ Added $PLAYER to whitelist"
    ;;
  whitelist_remove)
    [[ -z "$PLAYER" ]] && { echo "❌ Usage: --whitelist remove <player>"; exit 1; }
    send_cmd "whitelist remove $PLAYER"
    echo "✅ Removed $PLAYER from whitelist"
    ;;
  whitelist_list)
    if [[ -f whitelist.json ]]; then
      echo "📋 Whitelisted players:"
      jq -r '.[].name' whitelist.json | while read -r name; do
        echo "  - $name"
      done
      COUNT=$(jq '. | length' whitelist.json)
      echo "  Total: $COUNT players"
    else
      echo "📋 No whitelist file found"
    fi
    ;;
  op)
    send_cmd "op $PLAYER"
    echo "✅ $PLAYER is now an operator"
    ;;
  deop)
    send_cmd "deop $PLAYER"
    echo "✅ $PLAYER is no longer an operator"
    ;;
  ban)
    REASON="${REASON:-Banned by server admin}"
    send_cmd "ban $PLAYER $REASON"
    echo "✅ Banned $PLAYER ($REASON)"
    ;;
  unban)
    send_cmd "pardon $PLAYER"
    echo "✅ Unbanned $PLAYER"
    ;;
  online)
    send_cmd "list"
    echo "📋 Check screen session for online players: screen -r $MC_SCREEN"
    ;;
  *)
    echo "Usage: players.sh [OPTIONS]"
    echo "  --whitelist add|remove|list [player]"
    echo "  --op <player>"
    echo "  --deop <player>"
    echo "  --ban <player> [reason]"
    echo "  --unban <player>"
    echo "  --online"
    ;;
esac
