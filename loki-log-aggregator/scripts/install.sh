#!/bin/bash
# Loki Log Aggregator — Installer
# Installs Grafana Loki and Promtail binaries + systemd services

set -euo pipefail

LOKI_VERSION="${LOKI_VERSION:-3.4.2}"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR_LOKI="/etc/loki"
CONFIG_DIR_PROMTAIL="/etc/promtail"
DATA_DIR_LOKI="${LOKI_DATA_DIR:-/var/lib/loki}"
DATA_DIR_PROMTAIL="/var/lib/promtail"

INSTALL_LOKI=true
INSTALL_PROMTAIL=true
LOKI_URL="http://localhost:3100"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --loki-only) INSTALL_PROMTAIL=false; shift ;;
    --promtail-only) INSTALL_LOKI=false; shift ;;
    --loki-url) LOKI_URL="$2"; shift 2 ;;
    --version) LOKI_VERSION="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: install.sh [options]"
      echo "  --loki-only        Install only Loki"
      echo "  --promtail-only    Install only Promtail"
      echo "  --loki-url URL     Loki push URL (for remote Promtail)"
      echo "  --version VER      Loki/Promtail version (default: $LOKI_VERSION)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l|armhf) ARCH="arm" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
echo "🔍 Detected: ${OS}/${ARCH}"

BASE_URL="https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}"

# ── Install Loki ──────────────────────────────────────────────

if $INSTALL_LOKI; then
  echo ""
  echo "📦 Installing Loki v${LOKI_VERSION}..."

  LOKI_ARCHIVE="loki-${OS}-${ARCH}.zip"
  LOKI_DL_URL="${BASE_URL}/${LOKI_ARCHIVE}"

  cd /tmp
  echo "   Downloading ${LOKI_DL_URL}..."
  curl -fsSL -o "$LOKI_ARCHIVE" "$LOKI_DL_URL"
  unzip -o "$LOKI_ARCHIVE"
  chmod +x "loki-${OS}-${ARCH}"
  sudo mv "loki-${OS}-${ARCH}" "${INSTALL_DIR}/loki"
  rm -f "$LOKI_ARCHIVE"

  echo "   ✅ Loki binary installed to ${INSTALL_DIR}/loki"

  # Create directories
  sudo mkdir -p "$CONFIG_DIR_LOKI" "$DATA_DIR_LOKI" "${DATA_DIR_LOKI}/chunks" "${DATA_DIR_LOKI}/compactor"

  # Create user
  if ! id -u loki &>/dev/null; then
    sudo useradd --system --no-create-home --shell /bin/false loki
  fi
  sudo chown -R loki:loki "$DATA_DIR_LOKI"

  # Write default config
  if [ ! -f "${CONFIG_DIR_LOKI}/config.yaml" ]; then
    RETENTION="${LOKI_RETENTION:-720h}"
    LISTEN="${LOKI_LISTEN_ADDR:-0.0.0.0:3100}"
    LISTEN_PORT="${LISTEN##*:}"

    cat > /tmp/loki-config.yaml <<YAML
auth_enabled: false

server:
  http_listen_port: ${LISTEN_PORT}

common:
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory
  replication_factor: 1
  path_prefix: ${DATA_DIR_LOKI}

schema_config:
  configs:
    - from: "2024-01-01"
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

storage_config:
  filesystem:
    directory: ${DATA_DIR_LOKI}/chunks

limits_config:
  retention_period: ${RETENTION}
  max_query_length: 721h
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20

compactor:
  working_directory: ${DATA_DIR_LOKI}/compactor
  compaction_interval: 10m
  retention_enabled: true
  delete_request_cancel_period: 10m
  retention_delete_delay: 2h
YAML
    sudo mv /tmp/loki-config.yaml "${CONFIG_DIR_LOKI}/config.yaml"
    sudo chown loki:loki "${CONFIG_DIR_LOKI}/config.yaml"
    echo "   ✅ Config written to ${CONFIG_DIR_LOKI}/config.yaml"
  else
    echo "   ⚠️  Config already exists at ${CONFIG_DIR_LOKI}/config.yaml (skipped)"
  fi

  # Create systemd service
  cat > /tmp/loki.service <<SERVICE
[Unit]
Description=Grafana Loki Log Aggregation System
After=network-online.target
Wants=network-online.target

[Service]
User=loki
Group=loki
Type=simple
ExecStart=${INSTALL_DIR}/loki -config.file=${CONFIG_DIR_LOKI}/config.yaml
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SERVICE
  sudo mv /tmp/loki.service /etc/systemd/system/loki.service
  sudo systemctl daemon-reload
  sudo systemctl enable loki
  echo "   ✅ Systemd service created and enabled"
fi

# ── Install Promtail ──────────────────────────────────────────

if $INSTALL_PROMTAIL; then
  echo ""
  echo "📦 Installing Promtail v${LOKI_VERSION}..."

  PROMTAIL_ARCHIVE="promtail-${OS}-${ARCH}.zip"
  PROMTAIL_DL_URL="${BASE_URL}/${PROMTAIL_ARCHIVE}"

  cd /tmp
  echo "   Downloading ${PROMTAIL_DL_URL}..."
  curl -fsSL -o "$PROMTAIL_ARCHIVE" "$PROMTAIL_DL_URL"
  unzip -o "$PROMTAIL_ARCHIVE"
  chmod +x "promtail-${OS}-${ARCH}"
  sudo mv "promtail-${OS}-${ARCH}" "${INSTALL_DIR}/promtail"
  rm -f "$PROMTAIL_ARCHIVE"

  echo "   ✅ Promtail binary installed to ${INSTALL_DIR}/promtail"

  # Create directories
  sudo mkdir -p "$CONFIG_DIR_PROMTAIL" "$DATA_DIR_PROMTAIL"

  # Create user
  if ! id -u promtail &>/dev/null; then
    sudo useradd --system --no-create-home --shell /bin/false promtail
    sudo usermod -aG systemd-journal promtail 2>/dev/null || true
  fi
  sudo chown -R promtail:promtail "$DATA_DIR_PROMTAIL"

  # Write default config
  PROMTAIL_PORT="${PROMTAIL_PORT:-9080}"

  if [ ! -f "${CONFIG_DIR_PROMTAIL}/config.yaml" ]; then
    cat > /tmp/promtail-config.yaml <<YAML
server:
  http_listen_port: ${PROMTAIL_PORT}
  grpc_listen_port: 0

positions:
  filename: ${DATA_DIR_PROMTAIL}/positions.yaml

clients:
  - url: ${LOKI_URL}/loki/api/v1/push

scrape_configs:
  # Systemd journal logs
  - job_name: systemd
    journal:
      max_age: 12h
      labels:
        job: systemd
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: unit

  # Syslog
  - job_name: syslog
    static_configs:
      - targets: [localhost]
        labels:
          job: syslog
          __path__: /var/log/syslog

  # Auth logs
  - job_name: authlog
    static_configs:
      - targets: [localhost]
        labels:
          job: authlog
          __path__: /var/log/auth.log
YAML
    sudo mv /tmp/promtail-config.yaml "${CONFIG_DIR_PROMTAIL}/config.yaml"
    sudo chown promtail:promtail "${CONFIG_DIR_PROMTAIL}/config.yaml"
    echo "   ✅ Config written to ${CONFIG_DIR_PROMTAIL}/config.yaml"
  else
    echo "   ⚠️  Config already exists at ${CONFIG_DIR_PROMTAIL}/config.yaml (skipped)"
  fi

  # Create systemd service
  cat > /tmp/promtail.service <<SERVICE
[Unit]
Description=Promtail Log Shipper for Grafana Loki
After=network-online.target loki.service
Wants=network-online.target

[Service]
User=promtail
Group=promtail
Type=simple
ExecStart=${INSTALL_DIR}/promtail -config.file=${CONFIG_DIR_PROMTAIL}/config.yaml
Restart=on-failure
RestartSec=5
SupplementaryGroups=systemd-journal

[Install]
WantedBy=multi-user.target
SERVICE
  sudo mv /tmp/promtail.service /etc/systemd/system/promtail.service
  sudo systemctl daemon-reload
  sudo systemctl enable promtail
  echo "   ✅ Systemd service created and enabled"
fi

echo ""
echo "════════════════════════════════════════════════════"
echo "✅ Installation complete!"
$INSTALL_LOKI && echo "   Loki:     ${INSTALL_DIR}/loki (config: ${CONFIG_DIR_LOKI}/config.yaml)"
$INSTALL_PROMTAIL && echo "   Promtail: ${INSTALL_DIR}/promtail (config: ${CONFIG_DIR_PROMTAIL}/config.yaml)"
echo ""
echo "Next steps:"
echo "  bash scripts/manage.sh start loki"
echo "  bash scripts/manage.sh start promtail"
echo "  bash scripts/query.sh '{job=\"systemd\"}' --limit 10"
echo "════════════════════════════════════════════════════"
