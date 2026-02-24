#!/bin/bash
# Trigger a one-shot Watchtower update (no persistent instance needed)
set -e

echo "🔄 Triggering one-shot container update..."
echo ""

# Option 1: HTTP API (if Watchtower has API enabled)
if [ -n "$WATCHTOWER_API_TOKEN" ]; then
  WATCHTOWER_URL="${WATCHTOWER_URL:-http://localhost:8080}"
  echo "Using HTTP API at ${WATCHTOWER_URL}"
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${WATCHTOWER_API_TOKEN}" \
    "${WATCHTOWER_URL}/v1/update")
  
  if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✅ Update triggered via API"
  else
    echo "❌ API returned HTTP ${HTTP_CODE}"
    exit 1
  fi
else
  # Option 2: Run Watchtower in one-shot mode
  echo "Running Watchtower --run-once..."
  echo ""
  
  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower \
    --run-once \
    --cleanup \
    "$@"
  
  echo ""
  echo "✅ One-shot update complete"
fi
