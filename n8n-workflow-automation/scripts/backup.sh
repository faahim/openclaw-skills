#!/bin/bash
# Backup and restore n8n workflows
set -euo pipefail

N8N_DIR="${N8N_DIR:-$HOME/.n8n}"
N8N_PORT="${N8N_PORT:-5678}"
ACTION="export"
OUTPUT=""
RESTORE_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --output|-o) OUTPUT="$2"; shift 2 ;;
    --restore|-r) ACTION="restore"; RESTORE_FILE="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

BASE_URL="http://localhost:$N8N_PORT/api/v1"

if [ "$ACTION" = "export" ]; then
  OUTPUT="${OUTPUT:-$HOME/n8n-backup-$(date +%Y%m%d-%H%M%S).json}"

  echo "📦 Exporting workflows..."

  # Get all workflows
  WORKFLOWS=$(curl -sf "$BASE_URL/workflows?limit=100" 2>/dev/null)
  if [ -z "$WORKFLOWS" ]; then
    echo "❌ Cannot connect to n8n API. Is it running?"
    exit 1
  fi

  COUNT=$(echo "$WORKFLOWS" | grep -o '"count":[0-9]*' | head -1 | cut -d: -f2 || echo "0")

  echo "$WORKFLOWS" > "$OUTPUT"
  echo "✅ Exported $COUNT workflows to $OUTPUT"
  echo "   Size: $(du -h "$OUTPUT" | cut -f1)"

elif [ "$ACTION" = "restore" ]; then
  if [ ! -f "$RESTORE_FILE" ]; then
    echo "❌ File not found: $RESTORE_FILE"
    exit 1
  fi

  echo "📥 Restoring workflows from $RESTORE_FILE..."

  # Parse and import each workflow
  IMPORTED=0
  ERRORS=0

  # Extract workflow data and import one by one
  python3 -c "
import json, sys
data = json.load(open('$RESTORE_FILE'))
workflows = data.get('data', data.get('workflows', [data] if 'nodes' in data else []))
for w in workflows:
    print(json.dumps(w))
" 2>/dev/null | while read -r workflow; do
    NAME=$(echo "$workflow" | python3 -c "import json,sys; print(json.load(sys.stdin).get('name','unnamed'))" 2>/dev/null)
    RESULT=$(curl -sf -X POST "$BASE_URL/workflows" \
      -H "Content-Type: application/json" \
      -d "$workflow" 2>/dev/null)
    if [ $? -eq 0 ]; then
      echo "  ✅ Imported: $NAME"
      IMPORTED=$((IMPORTED + 1))
    else
      echo "  ❌ Failed: $NAME"
      ERRORS=$((ERRORS + 1))
    fi
  done

  echo "✅ Restore complete"
fi
