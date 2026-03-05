#!/bin/bash
# Scrutiny Disk Monitor — Deploy Script
# Deploys Scrutiny all-in-one (web + collector + InfluxDB) via Docker

set -euo pipefail

INSTALL_DIR="/opt/scrutiny"
PORT=8080
TELEGRAM_TOKEN=""
TELEGRAM_CHAT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --port) PORT="$2"; shift 2 ;;
    --telegram-token) TELEGRAM_TOKEN="$2"; shift 2 ;;
    --telegram-chat) TELEGRAM_CHAT="$2"; shift 2 ;;
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: deploy.sh [OPTIONS]"
      echo "  --port PORT           Web UI port (default: 8080)"
      echo "  --telegram-token TOK  Telegram bot token for alerts"
      echo "  --telegram-chat ID    Telegram chat ID for alerts"
      echo "  --install-dir DIR     Install directory (default: /opt/scrutiny)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "🔍 Scrutiny Disk Monitor — Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check prerequisites
echo ""
echo "Checking prerequisites..."

if ! command -v docker &>/dev/null; then
  echo "❌ Docker not found. Install: https://docs.docker.com/engine/install/"
  exit 1
fi
echo "  ✅ Docker $(docker --version | grep -oP '\d+\.\d+\.\d+')"

if ! command -v smartctl &>/dev/null; then
  echo "  ⚠️  smartmontools not found. Installing..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y smartmontools
  elif command -v yum &>/dev/null; then
    sudo yum install -y smartmontools
  elif command -v brew &>/dev/null; then
    brew install smartmontools
  else
    echo "❌ Cannot install smartmontools automatically. Install manually."
    exit 1
  fi
fi
echo "  ✅ smartctl $(smartctl --version | head -1 | grep -oP '\d+\.\d+')"

# Detect block devices
echo ""
echo "Detecting drives..."
DEVICES=""
DEVICE_LINES=""

for dev in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
  if [ -b "$dev" ]; then
    MODEL=$(lsblk -d -n -o MODEL "$dev" 2>/dev/null | xargs || echo "Unknown")
    SIZE=$(lsblk -d -n -o SIZE "$dev" 2>/dev/null | xargs || echo "?")
    echo "  📀 $dev — $MODEL ($SIZE)"
    DEVICES="$DEVICES      - $dev\n"
    DEVICE_LINES="$DEVICE_LINES    devices:\n      - $dev\n"
  fi
done

if [ -z "$DEVICES" ]; then
  echo "  ⚠️  No block devices found. Deploying without device passthrough."
  echo "  You may need to add devices manually to docker-compose.yml"
fi

# Create directories
echo ""
echo "Setting up directories..."
sudo mkdir -p "$INSTALL_DIR"/{config,influxdb}

# Generate Scrutiny config
echo ""
echo "Generating configuration..."

NOTIFY_SECTION=""
if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT" ]; then
  NOTIFY_SECTION="notify:
  urls:
    - \"telegram://${TELEGRAM_TOKEN}@telegram?channels=${TELEGRAM_CHAT}\""
  echo "  ✅ Telegram alerts configured"
fi

cat > "$INSTALL_DIR/config/scrutiny.yaml" << YAML
version: 1

web:
  listen:
    port: 8080
    host: 0.0.0.0
  influxdb:
    port: 8086
    retention_policy: true

${NOTIFY_SECTION}
YAML

# Generate docker-compose.yml
DEVICES_YAML=""
for dev in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
  if [ -b "$dev" ]; then
    DEVICES_YAML="${DEVICES_YAML}      - ${dev}\n"
  fi
done

cat > "$INSTALL_DIR/docker-compose.yml" << COMPOSE
version: "3.8"
services:
  scrutiny:
    image: ghcr.io/analogj/scrutiny:master-omnibus
    container_name: scrutiny
    restart: unless-stopped
    cap_add:
      - SYS_RAWIO
      - SYS_ADMIN
    ports:
      - "${PORT}:8080"
      - "8086:8086"
    volumes:
      - ${INSTALL_DIR}/config:/opt/scrutiny/config
      - ${INSTALL_DIR}/influxdb:/opt/scrutiny/influxdb
      - /run/udev:/run/udev:ro
$(if [ -n "$DEVICES_YAML" ]; then echo "    devices:"; echo -e "$DEVICES_YAML"; fi)
    environment:
      - SCRUTINY_WEB_INFLUXDB_HOST=0.0.0.0
      - COLLECTOR_CRON_SCHEDULE=0 */6 * * *
COMPOSE

# Deploy
echo ""
echo "Pulling and starting Scrutiny..."
cd "$INSTALL_DIR"
docker compose up -d

# Wait for startup
echo ""
echo "Waiting for Scrutiny to start..."
for i in $(seq 1 30); do
  if curl -s "http://localhost:${PORT}/api/health" &>/dev/null; then
    break
  fi
  sleep 2
done

# Trigger initial scan
echo "Running initial S.M.A.R.T scan..."
docker exec scrutiny scrutiny-collector-metrics run &>/dev/null || true

# Done
IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Scrutiny deployed successfully!"
echo ""
echo "  📊 Dashboard:  http://${IP}:${PORT}"
echo "  📁 Config:     ${INSTALL_DIR}/config/scrutiny.yaml"
echo "  📁 Data:       ${INSTALL_DIR}/influxdb/"
echo "  🔄 Scan cron:  Every 6 hours (configurable)"
echo ""
echo "  Next steps:"
echo "    • Open the dashboard to view drive health"
echo "    • Run 'bash scripts/scan-now.sh' for immediate scan"
echo "    • Run 'bash scripts/configure-alerts.sh' to set up notifications"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
