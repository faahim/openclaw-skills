#!/bin/bash
# Typesense Collection & Document Manager
set -e

INSTALL_DIR="${TYPESENSE_DIR:-$HOME/.typesense}"
CONFIG="$INSTALL_DIR/config.ini"

# Load config
if [ -f "$CONFIG" ]; then
  TYPESENSE_API_KEY="${TYPESENSE_API_KEY:-$(grep 'api-key' "$CONFIG" | cut -d'=' -f2 | tr -d ' ')}"
  TYPESENSE_PORT="${TYPESENSE_PORT:-$(grep 'api-port' "$CONFIG" | cut -d'=' -f2 | tr -d ' ')}"
fi

HOST="${TYPESENSE_HOST:-localhost}"
PORT="${TYPESENSE_PORT:-8108}"
API_KEY="${TYPESENSE_API_KEY}"
BASE_URL="http://$HOST:$PORT"

if [ -z "$API_KEY" ]; then
  echo "❌ No API key found. Set TYPESENSE_API_KEY or run install.sh first."
  exit 1
fi

ts_curl() {
  curl -sf -H "X-TYPESENSE-API-KEY: $API_KEY" -H "Content-Type: application/json" "$@"
}

ts_curl_verbose() {
  curl -s -H "X-TYPESENSE-API-KEY: $API_KEY" -H "Content-Type: application/json" "$@"
}

# --- Collections ---

cmd_create_collection() {
  local SCHEMA="$1"
  if [ -z "$SCHEMA" ]; then
    echo "Usage: manage.sh create-collection '<json-schema>'"
    exit 1
  fi
  RESULT=$(ts_curl_verbose -X POST "$BASE_URL/collections" -d "$SCHEMA")
  echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
}

cmd_list_collections() {
  RESULT=$(ts_curl "$BASE_URL/collections")
  echo "$RESULT" | jq '[.[] | {name, num_documents, created_at}]' 2>/dev/null || echo "$RESULT"
}

cmd_get_collection() {
  local NAME="$1"
  [ -z "$NAME" ] && { echo "Usage: manage.sh get-collection <name>"; exit 1; }
  RESULT=$(ts_curl "$BASE_URL/collections/$NAME")
  echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
}

cmd_drop_collection() {
  local NAME="$1"
  [ -z "$NAME" ] && { echo "Usage: manage.sh drop-collection <name>"; exit 1; }
  echo "⚠️  Deleting collection '$NAME'..."
  RESULT=$(ts_curl_verbose -X DELETE "$BASE_URL/collections/$NAME")
  echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
  echo "✅ Collection deleted"
}

# --- Documents ---

cmd_index() {
  local COLLECTION="$1"
  local DOC="$2"
  [ -z "$COLLECTION" ] || [ -z "$DOC" ] && { echo "Usage: manage.sh index <collection> '<json>'"; exit 1; }
  RESULT=$(ts_curl_verbose -X POST "$BASE_URL/collections/$COLLECTION/documents" -d "$DOC")
  echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
}

cmd_bulk_import() {
  local COLLECTION="$1"
  local FILE="$2"
  [ -z "$COLLECTION" ] || [ -z "$FILE" ] && { echo "Usage: manage.sh bulk-import <collection> <file.jsonl>"; exit 1; }
  [ ! -f "$FILE" ] && { echo "❌ File not found: $FILE"; exit 1; }

  LINES=$(wc -l < "$FILE")
  echo "📦 Importing $LINES documents into '$COLLECTION'..."

  RESULT=$(curl -s -H "X-TYPESENSE-API-KEY: $API_KEY" \
    -X POST "$BASE_URL/collections/$COLLECTION/documents/import?action=create" \
    --data-binary @"$FILE")

  SUCCESS=$(echo "$RESULT" | grep -c '"success":true' || echo 0)
  FAILED=$(echo "$RESULT" | grep -c '"success":false' || echo 0)
  echo "✅ Imported: $SUCCESS success, $FAILED failed"

  if [ "$FAILED" -gt 0 ]; then
    echo "❌ Failed documents:"
    echo "$RESULT" | grep '"success":false' | head -5
  fi
}

cmd_bulk_import_json() {
  local COLLECTION="$1"
  local FILE="$2"
  [ -z "$COLLECTION" ] || [ -z "$FILE" ] && { echo "Usage: manage.sh bulk-import-json <collection> <file.json>"; exit 1; }
  [ ! -f "$FILE" ] && { echo "❌ File not found: $FILE"; exit 1; }

  # Convert JSON array to JSONL
  TEMP=$(mktemp)
  jq -c '.[]' "$FILE" > "$TEMP"
  cmd_bulk_import "$COLLECTION" "$TEMP"
  rm -f "$TEMP"
}

cmd_get_doc() {
  local COLLECTION="$1"
  local ID="$2"
  [ -z "$COLLECTION" ] || [ -z "$ID" ] && { echo "Usage: manage.sh get-doc <collection> <id>"; exit 1; }
  RESULT=$(ts_curl "$BASE_URL/collections/$COLLECTION/documents/$ID")
  echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
}

cmd_delete_doc() {
  local COLLECTION="$1"
  local ID="$2"
  [ -z "$COLLECTION" ] || [ -z "$ID" ] && { echo "Usage: manage.sh delete-doc <collection> <id>"; exit 1; }
  RESULT=$(ts_curl_verbose -X DELETE "$BASE_URL/collections/$COLLECTION/documents/$ID")
  echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
}

# --- Search ---

cmd_search() {
  local COLLECTION="$1"
  local QUERY="$2"
  shift 2 2>/dev/null || { echo "Usage: manage.sh search <collection> <query> [--filter ...] [--facet ...] [--sort ...] [--limit N]"; exit 1; }

  # Parse optional args
  FILTER=""
  FACET=""
  SORT=""
  LIMIT="10"
  QUERY_BY=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --filter) FILTER="$2"; shift 2 ;;
      --facet) FACET="$2"; shift 2 ;;
      --sort) SORT="$2"; shift 2 ;;
      --limit) LIMIT="$2"; shift 2 ;;
      --query-by) QUERY_BY="$2"; shift 2 ;;
      --group) GROUP="$2"; shift 2 ;;
      --group-limit) GROUP_LIMIT="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  # If no query_by specified, get all string fields
  if [ -z "$QUERY_BY" ]; then
    QUERY_BY=$(ts_curl "$BASE_URL/collections/$COLLECTION" 2>/dev/null | \
      jq -r '[.fields[] | select(.type == "string" or .type == "string[]") | .name] | join(",")' 2>/dev/null)
    [ -z "$QUERY_BY" ] && QUERY_BY="*"
  fi

  # Build search params
  PARAMS="q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))" 2>/dev/null || echo "$QUERY")&query_by=$QUERY_BY&per_page=$LIMIT"
  [ -n "$FILTER" ] && PARAMS="$PARAMS&filter_by=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$FILTER'))" 2>/dev/null || echo "$FILTER")"
  [ -n "$FACET" ] && PARAMS="$PARAMS&facet_by=$FACET"
  [ -n "$SORT" ] && PARAMS="$PARAMS&sort_by=$SORT"
  [ -n "$GROUP" ] && PARAMS="$PARAMS&group_by=$GROUP"
  [ -n "$GROUP_LIMIT" ] && PARAMS="$PARAMS&group_limit=$GROUP_LIMIT"

  RESULT=$(ts_curl "$BASE_URL/collections/$COLLECTION/documents/search?$PARAMS")

  if [ $? -eq 0 ] && [ -n "$RESULT" ]; then
    FOUND=$(echo "$RESULT" | jq '.found' 2>/dev/null)
    TIME=$(echo "$RESULT" | jq '.search_time_ms' 2>/dev/null)
    echo "🔍 Found $FOUND results in ${TIME}ms"
    echo ""
    echo "$RESULT" | jq '.hits[] | .document' 2>/dev/null || echo "$RESULT"
  else
    echo "❌ Search failed"
    echo "$RESULT"
  fi
}

# --- Keys ---

cmd_create_key() {
  local KEY_DEF="$1"
  [ -z "$KEY_DEF" ] && { echo "Usage: manage.sh create-key '<json>'"; exit 1; }
  RESULT=$(ts_curl_verbose -X POST "$BASE_URL/keys" -d "$KEY_DEF")
  echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
}

cmd_list_keys() {
  RESULT=$(ts_curl "$BASE_URL/keys")
  echo "$RESULT" | jq '.keys[] | {id, description, actions, collections}' 2>/dev/null || echo "$RESULT"
}

cmd_delete_key() {
  local KEY_ID="$1"
  [ -z "$KEY_ID" ] && { echo "Usage: manage.sh delete-key <key-id>"; exit 1; }
  ts_curl_verbose -X DELETE "$BASE_URL/keys/$KEY_ID"
  echo "✅ Key $KEY_ID deleted"
}

# --- Aliases ---

cmd_create_alias() {
  local ALIAS_NAME="$1"
  local COLLECTION="$2"
  [ -z "$ALIAS_NAME" ] || [ -z "$COLLECTION" ] && { echo "Usage: manage.sh create-alias <alias> <collection>"; exit 1; }
  RESULT=$(ts_curl_verbose -X PUT "$BASE_URL/aliases/$ALIAS_NAME" -d "{\"collection_name\": \"$COLLECTION\"}")
  echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
}

cmd_list_aliases() {
  RESULT=$(ts_curl "$BASE_URL/aliases")
  echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
}

# --- Export & Backup ---

cmd_export() {
  local COLLECTION="$1"
  [ -z "$COLLECTION" ] && { echo "Usage: manage.sh export <collection>"; exit 1; }
  curl -s -H "X-TYPESENSE-API-KEY: $API_KEY" "$BASE_URL/collections/$COLLECTION/documents/export"
}

cmd_snapshot() {
  local SNAPSHOT_PATH="$1"
  [ -z "$SNAPSHOT_PATH" ] && SNAPSHOT_PATH="$INSTALL_DIR/snapshots/$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$(dirname "$SNAPSHOT_PATH")"
  RESULT=$(ts_curl_verbose -X POST "$BASE_URL/operations/snapshot?snapshot_path=$SNAPSHOT_PATH")
  echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
  echo "📸 Snapshot saved to: $SNAPSHOT_PATH"
}

# --- Main ---

case "${1:-help}" in
  create-collection) cmd_create_collection "$2" ;;
  list-collections)  cmd_list_collections ;;
  get-collection)    cmd_get_collection "$2" ;;
  drop-collection)   cmd_drop_collection "$2" ;;
  index)             cmd_index "$2" "$3" ;;
  bulk-import)       cmd_bulk_import "$2" "$3" ;;
  bulk-import-json)  cmd_bulk_import_json "$2" "$3" ;;
  get-doc)           cmd_get_doc "$2" "$3" ;;
  delete-doc)        cmd_delete_doc "$2" "$3" ;;
  search)            cmd_search "${@:2}" ;;
  create-key)        cmd_create_key "$2" ;;
  list-keys)         cmd_list_keys ;;
  delete-key)        cmd_delete_key "$2" ;;
  create-alias)      cmd_create_alias "$2" "$3" ;;
  list-aliases)      cmd_list_aliases ;;
  export)            cmd_export "$2" ;;
  snapshot)          cmd_snapshot "$2" ;;
  *)
    echo "Typesense Manager — Collection & Document Operations"
    echo ""
    echo "Collections:"
    echo "  create-collection '<json>'   Create a new collection"
    echo "  list-collections             List all collections"
    echo "  get-collection <name>        Get collection details"
    echo "  drop-collection <name>       Delete a collection"
    echo ""
    echo "Documents:"
    echo "  index <collection> '<json>'           Index a single document"
    echo "  bulk-import <collection> <file.jsonl>  Bulk import from JSONL"
    echo "  bulk-import-json <collection> <file>   Bulk import from JSON array"
    echo "  get-doc <collection> <id>              Get document by ID"
    echo "  delete-doc <collection> <id>           Delete document"
    echo ""
    echo "Search:"
    echo "  search <collection> <query> [--filter ...] [--facet ...] [--sort ...] [--limit N]"
    echo ""
    echo "Keys:"
    echo "  create-key '<json>'    Create scoped API key"
    echo "  list-keys              List all API keys"
    echo "  delete-key <id>        Delete an API key"
    echo ""
    echo "Aliases:"
    echo "  create-alias <alias> <collection>   Create/update alias"
    echo "  list-aliases                        List all aliases"
    echo ""
    echo "Backup:"
    echo "  export <collection>       Export documents as JSONL"
    echo "  snapshot [path]           Take full snapshot"
    ;;
esac
