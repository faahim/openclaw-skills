#!/bin/bash
# PocketBase Health Checker
set -euo pipefail

DATA_BASE="/opt/pocketbase"
URL=""
ALL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --url) URL="$2"; shift 2 ;;
    --all) ALL=true; shift ;;
    -h|--help) echo "Usage: $0 [--url URL | --all]"; exit 0 ;;
    *) shift ;;
  esac
done

check_health() {
  local name="$1"
  local url="$2"

  local start end elapsed http_code
  start=$(date +%s%3N)
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${url}/api/health" 2>/dev/null || echo "000")
  end=$(date +%s%3N)
  elapsed=$((end - start))

  if [[ "$http_code" == "200" ]]; then
    # Get DB size
    local dir="${DATA_BASE}/${name}"
    local db_size="-"
    if [[ -f "$dir/pb_data/data.db" ]]; then
      db_size=$(du -sh "$dir/pb_data/data.db" 2>/dev/null | cut -f1 || echo "-")
    fi
    echo "✅ ${name} (${url}) — UP (${elapsed}ms) — DB: ${db_size}"
  else
    echo "❌ ${name} (${url}) — DOWN (HTTP ${http_code})"
  fi
}

if [[ "$ALL" == "true" ]]; then
  for dir in "$DATA_BASE"/*/; do
    [[ -d "$dir" ]] || continue
    name=$(basename "$dir")
    port="8090"
    if [[ -f "$dir/config.yaml" ]]; then
      port=$(grep -oP 'port:\s*\K\d+' "$dir/config.yaml" 2>/dev/null || echo "8090")
    fi
    check_health "$name" "http://localhost:${port}"
  done
elif [[ -n "$URL" ]]; then
  check_health "instance" "$URL"
else
  echo "Usage: $0 [--url URL | --all]"
  exit 1
fi
