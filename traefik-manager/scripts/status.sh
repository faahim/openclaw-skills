#!/bin/bash
# Check Traefik status and health

set -euo pipefail

TRAEFIK_DIR="/opt/traefik"

echo "=== Traefik Status ==="
echo ""

# Check container
if docker inspect traefik &>/dev/null; then
  STATUS=$(docker inspect traefik --format '{{.State.Status}}')
  UPTIME=$(docker inspect traefik --format '{{.State.StartedAt}}')
  VERSION=$(docker inspect traefik --format '{{.Config.Image}}')
  echo "✅ Traefik: ${STATUS} (${VERSION})"
  echo "   Started: ${UPTIME}"
else
  echo "❌ Traefik container not found"
  exit 1
fi

echo ""

# Check ports
echo "--- Ports ---"
for PORT in 80 443; do
  if ss -tlnp 2>/dev/null | grep -q ":${PORT} " || netstat -tlnp 2>/dev/null | grep -q ":${PORT} "; then
    echo "✅ Port ${PORT}: listening"
  else
    echo "⚠️  Port ${PORT}: not detected (may be inside container)"
  fi
done

echo ""

# Check certificates
echo "--- Certificates ---"
ACME_FILE="${TRAEFIK_DIR}/acme/acme.json"
if [[ -f "$ACME_FILE" ]]; then
  CERT_COUNT=$(jq '[.letsencrypt.Certificates // [] | length] | add // 0' "$ACME_FILE" 2>/dev/null || echo "0")
  echo "📜 Certificates stored: ${CERT_COUNT}"
  
  if [[ "$CERT_COUNT" -gt 0 ]]; then
    jq -r '.letsencrypt.Certificates[]? | .domain.main' "$ACME_FILE" 2>/dev/null | while read -r domain; do
      echo "   - ${domain}"
    done
  fi
else
  echo "⚠️  No ACME file found at ${ACME_FILE}"
fi

echo ""

# Check config files
echo "--- Dynamic Config ---"
CONFIG_COUNT=$(find "${TRAEFIK_DIR}/config" -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l)
echo "📂 Config files: ${CONFIG_COUNT}"
if [[ "$CONFIG_COUNT" -gt 0 ]]; then
  find "${TRAEFIK_DIR}/config" -name "*.yml" -o -name "*.yaml" 2>/dev/null | while read -r f; do
    echo "   - $(basename "$f")"
  done
fi

echo ""

# Check Docker containers on traefik-public network
echo "--- Docker Discovery ---"
CONTAINERS=$(docker network inspect traefik-public --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "")
if [[ -n "$CONTAINERS" ]]; then
  COUNT=$(echo "$CONTAINERS" | wc -w)
  echo "🐳 Containers on traefik-public: ${COUNT}"
  for c in $CONTAINERS; do
    ENABLED=$(docker inspect "$c" --format '{{index .Config.Labels "traefik.enable"}}' 2>/dev/null || echo "")
    if [[ "$ENABLED" == "true" ]]; then
      RULE=$(docker inspect "$c" --format '{{range $k, $v := .Config.Labels}}{{if eq $k "traefik.http.routers.'$c'.rule"}}{{$v}}{{end}}{{end}}' 2>/dev/null || echo "unknown")
      echo "   ✅ ${c} (traefik.enable=true)"
    else
      echo "   ⚪ ${c}"
    fi
  done
else
  echo "🐳 No containers on traefik-public network"
fi

echo ""

# Recent errors
echo "--- Recent Logs (last 10 errors) ---"
docker logs traefik 2>&1 | grep -i "error\|ERR\|fatal" | tail -10 || echo "No errors found ✅"
