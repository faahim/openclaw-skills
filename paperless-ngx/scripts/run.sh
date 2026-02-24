#!/bin/bash
# Paperless-ngx Management Script
# Manages a running Paperless-ngx instance via Docker + REST API
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${PAPERLESS_DATA_DIR:-$HOME/paperless-ngx}"
ENV_FILE="${DATA_DIR}/.env"

# Load env if exists
if [ -f "$ENV_FILE" ]; then
  set -a; source "$ENV_FILE"; set +a
fi

PAPERLESS_URL="${PAPERLESS_URL:-http://localhost:8000}"
PAPERLESS_TOKEN="${PAPERLESS_TOKEN:-}"

usage() {
  cat <<EOF
Usage: $0 <command> [options]

Document Management:
  status                 Show instance status
  search QUERY           Search documents
  list [--limit N]       List documents
  get --id ID            Get document details
  download --id ID       Download document
  consume FILE           Upload a file for processing
  import DIR             Bulk import directory
  tag --id ID --tags T   Tag a document
  correspondent --id ID  Set correspondent

Rule Management:
  rules                  List matching rules
  rule-add               Create a matching rule
  rule-test --id ID      Test rule against documents

Maintenance:
  health                 Health check
  queue                  View processing queue
  logs [--lines N]       View container logs
  update                 Update to latest version
  restart                Restart containers
  reindex                Rebuild search index
  disk-usage             Show disk usage
  cleanup                Clean up temp files

Backup:
  backup --output PATH   Full backup
  backup-cron            Setup scheduled backups
  restore --input PATH   Restore from backup

User Management:
  token                  Generate API token
  user-add               Add user
  user-perms             Set user permissions

Configuration:
  config get KEY         Get config value
  config set KEY VALUE   Set config value
  ocr-install LANGS      Install OCR languages
EOF
  exit 1
}

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
err() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $*" >&2; }
ok()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $*"; }

compose_cmd() {
  cd "$DATA_DIR"
  if docker compose version &>/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

# Get or prompt for API token
ensure_token() {
  if [ -n "$PAPERLESS_TOKEN" ]; then return 0; fi
  err "No API token set. Generate one:"
  err "  $0 token --user admin --pass yourpassword"
  err "Then: export PAPERLESS_TOKEN=<token>"
  exit 1
}

api() {
  local method="$1" endpoint="$2"
  shift 2
  curl -sf -X "$method" \
    -H "Authorization: Token $PAPERLESS_TOKEN" \
    -H "Content-Type: application/json" \
    "${PAPERLESS_URL}/api${endpoint}" "$@"
}

# --- Commands ---

cmd_status() {
  log "Checking Paperless-ngx status..."

  # Container status
  local containers
  containers=$(compose_cmd ps --format json 2>/dev/null || compose_cmd ps 2>/dev/null)

  if curl -sf "${PAPERLESS_URL}/api/" &>/dev/null; then
    ok "Paperless-ngx running at ${PAPERLESS_URL}"
  else
    err "Paperless-ngx not responding at ${PAPERLESS_URL}"
    return 1
  fi

  # Check individual services
  for svc in broker db webserver; do
    local state
    state=$(compose_cmd ps "$svc" --format '{{.State}}' 2>/dev/null || echo "unknown")
    if [[ "$state" == "running" ]]; then
      ok "$svc: running"
    else
      err "$svc: $state"
    fi
  done

  # Document stats (if token available)
  if [ -n "$PAPERLESS_TOKEN" ]; then
    local stats
    stats=$(api GET "/documents/?page_size=1" 2>/dev/null)
    if [ -n "$stats" ]; then
      local doc_count
      doc_count=$(echo "$stats" | jq -r '.count // 0')
      ok "Documents: $doc_count"
    fi

    local tags
    tags=$(api GET "/tags/?page_size=1" 2>/dev/null)
    if [ -n "$tags" ]; then
      ok "Tags: $(echo "$tags" | jq -r '.count // 0')"
    fi

    local correspondents
    correspondents=$(api GET "/correspondents/?page_size=1" 2>/dev/null)
    if [ -n "$correspondents" ]; then
      ok "Correspondents: $(echo "$correspondents" | jq -r '.count // 0')"
    fi
  fi
}

cmd_token() {
  local user="" pass=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --user) user="$2"; shift 2 ;;
      --pass) pass="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$user" ] || [ -z "$pass" ]; then
    err "Usage: $0 token --user USERNAME --pass PASSWORD"
    exit 1
  fi

  local token
  token=$(curl -sf -X POST "${PAPERLESS_URL}/api/token/" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$user\",\"password\":\"$pass\"}" | jq -r '.token')

  if [ -n "$token" ] && [ "$token" != "null" ]; then
    ok "API Token: $token"
    echo ""
    echo "Add to your environment:"
    echo "  export PAPERLESS_TOKEN=\"$token\""
    echo ""
    echo "Or add to ${DATA_DIR}/.env:"
    echo "  PAPERLESS_TOKEN=$token"

    # Auto-save to .env
    if grep -q "^PAPERLESS_TOKEN=" "$ENV_FILE" 2>/dev/null; then
      sed -i "s|^PAPERLESS_TOKEN=.*|PAPERLESS_TOKEN=$token|" "$ENV_FILE"
    else
      echo "PAPERLESS_TOKEN=$token" >> "$ENV_FILE"
    fi
    ok "Token saved to $ENV_FILE"
  else
    err "Failed to get token. Check credentials."
    exit 1
  fi
}

cmd_search() {
  ensure_token
  local query="$*"
  if [ -z "$query" ]; then err "Usage: $0 search QUERY"; exit 1; fi

  local results
  results=$(api GET "/documents/?query=$(printf '%s' "$query" | jq -sRr @uri)&page_size=10")

  local count
  count=$(echo "$results" | jq -r '.count // 0')
  log "Found $count documents matching '$query':"
  echo ""
  echo "$results" | jq -r '.results[] | "  [\(.id)] \(.title) (\(.created | split("T")[0])) — \(.correspondent_name // "no correspondent") | tags: \((.tags // []) | join(", "))"' 2>/dev/null || echo "$results" | jq -r '.results[] | "  [\(.id)] \(.title)"'
}

cmd_list() {
  ensure_token
  local limit=20 ordering="-created"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --limit) limit="$2"; shift 2 ;;
      --ordering) ordering="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local results
  results=$(api GET "/documents/?page_size=${limit}&ordering=${ordering}")

  local count
  count=$(echo "$results" | jq -r '.count // 0')
  log "Showing ${limit} of $count documents:"
  echo ""
  echo "$results" | jq -r '.results[] | "  [\(.id)] \(.title) (\(.created | split("T")[0]))"'
}

cmd_get() {
  ensure_token
  local id=""
  while [[ $# -gt 0 ]]; do
    case $1 in --id) id="$2"; shift 2 ;; *) shift ;; esac
  done
  if [ -z "$id" ]; then err "Usage: $0 get --id ID"; exit 1; fi

  api GET "/documents/${id}/" | jq .
}

cmd_download() {
  ensure_token
  local id="" output="."
  while [[ $# -gt 0 ]]; do
    case $1 in
      --id) id="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [ -z "$id" ]; then err "Usage: $0 download --id ID [--output DIR]"; exit 1; fi

  local meta
  meta=$(api GET "/documents/${id}/")
  local filename
  filename=$(echo "$meta" | jq -r '.original_file_name // .title')

  curl -sf -H "Authorization: Token $PAPERLESS_TOKEN" \
    "${PAPERLESS_URL}/api/documents/${id}/download/" \
    -o "${output}/${filename}"
  ok "Downloaded: ${output}/${filename}"
}

cmd_consume() {
  local file="$1"
  if [ ! -f "$file" ]; then err "File not found: $file"; exit 1; fi

  local consume_dir="${DATA_DIR}/consume"
  cp "$file" "$consume_dir/"
  ok "Copied $(basename "$file") to consume directory. Processing will start within 30s."
}

cmd_import() {
  local dir="$1"
  if [ ! -d "$dir" ]; then err "Directory not found: $dir"; exit 1; fi

  local count=0
  local consume_dir="${DATA_DIR}/consume"
  while IFS= read -r -d '' f; do
    cp "$f" "$consume_dir/"
    ((count++))
  done < <(find "$dir" -maxdepth 1 -type f \( -iname '*.pdf' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.tiff' -o -iname '*.tif' -o -iname '*.txt' -o -iname '*.csv' -o -iname '*.docx' -o -iname '*.odt' \) -print0)
  ok "Imported $count files to consume directory."
}

cmd_tag() {
  ensure_token
  local id="" tags=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --id) id="$2"; shift 2 ;;
      --tags) tags="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [ -z "$id" ] || [ -z "$tags" ]; then
    err "Usage: $0 tag --id ID --tags tag1,tag2"
    exit 1
  fi

  # Resolve tag names to IDs, creating if needed
  local tag_ids=()
  IFS=',' read -ra TAG_NAMES <<< "$tags"
  for tag_name in "${TAG_NAMES[@]}"; do
    tag_name=$(echo "$tag_name" | xargs)  # trim
    local existing
    existing=$(api GET "/tags/?name__iexact=$(printf '%s' "$tag_name" | jq -sRr @uri)")
    local tag_id
    tag_id=$(echo "$existing" | jq -r '.results[0].id // empty')
    if [ -z "$tag_id" ]; then
      # Create tag
      local created
      created=$(api POST "/tags/" -d "{\"name\":\"$tag_name\"}")
      tag_id=$(echo "$created" | jq -r '.id')
      log "Created tag: $tag_name (#$tag_id)"
    fi
    tag_ids+=("$tag_id")
  done

  # Update document
  local tag_json
  tag_json=$(printf '%s\n' "${tag_ids[@]}" | jq -s '.')
  api PATCH "/documents/${id}/" -d "{\"tags\":$tag_json}" > /dev/null
  ok "Tagged document #$id with: $tags"
}

cmd_health() {
  local issues=0

  # Web server
  if curl -sf "${PAPERLESS_URL}/api/" &>/dev/null; then
    ok "Web server: healthy"
  else
    err "Web server: down"
    ((issues++))
  fi

  # Containers
  for svc in broker db webserver; do
    local state
    state=$(compose_cmd ps "$svc" --format '{{.State}}' 2>/dev/null || echo "unknown")
    if [[ "$state" == "running" ]]; then
      ok "$svc: healthy"
    else
      err "$svc: $state"
      ((issues++))
    fi
  done

  # Disk
  local usage
  usage=$(du -sh "$DATA_DIR" 2>/dev/null | awk '{print $1}')
  ok "Data directory: $usage"

  if [ $issues -eq 0 ]; then
    ok "All systems healthy!"
  else
    err "$issues issue(s) detected"
  fi
}

cmd_queue() {
  ensure_token
  local tasks
  tasks=$(api GET "/tasks/" 2>/dev/null || echo "[]")
  if [ "$tasks" = "[]" ] || [ -z "$tasks" ]; then
    ok "Processing queue empty"
  else
    echo "$tasks" | jq -r '.[] | "  [\(.status)] \(.task_file_name // .task_id) — \(.type)"' 2>/dev/null || echo "$tasks"
  fi
}

cmd_logs() {
  local lines=50
  while [[ $# -gt 0 ]]; do
    case $1 in --lines) lines="$2"; shift 2 ;; *) shift ;; esac
  done
  compose_cmd logs --tail "$lines" webserver
}

cmd_update() {
  log "Updating Paperless-ngx..."
  compose_cmd pull
  compose_cmd up -d
  ok "Updated to latest version"
}

cmd_restart() {
  compose_cmd restart
  ok "Containers restarted"
}

cmd_reindex() {
  log "Rebuilding search index..."
  compose_cmd exec -T webserver document_index reindex
  ok "Search index rebuilt"
}

cmd_backup() {
  local output=""
  while [[ $# -gt 0 ]]; do
    case $1 in --output) output="$2"; shift 2 ;; *) shift ;; esac
  done

  if [ -z "$output" ]; then
    output="${DATA_DIR}/backups/paperless-$(date +%Y%m%d-%H%M%S).tar.gz"
  fi

  mkdir -p "$(dirname "$output")"

  log "Creating backup..."

  # Export documents via Paperless exporter
  compose_cmd exec -T webserver document_exporter ../export/ --no-progress-bar 2>/dev/null || true

  # Dump PostgreSQL
  compose_cmd exec -T db pg_dump -U paperless paperless > "${DATA_DIR}/db-dump.sql"

  # Create archive
  tar -czf "$output" \
    -C "$DATA_DIR" \
    data/ media/ export/ db-dump.sql docker-compose.yml .env \
    2>/dev/null

  rm -f "${DATA_DIR}/db-dump.sql"

  local size
  size=$(du -h "$output" | awk '{print $1}')
  ok "Backup created: $output ($size)"
}

cmd_backup_cron() {
  local schedule="0 2 * * *" output="${DATA_DIR}/backups/" keep=7
  while [[ $# -gt 0 ]]; do
    case $1 in
      --schedule) schedule="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --keep) keep="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local cron_cmd="$schedule cd $(dirname "$SCRIPT_DIR") && bash scripts/run.sh backup --output ${output}/paperless-\$(date +\\%Y\\%m\\%d).tar.gz && find ${output} -name 'paperless-*.tar.gz' -mtime +${keep} -delete"

  (crontab -l 2>/dev/null | grep -v 'paperless.*backup'; echo "$cron_cmd") | crontab -
  ok "Backup cron installed: $schedule (keep last $keep backups)"
}

cmd_restore() {
  local input=""
  while [[ $# -gt 0 ]]; do
    case $1 in --input) input="$2"; shift 2 ;; *) shift ;; esac
  done

  if [ -z "$input" ] || [ ! -f "$input" ]; then
    err "Usage: $0 restore --input /path/to/backup.tar.gz"
    exit 1
  fi

  log "⚠️  This will overwrite existing data. Ctrl+C to abort (5s)..."
  sleep 5

  compose_cmd down

  log "Extracting backup..."
  tar -xzf "$input" -C "$DATA_DIR"

  # Restore database
  if [ -f "${DATA_DIR}/db-dump.sql" ]; then
    compose_cmd up -d db
    sleep 5
    compose_cmd exec -T db psql -U paperless paperless < "${DATA_DIR}/db-dump.sql"
    rm -f "${DATA_DIR}/db-dump.sql"
  fi

  compose_cmd up -d
  ok "Restore complete. Paperless-ngx starting..."
}

cmd_disk_usage() {
  echo "Paperless-ngx disk usage:"
  du -sh "$DATA_DIR"/data/ 2>/dev/null | awk '{print "  Data:    " $1}'
  du -sh "$DATA_DIR"/media/ 2>/dev/null | awk '{print "  Media:   " $1}'
  du -sh "$DATA_DIR"/pgdata/ 2>/dev/null | awk '{print "  Database:" $1}'
  du -sh "$DATA_DIR"/redisdata/ 2>/dev/null | awk '{print "  Redis:   " $1}'
  echo "  ─────────────"
  du -sh "$DATA_DIR" 2>/dev/null | awk '{print "  Total:   " $1}'
}

# Main router
case "${1:-}" in
  status) shift; cmd_status "$@" ;;
  token) shift; cmd_token "$@" ;;
  search) shift; cmd_search "$@" ;;
  list) shift; cmd_list "$@" ;;
  get) shift; cmd_get "$@" ;;
  download) shift; cmd_download "$@" ;;
  consume) shift; cmd_consume "$@" ;;
  import) shift; cmd_import "$@" ;;
  tag) shift; cmd_tag "$@" ;;
  health) shift; cmd_health "$@" ;;
  queue) shift; cmd_queue "$@" ;;
  logs) shift; cmd_logs "$@" ;;
  update) shift; cmd_update "$@" ;;
  restart) shift; cmd_restart "$@" ;;
  reindex) shift; cmd_reindex "$@" ;;
  backup) shift; cmd_backup "$@" ;;
  backup-cron) shift; cmd_backup_cron "$@" ;;
  restore) shift; cmd_restore "$@" ;;
  disk-usage) shift; cmd_disk_usage "$@" ;;
  *) usage ;;
esac
