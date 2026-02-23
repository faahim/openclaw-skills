#!/usr/bin/env bash
# Git Repository Backup — Mirror all GitHub/GitLab repos locally
# Usage: bash run.sh --provider github --user <username> --dir <backup-dir>

set -uo pipefail

# ─── Defaults ───
PROVIDER=""
USER=""
ORG=""
BACKUP_DIR="${GIT_BACKUP_DIR:-$HOME/git-backups}"
INCLUDE_PRIVATE=false
INCLUDE_FORKS=false
INCLUDE_ARCHIVED=true
SYNC_ONLY=false
COMPRESS=false
COMPRESS_DAYS=90
REPORT=false
NOTIFY=""
INCLUDE_PATTERN=""
EXCLUDE_PATTERN=""
THREADS="${GIT_BACKUP_THREADS:-4}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"
GITLAB_URL="${GITLAB_URL:-https://gitlab.com}"

# ─── Parse Args ───
while [[ $# -gt 0 ]]; do
  case $1 in
    --provider)      PROVIDER="$2"; shift 2 ;;
    --user)          USER="$2"; shift 2 ;;
    --org)           ORG="$2"; shift 2 ;;
    --dir)           BACKUP_DIR="$2"; shift 2 ;;
    --include-private) INCLUDE_PRIVATE=true; shift ;;
    --include-forks) INCLUDE_FORKS=true; shift ;;
    --include-archived) INCLUDE_ARCHIVED=true; shift ;;
    --sync-only)     SYNC_ONLY=true; shift ;;
    --compress)      COMPRESS=true; shift ;;
    --older-than)    COMPRESS_DAYS="$2"; shift 2 ;;
    --report)        REPORT=true; shift ;;
    --notify)        NOTIFY="$2"; shift 2 ;;
    --include)       INCLUDE_PATTERN="$2"; shift 2 ;;
    --exclude)       EXCLUDE_PATTERN="$2"; shift 2 ;;
    --threads)       THREADS="$2"; shift 2 ;;
    --config)        CONFIG="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Helpers ───
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
err() { log "❌ $*" >&2; }

notify_telegram() {
  local msg="$1"
  local bot="${TELEGRAM_BOT_TOKEN:-}"
  local chat="${TELEGRAM_CHAT_ID:-}"
  [[ -z "$bot" || -z "$chat" ]] && return 0
  curl -s -X POST "https://api.telegram.org/bot${bot}/sendMessage" \
    -d chat_id="$chat" -d text="$msg" -d parse_mode=Markdown >/dev/null 2>&1 || true
}

notify() {
  local msg="$1"
  case "$NOTIFY" in
    telegram) notify_telegram "$msg" ;;
    *) ;;
  esac
}

matches_pattern() {
  local name="$1" pattern="$2"
  [[ -z "$pattern" ]] && return 1
  IFS=',' read -ra PATS <<< "$pattern"
  for p in "${PATS[@]}"; do
    p=$(echo "$p" | xargs)  # trim
    # Use extglob-safe eval for wildcard matching
    if [[ "$name" == $p ]]; then
      return 0
    fi
  done
  return 1
}

should_include() {
  local name="$1"
  if [[ -n "$INCLUDE_PATTERN" ]]; then
    matches_pattern "$name" "$INCLUDE_PATTERN" && return 0 || return 1
  fi
  if [[ -n "$EXCLUDE_PATTERN" ]]; then
    matches_pattern "$name" "$EXCLUDE_PATTERN" && return 1 || return 0
  fi
  return 0
}

# ─── Report Mode ───
if $REPORT; then
  if [[ ! -d "$BACKUP_DIR" ]]; then
    err "Backup directory not found: $BACKUP_DIR"
    exit 1
  fi
  TOTAL=$(find "$BACKUP_DIR" -maxdepth 3 -name "*.git" -type d 2>/dev/null | wc -l)
  COMPRESSED=$(find "$BACKUP_DIR" -maxdepth 3 -name "*.git.tar.gz" -type f 2>/dev/null | wc -l)
  SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
  MANIFEST="$BACKUP_DIR/manifest.json"
  LAST_SYNC="never"
  [[ -f "$MANIFEST" ]] && LAST_SYNC=$(jq -r '.last_sync // "never"' "$MANIFEST" 2>/dev/null || echo "never")

  echo "📊 Git Backup Report"
  echo "Total repos: $TOTAL"
  echo "Compressed archives: $COMPRESSED"
  echo "Total size: $SIZE"
  echo "Last sync: $LAST_SYNC"
  echo "Location: $BACKUP_DIR"

  # List providers
  for provider_dir in "$BACKUP_DIR"/*/; do
    [[ -d "$provider_dir" ]] || continue
    pname=$(basename "$provider_dir")
    count=$(find "$provider_dir" -maxdepth 2 -name "*.git" -type d 2>/dev/null | wc -l)
    echo "  $pname: $count repos"
  done
  exit 0
fi

# ─── Compress Mode ───
if $COMPRESS; then
  log "🗜️ Compressing repos not updated in ${COMPRESS_DAYS}+ days..."
  COMPRESSED=0
  while IFS= read -r repo_dir; do
    [[ -d "$repo_dir" ]] || continue
    # Check last fetch time
    fetch_head="$repo_dir/FETCH_HEAD"
    if [[ -f "$fetch_head" ]]; then
      last_mod=$(stat -c %Y "$fetch_head" 2>/dev/null || stat -f %m "$fetch_head" 2>/dev/null || echo 0)
      now=$(date +%s)
      age_days=$(( (now - last_mod) / 86400 ))
      if [[ $age_days -ge $COMPRESS_DAYS ]]; then
        archive="${repo_dir}.tar.gz"
        if [[ ! -f "$archive" ]]; then
          log "🗜️ Compressing $(basename "$repo_dir") (${age_days}d old)..."
          tar -czf "$archive" -C "$(dirname "$repo_dir")" "$(basename "$repo_dir")" && rm -rf "$repo_dir"
          ((COMPRESSED++))
        fi
      fi
    fi
  done < <(find "$BACKUP_DIR" -maxdepth 3 -name "*.git" -type d 2>/dev/null)
  log "✅ Compressed $COMPRESSED repos"
  exit 0
fi

# ─── Validate ───
if [[ -z "$PROVIDER" ]]; then
  err "Provider required: --provider github|gitlab"
  exit 1
fi
if [[ -z "$USER" && -z "$ORG" ]]; then
  err "User or org required: --user <name> or --org <name>"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

# ─── Fetch Repo List ───
fetch_github_repos() {
  local target="$1" target_type="$2"
  local endpoint page=1 repos="[]"

  if [[ "$target_type" == "org" ]]; then
    endpoint="https://api.github.com/orgs/${target}/repos"
  else
    endpoint="https://api.github.com/users/${target}/repos"
  fi

  local auth_header=""
  if [[ -n "$GITHUB_TOKEN" ]]; then
    auth_header="Authorization: token $GITHUB_TOKEN"
  elif command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    GITHUB_TOKEN=$(gh auth token 2>/dev/null || true)
    [[ -n "$GITHUB_TOKEN" ]] && auth_header="Authorization: token $GITHUB_TOKEN"
  fi

  while true; do
    local url="${endpoint}?per_page=100&page=${page}&type=all"
    local response
    if [[ -n "$auth_header" ]]; then
      response=$(curl -sfL -H "$auth_header" "$url" 2>/dev/null) || break
    else
      response=$(curl -sfL "$url" 2>/dev/null) || break
    fi

    local count
    count=$(echo "$response" | jq 'length' 2>/dev/null || echo 0)
    [[ "$count" -eq 0 ]] && break

    repos=$(echo "$repos $response" | jq -s 'add')
    ((page++))
  done

  # Filter
  echo "$repos" | jq -c --argjson forks "$INCLUDE_FORKS" --argjson archived "$INCLUDE_ARCHIVED" --argjson private "$INCLUDE_PRIVATE" '
    [.[] | select(
      ($forks or .fork == false) and
      ($archived or .archived == false) and
      ($private or .private == false)
    ) | {name: .name, full_name: .full_name, clone_url: .clone_url, ssh_url: .ssh_url, private: .private, size: .size}]'
}

fetch_gitlab_repos() {
  local user="$1"
  local page=1 repos="[]"

  while true; do
    local url="${GITLAB_URL}/api/v4/users/${user}/projects?per_page=100&page=${page}"
    local response
    response=$(curl -sfL -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$url" 2>/dev/null) || break

    local count
    count=$(echo "$response" | jq 'length' 2>/dev/null || echo 0)
    [[ "$count" -eq 0 ]] && break

    repos=$(echo "$repos $response" | jq -s 'add')
    ((page++))
  done

  echo "$repos" | jq -c '[.[] | {name: .path, full_name: .path_with_namespace, clone_url: .http_url_to_repo, private: (.visibility != "public"), size: 0}]'
}

# ─── Main ───
TARGET="${USER:-$ORG}"
TARGET_TYPE="user"
[[ -n "$ORG" ]] && TARGET_TYPE="org"

log "📋 Fetching repository list for $TARGET_TYPE: $TARGET ($PROVIDER)..."

case "$PROVIDER" in
  github) REPOS=$(fetch_github_repos "$TARGET" "$TARGET_TYPE") ;;
  gitlab) REPOS=$(fetch_gitlab_repos "$TARGET") ;;
  *) err "Unknown provider: $PROVIDER"; exit 1 ;;
esac

TOTAL=$(echo "$REPOS" | jq 'length')
log "📋 Found $TOTAL repositories for $TARGET_TYPE $TARGET"

PROVIDER_DIR="$BACKUP_DIR/$PROVIDER/$TARGET"
mkdir -p "$PROVIDER_DIR"

CLONED=0
SYNCED=0
FAILED=0
NEW=0
FAILED_NAMES=()

clone_or_sync() {
  local name="$1" clone_url="$2"
  local repo_path="$PROVIDER_DIR/${name}.git"

  # Check include/exclude
  if ! should_include "$name"; then
    return 0
  fi

  if [[ -d "$repo_path" ]]; then
    # Sync existing mirror
    log "🔄 Fetching $name..."
    if git -C "$repo_path" fetch --all --prune --quiet 2>/dev/null; then
      ((SYNCED++))
      log "✅ $name — synced"
    else
      ((FAILED++))
      FAILED_NAMES+=("$name")
      err "$name — fetch failed"
    fi
  else
    if $SYNC_ONLY; then
      log "🆕 $name — new repo detected (skipping in sync-only mode)"
      return 0
    fi
    # Clone new mirror
    log "🔄 Cloning $name (mirror)..."
    local auth_url="$clone_url"
    # Inject token for private repos
    if [[ -n "$GITHUB_TOKEN" && "$PROVIDER" == "github" ]]; then
      auth_url=$(echo "$clone_url" | sed "s|https://|https://${GITHUB_TOKEN}@|")
    elif [[ -n "$GITLAB_TOKEN" && "$PROVIDER" == "gitlab" ]]; then
      auth_url=$(echo "$clone_url" | sed "s|https://|https://oauth2:${GITLAB_TOKEN}@|")
    fi

    if git clone --mirror "$auth_url" "$repo_path" 2>/dev/null; then
      ((CLONED++))
      ((NEW++))
      local size
      size=$(du -sh "$repo_path" 2>/dev/null | cut -f1)
      log "✅ $name — cloned ($size)"
    else
      ((FAILED++))
      FAILED_NAMES+=("$name")
      err "$name — clone failed"
    fi
  fi
}

# Process repos
# Note: runs sequentially to track counters properly. For large repos, 
# parallelism can be added with GNU parallel or xargs -P.
for i in $(seq 0 $((TOTAL - 1))); do
  name=$(echo "$REPOS" | jq -r ".[$i].name")
  clone_url=$(echo "$REPOS" | jq -r ".[$i].clone_url")
  clone_or_sync "$name" "$clone_url"
done

# ─── Update Manifest ───
MANIFEST="$BACKUP_DIR/manifest.json"
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
TOTAL_REPOS=$(find "$BACKUP_DIR" -maxdepth 3 -name "*.git" -type d 2>/dev/null | wc -l)

cat > "$MANIFEST" <<EOF
{
  "last_sync": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "provider": "$PROVIDER",
  "target": "$TARGET",
  "total_repos": $TOTAL_REPOS,
  "total_size": "$TOTAL_SIZE",
  "last_run": {
    "cloned": $CLONED,
    "synced": $SYNCED,
    "new": $NEW,
    "failed": $FAILED,
    "failed_repos": $(printf '%s\n' "${FAILED_NAMES[@]:-}" | jq -R -s 'split("\n") | map(select(. != ""))')
  }
}
EOF

# ─── Summary ───
log "✅ Backup complete: $((CLONED + SYNCED))/$TOTAL repos, $TOTAL_SIZE total"
[[ $NEW -gt 0 ]] && log "🆕 $NEW new repos cloned"
[[ $FAILED -gt 0 ]] && log "⚠️ $FAILED repos failed: ${FAILED_NAMES[*]}"

# ─── Notify ───
if [[ -n "$NOTIFY" ]]; then
  if [[ $FAILED -gt 0 ]]; then
    notify "🚨 Git Backup: ${FAILED} repos failed to sync: ${FAILED_NAMES[*]}"
  else
    MSG="📦 Git Backup: $((CLONED + SYNCED))/$TOTAL repos synced ($TOTAL_SIZE)."
    [[ $NEW -gt 0 ]] && MSG="$MSG $NEW new repos detected."
    notify "$MSG"
  fi
fi
