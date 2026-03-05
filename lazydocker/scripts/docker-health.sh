#!/bin/bash
set -euo pipefail

# Docker Health Dashboard — overview of all containers, images, volumes
# Usage: bash docker-health.sh [--json] [--restart-unhealthy]

JSON_MODE=false
RESTART_UNHEALTHY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --json) JSON_MODE=true; shift ;;
    --restart-unhealthy) RESTART_UNHEALTHY=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Check Docker is accessible
if ! docker info &>/dev/null; then
  echo "❌ Cannot connect to Docker daemon. Is Docker running?"
  exit 1
fi

# Gather stats
RUNNING=$(docker ps -q | wc -l | tr -d ' ')
STOPPED=$(docker ps -aq --filter "status=exited" | wc -l | tr -d ' ')
TOTAL_CONTAINERS=$((RUNNING + STOPPED))

UNHEALTHY_IDS=$(docker ps -q --filter "health=unhealthy" 2>/dev/null || echo "")
UNHEALTHY_COUNT=$(echo "$UNHEALTHY_IDS" | grep -c . 2>/dev/null || echo "0")
[ -z "$UNHEALTHY_IDS" ] && UNHEALTHY_COUNT=0

IMAGE_COUNT=$(docker images -q | wc -l | tr -d ' ')
IMAGE_SIZE=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1 || echo "N/A")

VOLUME_COUNT=$(docker volume ls -q | wc -l | tr -d ' ')
NETWORK_COUNT=$(docker network ls -q | wc -l | tr -d ' ')

if $JSON_MODE; then
  # JSON output
  echo "{"
  echo "  \"running\": $RUNNING,"
  echo "  \"stopped\": $STOPPED,"
  echo "  \"unhealthy\": $UNHEALTHY_COUNT,"
  echo "  \"images\": $IMAGE_COUNT,"
  echo "  \"volumes\": $VOLUME_COUNT,"
  echo "  \"networks\": $NETWORK_COUNT,"
  
  # List unhealthy containers
  echo "  \"unhealthy_containers\": ["
  if [ -n "$UNHEALTHY_IDS" ] && [ "$UNHEALTHY_COUNT" -gt 0 ]; then
    FIRST=true
    for ID in $UNHEALTHY_IDS; do
      NAME=$(docker inspect --format '{{.Name}}' "$ID" | sed 's/^\///')
      $FIRST || echo ","
      echo -n "    \"$NAME\""
      FIRST=false
    done
    echo ""
  fi
  echo "  ],"
  
  # Container details
  echo "  \"containers\": ["
  FIRST=true
  docker ps -a --format '{{.ID}}|{{.Names}}|{{.Status}}|{{.Image}}' | while IFS='|' read -r id name status image; do
    $FIRST || echo ","
    # Get CPU/Mem if running
    if docker ps -q --no-trunc | grep -q "^$(docker inspect --format '{{.Id}}' "$id")"; then
      STATS=$(docker stats --no-stream --format '{{.CPUPerc}}|{{.MemUsage}}' "$id" 2>/dev/null || echo "—|—")
      CPU=$(echo "$STATS" | cut -d'|' -f1)
      MEM=$(echo "$STATS" | cut -d'|' -f2)
    else
      CPU="—"
      MEM="—"
    fi
    echo -n "    {\"name\": \"$name\", \"status\": \"$status\", \"image\": \"$image\", \"cpu\": \"$CPU\", \"mem\": \"$MEM\"}"
    FIRST=false
  done
  echo ""
  echo "  ]"
  echo "}"
  exit 0
fi

# Human-readable output
echo "=== Docker Health Dashboard ==="
echo "Containers: $RUNNING running, $STOPPED stopped, $UNHEALTHY_COUNT unhealthy"
echo "Images: $IMAGE_COUNT ($IMAGE_SIZE)"
echo "Volumes: $VOLUME_COUNT"
echo "Networks: $NETWORK_COUNT"
echo ""

# Container table
printf "%-20s %-14s %-7s %-10s %-10s\n" "CONTAINER" "STATUS" "CPU" "MEM" "HEALTH"
printf "%-20s %-14s %-7s %-10s %-10s\n" "—————————" "——————" "———" "———" "——————"

docker ps -a --format '{{.Names}}|{{.Status}}|{{.ID}}' | while IFS='|' read -r name status id; do
  # Shorten status
  SHORT_STATUS=$(echo "$status" | sed 's/Up /↑/; s/Exited (/Exit(/; s/ ago//')
  SHORT_STATUS="${SHORT_STATUS:0:13}"
  
  # Get health
  HEALTH=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}—{{end}}' "$id" 2>/dev/null || echo "—")
  
  # Get stats if running
  if echo "$status" | grep -q "^Up"; then
    STATS=$(docker stats --no-stream --format '{{.CPUPerc}}|{{.MemUsage}}' "$id" 2>/dev/null || echo "—|—")
    CPU=$(echo "$STATS" | cut -d'|' -f1)
    MEM=$(echo "$STATS" | cut -d'|' -f2 | cut -d'/' -f1 | xargs)
  else
    CPU="—"
    MEM="—"
  fi
  
  printf "%-20s %-14s %-7s %-10s %-10s\n" "${name:0:19}" "$SHORT_STATUS" "$CPU" "$MEM" "$HEALTH"
done

# Restart unhealthy if requested
if $RESTART_UNHEALTHY && [ -n "$UNHEALTHY_IDS" ] && [ "$UNHEALTHY_COUNT" -gt 0 ]; then
  echo ""
  echo "🔄 Restarting unhealthy containers..."
  for ID in $UNHEALTHY_IDS; do
    NAME=$(docker inspect --format '{{.Name}}' "$ID" | sed 's/^\///')
    echo "   Restarting $NAME..."
    docker restart "$ID" >/dev/null 2>&1
    echo "   ✅ $NAME restarted"
  done
fi
