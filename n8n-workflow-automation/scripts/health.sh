#!/bin/bash
# n8n health check
set -euo pipefail

N8N_PORT="${N8N_PORT:-5678}"
BASE="http://localhost:$N8N_PORT"

# API health
START=$(date +%s%3N)
HTTP=$(curl -sf -o /dev/null -w "%{http_code}" "$BASE/healthz" 2>/dev/null || echo "000")
END=$(date +%s%3N)

if [ "$HTTP" = "200" ]; then
  echo "✅ API: healthy (${$((END-START))}ms)"
else
  echo "❌ API: unreachable (HTTP $HTTP)"
  exit 1
fi

# Webhooks
WEBHOOK=$(curl -sf -o /dev/null -w "%{http_code}" "$BASE/webhook-test/health" 2>/dev/null || echo "000")
if [ "$WEBHOOK" != "000" ]; then
  echo "✅ Webhooks: active"
else
  echo "⚠️  Webhooks: may need configuration"
fi

# Workflow stats
ACTIVE=$(curl -sf "$BASE/api/v1/workflows?active=true&limit=0" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d: -f2 || echo "?")
INACTIVE=$(curl -sf "$BASE/api/v1/workflows?active=false&limit=0" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d: -f2 || echo "?")
echo "📊 Workflows: $ACTIVE active, $INACTIVE inactive"

# Disk usage
N8N_DIR="${N8N_DIR:-$HOME/.n8n}"
DISK=$(du -sh "$N8N_DIR" 2>/dev/null | cut -f1 || echo "?")
echo "💾 Disk: $DISK"
