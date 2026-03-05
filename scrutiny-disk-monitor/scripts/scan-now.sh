#!/bin/bash
# Trigger an immediate S.M.A.R.T scan via the Scrutiny collector
set -euo pipefail

if docker ps --format '{{.Names}}' | grep -q scrutiny; then
  echo "🔍 Running S.M.A.R.T scan..."
  docker exec scrutiny scrutiny-collector-metrics run
  echo "✅ Scan complete — check dashboard for results"
else
  echo "❌ Scrutiny container not running"
  echo "   Start it: cd /opt/scrutiny && docker compose up -d"
  exit 1
fi
