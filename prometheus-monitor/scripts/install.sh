#!/bin/bash
# Prometheus + Node Exporter Installer
# Supports amd64 and arm64 Linux

set -euo pipefail

PROM_VERSION="${PROMETHEUS_VERSION:-2.54.1}"
NODE_VERSION="${NODE_EXPORTER_VERSION:-1.8.2}"
ALERTMANAGER_VERSION="${ALERTMANAGER_VERSION:-0.27.0}"
DATA_DIR="${PROMETHEUS_DATA_DIR:-/var/lib/prometheus}"
RETENTION="${PROMETHEUS_RETENTION:-15d}"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  GOARCH="amd64" ;;
  aarch64) GOARCH="arm64" ;;
  armv7l)  GOARCH="armv7" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

OS="linux"
echo "📦 Installing Prometheus stack for ${OS}/${GOARCH}"

# Create prometheus user
if ! id -u prometheus &>/dev/null; then
  echo "👤 Creating prometheus user..."
  useradd --no-create-home --shell /bin/false prometheus
fi

# Create directories
mkdir -p /etc/prometheus/rules "${DATA_DIR}" /tmp/prometheus-install
chown prometheus:prometheus "${DATA_DIR}"

cd /tmp/prometheus-install

# --- Install Prometheus ---
PROM_ARCHIVE="prometheus-${PROM_VERSION}.${OS}-${GOARCH}.tar.gz"
PROM_URL="https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/${PROM_ARCHIVE}"

if [ ! -f /usr/local/bin/prometheus ] || [ "$(/usr/local/bin/prometheus --version 2>&1 | head -1 | grep -oP '\d+\.\d+\.\d+')" != "${PROM_VERSION}" ]; then
  echo "⬇️  Downloading Prometheus ${PROM_VERSION}..."
  curl -fsSL -o "${PROM_ARCHIVE}" "${PROM_URL}"
  tar xzf "${PROM_ARCHIVE}"
  
  PROM_DIR="prometheus-${PROM_VERSION}.${OS}-${GOARCH}"
  cp "${PROM_DIR}/prometheus" /usr/local/bin/
  cp "${PROM_DIR}/promtool" /usr/local/bin/
  
  # Copy default console templates
  cp -r "${PROM_DIR}/consoles" /etc/prometheus/ 2>/dev/null || true
  cp -r "${PROM_DIR}/console_libraries" /etc/prometheus/ 2>/dev/null || true
  
  chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool
  echo "✅ Prometheus ${PROM_VERSION} installed"
else
  echo "✅ Prometheus ${PROM_VERSION} already installed"
fi

# --- Install Node Exporter ---
NODE_ARCHIVE="node_exporter-${NODE_VERSION}.${OS}-${GOARCH}.tar.gz"
NODE_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/${NODE_ARCHIVE}"

if [ ! -f /usr/local/bin/node_exporter ] || [ "$(/usr/local/bin/node_exporter --version 2>&1 | head -1 | grep -oP '\d+\.\d+\.\d+')" != "${NODE_VERSION}" ]; then
  echo "⬇️  Downloading Node Exporter ${NODE_VERSION}..."
  curl -fsSL -o "${NODE_ARCHIVE}" "${NODE_URL}"
  tar xzf "${NODE_ARCHIVE}"
  
  NODE_DIR="node_exporter-${NODE_VERSION}.${OS}-${GOARCH}"
  cp "${NODE_DIR}/node_exporter" /usr/local/bin/
  chown prometheus:prometheus /usr/local/bin/node_exporter
  echo "✅ Node Exporter ${NODE_VERSION} installed"
else
  echo "✅ Node Exporter ${NODE_VERSION} already installed"
fi

# --- Write default Prometheus config ---
if [ ! -f /etc/prometheus/prometheus.yml ]; then
  cat > /etc/prometheus/prometheus.yml << 'YAML'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          instance_name: 'local'
YAML
  chown prometheus:prometheus /etc/prometheus/prometheus.yml
  echo "📝 Default prometheus.yml created"
fi

# --- Write default alert rules ---
if [ ! -f /etc/prometheus/rules/alerts.yml ]; then
  cat > /etc/prometheus/rules/alerts.yml << 'YAML'
groups:
  - name: system-alerts
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} down"
          description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 2 minutes."

      - alert: HighCPU
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU on {{ $labels.instance }}: {{ $value | printf \"%.1f\" }}%"

      - alert: HighMemory
        expr: 100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High memory on {{ $labels.instance }}: {{ $value | printf \"%.1f\" }}%"

      - alert: DiskAlmostFull
        expr: 100 * (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disk almost full on {{ $labels.instance }}: {{ $value | printf \"%.1f\" }}%"

      - alert: HighLoad
        expr: node_load15 > count by(instance) (node_cpu_seconds_total{mode="idle"})
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "High load average on {{ $labels.instance }}: {{ $value | printf \"%.1f\" }}"
YAML
  chown prometheus:prometheus /etc/prometheus/rules/alerts.yml
  echo "📝 Default alert rules created"
fi

# --- Create systemd services ---
cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=${DATA_DIR} \\
  --storage.tsdb.retention.time=${RETENTION} \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries \\
  --web.enable-lifecycle
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/node_exporter \
  --collector.systemd \
  --collector.processes
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# --- Start services ---
systemctl daemon-reload
systemctl enable --now prometheus node_exporter

echo ""
echo "🎉 Prometheus stack installed successfully!"
echo ""
echo "  📊 Prometheus UI:     http://localhost:9090"
echo "  📈 Node Exporter:     http://localhost:9100/metrics"
echo "  📁 Config:            /etc/prometheus/prometheus.yml"
echo "  📁 Alert rules:       /etc/prometheus/rules/alerts.yml"
echo "  📁 Data:              ${DATA_DIR}"
echo "  🔄 Retention:         ${RETENTION}"
echo ""
echo "Next steps:"
echo "  1. Add remote targets: sudo bash scripts/add-target.sh <host>:9100 <name>"
echo "  2. Set up Telegram alerts: sudo bash scripts/setup-alertmanager.sh"
echo "  3. Check status: bash scripts/status.sh"

# Cleanup
rm -rf /tmp/prometheus-install
