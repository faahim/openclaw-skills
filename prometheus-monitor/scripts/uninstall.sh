#!/bin/bash
# Uninstall Prometheus stack
set -euo pipefail

echo "🗑️  Uninstalling Prometheus stack..."

# Stop and disable services
for svc in prometheus node_exporter alertmanager; do
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    systemctl stop "$svc"
    systemctl disable "$svc"
    echo "  Stopped $svc"
  fi
done

# Remove binaries
for bin in prometheus promtool node_exporter alertmanager amtool; do
  rm -f "/usr/local/bin/$bin"
done

# Remove service files
rm -f /etc/systemd/system/prometheus.service
rm -f /etc/systemd/system/node_exporter.service
rm -f /etc/systemd/system/alertmanager.service
systemctl daemon-reload

echo ""
read -p "Remove config files? (/etc/prometheus, /etc/alertmanager) [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -rf /etc/prometheus /etc/alertmanager
  echo "  Config files removed"
fi

read -p "Remove data? (/var/lib/prometheus, /var/lib/alertmanager) [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -rf /var/lib/prometheus /var/lib/alertmanager
  echo "  Data removed"
fi

# Optionally remove user
read -p "Remove prometheus user? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  userdel prometheus 2>/dev/null || true
  echo "  User removed"
fi

echo ""
echo "✅ Prometheus stack uninstalled"
