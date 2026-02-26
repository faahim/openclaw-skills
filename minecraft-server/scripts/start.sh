#!/bin/bash
# Start Minecraft server in a screen session with optimized JVM flags
set -euo pipefail

MC_DIR="${MC_DIR:-$HOME/minecraft-server}"
MC_MIN_RAM="${MC_MIN_RAM:-2G}"
MC_MAX_RAM="${MC_MAX_RAM:-4G}"
MC_SCREEN="minecraft"
WATCHDOG=false
BACKUP_INTERVAL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --watchdog) WATCHDOG=true; shift ;;
    --backup-interval) BACKUP_INTERVAL="$2"; shift 2 ;;
    --screen) MC_SCREEN="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

cd "$MC_DIR"

if [[ ! -f server.jar ]]; then
  echo "❌ server.jar not found in $MC_DIR"
  echo "   Run install.sh first"
  exit 1
fi

# Check if already running
if screen -list | grep -q "\.$MC_SCREEN\b"; then
  echo "⚠️  Server already running in screen session '$MC_SCREEN'"
  echo "   Attach: screen -r $MC_SCREEN"
  echo "   Stop:   bash scripts/stop.sh"
  exit 1
fi

# Aikar's optimized JVM flags for Minecraft
JVM_FLAGS="${MC_JVM_FLAGS:--XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1}"

CMD="java -Xms$MC_MIN_RAM -Xmx$MC_MAX_RAM $JVM_FLAGS -jar server.jar nogui"

if $WATCHDOG; then
  # Watchdog mode: auto-restart on crash
  WRAPPER='while true; do '"$CMD"'; echo "Server stopped. Restarting in 10s..."; sleep 10; done'
  screen -dmS "$MC_SCREEN" bash -c "$WRAPPER"
  echo "✅ Server started with watchdog (auto-restart on crash)"
else
  screen -dmS "$MC_SCREEN" bash -c "$CMD"
  echo "✅ Server started"
fi

echo "   📺 Attach: screen -r $MC_SCREEN"
echo "   🛑 Stop:   bash scripts/stop.sh"
echo "   💾 RAM:    $MC_MIN_RAM - $MC_MAX_RAM"

# Set up backup cron if requested
if [[ -n "$BACKUP_INTERVAL" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  HOURS="${BACKUP_INTERVAL%h}"
  if [[ "$HOURS" =~ ^[0-9]+$ ]]; then
    CRON_EXPR="0 */$HOURS * * *"
    (crontab -l 2>/dev/null | grep -v "minecraft.*backup"; echo "$CRON_EXPR MC_DIR=$MC_DIR bash $SCRIPT_DIR/backup.sh >> $MC_DIR/logs/backup.log 2>&1") | crontab -
    echo "   ⏰ Auto-backup: every ${HOURS}h"
  fi
fi
