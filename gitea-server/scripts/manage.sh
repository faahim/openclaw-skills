#!/bin/bash
# Gitea Server Manager — manage repos, users, webhooks, updates
set -euo pipefail

GITEA_URL="${GITEA_URL:-http://localhost:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[GITEA]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }

# API helper
api() {
  local method="$1" endpoint="$2"
  shift 2
  local auth_header=""
  [[ -n "$GITEA_TOKEN" ]] && auth_header="-H Authorization:\ token\ $GITEA_TOKEN"

  if [[ "$method" == "GET" ]]; then
    curl -sL -H "Content-Type: application/json" \
      ${GITEA_TOKEN:+-H "Authorization: token $GITEA_TOKEN"} \
      "${GITEA_URL}/api/v1${endpoint}" "$@"
  else
    curl -sL -X "$method" -H "Content-Type: application/json" \
      ${GITEA_TOKEN:+-H "Authorization: token $GITEA_TOKEN"} \
      "${GITEA_URL}/api/v1${endpoint}" "$@"
  fi
}

# Commands
cmd_status() {
  log "Checking Gitea status..."

  # Systemd status
  if systemctl is-active --quiet gitea 2>/dev/null; then
    log "Service: ✅ Running"
  else
    log "Service: ❌ Not running"
  fi

  # Version
  local version
  version=$(gitea --version 2>/dev/null || echo "not installed")
  log "Version: $version"

  # API check
  local api_status
  api_status=$(curl -sL -o /dev/null -w "%{http_code}" "${GITEA_URL}/api/v1/version" 2>/dev/null || echo "000")
  if [[ "$api_status" == "200" ]]; then
    local api_ver
    api_ver=$(curl -sL "${GITEA_URL}/api/v1/version" | grep -oP '"version":\s*"\K[^"]+')
    log "API: ✅ Responding (v${api_ver})"
  else
    log "API: ❌ Not responding (HTTP $api_status)"
  fi

  # Stats (if authenticated)
  if [[ -n "$GITEA_TOKEN" ]]; then
    local repos users
    repos=$(api GET "/repos/search?limit=1" | grep -oP '"ok":\s*true' && api GET "/repos/search?limit=1" | grep -oP '"data":\s*\[' | wc -l || echo "?")
    info "URL: $GITEA_URL"
  fi
}

cmd_version() {
  gitea --version 2>/dev/null || echo "Gitea not installed"
}

cmd_create_admin() {
  local username="" password="" email=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --username) username="$2"; shift 2 ;;
      --password) password="$2"; shift 2 ;;
      --email) email="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$username" || -z "$password" || -z "$email" ]]; then
    error "Usage: manage.sh create-admin --username <user> --password <pass> --email <email>"
    exit 1
  fi

  log "Creating admin user '$username'..."
  sudo -u git gitea admin user create \
    --config /etc/gitea/app.ini \
    --username "$username" \
    --password "$password" \
    --email "$email" \
    --admin \
    --must-change-password=false

  log "✅ Admin user '$username' created"
  log "Generate an API token at ${GITEA_URL}/user/settings/applications"
}

cmd_create_user() {
  local username="" password="" email=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --username) username="$2"; shift 2 ;;
      --password) password="$2"; shift 2 ;;
      --email) email="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$username" || -z "$password" || -z "$email" ]]; then
    error "Usage: manage.sh create-user --username <user> --password <pass> --email <email>"
    exit 1
  fi

  log "Creating user '$username'..."
  api POST "/admin/users" -d "{
    \"username\": \"$username\",
    \"password\": \"$password\",
    \"email\": \"$email\",
    \"must_change_password\": false
  }" | grep -oP '"id":\s*\K\d+' && log "✅ User '$username' created" || error "Failed to create user"
}

cmd_list_users() {
  log "Users:"
  api GET "/admin/users?limit=50" | python3 -c "
import sys, json
users = json.load(sys.stdin)
for u in users:
    status = '🟢' if u.get('active', True) else '🔴'
    admin = ' [admin]' if u.get('is_admin') else ''
    print(f\"  {status} {u['login']}{admin} — {u.get('email', 'no email')}\")
" 2>/dev/null || error "Failed to list users. Set GITEA_TOKEN."
}

cmd_disable_user() {
  local username=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --username) username="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  api PATCH "/admin/users/$username" -d '{"active": false, "login_name": "'"$username"'"}' >/dev/null
  log "✅ User '$username' disabled"
}

cmd_create_repo() {
  local name="" description="" private="false"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --description) description="$2"; shift 2 ;;
      --private) private="true"; shift ;;
      *) shift ;;
    esac
  done

  if [[ -z "$name" ]]; then
    error "Usage: manage.sh create-repo --name <name> [--description <desc>] [--private]"
    exit 1
  fi

  log "Creating repository '$name'..."
  api POST "/user/repos" -d "{
    \"name\": \"$name\",
    \"description\": \"$description\",
    \"private\": $private,
    \"auto_init\": true,
    \"default_branch\": \"main\"
  }" | grep -oP '"clone_url":\s*"\K[^"]+' && log "✅ Repository '$name' created" || error "Failed"
}

cmd_list_repos() {
  log "Repositories:"
  api GET "/repos/search?limit=50&sort=updated&order=desc" | python3 -c "
import sys, json
data = json.load(sys.stdin)
repos = data.get('data', [])
for r in repos:
    vis = '🔒' if r.get('private') else '🌍'
    stars = r.get('stars_count', 0)
    print(f\"  {vis} {r['full_name']} — ⭐{stars} — {r.get('description', 'no description')}\")
print(f\"\nTotal: {len(repos)} repositories\")
" 2>/dev/null || error "Failed to list repos. Set GITEA_TOKEN."
}

cmd_delete_repo() {
  local owner="" name=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --owner) owner="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$owner" || -z "$name" ]]; then
    error "Usage: manage.sh delete-repo --owner <owner> --name <name>"
    exit 1
  fi

  warn "Deleting repository $owner/$name..."
  api DELETE "/repos/$owner/$name" >/dev/null
  log "✅ Repository $owner/$name deleted"
}

cmd_mirror_repo() {
  local source="" name=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --source) source="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$source" || -z "$name" ]]; then
    error "Usage: manage.sh mirror-repo --source <url> --name <name>"
    exit 1
  fi

  log "Mirroring $source as $name..."
  api POST "/repos/migrate" -d "{
    \"clone_addr\": \"$source\",
    \"repo_name\": \"$name\",
    \"mirror\": true,
    \"service\": \"git\"
  }" | grep -oP '"clone_url":\s*"\K[^"]+' && log "✅ Mirror '$name' created" || error "Failed"
}

cmd_mirror_org() {
  local github_org="" interval="8h"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --github-org) github_org="$2"; shift 2 ;;
      --interval) interval="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$github_org" ]]; then
    error "Usage: manage.sh mirror-org --github-org <org> [--interval 8h]"
    exit 1
  fi

  log "Fetching repos from github.com/$github_org..."
  local repos
  repos=$(curl -sL "https://api.github.com/orgs/$github_org/repos?per_page=100" | grep -oP '"clone_url":\s*"\K[^"]+')

  for repo_url in $repos; do
    local repo_name
    repo_name=$(basename "$repo_url" .git)
    log "Mirroring $repo_name..."
    api POST "/repos/migrate" -d "{
      \"clone_addr\": \"$repo_url\",
      \"repo_name\": \"$repo_name\",
      \"mirror\": true,
      \"mirror_interval\": \"$interval\",
      \"service\": \"github\"
    }" >/dev/null 2>&1 && log "  ✅ $repo_name" || warn "  ⚠️ $repo_name (may already exist)"
  done
}

cmd_add_webhook() {
  local repo="" url="" events="push"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --repo) repo="$2"; shift 2 ;;
      --url) url="$2"; shift 2 ;;
      --events) events="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  # Get authenticated user
  local owner
  owner=$(api GET "/user" | grep -oP '"login":\s*"\K[^"]+')

  local events_json
  events_json=$(echo "$events" | tr ',' '\n' | sed 's/.*/"&"/' | paste -sd,)

  api POST "/repos/$owner/$repo/hooks" -d "{
    \"type\": \"gitea\",
    \"active\": true,
    \"events\": [$events_json],
    \"config\": {
      \"url\": \"$url\",
      \"content_type\": \"json\"
    }
  }" | grep -oP '"id":\s*\K\d+' && log "✅ Webhook added to $repo" || error "Failed"
}

cmd_list_webhooks() {
  local repo=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --repo) repo="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local owner
  owner=$(api GET "/user" | grep -oP '"login":\s*"\K[^"]+')

  log "Webhooks for $repo:"
  api GET "/repos/$owner/$repo/hooks" | python3 -c "
import sys, json
hooks = json.load(sys.stdin)
for h in hooks:
    active = '🟢' if h.get('active') else '🔴'
    print(f\"  {active} [{h['id']}] {h['config']['url']} — events: {', '.join(h.get('events', []))}\")
" 2>/dev/null || error "Failed"
}

cmd_update() {
  local version="latest"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --version) version="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  log "Updating Gitea..."

  # Detect arch
  local arch
  case $(uname -m) in
    x86_64) arch="linux-amd64" ;;
    aarch64|arm64) arch="linux-arm64" ;;
    armv7l) arch="linux-armv6" ;;
  esac

  if [[ "$version" == "latest" ]]; then
    version=$(curl -sL https://api.github.com/repos/go-gitea/gitea/releases/latest | grep -oP '"tag_name":\s*"v?\K[^"]+' || echo "")
    if [[ -z "$version" ]]; then
      error "Could not fetch latest version"
      exit 1
    fi
  fi

  log "Downloading v${version}..."
  sudo systemctl stop gitea
  curl -sL -o /usr/local/bin/gitea "https://dl.gitea.com/gitea/${version}/gitea-${version}-${arch}"
  chmod +x /usr/local/bin/gitea
  sudo systemctl start gitea

  sleep 2
  if systemctl is-active --quiet gitea; then
    log "✅ Updated to $(gitea --version)"
  else
    error "Gitea failed to start after update. Check: sudo journalctl -u gitea -f"
  fi
}

cmd_nginx_config() {
  local domain="" ssl="false"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --domain) domain="$2"; shift 2 ;;
      --ssl) ssl="true"; shift ;;
      *) shift ;;
    esac
  done

  if [[ -z "$domain" ]]; then
    error "Usage: manage.sh nginx-config --domain git.example.com [--ssl]"
    exit 1
  fi

  local config_file="/etc/nginx/sites-available/gitea.conf"

  if [[ "$ssl" == "true" ]]; then
    cat > "$config_file" << EONGINX
server {
    listen 80;
    server_name ${domain};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${domain};

    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:${GITEA_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 100M;
    }
}
EONGINX
  else
    cat > "$config_file" << EONGINX
server {
    listen 80;
    server_name ${domain};

    location / {
        proxy_pass http://127.0.0.1:${GITEA_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 100M;
    }
}
EONGINX
  fi

  log "✅ Nginx config written to $config_file"
  log "Run: sudo ln -sf $config_file /etc/nginx/sites-enabled/ && sudo nginx -t && sudo systemctl reload nginx"
}

# Main dispatch
COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  status) cmd_status ;;
  version) cmd_version ;;
  create-admin) cmd_create_admin "$@" ;;
  create-user) cmd_create_user "$@" ;;
  list-users) cmd_list_users ;;
  disable-user) cmd_disable_user "$@" ;;
  create-repo) cmd_create_repo "$@" ;;
  list-repos) cmd_list_repos ;;
  delete-repo) cmd_delete_repo "$@" ;;
  mirror-repo) cmd_mirror_repo "$@" ;;
  mirror-org) cmd_mirror_org "$@" ;;
  add-webhook) cmd_add_webhook "$@" ;;
  list-webhooks) cmd_list_webhooks "$@" ;;
  update) cmd_update "$@" ;;
  nginx-config) cmd_nginx_config "$@" ;;
  help|*)
    echo "Gitea Server Manager"
    echo ""
    echo "Usage: manage.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status                         Check Gitea service status"
    echo "  version                        Show Gitea version"
    echo "  create-admin                   Create admin user (--username --password --email)"
    echo "  create-user                    Create regular user (--username --password --email)"
    echo "  list-users                     List all users"
    echo "  disable-user                   Disable a user (--username)"
    echo "  create-repo                    Create repository (--name [--description] [--private])"
    echo "  list-repos                     List all repositories"
    echo "  delete-repo                    Delete repository (--owner --name)"
    echo "  mirror-repo                    Mirror external repo (--source --name)"
    echo "  mirror-org                     Mirror all repos from GitHub org (--github-org)"
    echo "  add-webhook                    Add webhook (--repo --url [--events push,pr])"
    echo "  list-webhooks                  List webhooks (--repo)"
    echo "  update                         Update Gitea [--version X.Y.Z]"
    echo "  nginx-config                   Generate Nginx reverse proxy config (--domain [--ssl])"
    echo ""
    echo "Environment:"
    echo "  GITEA_URL    API base URL (default: http://localhost:3000)"
    echo "  GITEA_TOKEN  API token (generate in Settings > Applications)"
    ;;
esac
