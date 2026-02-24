#!/bin/bash
# Watchtower Status Checker
set -e

echo "🐋 Watchtower Status"
echo "===================="
echo ""

# Check if running
if docker ps --format '{{.Names}}' | grep -q "^watchtower$"; then
  echo "✅ Watchtower is RUNNING"
  echo ""
  
  # Get container details
  CREATED=$(docker inspect watchtower --format '{{.Created}}' 2>/dev/null | cut -d'T' -f1)
  UPTIME=$(docker inspect watchtower --format '{{.State.StartedAt}}' 2>/dev/null)
  IMAGE=$(docker inspect watchtower --format '{{.Config.Image}}' 2>/dev/null)
  
  echo "  Image:   ${IMAGE}"
  echo "  Created: ${CREATED}"
  echo "  Started: ${UPTIME}"
  echo ""
  
  # Show environment config
  echo "📋 Configuration:"
  docker inspect watchtower --format '{{range .Config.Env}}  {{.}}{{"\n"}}{{end}}' 2>/dev/null | grep -i watchtower || echo "  (default config)"
  echo ""
  
  # Recent logs
  echo "📜 Recent Activity (last 20 lines):"
  echo "---"
  docker logs watchtower --tail 20 2>&1
  echo "---"
  
elif docker ps -a --format '{{.Names}}' | grep -q "^watchtower$"; then
  echo "⚠️  Watchtower exists but is STOPPED"
  echo ""
  echo "  Start it: docker start watchtower"
  echo "  Or remove and reconfigure: docker rm watchtower && bash scripts/setup.sh"
else
  echo "❌ Watchtower is NOT installed"
  echo ""
  echo "  Run: bash scripts/setup.sh"
fi

echo ""

# Show monitored containers
echo "🐳 Running Containers (monitored by Watchtower):"
echo ""
docker ps --format "  {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null | grep -v watchtower || echo "  (none)"
echo ""

# Check for labeled containers
LABELED=$(docker ps --filter "label=com.centurylinklabs.watchtower.enable" --format "  {{.Names}} → {{.Label \"com.centurylinklabs.watchtower.enable\"}}" 2>/dev/null)
if [ -n "$LABELED" ]; then
  echo "🏷️  Labeled Containers:"
  echo "$LABELED"
  echo ""
fi

# Disk usage from old images
echo "💾 Docker Disk Usage:"
docker system df 2>/dev/null | head -5
