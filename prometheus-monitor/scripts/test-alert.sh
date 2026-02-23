#!/bin/bash
# Send a test alert through Alertmanager
set -euo pipefail

ALERTMANAGER_URL="${ALERTMANAGER_URL:-http://localhost:9093}"

echo "🧪 Sending test alert to Alertmanager..."

curl -sf -X POST "${ALERTMANAGER_URL}/api/v2/alerts" \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "instance": "localhost:9100"
    },
    "annotations": {
      "summary": "This is a test alert from prometheus-monitor skill"
    },
    "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "endsAt": "'$(date -u -d "+5 minutes" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+5M +%Y-%m-%dT%H:%M:%SZ)'"
  }]'

echo ""
echo "✅ Test alert sent! Check your Telegram in ~30 seconds."
echo "   (Alertmanager groups alerts with a 30s wait by default)"
