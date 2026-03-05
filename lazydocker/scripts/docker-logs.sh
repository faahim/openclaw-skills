#!/bin/bash
set -euo pipefail

# Docker Log Viewer — tail, filter, and search container logs
# Usage: bash docker-logs.sh <container> [--lines N] [--follow] [--grep PATTERN] [--since TIME]

CONTAINER=""
LINES=100
FOLLOW=false
GREP_PATTERN=""
SINCE=""

if [ $# -lt 1 ]; then
  echo "Usage: bash docker-logs.sh <container-name> [--lines N] [--follow] [--grep PATTERN] [--since TIME]"
  exit 1
fi

CONTAINER="$1"; shift

while [[ $# -gt 0 ]]; do
  case $1 in
    --lines|-n) LINES="$2"; shift 2 ;;
    --follow|-f) FOLLOW=true; shift ;;
    --grep|-g) GREP_PATTERN="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Verify container exists
if ! docker inspect "$CONTAINER" &>/dev/null; then
  echo "❌ Container '$CONTAINER' not found."
  echo ""
  echo "Available containers:"
  docker ps -a --format '  {{.Names}} ({{.Status}})' | head -20
  exit 1
fi

# Build docker logs command
CMD="docker logs"
[ -n "$SINCE" ] && CMD="$CMD --since $SINCE"
CMD="$CMD --tail $LINES"
$FOLLOW && CMD="$CMD --follow"
CMD="$CMD $CONTAINER"

# Execute with optional grep
if [ -n "$GREP_PATTERN" ]; then
  if $FOLLOW; then
    $CMD 2>&1 | grep --line-buffered -iE "$GREP_PATTERN"
  else
    $CMD 2>&1 | grep -iE "$GREP_PATTERN"
  fi
else
  $CMD 2>&1
fi
