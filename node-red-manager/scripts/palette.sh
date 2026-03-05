#!/bin/bash
# Node-RED Manager — Palette (Node) Management
set -euo pipefail

NR_DIR="${NODE_RED_DIR:-$HOME/.node-red}"
ACTION="${1:-help}"
shift 2>/dev/null || true

case "$ACTION" in
  install)
    if [ $# -eq 0 ]; then
      echo "Usage: bash scripts/palette.sh install <package1> [package2] ..."
      exit 1
    fi
    cd "$NR_DIR"
    for PKG in "$@"; do
      echo "📦 Installing $PKG..."
      npm install "$PKG"
      echo "✅ $PKG installed"
    done
    echo ""
    echo "Restart Node-RED to load new nodes: bash scripts/manage.sh restart"
    ;;

  remove|uninstall)
    if [ $# -eq 0 ]; then
      echo "Usage: bash scripts/palette.sh remove <package1> [package2] ..."
      exit 1
    fi
    cd "$NR_DIR"
    for PKG in "$@"; do
      echo "🗑️  Removing $PKG..."
      npm uninstall "$PKG"
      echo "✅ $PKG removed"
    done
    echo ""
    echo "Restart Node-RED to apply: bash scripts/manage.sh restart"
    ;;

  list)
    echo "📦 Installed Node-RED Nodes"
    echo "=========================="
    cd "$NR_DIR"
    if [ -f package.json ]; then
      node -e "
        const pkg = require('./package.json');
        const deps = pkg.dependencies || {};
        const entries = Object.entries(deps).filter(([k]) => k.startsWith('node-red-'));
        if (entries.length === 0) {
          console.log('No extra nodes installed');
        } else {
          entries.forEach(([name, ver]) => console.log('  ' + name + ' @ ' + ver));
          console.log('');
          console.log('Total: ' + entries.length + ' node packages');
        }
      "
    else
      echo "No package.json found in $NR_DIR"
    fi
    ;;

  search)
    QUERY="${1:-}"
    if [ -z "$QUERY" ]; then
      echo "Usage: bash scripts/palette.sh search <query>"
      exit 1
    fi
    echo "🔍 Searching npm for Node-RED nodes: $QUERY"
    echo ""
    npm search "node-red-contrib-${QUERY}" --long 2>/dev/null | head -20 || \
    npm search "node-red ${QUERY}" --long 2>/dev/null | head -20
    ;;

  update)
    cd "$NR_DIR"
    echo "⬆️  Updating all Node-RED nodes..."
    if [ -f package.json ]; then
      node -e "
        const pkg = require('./package.json');
        const deps = Object.keys(pkg.dependencies || {}).filter(k => k.startsWith('node-red-'));
        if (deps.length) {
          console.log('Updating: ' + deps.join(', '));
        }
      "
      npm update
      echo "✅ All nodes updated"
      echo "Restart Node-RED to apply: bash scripts/manage.sh restart"
    else
      echo "No package.json found"
    fi
    ;;

  help|*)
    echo "Node-RED Palette Manager"
    echo ""
    echo "Usage: bash scripts/palette.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  install <pkg...>   Install node packages"
    echo "  remove <pkg...>    Remove node packages"
    echo "  list               List installed nodes"
    echo "  search <query>     Search npm for nodes"
    echo "  update             Update all installed nodes"
    echo ""
    echo "Popular nodes:"
    echo "  node-red-dashboard              Web dashboard UI"
    echo "  node-red-contrib-telegrambot    Telegram bot integration"
    echo "  node-red-contrib-home-assistant-websocket  Home Assistant"
    echo "  node-red-contrib-cron-plus      Advanced cron scheduling"
    echo "  node-red-contrib-influxdb       InfluxDB time-series DB"
    echo "  node-red-contrib-mqtt-broker    MQTT broker"
    echo "  @flowfuse/node-red-dashboard    Dashboard 2.0"
    ;;
esac
