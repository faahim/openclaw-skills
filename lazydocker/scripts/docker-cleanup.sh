#!/bin/bash
set -euo pipefail

# Docker Cleanup — remove unused images, volumes, networks, build cache
# Usage: bash docker-cleanup.sh [--dry-run] [--aggressive]

DRY_RUN=false
AGGRESSIVE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --aggressive) AGGRESSIVE=true; shift ;;
    -h|--help) echo "Usage: bash docker-cleanup.sh [--dry-run] [--aggressive]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if ! docker info &>/dev/null; then
  echo "❌ Cannot connect to Docker daemon."
  exit 1
fi

echo "=== Docker Cleanup Report ==="
TOTAL_FREED=0

# Dangling images
DANGLING=$(docker images -f "dangling=true" -q | wc -l | tr -d ' ')
if [ "$DANGLING" -gt 0 ]; then
  DANGLING_SIZE=$(docker images -f "dangling=true" --format '{{.Size}}' | paste -sd+ | bc 2>/dev/null || echo "unknown")
  if $DRY_RUN; then
    echo "Dangling images:     $DANGLING — WOULD REMOVE"
  else
    docker image prune -f >/dev/null 2>&1
    echo "Dangling images:     $DANGLING — REMOVED"
  fi
else
  echo "Dangling images:     0 (clean)"
fi

# Unused volumes
UNUSED_VOLS=$(docker volume ls -qf "dangling=true" | wc -l | tr -d ' ')
if [ "$UNUSED_VOLS" -gt 0 ]; then
  if $DRY_RUN; then
    echo "Unused volumes:      $UNUSED_VOLS — WOULD REMOVE"
  else
    docker volume prune -f >/dev/null 2>&1
    echo "Unused volumes:      $UNUSED_VOLS — REMOVED"
  fi
else
  echo "Unused volumes:      0 (clean)"
fi

# Unused networks
UNUSED_NETS=$(docker network ls -q --filter "type=custom" | while read -r net; do
  CONNECTED=$(docker network inspect "$net" --format '{{len .Containers}}' 2>/dev/null || echo "0")
  [ "$CONNECTED" = "0" ] && echo "$net"
done | wc -l | tr -d ' ')

if [ "$UNUSED_NETS" -gt 0 ]; then
  if $DRY_RUN; then
    echo "Unused networks:     $UNUSED_NETS — WOULD REMOVE"
  else
    docker network prune -f >/dev/null 2>&1
    echo "Unused networks:     $UNUSED_NETS — REMOVED"
  fi
else
  echo "Unused networks:     0 (clean)"
fi

# Stopped containers (only with --aggressive)
STOPPED=$(docker ps -aq --filter "status=exited" | wc -l | tr -d ' ')
if $AGGRESSIVE && [ "$STOPPED" -gt 0 ]; then
  if $DRY_RUN; then
    echo "Stopped containers:  $STOPPED — WOULD REMOVE"
  else
    docker container prune -f >/dev/null 2>&1
    echo "Stopped containers:  $STOPPED — REMOVED"
  fi
elif [ "$STOPPED" -gt 0 ]; then
  echo "Stopped containers:  $STOPPED (skipped, use --aggressive)"
else
  echo "Stopped containers:  0 (clean)"
fi

# Build cache
if $DRY_RUN; then
  BUILD_CACHE=$(docker builder du 2>/dev/null | tail -1 | awk '{print $NF}' || echo "0B")
  echo "Build cache:         $BUILD_CACHE — WOULD REMOVE"
else
  BUILD_CACHE=$(docker builder prune -f 2>/dev/null | grep -oP 'Total reclaimed space: \K.*' || echo "0B")
  echo "Build cache:         $BUILD_CACHE — REMOVED"
fi

# Summary
echo ""
if $DRY_RUN; then
  echo "🔍 Dry run complete. Run without --dry-run to execute cleanup."
else
  TOTAL=$(docker system df --format '{{.Reclaimable}}' 2>/dev/null | head -1 || echo "check docker system df")
  echo "✅ Cleanup complete. Remaining reclaimable: $TOTAL"
fi
