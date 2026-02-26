#!/bin/bash
# Check Minecraft server status
set -euo pipefail

MC_DIR="${MC_DIR:-$HOME/minecraft-server}"
MC_SCREEN="${MC_SCREEN:-minecraft}"

cd "$MC_DIR"

# Check if running
if screen -list | grep -q "\.$MC_SCREEN\b"; then
  PID=$(screen -list | grep "\.$MC_SCREEN\b" | awk '{print $1}' | cut -d. -f1)
  
  # Get Java process PID (child of screen)
  JAVA_PID=$(pgrep -P "$PID" -f "java.*server.jar" 2>/dev/null | head -1 || echo "")
  
  echo "✅ Server RUNNING"
  [[ -n "$JAVA_PID" ]] && echo "   PID: $JAVA_PID"
  
  # Memory usage
  if [[ -n "$JAVA_PID" ]]; then
    RSS=$(ps -o rss= -p "$JAVA_PID" 2>/dev/null | tr -d ' ')
    if [[ -n "$RSS" ]]; then
      RSS_MB=$((RSS / 1024))
      echo "   💾 RAM: ${RSS_MB} MB"
    fi
    
    # CPU usage
    CPU=$(ps -o %cpu= -p "$JAVA_PID" 2>/dev/null | tr -d ' ')
    [[ -n "$CPU" ]] && echo "   🖥️  CPU: ${CPU}%"
    
    # Uptime
    ELAPSED=$(ps -o etime= -p "$JAVA_PID" 2>/dev/null | tr -d ' ')
    [[ -n "$ELAPSED" ]] && echo "   🕐 Uptime: $ELAPSED"
  fi
  
  # World size
  if [[ -d world ]]; then
    WORLD_SIZE=$(du -sh world 2>/dev/null | cut -f1)
    echo "   🌍 World: $WORLD_SIZE"
  fi
  
  # Backup info
  if [[ -d backups ]] && ls backups/*.tar.gz &>/dev/null; then
    BACKUP_COUNT=$(ls -1 backups/*.tar.gz | wc -l)
    BACKUP_SIZE=$(du -sh backups | cut -f1)
    LATEST=$(ls -1t backups/*.tar.gz | head -1 | xargs basename)
    echo "   📦 Backups: $BACKUP_COUNT ($BACKUP_SIZE) — latest: $LATEST"
  fi
  
  # Version info
  if [[ -f .mc-info.json ]]; then
    VERSION=$(jq -r '.version' .mc-info.json)
    TYPE=$(jq -r '.type' .mc-info.json)
    echo "   📋 Version: $VERSION ($TYPE)"
  fi
  
  echo ""
  echo "   📺 Attach: screen -r $MC_SCREEN"
else
  echo "❌ Server NOT RUNNING"
  
  # Show version info
  if [[ -f .mc-info.json ]]; then
    VERSION=$(jq -r '.version' .mc-info.json)
    TYPE=$(jq -r '.type' .mc-info.json)
    echo "   📋 Installed: $VERSION ($TYPE)"
  fi
  
  echo "   ▶️  Start: bash scripts/start.sh"
fi
