#!/bin/bash
# Import a workflow into n8n from file or URL
set -euo pipefail

N8N_PORT="${N8N_PORT:-5678}"
BASE="http://localhost:$N8N_PORT/api/v1"
FILE=""
URL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --url) URL="$2"; shift 2 ;;
    *) FILE="$1"; shift ;;
  esac
done

if [ -n "$URL" ]; then
  echo "📥 Fetching workflow from $URL..."
  WORKFLOW=$(curl -sf "$URL")
elif [ -n "$FILE" ] && [ -f "$FILE" ]; then
  WORKFLOW=$(cat "$FILE")
else
  echo "Usage: import-workflow.sh <file.json> | --url <url>"
  exit 1
fi

NAME=$(echo "$WORKFLOW" | python3 -c "import json,sys; print(json.load(sys.stdin).get('name','Imported Workflow'))" 2>/dev/null || echo "Imported")

echo "📋 Importing: $NAME"

RESULT=$(curl -sf -X POST "$BASE/workflows" \
  -H "Content-Type: application/json" \
  -d "$WORKFLOW" 2>/dev/null)

if [ $? -eq 0 ]; then
  ID=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id','?'))" 2>/dev/null || echo "?")
  echo "✅ Imported: $NAME (ID: $ID)"
  echo "   Open: http://localhost:$N8N_PORT/workflow/$ID"
else
  echo "❌ Import failed. Is n8n running?"
  exit 1
fi
