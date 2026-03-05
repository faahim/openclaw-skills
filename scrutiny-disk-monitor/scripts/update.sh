#!/bin/bash
# Update Scrutiny to latest version
set -euo pipefail

INSTALL_DIR="${1:-/opt/scrutiny}"

echo "🔄 Updating Scrutiny..."
cd "$INSTALL_DIR"

docker compose pull
docker compose up -d

echo "✅ Scrutiny updated to latest version"
echo "   Dashboard: http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'localhost'):$(grep -oP '\d+(?=:8080)' docker-compose.yml || echo '8080')"
