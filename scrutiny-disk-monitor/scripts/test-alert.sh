#!/bin/bash
# Test Scrutiny alert notifications
set -euo pipefail

echo "🔔 Testing Scrutiny notifications..."

if docker ps --format '{{.Names}}' | grep -q scrutiny; then
  # Scrutiny exposes a test notification endpoint
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:8080/api/health/notify" 2>/dev/null || echo "000")
  
  if [ "$RESPONSE" = "200" ]; then
    echo "✅ Test notification sent — check your alert channels"
  else
    echo "⚠️  API returned $RESPONSE — checking config..."
    echo ""
    echo "Notification config:"
    grep -A 5 "notify:" /opt/scrutiny/config/scrutiny.yaml 2>/dev/null || echo "  No notify section found"
    echo ""
    echo "Recent logs:"
    docker logs scrutiny --tail 10 2>&1 | grep -i "notify\|alert\|error" || echo "  No relevant logs"
  fi
else
  echo "❌ Scrutiny not running — start it first"
  exit 1
fi
