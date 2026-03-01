#!/bin/bash
# Loki Log Aggregator — Grafana Datasource Setup
# Adds Loki as a datasource in Grafana

set -euo pipefail

GRAFANA_URL="${1:-http://localhost:3000}"
LOKI_URL="${LOKI_URL:-http://localhost:3100}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"

echo "🔗 Adding Loki datasource to Grafana..."
echo "   Grafana: ${GRAFANA_URL}"
echo "   Loki:    ${LOKI_URL}"

RESPONSE=$(curl -sf -X POST "${GRAFANA_URL}/api/datasources" \
  -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Loki\",
    \"type\": \"loki\",
    \"url\": \"${LOKI_URL}\",
    \"access\": \"proxy\",
    \"isDefault\": false
  }" 2>&1)

if echo "$RESPONSE" | grep -q '"id"'; then
  echo "✅ Loki datasource added to Grafana!"
  echo "   Open ${GRAFANA_URL}/explore and select 'Loki' to query logs"
elif echo "$RESPONSE" | grep -q "already exists"; then
  echo "⚠️  Loki datasource already exists in Grafana"
else
  echo "❌ Failed to add datasource:"
  echo "   ${RESPONSE}"
  echo ""
  echo "Make sure Grafana is running and credentials are correct."
  echo "Set GRAFANA_USER and GRAFANA_PASS env vars if not using defaults."
fi
