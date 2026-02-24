#!/bin/bash
# View and filter Traefik logs

set -euo pipefail

TAIL=50
FILTER=""
LOG_TYPE="all"

while [[ $# -gt 0 ]]; do
  case $1 in
    --tail) TAIL="$2"; shift 2 ;;
    --filter) FILTER="$2"; shift 2 ;;
    --errors) FILTER="error\|ERR\|500\|502\|503\|504"; shift ;;
    --access) LOG_TYPE="access"; shift ;;
    -h|--help)
      echo "Usage: $0 [--tail N] [--filter pattern] [--errors] [--access]"
      exit 0 ;;
    *) shift ;;
  esac
done

if [[ "$LOG_TYPE" == "access" ]]; then
  ACCESS_LOG="/opt/traefik/logs/access.log"
  if [[ -f "$ACCESS_LOG" ]]; then
    if [[ -n "$FILTER" ]]; then
      tail -n "$TAIL" "$ACCESS_LOG" | grep -i "$FILTER"
    else
      tail -n "$TAIL" "$ACCESS_LOG"
    fi
  else
    echo "No access log found at $ACCESS_LOG"
  fi
else
  if [[ -n "$FILTER" ]]; then
    docker logs traefik 2>&1 | grep -i "$FILTER" | tail -n "$TAIL"
  else
    docker logs traefik 2>&1 | tail -n "$TAIL"
  fi
fi
