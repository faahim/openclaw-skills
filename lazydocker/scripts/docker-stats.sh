#!/bin/bash
set -euo pipefail

# Docker Resource Monitor — live CPU/memory/network stats
# Usage: bash docker-stats.sh [--once] [--container NAME]

ONCE=false
CONTAINER=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --once) ONCE=true; shift ;;
    --container|-c) CONTAINER="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if ! docker info &>/dev/null; then
  echo "❌ Cannot connect to Docker daemon."
  exit 1
fi

if [ -n "$CONTAINER" ]; then
  if $ONCE; then
    docker stats --no-stream "$CONTAINER"
  else
    docker stats "$CONTAINER"
  fi
else
  if $ONCE; then
    docker stats --no-stream
  else
    docker stats
  fi
fi
