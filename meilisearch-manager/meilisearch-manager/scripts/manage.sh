#!/bin/bash
# Manage Meilisearch indexes, documents, search, and settings
set -euo pipefail

MEILI_HOST="${MEILI_HOST:-http://localhost:7700}"
MEILI_MASTER_KEY="${MEILI_MASTER_KEY:-}"

auth_header() {
  [ -n "$MEILI_MASTER_KEY" ] && echo "Authorization: Bearer $MEILI_MASTER_KEY" || echo "X-No-Auth: true"
}

api() {
  local method="$1" endpoint="$2"
  shift 2
  curl -sf -X "$method" "$MEILI_HOST$endpoint" \
    -H "Content-Type: application/json" \
    -H "$(auth_header)" \
    "$@" | jq . 2>/dev/null || echo '{"error": "Request failed"}'
}

usage() {
  cat <<EOF
Usage: $0 <command> [args]

Index Commands:
  create-index <uid> [--primary-key KEY]   Create an index
  delete-index <uid>                       Delete an index
  list-indexes                             List all indexes

Document Commands:
  add-docs <index> <file|-> [--format json|ndjson] [--batch-size N]
  update-docs <index> <file>               Partial update documents
  delete-docs <index> '<json-array>'       Delete specific documents
  delete-all-docs <index>                  Delete all documents
  export <index>                           Export all documents as JSON

Search Commands:
  search <index> <query> [--filter F] [--sort S] [--facets F] [--limit N] [--offset N] [--highlight]

Settings Commands:
  settings <index> <setting> '<json>'      Update a setting
  get-settings <index>                     Get all settings

Admin Commands:
  health                                   Health check
  stats                                    Instance statistics
  version                                  Version info
  tasks                                    List recent tasks
  task <id>                                Get task details
  create-dump                              Create a database dump
  create-key [options]                     Create an API key
  list-keys                                List API keys
  nginx-config [--domain D] [--port P]     Generate Nginx config
EOF
}

cmd_create_index() {
  local uid="$1" pk=""
  shift
  while [[ $# -gt 0 ]]; do
    case $1 in
      --primary-key) pk="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  local body="{\"uid\":\"$uid\""
  [ -n "$pk" ] && body+=",\"primaryKey\":\"$pk\""
  body+="}"
  echo "📦 Creating index '$uid'..."
  api POST "/indexes" -d "$body"
}

cmd_delete_index() {
  echo "🗑️  Deleting index '$1'..."
  api DELETE "/indexes/$1"
}

cmd_list_indexes() {
  api GET "/indexes?limit=100"
}

cmd_add_docs() {
  local index="$1" file="$2" format="json" batch_size=0
  shift 2
  while [[ $# -gt 0 ]]; do
    case $1 in
      --format) format="$2"; shift 2 ;;
      --batch-size) batch_size="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local content_type="application/json"
  [ "$format" = "ndjson" ] && content_type="application/x-ndjson"

  if [ "$file" = "-" ]; then
    local data
    data=$(cat)
  else
    if [ ! -f "$file" ]; then
      echo "❌ File not found: $file"
      exit 1
    fi
    local data
    data=$(cat "$file")
  fi

  if [ "$batch_size" -gt 0 ] && [ "$format" = "json" ]; then
    local total
    total=$(echo "$data" | jq 'length')
    local offset=0
    echo "📤 Importing $total documents in batches of $batch_size..."
    while [ "$offset" -lt "$total" ]; do
      echo "$data" | jq ".[$offset:$((offset + batch_size))]" | \
        curl -sf -X POST "$MEILI_HOST/indexes/$index/documents" \
          -H "Content-Type: $content_type" \
          -H "$(auth_header)" \
          -d @- | jq .
      offset=$((offset + batch_size))
      echo "   Processed $((offset < total ? offset : total))/$total"
    done
  else
    echo "📤 Adding documents to '$index'..."
    echo "$data" | curl -sf -X POST "$MEILI_HOST/indexes/$index/documents" \
      -H "Content-Type: $content_type" \
      -H "$(auth_header)" \
      -d @- | jq .
  fi
}

cmd_update_docs() {
  echo "📝 Updating documents in '$1'..."
  api PUT "/indexes/$1/documents" -d "@$2"
}

cmd_delete_docs() {
  echo "🗑️  Deleting documents from '$1'..."
  api POST "/indexes/$1/documents/delete-batch" -d "$2"
}

cmd_delete_all_docs() {
  echo "🗑️  Deleting ALL documents from '$1'..."
  api DELETE "/indexes/$1/documents"
}

cmd_export() {
  local index="$1" offset=0 limit=1000 all="[]"
  while true; do
    local batch
    batch=$(curl -sf "$MEILI_HOST/indexes/$index/documents?limit=$limit&offset=$offset" \
      -H "$(auth_header)" | jq '.results')
    local count
    count=$(echo "$batch" | jq 'length')
    [ "$count" -eq 0 ] && break
    all=$(echo "$all" "$batch" | jq -s '.[0] + .[1]')
    offset=$((offset + limit))
  done
  echo "$all"
}

cmd_search() {
  local index="$1" query="$2"
  shift 2
  local body="{\"q\":\"$query\""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --filter) body+=",\"filter\":\"$2\""; shift 2 ;;
      --sort) body+=",\"sort\":[\"$2\"]"; shift 2 ;;
      --facets) body+=",\"facets\":$2"; shift 2 ;;
      --limit) body+=",\"limit\":$2"; shift 2 ;;
      --offset) body+=",\"offset\":$2"; shift 2 ;;
      --highlight) body+=",\"attributesToHighlight\":[\"*\"]"; shift ;;
      *) shift ;;
    esac
  done
  body+="}"
  api POST "/indexes/$index/search" -d "$body"
}

cmd_settings() {
  local index="$1" setting="$2" value="$3"
  echo "⚙️  Updating $setting for '$index'..."
  api PATCH "/indexes/$index/settings" -d "{\"$setting\":$value}"
}

cmd_get_settings() {
  api GET "/indexes/$1/settings"
}

cmd_health() {
  local result
  result=$(curl -sf "$MEILI_HOST/health" 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "✅ Meilisearch is healthy"
    echo "$result" | jq .
  else
    echo "❌ Meilisearch is not reachable at $MEILI_HOST"
    exit 1
  fi
}

cmd_stats() { api GET "/stats"; }
cmd_version() { api GET "/version"; }
cmd_tasks() { api GET "/tasks?limit=20"; }
cmd_task() { api GET "/tasks/$1"; }
cmd_create_dump() { echo "💾 Creating dump..."; api POST "/dumps"; }

cmd_create_key() {
  local desc="" actions='["*"]' indexes='["*"]' expires=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --description) desc="$2"; shift 2 ;;
      --actions) actions="$2"; shift 2 ;;
      --indexes) indexes="$2"; shift 2 ;;
      --expires-at) expires="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  local body="{\"actions\":$actions,\"indexes\":$indexes"
  [ -n "$desc" ] && body+=",\"description\":\"$desc\""
  [ -n "$expires" ] && body+=",\"expiresAt\":\"$expires\""
  body+="}"
  api POST "/keys" -d "$body"
}

cmd_list_keys() { api GET "/keys"; }

cmd_nginx_config() {
  local domain="search.example.com" port=7700
  while [[ $# -gt 0 ]]; do
    case $1 in
      --domain) domain="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  cat <<NGINX
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://127.0.0.1:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Increase max body size for document uploads
        client_max_body_size 100M;
    }
}
NGINX
  echo ""
  echo "# Save to /etc/nginx/sites-available/$domain"
  echo "# Then: sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/"
  echo "# Then: sudo nginx -t && sudo systemctl reload nginx"
}

# Route
case "${1:-}" in
  create-index) shift; cmd_create_index "$@" ;;
  delete-index) shift; cmd_delete_index "$@" ;;
  list-indexes) cmd_list_indexes ;;
  add-docs) shift; cmd_add_docs "$@" ;;
  update-docs) shift; cmd_update_docs "$@" ;;
  delete-docs) shift; cmd_delete_docs "$@" ;;
  delete-all-docs) shift; cmd_delete_all_docs "$@" ;;
  export) shift; cmd_export "$@" ;;
  search) shift; cmd_search "$@" ;;
  settings) shift; cmd_settings "$@" ;;
  get-settings) shift; cmd_get_settings "$@" ;;
  health) cmd_health ;;
  stats) cmd_stats ;;
  version) cmd_version ;;
  tasks) cmd_tasks ;;
  task) shift; cmd_task "$@" ;;
  create-dump) cmd_create_dump ;;
  create-key) shift; cmd_create_key "$@" ;;
  list-keys) cmd_list_keys ;;
  nginx-config) shift; cmd_nginx_config "$@" ;;
  *) usage; exit 1 ;;
esac
