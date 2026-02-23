#!/bin/bash
# Install Alertmanager + configure Telegram notifications
set -euo pipefail

ALERTMANAGER_VERSION="${ALERTMANAGER_VERSION:-0.27.0}"
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:?Set TELEGRAM_BOT_TOKEN env var}"
CHAT_ID="${TELEGRAM_CHAT_ID:?Set TELEGRAM_CHAT_ID env var}"

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  GOARCH="amd64" ;;
  aarch64) GOARCH="arm64" ;;
  armv7l)  GOARCH="armv7" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Install Alertmanager
if [ ! -f /usr/local/bin/alertmanager ]; then
  echo "⬇️  Downloading Alertmanager ${ALERTMANAGER_VERSION}..."
  cd /tmp
  ARCHIVE="alertmanager-${ALERTMANAGER_VERSION}.linux-${GOARCH}.tar.gz"
  curl -fsSL -o "${ARCHIVE}" \
    "https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/${ARCHIVE}"
  tar xzf "${ARCHIVE}"
  cp "alertmanager-${ALERTMANAGER_VERSION}.linux-${GOARCH}/alertmanager" /usr/local/bin/
  cp "alertmanager-${ALERTMANAGER_VERSION}.linux-${GOARCH}/amtool" /usr/local/bin/
  chown prometheus:prometheus /usr/local/bin/alertmanager /usr/local/bin/amtool
  rm -rf /tmp/${ARCHIVE} /tmp/alertmanager-${ALERTMANAGER_VERSION}.*
  echo "✅ Alertmanager ${ALERTMANAGER_VERSION} installed"
fi

# Create config directory
mkdir -p /etc/alertmanager /var/lib/alertmanager
chown prometheus:prometheus /var/lib/alertmanager

# Write Alertmanager config with Telegram
cat > /etc/alertmanager/alertmanager.yml << YAML
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'telegram'

  routes:
    - match:
        severity: critical
      receiver: 'telegram'
      repeat_interval: 1h

receivers:
  - name: 'telegram'
    telegram_configs:
      - bot_token: '${BOT_TOKEN}'
        chat_id: ${CHAT_ID}
        parse_mode: 'HTML'
        message: |
          {{ if eq .Status "firing" }}🔴{{ else }}🟢{{ end }} <b>{{ .Status | toUpper }}</b>
          {{ range .Alerts }}
          <b>{{ .Labels.alertname }}</b>
          {{ .Annotations.summary }}
          Severity: {{ .Labels.severity }}
          {{ end }}

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
YAML

chown prometheus:prometheus /etc/alertmanager/alertmanager.yml

# Create systemd service
cat > /etc/systemd/system/alertmanager.service << 'EOF'
[Unit]
Description=Prometheus Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Update Prometheus config to point to Alertmanager
if ! grep -q "alertmanagers" /etc/prometheus/prometheus.yml; then
  python3 << 'PYEOF' || true
import yaml

with open("/etc/prometheus/prometheus.yml") as f:
    cfg = yaml.safe_load(f)

cfg["alerting"] = {
    "alertmanagers": [{
        "static_configs": [{"targets": ["localhost:9093"]}]
    }]
}

with open("/etc/prometheus/prometheus.yml", "w") as f:
    yaml.dump(cfg, f, default_flow_style=False)

print("📝 Updated prometheus.yml with alertmanager config")
PYEOF
fi

# Start services
systemctl daemon-reload
systemctl enable --now alertmanager
systemctl reload prometheus 2>/dev/null || true

echo ""
echo "🎉 Alertmanager configured with Telegram notifications!"
echo ""
echo "  🔔 Alertmanager UI: http://localhost:9093"
echo "  📱 Telegram alerts → chat ${CHAT_ID}"
echo "  📁 Config: /etc/alertmanager/alertmanager.yml"
echo ""
echo "Test it: bash scripts/test-alert.sh"
