#!/bin/bash
# Meilisearch Manager — CLI wrapper for Meilisearch REST API
# Usage: run.sh <command> [args...]

set -euo pipefail

MEILI_URL="${MEILI_URL:-http://localhost:7700}"
MEILI_MASTER_KEY="${MEILI_MASTER_KEY:-}"

# Auth header
auth_header() {
  if [[ -n "$MEILI_MASTER_KEY" ]]; then
    echo "Authorization: Bearer $MEILI_MASTER_KEY"
  else
    echo "X-No-Auth: true"
  fi
}

# API call helper
api() {
  local method="$1" path="$2"
  shift 2
  curl -s -X "$method" \
    "${MEILI_URL}${path}" \
    -H "Content-Type: application/json" \
    -H "$(auth_header)" \
    "$@"
}

# Pretty print JSON
pp() { jq '.' 2>/dev/null || cat; }

CMD="${1:-help}"
shift || true

case "$CMD" in

  # --- Server ---
  start)
    ARGS=()
    while [[ $# -gt 0 ]]; do
      case $1 in
        --master-key) ARGS+=(--master-key "$2"); shift 2 ;;
        --env) ARGS+=(--env "$2"); shift 2 ;;
        --http-addr) ARGS+=(--http-addr "$2"); shift 2 ;;
        --db-path) ARGS+=(--db-path "$2"); shift 2 ;;
        *) ARGS+=("$1"); shift ;;
      esac
    done
    echo "🚀 Starting Meilisearch at ${MEILI_URL}..."
    exec meilisearch "${ARGS[@]}"
    ;;

  health)
    api GET /health | pp
    ;;

  version)
    api GET /version | pp
    ;;

  stats)
    api GET /stats | pp
    ;;

  # --- Indexes ---
  create-index)
    INDEX="$1"; shift
    PRIMARY_KEY=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --primary-key) PRIMARY_KEY="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    BODY="{\"uid\":\"${INDEX}\""
    [[ -n "$PRIMARY_KEY" ]] && BODY+=",\"primaryKey\":\"${PRIMARY_KEY}\""
    BODY+="}"
    echo "📦 Creating index '${INDEX}'..."
    api POST /indexes -d "$BODY" | pp
    ;;

  list-indexes)
    api GET /indexes | pp
    ;;

  get-index)
    api GET "/indexes/$1" | pp
    ;;

  delete-index)
    echo "🗑️  Deleting index '$1'..."
    api DELETE "/indexes/$1" | pp
    ;;

  # --- Documents ---
  add-docs)
    INDEX="$1"; shift
    SOURCE="${1:--}"
    if [[ "$SOURCE" == "-" ]]; then
      DATA=$(cat)
    else
      DATA=$(cat "$SOURCE")
    fi
    DOC_COUNT=$(echo "$DATA" | jq 'length' 2>/dev/null || echo "?")
    echo "📄 Adding ${DOC_COUNT} documents to '${INDEX}'..."
    echo "$DATA" | api POST "/indexes/${INDEX}/documents" -d @- | pp
    ;;

  get-doc)
    api GET "/indexes/$1/documents/$2" | pp
    ;;

  delete-doc)
    echo "🗑️  Deleting document '$2' from '$1'..."
    api DELETE "/indexes/$1/documents/$2" | pp
    ;;

  delete-all-docs)
    echo "🗑️  Deleting all documents from '$1'..."
    api DELETE "/indexes/$1/documents" | pp
    ;;

  export)
    # Export all documents from an index
    INDEX="$1"
    OFFSET=0
    LIMIT=1000
    echo "[" 
    FIRST=true
    while true; do
      BATCH=$(api GET "/indexes/${INDEX}/documents?offset=${OFFSET}&limit=${LIMIT}")
      RESULTS=$(echo "$BATCH" | jq '.results')
      COUNT=$(echo "$RESULTS" | jq 'length')
      if [[ "$COUNT" -eq 0 ]]; then break; fi
      if [[ "$FIRST" == "true" ]]; then
        FIRST=false
      else
        echo ","
      fi
      echo "$RESULTS" | jq -c '.[]' | paste -sd ',' -
      OFFSET=$((OFFSET + LIMIT))
      [[ "$COUNT" -lt "$LIMIT" ]] && break
    done
    echo "]"
    ;;

  bulk-import)
    INDEX="$1"; shift
    FILE="$1"; shift
    BATCH_SIZE=10000
    while [[ $# -gt 0 ]]; do
      case $1 in
        --batch-size) BATCH_SIZE="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    TOTAL=$(jq 'length' "$FILE")
    echo "📦 Bulk importing ${TOTAL} documents in batches of ${BATCH_SIZE}..."
    OFFSET=0
    BATCH_NUM=0
    while [[ $OFFSET -lt $TOTAL ]]; do
      BATCH_NUM=$((BATCH_NUM + 1))
      END=$((OFFSET + BATCH_SIZE))
      [[ $END -gt $TOTAL ]] && END=$TOTAL
      echo "   Batch ${BATCH_NUM}: documents ${OFFSET}-${END}..."
      jq ".[$OFFSET:$END]" "$FILE" | api POST "/indexes/${INDEX}/documents" -d @- > /dev/null
      OFFSET=$END
      sleep 0.5
    done
    echo "✅ Import complete! ${TOTAL} documents sent in ${BATCH_NUM} batches."
    echo "   Check status: $0 tasks"
    ;;

  # --- Search ---
  search)
    INDEX="$1"; shift
    QUERY="$1"; shift
    BODY="{\"q\":\"${QUERY}\""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --filter) BODY+=",\"filter\":\"$2\""; shift 2 ;;
        --sort) BODY+=",\"sort\":[\"$2\"]"; shift 2 ;;
        --limit) BODY+=",\"limit\":$2"; shift 2 ;;
        --offset) BODY+=",\"offset\":$2"; shift 2 ;;
        --facets) BODY+=",\"facets\":$2"; shift 2 ;;
        --highlight) BODY+=",\"attributesToHighlight\":[\"$2\"]"; shift 2 ;;
        *) shift ;;
      esac
    done
    BODY+="}"
    api POST "/indexes/${INDEX}/search" -d "$BODY" | pp
    ;;

  # --- Settings ---
  settings)
    INDEX="$1"; shift
    SETTING="${1:-get}"; shift || true
    case "$SETTING" in
      get)
        api GET "/indexes/${INDEX}/settings" | pp
        ;;
      searchable)
        echo "⚙️  Updating searchable attributes..."
        api PUT "/indexes/${INDEX}/settings/searchable-attributes" -d "$1" | pp
        ;;
      filterable)
        echo "⚙️  Updating filterable attributes..."
        api PUT "/indexes/${INDEX}/settings/filterable-attributes" -d "$1" | pp
        ;;
      sortable)
        echo "⚙️  Updating sortable attributes..."
        api PUT "/indexes/${INDEX}/settings/sortable-attributes" -d "$1" | pp
        ;;
      ranking)
        echo "⚙️  Updating ranking rules..."
        api PUT "/indexes/${INDEX}/settings/ranking-rules" -d "$1" | pp
        ;;
      synonyms)
        echo "⚙️  Updating synonyms..."
        api PUT "/indexes/${INDEX}/settings/synonyms" -d "$1" | pp
        ;;
      stop-words)
        echo "⚙️  Updating stop words..."
        api PUT "/indexes/${INDEX}/settings/stop-words" -d "$1" | pp
        ;;
      apply)
        echo "⚙️  Applying full settings from file..."
        api PATCH "/indexes/${INDEX}/settings" -d "@$1" | pp
        ;;
      reset)
        echo "⚙️  Resetting all settings to default..."
        api DELETE "/indexes/${INDEX}/settings" | pp
        ;;
      *)
        echo "Unknown setting: $SETTING"
        echo "Available: get, searchable, filterable, sortable, ranking, synonyms, stop-words, apply, reset"
        exit 1
        ;;
    esac
    ;;

  # --- Tasks ---
  tasks)
    FILTER="${1:-}"
    if [[ -n "$FILTER" ]]; then
      api GET "/tasks?indexUids=${FILTER}" | jq '.results[:10]'
    else
      api GET "/tasks?limit=10" | jq '.results'
    fi
    ;;

  # --- Dumps ---
  dump)
    echo "💾 Creating database dump..."
    api POST /dumps | pp
    ;;

  # --- Keys ---
  keys)
    SUBCMD="${1:-list}"; shift || true
    case "$SUBCMD" in
      list)
        api GET /keys | jq '.results'
        ;;
      create)
        BODY='{"actions":["*"],"indexes":["*"],"expiresAt":null}'
        while [[ $# -gt 0 ]]; do
          case $1 in
            --description) BODY=$(echo "$BODY" | jq --arg d "$2" '.description=$d'); shift 2 ;;
            --actions) BODY=$(echo "$BODY" | jq --argjson a "$2" '.actions=$a'); shift 2 ;;
            --indexes) BODY=$(echo "$BODY" | jq --argjson i "$2" '.indexes=$i'); shift 2 ;;
            --expires) BODY=$(echo "$BODY" | jq --arg e "$2" '.expiresAt=$e'); shift 2 ;;
            *) shift ;;
          esac
        done
        echo "🔑 Creating API key..."
        api POST /keys -d "$BODY" | pp
        ;;
      delete)
        echo "🗑️  Deleting key $1..."
        api DELETE "/keys/$1" | pp
        ;;
      *)
        echo "Usage: keys [list|create|delete]"
        exit 1
        ;;
    esac
    ;;

  help|*)
    cat << 'HELP'
Meilisearch Manager — CLI wrapper

USAGE: run.sh <command> [args...]

SERVER:
  start [--master-key KEY] [--env dev|prod]   Start Meilisearch
  health                                       Check server health
  version                                      Show version
  stats                                        Show index stats

INDEXES:
  create-index <name> [--primary-key KEY]      Create an index
  list-indexes                                 List all indexes
  get-index <name>                             Get index info
  delete-index <name>                          Delete an index

DOCUMENTS:
  add-docs <index> <file|->                    Add documents (JSON array)
  get-doc <index> <id>                         Get a document
  delete-doc <index> <id>                      Delete a document
  delete-all-docs <index>                      Delete all documents
  export <index>                               Export all documents as JSON
  bulk-import <index> <file> [--batch-size N]  Import large datasets

SEARCH:
  search <index> <query> [--filter F] [--sort S] [--limit N] [--facets F]

SETTINGS:
  settings <index> get                         Get all settings
  settings <index> searchable '["a","b"]'      Set searchable attributes
  settings <index> filterable '["a","b"]'      Set filterable attributes
  settings <index> sortable '["a","b"]'        Set sortable attributes
  settings <index> apply <file.json>           Apply settings from file
  settings <index> reset                       Reset to defaults

TASKS:
  tasks [index]                                List recent tasks

BACKUPS:
  dump                                         Create database dump

KEYS:
  keys list                                    List API keys
  keys create [--description D] [--actions A]  Create API key
  keys delete <uid>                            Delete API key

ENVIRONMENT:
  MEILI_URL         Server URL (default: http://localhost:7700)
  MEILI_MASTER_KEY  Master API key
HELP
    ;;
esac
