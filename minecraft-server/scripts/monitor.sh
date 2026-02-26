#!/bin/bash
# Monitor Minecraft server resources
set -euo pipefail

MC_DIR="${MC_DIR:-$HOME/minecraft-server}"
MC_SCREEN="${MC_SCREEN:-minecraft}"
WATCH=false

[[ "${1:-}" == "--watch" ]] && WATCH=true

show_stats() {
  cd "$MC_DIR"
  
  if ! screen -list | grep -q "\.$MC_SCREEN\b"; then
    echo "❌ Server not running"
    return 1
  fi
  
  JAVA_PID=$(pgrep -f "java.*server.jar" 2>/dev/null | head -1 || echo "")
  
  echo "═══════════════════════════════════"
  echo "  🎮 Minecraft Server Monitor"
  echo "═══════════════════════════════════"
  
  if [[ -n "$JAVA_PID" ]]; then
    # CPU & Memory
    CPU=$(ps -o %cpu= -p "$JAVA_PID" 2>/dev/null | tr -d ' ')
    RSS=$(ps -o rss= -p "$JAVA_PID" 2>/dev/null | tr -d ' ')
    RSS_MB=$((${RSS:-0} / 1024))
    ELAPSED=$(ps -o etime= -p "$JAVA_PID" 2>/dev/null | tr -d ' ')
    
    echo "  🖥️  CPU: ${CPU:-?}%"
    echo "  💾 RAM: ${RSS_MB} MB"
    echo "  🕐 Uptime: ${ELAPSED:-?}"
  fi
  
  # World size
  [[ -d world ]] && echo "  🌍 World: $(du -sh world 2>/dev/null | cut -f1)"
  
  # Backups
  if [[ -d backups ]] && ls backups/*.tar.gz &>/dev/null; then
    echo "  📦 Backups: $(ls -1 backups/*.tar.gz | wc -l) ($(du -sh backups | cut -f1))"
  fi
  
  # Version
  [[ -f .mc-info.json ]] && echo "  📋 $(jq -r '.version + " (" + .type + ")"' .mc-info.json)"
  
  # System resources
  echo "  ─────────────────────────────────"
  echo "  📊 System: $(free -h | awk '/Mem:/{print $3 "/" $2 " used"}') | $(nproc) cores"
  echo "  💽 Disk: $(df -h "$MC_DIR" | awk 'NR==2{print $3 "/" $2 " (" $5 " used)"}')"
  echo "═══════════════════════════════════"
  echo "  $(date '+%Y-%m-%d %H:%M:%S')"
}

if $WATCH; then
  while true; do
    clear
    show_stats || exit 1
    sleep 30
  done
else
  show_stats
fi
