#!/bin/bash
# Deploy Scrutiny collector only (for remote servers reporting to central instance)
set -euo pipefail

API_URL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --api-url) API_URL="$2"; shift 2 ;;
    -h|--help) echo "Usage: deploy-collector.sh --api-url http://scrutiny-server:8080"; exit 0 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

[ -z "$API_URL" ] && { echo "❌ Provide --api-url"; exit 1; }

echo "📡 Deploying Scrutiny collector..."

# Install smartmontools if needed
command -v smartctl &>/dev/null || sudo apt-get install -y smartmontools

# Download collector binary
ARCH=$(uname -m)
case $ARCH in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
esac

LATEST=$(curl -s https://api.github.com/repos/AnalogJ/scrutiny/releases/latest | grep -oP '"tag_name": "\K[^"]+')
COLLECTOR_URL="https://github.com/AnalogJ/scrutiny/releases/download/${LATEST}/scrutiny-collector-metrics-linux-${ARCH}"

sudo curl -L "$COLLECTOR_URL" -o /usr/local/bin/scrutiny-collector-metrics
sudo chmod +x /usr/local/bin/scrutiny-collector-metrics

# Create collector config
sudo mkdir -p /opt/scrutiny/config
cat | sudo tee /opt/scrutiny/config/collector.yaml > /dev/null << YAML
version: 1

host:
  id: "$(hostname)"

api:
  endpoint: "${API_URL}"
YAML

# Add cron job (every 6 hours)
CRON_LINE="0 */6 * * * /usr/local/bin/scrutiny-collector-metrics run --config /opt/scrutiny/config/collector.yaml"
(crontab -l 2>/dev/null | grep -v scrutiny-collector; echo "$CRON_LINE") | crontab -

# Run first collection
sudo /usr/local/bin/scrutiny-collector-metrics run --config /opt/scrutiny/config/collector.yaml

echo "✅ Collector deployed"
echo "   Reporting to: $API_URL"
echo "   Schedule: Every 6 hours via cron"
echo "   Config: /opt/scrutiny/config/collector.yaml"
