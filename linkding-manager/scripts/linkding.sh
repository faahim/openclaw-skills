#!/bin/bash
# Linkding Bookmark Manager — CLI wrapper
set -euo pipefail

LINKDING_URL="${LINKDING_URL:-http://localhost:9090}"
LINKDING_TOKEN="${LINKDING_TOKEN:-}"
LINKDING_DATA="${LINKDING_DATA:-$HOME/.linkding}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
  cat <<EOF
Linkding Bookmark Manager

Usage: linkding.sh <command> [options]

Commands:
  add <url>           Add a bookmark
  search <query>      Search bookmarks
  list                List bookmarks
  tags                List all tags
  delete <id>         Delete a bookmark
  export              Export bookmarks (Netscape HTML)
  import <file>       Import bookmarks from HTML file
  archive <id>        Archive a bookmark snapshot
  bulk-add <file>     Add bookmarks from file (one URL per line)
  status              Check Linkding container status
  start               Start Linkding container
  stop                Stop Linkding container
  restart             Restart Linkding container
  logs                View container logs
  update              Update Linkding to latest version
  backup              Backup the database
  restore <file>      Restore database from backup

Options:
  --tags <t1,t2>      Tags (comma-separated)
  --title <title>     Bookmark title
  --description <d>   Bookmark description
  --tag <tag>         Filter by tag (for list)
  --limit <n>         Limit results (default: 50)

Environment:
  LINKDING_URL        Linkding instance URL (default: http://localhost:9090)
  LINKDING_TOKEN      API token (required for API commands)
EOF
  exit 0
}

check_token() {
  if [ -z "$LINKDING_TOKEN" ]; then
    echo -e "${RED}❌ LINKDING_TOKEN not set.${NC}"
    echo "Get your token: Linkding UI → Settings → Integrations → REST API"
    echo "Then: export LINKDING_TOKEN=\"your-token\""
    exit 1
  fi
}

api() {
  local method="$1" endpoint="$2"
  shift 2
  curl -sf -X "$method" "${LINKDING_URL}/api${endpoint}" \
    -H "Authorization: Token $LINKDING_TOKEN" \
    -H "Content-Type: application/json" \
    "$@"
}

cmd_add() {
  check_token
  local url="" tags="" title="" description=""
  url="$1"; shift
  while [[ $# -gt 0 ]]; do
    case $1 in
      --tags) tags="$2"; shift 2 ;;
      --title) title="$2"; shift 2 ;;
      --description) description="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local tag_array="[]"
  if [ -n "$tags" ]; then
    tag_array=$(echo "$tags" | tr ',' '\n' | jq -R . | jq -s .)
  fi

  local payload
  payload=$(jq -n \
    --arg url "$url" \
    --arg title "$title" \
    --arg desc "$description" \
    --argjson tags "$tag_array" \
    '{url: $url, title: $title, description: $desc, tag_names: $tags}')

  local result
  result=$(api POST "/bookmarks/" -d "$payload")
  local id=$(echo "$result" | jq -r '.id')
  local saved_url=$(echo "$result" | jq -r '.url')
  local saved_title=$(echo "$result" | jq -r '.title // .url')
  echo -e "${GREEN}✅ Saved${NC} [#${id}] ${saved_title}"
  echo "   ${saved_url}"
}

cmd_search() {
  check_token
  local query="$1" limit="${2:-50}"
  local result
  result=$(api GET "/bookmarks/?q=$(jq -rn --arg q "$query" '$q|@uri')&limit=${limit}")
  local count=$(echo "$result" | jq -r '.count')
  echo -e "${CYAN}Found ${count} bookmark(s) matching \"${query}\":${NC}"
  echo ""
  echo "$result" | jq -r '.results[] | "  [\(.id)] \(.title // .url)\n       \(.url)\n       Tags: \(.tag_names | join(", "))\n"'
}

cmd_list() {
  check_token
  local tag="" limit="50"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --tag) tag="$2"; shift 2 ;;
      --limit) limit="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local endpoint="/bookmarks/?limit=${limit}"
  if [ -n "$tag" ]; then
    endpoint="/bookmarks/?q=%23${tag}&limit=${limit}"
  fi

  local result
  result=$(api GET "$endpoint")
  local count=$(echo "$result" | jq -r '.count')
  echo -e "${CYAN}Bookmarks (${count} total, showing up to ${limit}):${NC}"
  echo ""
  echo "$result" | jq -r '.results[] | "  [\(.id)] \(.title // .url)\n       \(.url)\n       Tags: \(.tag_names | join(", "))\n"'
}

cmd_tags() {
  check_token
  local result
  result=$(api GET "/tags/?limit=1000")
  echo -e "${CYAN}Tags:${NC}"
  echo "$result" | jq -r '.results[] | "  \(.name) (\(.count_bookmarks // 0) bookmarks)"'
}

cmd_delete() {
  check_token
  local id="$1"
  api DELETE "/bookmarks/${id}/" > /dev/null
  echo -e "${GREEN}✅ Deleted bookmark #${id}${NC}"
}

cmd_export() {
  check_token
  api GET "/bookmarks/export/" 2>/dev/null
}

cmd_import() {
  check_token
  local file="$1"
  if [ ! -f "$file" ]; then
    echo -e "${RED}❌ File not found: ${file}${NC}"
    exit 1
  fi
  curl -sf -X POST "${LINKDING_URL}/api/bookmarks/import/" \
    -H "Authorization: Token $LINKDING_TOKEN" \
    -F "import_file=@${file}"
  echo -e "${GREEN}✅ Import complete${NC}"
}

cmd_bulk_add() {
  check_token
  local file="$1"; shift
  local tags=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --tags) tags="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local count=0
  while IFS= read -r url; do
    url=$(echo "$url" | xargs)  # trim whitespace
    [ -z "$url" ] && continue
    [[ "$url" == \#* ]] && continue  # skip comments
    if [ -n "$tags" ]; then
      cmd_add "$url" --tags "$tags" 2>/dev/null && ((count++)) || echo -e "${RED}Failed: ${url}${NC}"
    else
      cmd_add "$url" 2>/dev/null && ((count++)) || echo -e "${RED}Failed: ${url}${NC}"
    fi
  done < "$file"
  echo -e "\n${GREEN}✅ Added ${count} bookmarks${NC}"
}

cmd_archive() {
  check_token
  local id="$1"
  api POST "/bookmarks/${id}/archive/" > /dev/null
  echo -e "${GREEN}✅ Archiving bookmark #${id}${NC}"
}

docker_cmd() {
  if docker compose version &>/dev/null 2>&1; then
    echo "docker compose"
  else
    echo "docker-compose"
  fi
}

cmd_status() {
  echo -e "${CYAN}Linkding Status:${NC}"
  if docker ps --filter "name=linkding" --format "{{.Status}}" | grep -q "Up"; then
    echo -e "  Container: ${GREEN}Running${NC}"
    echo "  URL: ${LINKDING_URL}"
    local uptime=$(docker ps --filter "name=linkding" --format "{{.Status}}")
    echo "  Uptime: ${uptime}"
    # DB size
    if [ -f "$LINKDING_DATA/data/db.sqlite3" ]; then
      local dbsize=$(du -h "$LINKDING_DATA/data/db.sqlite3" | cut -f1)
      echo "  Database: ${dbsize}"
    fi
  else
    echo -e "  Container: ${RED}Stopped${NC}"
  fi
}

cmd_start() {
  cd "$LINKDING_DATA"
  $(docker_cmd) up -d
  echo -e "${GREEN}✅ Linkding started${NC}"
}

cmd_stop() {
  cd "$LINKDING_DATA"
  $(docker_cmd) down
  echo -e "${YELLOW}⏹ Linkding stopped${NC}"
}

cmd_restart() {
  cd "$LINKDING_DATA"
  $(docker_cmd) restart
  echo -e "${GREEN}✅ Linkding restarted${NC}"
}

cmd_logs() {
  cd "$LINKDING_DATA"
  $(docker_cmd) logs --tail 100 -f
}

cmd_update() {
  cd "$LINKDING_DATA"
  echo "📦 Pulling latest Linkding image..."
  $(docker_cmd) pull
  $(docker_cmd) up -d
  echo -e "${GREEN}✅ Linkding updated to latest version${NC}"
}

cmd_backup() {
  local timestamp=$(date +%Y-%m-%d_%H%M%S)
  local backup_file="$LINKDING_DATA/backups/linkding-${timestamp}.db"
  mkdir -p "$LINKDING_DATA/backups"

  if [ -f "$LINKDING_DATA/data/db.sqlite3" ]; then
    cp "$LINKDING_DATA/data/db.sqlite3" "$backup_file"
    local size=$(du -h "$backup_file" | cut -f1)
    echo -e "${GREEN}✅ Backup created: ${backup_file} (${size})${NC}"
  else
    echo -e "${RED}❌ Database not found at ${LINKDING_DATA}/data/db.sqlite3${NC}"
    exit 1
  fi
}

cmd_restore() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo -e "${RED}❌ Backup file not found: ${file}${NC}"
    exit 1
  fi

  echo -e "${YELLOW}⚠ This will replace the current database. Continue? (y/N)${NC}"
  read -r confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Cancelled."
    exit 0
  fi

  cd "$LINKDING_DATA"
  $(docker_cmd) stop
  cp "$file" "$LINKDING_DATA/data/db.sqlite3"
  $(docker_cmd) up -d
  echo -e "${GREEN}✅ Database restored from ${file}${NC}"
}

# Main
[ $# -eq 0 ] && usage
COMMAND="$1"; shift

case "$COMMAND" in
  add)       cmd_add "$@" ;;
  search)    cmd_search "$@" ;;
  list)      cmd_list "$@" ;;
  tags)      cmd_tags ;;
  delete)    cmd_delete "$@" ;;
  export)    cmd_export ;;
  import)    cmd_import "$@" ;;
  archive)   cmd_archive "$@" ;;
  bulk-add)  cmd_bulk_add "$@" ;;
  status)    cmd_status ;;
  start)     cmd_start ;;
  stop)      cmd_stop ;;
  restart)   cmd_restart ;;
  logs)      cmd_logs ;;
  update)    cmd_update ;;
  backup)    cmd_backup ;;
  restore)   cmd_restore "$@" ;;
  help|--help|-h) usage ;;
  *)         echo "Unknown command: $COMMAND"; usage ;;
esac
