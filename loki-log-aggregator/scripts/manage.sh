#!/bin/bash
# Loki Log Aggregator — Service Manager
# Manage Loki and Promtail services

set -euo pipefail

ACTION="${1:-help}"
TARGET="${2:-all}"

LOKI_CONFIG="/etc/loki/config.yaml"
PROMTAIL_CONFIG="/etc/promtail/config.yaml"

usage() {
  cat <<EOF
Usage: manage.sh <action> [target]

Actions:
  start [loki|promtail|all]    Start service(s)
  stop [loki|promtail|all]     Stop service(s)
  restart [loki|promtail|all]  Restart service(s)
  status                       Show status of all services
  logs [loki|promtail]         Show recent logs
  storage-info                 Show Loki storage usage
  set-retention <duration>     Set log retention (e.g., 168h for 7 days)
  compact                      Force Loki compaction
  backup <dest-dir>            Backup Loki data
  restore <src-dir>            Restore Loki data
  alerts                       List configured alert rules
  uninstall                    Remove Loki + Promtail

Target: loki, promtail, or all (default: all)
EOF
}

do_service() {
  local action=$1 service=$2
  echo "  ${action}ing ${service}..."
  sudo systemctl "$action" "$service"
  echo "  ✅ ${service} ${action}ed"
}

case "$ACTION" in
  start|stop|restart)
    echo "🔄 ${ACTION^}ing services..."
    if [[ "$TARGET" == "all" ]]; then
      [[ "$ACTION" != "stop" ]] && do_service "$ACTION" loki
      do_service "$ACTION" promtail
      [[ "$ACTION" == "stop" ]] && do_service "$ACTION" loki
    else
      do_service "$ACTION" "$TARGET"
    fi
    ;;

  status)
    echo "═══════════════ Service Status ═══════════════"
    echo ""
    echo "── Loki ──"
    systemctl is-active loki 2>/dev/null && echo "  Status: ✅ Running" || echo "  Status: ❌ Stopped"
    if systemctl is-active loki &>/dev/null; then
      READY=$(curl -sf http://localhost:3100/ready 2>/dev/null || echo "unreachable")
      echo "  Ready:  ${READY}"
      METRICS=$(curl -sf http://localhost:3100/metrics 2>/dev/null | grep -c "^loki_" || echo "0")
      echo "  Metrics: ${METRICS} loki_* series"
    fi
    echo ""
    echo "── Promtail ──"
    systemctl is-active promtail 2>/dev/null && echo "  Status: ✅ Running" || echo "  Status: ❌ Stopped"
    if systemctl is-active promtail &>/dev/null; then
      PORT=$(grep 'http_listen_port' "$PROMTAIL_CONFIG" 2>/dev/null | head -1 | awk '{print $2}')
      TARGETS=$(curl -sf "http://localhost:${PORT:-9080}/targets" 2>/dev/null | grep -c '"state":"Ready"' || echo "0")
      echo "  Active targets: ${TARGETS}"
    fi
    echo ""
    echo "── Storage ──"
    if [ -d /var/lib/loki ]; then
      SIZE=$(du -sh /var/lib/loki 2>/dev/null | cut -f1)
      echo "  Loki data: ${SIZE}"
    fi
    echo "════════════════════════════════════════════════"
    ;;

  logs)
    SERVICE="${TARGET:-loki}"
    [[ "$SERVICE" == "all" ]] && SERVICE="loki"
    echo "📋 Recent logs for ${SERVICE}:"
    sudo journalctl -u "$SERVICE" -n 50 --no-pager
    ;;

  storage-info)
    echo "📊 Loki Storage Info:"
    echo ""
    if [ -d /var/lib/loki ]; then
      echo "Total size:"
      du -sh /var/lib/loki
      echo ""
      echo "Breakdown:"
      du -sh /var/lib/loki/*/ 2>/dev/null || echo "  (no subdirectories)"
      echo ""
      echo "Disk free:"
      df -h /var/lib/loki | tail -1
    else
      echo "❌ Loki data directory not found"
    fi
    ;;

  set-retention)
    RETENTION="${2:?Usage: manage.sh set-retention <duration> (e.g., 168h)}"
    echo "⏰ Setting retention to ${RETENTION}..."
    sudo sed -i "s/retention_period:.*/retention_period: ${RETENTION}/" "$LOKI_CONFIG"
    echo "  ✅ Config updated. Restarting Loki..."
    sudo systemctl restart loki
    echo "  ✅ Loki restarted with retention: ${RETENTION}"
    ;;

  compact)
    echo "🗜️ Forcing compaction..."
    curl -sf -X POST http://localhost:3100/compactor/ring/compact 2>/dev/null && \
      echo "  ✅ Compaction triggered" || \
      echo "  ⚠️  Compaction endpoint not available (may run automatically)"
    ;;

  backup)
    DEST="${2:?Usage: manage.sh backup <dest-dir>}"
    echo "💾 Backing up Loki data to ${DEST}..."
    sudo systemctl stop loki
    sudo mkdir -p "$DEST"
    sudo cp -a /var/lib/loki "$DEST/"
    sudo cp "$LOKI_CONFIG" "$DEST/"
    sudo cp "$PROMTAIL_CONFIG" "$DEST/" 2>/dev/null || true
    sudo systemctl start loki
    SIZE=$(du -sh "$DEST" | cut -f1)
    echo "  ✅ Backup complete (${SIZE})"
    ;;

  restore)
    SRC="${2:?Usage: manage.sh restore <src-dir>}"
    echo "♻️ Restoring Loki data from ${SRC}..."
    if [ ! -d "$SRC/loki" ]; then
      echo "❌ No loki/ directory found in ${SRC}"
      exit 1
    fi
    sudo systemctl stop loki
    sudo rm -rf /var/lib/loki
    sudo cp -a "$SRC/loki" /var/lib/loki
    sudo chown -R loki:loki /var/lib/loki
    sudo systemctl start loki
    echo "  ✅ Restore complete"
    ;;

  alerts)
    echo "🔔 Configured Alert Rules:"
    if [ -f /etc/loki/rules.yaml ]; then
      cat /etc/loki/rules.yaml
    else
      echo "  No alert rules configured. Use add-alert.sh to create one."
    fi
    ;;

  uninstall)
    echo "🗑️ Uninstalling Loki + Promtail..."
    read -rp "  Are you sure? This will delete all data. (y/N) " confirm
    if [[ "$confirm" =~ ^[Yy] ]]; then
      sudo systemctl stop loki promtail 2>/dev/null || true
      sudo systemctl disable loki promtail 2>/dev/null || true
      sudo rm -f /etc/systemd/system/loki.service /etc/systemd/system/promtail.service
      sudo systemctl daemon-reload
      sudo rm -f /usr/local/bin/loki /usr/local/bin/promtail
      sudo rm -rf /etc/loki /etc/promtail /var/lib/loki /var/lib/promtail
      sudo userdel loki 2>/dev/null || true
      sudo userdel promtail 2>/dev/null || true
      echo "  ✅ Uninstalled"
    else
      echo "  Cancelled."
    fi
    ;;

  help|--help|-h|*)
    usage
    ;;
esac
