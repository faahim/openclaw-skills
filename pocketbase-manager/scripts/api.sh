#!/bin/bash
# PocketBase API Helper — Collections, stats, schema management
set -euo pipefail

URL="${PB_URL:-http://localhost:8090}"
TOKEN="${PB_ADMIN_TOKEN:-}"
COMMAND=""
SUBCOMMAND=""
OUTPUT=""
INPUT=""
JSON=""

usage() {
  cat <<EOF
Usage: $0 <command> <subcommand> [options]

Commands:
  collections list      List all collections
  collections export    Export collection schema to JSON
  collections import    Import collection schema from JSON
  collections create    Create a collection from JSON
  stats                 Show instance statistics

Options:
  --url URL             PocketBase URL (default: \$PB_URL or http://localhost:8090)
  --admin-token TOKEN   Admin auth token (default: \$PB_ADMIN_TOKEN)
  --output FILE         Output file (for export)
  --input FILE          Input file (for import)
  --json JSON           Inline JSON (for create)
EOF
  exit 1
}

[[ $# -lt 1 ]] && usage
COMMAND="$1"; shift
[[ $# -ge 1 && ! "$1" =~ ^-- ]] && { SUBCOMMAND="$1"; shift; }

while [[ $# -gt 0 ]]; do
  case $1 in
    --url) URL="$2"; shift 2 ;;
    --admin-token) TOKEN="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --input) INPUT="$2"; shift 2 ;;
    --json) JSON="$2"; shift 2 ;;
    *) shift ;;
  esac
done

auth_header() {
  if [[ -n "$TOKEN" ]]; then
    echo "Authorization: $TOKEN"
  else
    echo "X-No-Auth: true"
  fi
}

collections_list() {
  local result
  result=$(curl -s "${URL}/api/collections" -H "$(auth_header)")
  echo "$result" | jq -r '.items[] | "\(.name)\t\(.type)\t\(.schema | length) fields"' 2>/dev/null || echo "$result"
}

collections_export() {
  local result
  result=$(curl -s "${URL}/api/collections" -H "$(auth_header)")
  if [[ -n "$OUTPUT" ]]; then
    echo "$result" | jq '.items' > "$OUTPUT"
    echo "✅ Schema exported to $OUTPUT ($(echo "$result" | jq '.items | length') collections)"
  else
    echo "$result" | jq '.items'
  fi
}

collections_import() {
  [[ -z "$INPUT" ]] && { echo "❌ --input required"; exit 1; }
  [[ -f "$INPUT" ]] || { echo "❌ File not found: $INPUT"; exit 1; }

  local result
  result=$(curl -s -X PUT "${URL}/api/collections/import" \
    -H "$(auth_header)" \
    -H "Content-Type: application/json" \
    -d "{\"collections\": $(cat "$INPUT")}")

  if echo "$result" | jq -e '.code' &>/dev/null; then
    echo "❌ Import failed: $(echo "$result" | jq -r '.message')"
  else
    echo "✅ Schema imported successfully"
  fi
}

collections_create() {
  [[ -z "$JSON" ]] && { echo "❌ --json required"; exit 1; }

  local result
  result=$(curl -s -X POST "${URL}/api/collections" \
    -H "$(auth_header)" \
    -H "Content-Type: application/json" \
    -d "$JSON")

  if echo "$result" | jq -e '.id' &>/dev/null; then
    local name
    name=$(echo "$result" | jq -r '.name')
    echo "✅ Collection '$name' created"
  else
    echo "❌ Create failed: $(echo "$result" | jq -r '.message' 2>/dev/null || echo "$result")"
  fi
}

cmd_stats() {
  echo "📊 PocketBase Stats (${URL})"
  echo ""

  # Health check
  local health
  health=$(curl -s "${URL}/api/health")
  echo "Health: $(echo "$health" | jq -r '.message // "unknown"')"

  # Collections
  local collections
  collections=$(curl -s "${URL}/api/collections" -H "$(auth_header)" 2>/dev/null)
  local count
  count=$(echo "$collections" | jq '.totalItems // 0' 2>/dev/null || echo "?")
  echo "Collections: $count"

  echo ""
  echo "Collections:"
  echo "$collections" | jq -r '.items[]? | "  \(.name) (\(.type)) — \(.schema | length) fields"' 2>/dev/null || echo "  (auth required)"
}

case "$COMMAND" in
  collections)
    case "$SUBCOMMAND" in
      list) collections_list ;;
      export) collections_export ;;
      import) collections_import ;;
      create) collections_create ;;
      *) echo "Unknown subcommand: $SUBCOMMAND"; usage ;;
    esac
    ;;
  stats) cmd_stats ;;
  *) echo "Unknown command: $COMMAND"; usage ;;
esac
