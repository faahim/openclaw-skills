#!/bin/bash
# Private Docker Registry — Management Script
# Manage images, users, garbage collection, backups

set -euo pipefail

REGISTRY_DATA_DIR="${REGISTRY_DATA_DIR:-$HOME/.docker-registry}"

# Load saved config
if [[ -f "$REGISTRY_DATA_DIR/.env" ]]; then
  source "$REGISTRY_DATA_DIR/.env"
fi

REGISTRY_PORT="${REGISTRY_PORT:-5000}"
REGISTRY_DOMAIN="${REGISTRY_DOMAIN:-localhost}"
REGISTRY_USER="${REGISTRY_USER:-admin}"
REGISTRY_PASS="${REGISTRY_PASS:-}"
REGISTRY_CONTAINER_NAME="${REGISTRY_CONTAINER_NAME:-docker-registry}"
REGISTRY_URL="https://$REGISTRY_DOMAIN:$REGISTRY_PORT"

# ── Helper functions ─────────────────────────────────────────────────
api() {
  local path="$1"
  shift
  curl -sk -u "$REGISTRY_USER:$REGISTRY_PASS" "$@" "$REGISTRY_URL/v2/$path"
}

human_size() {
  local bytes=$1
  if (( bytes >= 1073741824 )); then
    echo "$(echo "scale=1; $bytes / 1073741824" | bc) GB"
  elif (( bytes >= 1048576 )); then
    echo "$(echo "scale=1; $bytes / 1048576" | bc) MB"
  elif (( bytes >= 1024 )); then
    echo "$(echo "scale=1; $bytes / 1024" | bc) KB"
  else
    echo "$bytes B"
  fi
}

# ── Commands ─────────────────────────────────────────────────────────

cmd_list() {
  echo "📦 Registry: $REGISTRY_URL"
  echo "─────────────────────────────────────────"
  
  local repos
  repos=$(api "_catalog" 2>/dev/null | python3 -c "import sys,json; [print(r) for r in json.load(sys.stdin).get('repositories',[])]" 2>/dev/null || echo "")
  
  if [[ -z "$repos" ]]; then
    echo "  (empty — no images pushed yet)"
    return
  fi

  printf "%-30s %-10s %s\n" "REPOSITORY" "TAGS" "SIZE"
  
  local total_size=0
  local total_tags=0
  local total_repos=0
  
  while IFS= read -r repo; do
    [[ -z "$repo" ]] && continue
    total_repos=$((total_repos + 1))
    
    local tags_json
    tags_json=$(api "$repo/tags/list" 2>/dev/null)
    local tag_count
    tag_count=$(echo "$tags_json" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('tags',[])))" 2>/dev/null || echo "0")
    total_tags=$((total_tags + tag_count))
    
    # Get size of latest tag
    local first_tag
    first_tag=$(echo "$tags_json" | python3 -c "import sys,json; tags=json.load(sys.stdin).get('tags',[]); print(tags[0] if tags else '')" 2>/dev/null || echo "")
    
    local size=0
    if [[ -n "$first_tag" ]]; then
      local manifest
      manifest=$(api "$repo/manifests/$first_tag" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" 2>/dev/null)
      size=$(echo "$manifest" | python3 -c "
import sys,json
m = json.load(sys.stdin)
total = m.get('config',{}).get('size',0)
for l in m.get('layers',[]): total += l.get('size',0)
print(total)
" 2>/dev/null || echo "0")
    fi
    total_size=$((total_size + size))
    
    printf "%-30s %-10s %s\n" "$repo" "$tag_count" "$(human_size "$size")"
  done <<< "$repos"
  
  echo "─────────────────────────────────────────"
  echo "Total: $total_repos repositories, $total_tags tags, $(human_size "$total_size")"
}

cmd_tags() {
  local repo="${1:-}"
  if [[ -z "$repo" ]]; then
    echo "Usage: manage.sh tags <repository>"
    exit 1
  fi
  
  echo "📦 Tags for $repo:"
  api "$repo/tags/list" 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
tags = data.get('tags', [])
if not tags:
    print('  (no tags)')
else:
    for t in sorted(tags):
        print(f'  • {t}')
print(f'\nTotal: {len(tags)} tags')
"
}

cmd_inspect() {
  local ref="${1:-}"
  if [[ -z "$ref" ]] || [[ "$ref" != *":"* ]]; then
    echo "Usage: manage.sh inspect <repository>:<tag>"
    exit 1
  fi
  
  local repo="${ref%%:*}"
  local tag="${ref##*:}"
  
  echo "🔍 Inspecting $repo:$tag"
  echo ""
  
  local manifest
  manifest=$(api "$repo/manifests/$tag" \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json" 2>/dev/null)
  
  # Get digest
  local digest
  digest=$(api "$repo/manifests/$tag" \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    -I 2>/dev/null | grep -i "docker-content-digest" | tr -d '\r' | awk '{print $2}')
  
  echo "$manifest" | python3 -c "
import sys, json
m = json.load(sys.stdin)
config = m.get('config', {})
layers = m.get('layers', [])
total = config.get('size', 0)
for l in layers:
    total += l.get('size', 0)

print(f'  Digest:     ${digest:-unknown}')
print(f'  Media Type: {m.get(\"mediaType\", \"unknown\")}')
print(f'  Layers:     {len(layers)}')
print(f'  Total Size: {total / 1048576:.1f} MB')
print()
print('  Layers:')
for i, l in enumerate(layers, 1):
    size_mb = l['size'] / 1048576
    print(f'    {i}. {l[\"digest\"][:19]}... ({size_mb:.1f} MB)')
"
}

cmd_delete() {
  local ref="${1:-}"
  if [[ -z "$ref" ]] || [[ "$ref" != *":"* ]]; then
    echo "Usage: manage.sh delete <repository>:<tag>"
    exit 1
  fi
  
  local repo="${ref%%:*}"
  local tag="${ref##*:}"
  
  # Get digest
  local digest
  digest=$(api "$repo/manifests/$tag" \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    -I 2>/dev/null | grep -i "docker-content-digest" | tr -d '\r' | awk '{print $2}')
  
  if [[ -z "$digest" ]]; then
    echo "❌ Could not find $repo:$tag"
    exit 1
  fi
  
  api "$repo/manifests/$digest" -X DELETE >/dev/null 2>&1
  echo "✅ Deleted $repo:$tag ($digest)"
  echo "   Run 'manage.sh gc' to reclaim disk space"
}

cmd_gc() {
  local dry_run=false
  local schedule=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dry-run) dry_run=true; shift ;;
      --schedule) schedule="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  if [[ -n "$schedule" ]]; then
    local cron_expr
    case "$schedule" in
      daily)   cron_expr="0 3 * * *" ;;
      weekly)  cron_expr="0 3 * * 0" ;;
      monthly) cron_expr="0 3 1 * *" ;;
      *) echo "❌ Unknown schedule: $schedule (use daily/weekly/monthly)"; exit 1 ;;
    esac
    
    # Add crontab entry
    local cron_cmd="docker exec $REGISTRY_CONTAINER_NAME bin/registry garbage-collect /etc/docker/registry/config.yml"
    (crontab -l 2>/dev/null | grep -v "registry garbage-collect"; echo "$cron_expr $cron_cmd") | crontab -
    echo "✅ Garbage collection scheduled: $schedule ($cron_expr)"
    return
  fi
  
  echo "🧹 Running garbage collection..."
  
  local gc_args="/etc/docker/registry/config.yml"
  if [[ "$dry_run" == "true" ]]; then
    gc_args="--dry-run $gc_args"
    echo "   (dry run — no changes will be made)"
  fi
  
  docker exec "$REGISTRY_CONTAINER_NAME" bin/registry garbage-collect $gc_args 2>&1
  
  if [[ "$dry_run" == "false" ]]; then
    echo ""
    echo "✅ Garbage collection complete"
    echo "   Restart registry to free memory: docker restart $REGISTRY_CONTAINER_NAME"
  fi
}

cmd_add_user() {
  local username="${1:-}"
  local password="${2:-}"
  
  if [[ -z "$username" || -z "$password" ]]; then
    echo "Usage: manage.sh add-user <username> <password>"
    exit 1
  fi
  
  if command -v htpasswd &>/dev/null; then
    htpasswd -Bb "$REGISTRY_DATA_DIR/auth/htpasswd" "$username" "$password"
  else
    docker run --rm --entrypoint htpasswd httpd:2 -Bbn "$username" "$password" \
      >> "$REGISTRY_DATA_DIR/auth/htpasswd"
  fi
  
  echo "✅ User '$username' added/updated"
}

cmd_list_users() {
  echo "👥 Registry Users:"
  if [[ -f "$REGISTRY_DATA_DIR/auth/htpasswd" ]]; then
    while IFS=: read -r user _; do
      echo "  • $user"
    done < "$REGISTRY_DATA_DIR/auth/htpasswd"
  else
    echo "  (no users configured)"
  fi
}

cmd_status() {
  local running="stopped"
  if docker ps -q -f name="$REGISTRY_CONTAINER_NAME" 2>/dev/null | grep -q .; then
    running="running"
  fi
  
  local status_icon="❌"
  [[ "$running" == "running" ]] && status_icon="✅"
  
  echo "$status_icon Registry: $running (container: $REGISTRY_CONTAINER_NAME)"
  
  if [[ "$running" == "running" ]]; then
    # Count repos and tags
    local catalog
    catalog=$(api "_catalog" 2>/dev/null || echo '{"repositories":[]}')
    local repo_count
    repo_count=$(echo "$catalog" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('repositories',[])))" 2>/dev/null || echo "0")
    echo "📦 Images: $repo_count repositories"
    
    # Storage size
    if [[ -d "$REGISTRY_DATA_DIR/data" ]]; then
      local size
      size=$(du -sh "$REGISTRY_DATA_DIR/data" 2>/dev/null | cut -f1)
      echo "💾 Storage: $size used (local)"
    fi
    
    # Auth
    local user_count=0
    if [[ -f "$REGISTRY_DATA_DIR/auth/htpasswd" ]]; then
      user_count=$(wc -l < "$REGISTRY_DATA_DIR/auth/htpasswd")
    fi
    echo "🔐 Auth: enabled ($user_count users)"
    
    # TLS
    if [[ -f "$REGISTRY_DATA_DIR/certs/server.crt" ]]; then
      local expiry
      expiry=$(openssl x509 -enddate -noout -in "$REGISTRY_DATA_DIR/certs/server.crt" 2>/dev/null | cut -d= -f2)
      local cert_type="provided"
      [[ -f "$REGISTRY_DATA_DIR/certs/ca.key" ]] && cert_type="self-signed"
      echo "🔒 TLS: $cert_type (expires $expiry)"
    fi
  fi
}

cmd_backup() {
  local output="${1:-registry-backup-$(date +%Y%m%d).tar.gz}"
  
  echo "📦 Backing up registry to $output..."
  
  # Stop registry briefly for consistent backup
  docker stop "$REGISTRY_CONTAINER_NAME" >/dev/null 2>&1
  tar -czf "$output" -C "$REGISTRY_DATA_DIR" .
  docker start "$REGISTRY_CONTAINER_NAME" >/dev/null 2>&1
  
  local size
  size=$(du -sh "$output" | cut -f1)
  echo "✅ Backup complete: $output ($size)"
}

cmd_restore() {
  local input="${1:-}"
  if [[ -z "$input" || ! -f "$input" ]]; then
    echo "Usage: manage.sh restore <backup-file.tar.gz>"
    exit 1
  fi
  
  echo "⚠️  This will replace all registry data. Continue? [y/N]"
  read -r confirm
  [[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0
  
  docker stop "$REGISTRY_CONTAINER_NAME" >/dev/null 2>&1 || true
  tar -xzf "$input" -C "$REGISTRY_DATA_DIR"
  docker start "$REGISTRY_CONTAINER_NAME" >/dev/null 2>&1
  
  echo "✅ Registry restored from $input"
}

cmd_disk_usage() {
  echo "💾 Registry Disk Usage:"
  echo ""
  if [[ -d "$REGISTRY_DATA_DIR" ]]; then
    du -sh "$REGISTRY_DATA_DIR"/{data,certs,auth,config} 2>/dev/null | while read -r size dir; do
      local name
      name=$(basename "$dir")
      echo "  $size  $name"
    done
    echo "  ─────────"
    du -sh "$REGISTRY_DATA_DIR" 2>/dev/null | while read -r size dir; do
      echo "  $size  total"
    done
  else
    echo "  Registry not initialized. Run setup.sh first."
  fi
}

# ── Main ─────────────────────────────────────────────────────────────
CMD="${1:-help}"
shift 2>/dev/null || true

case "$CMD" in
  list)        cmd_list ;;
  tags)        cmd_tags "$@" ;;
  inspect)     cmd_inspect "$@" ;;
  delete)      cmd_delete "$@" ;;
  gc)          cmd_gc "$@" ;;
  add-user)    cmd_add_user "$@" ;;
  list-users)  cmd_list_users ;;
  status)      cmd_status ;;
  backup)      cmd_backup "$@" ;;
  restore)     cmd_restore "$@" ;;
  disk-usage)  cmd_disk_usage ;;
  set-quota)
    echo "⚠️  Storage quotas require registry restart."
    echo "   Set REGISTRY_STORAGE_MAINTENANCE_READONLY in config."
    echo "   Monitor with: manage.sh disk-usage"
    ;;
  help|*)
    echo "Private Docker Registry Manager"
    echo ""
    echo "Usage: manage.sh <command> [args]"
    echo ""
    echo "Image Management:"
    echo "  list                    List all repositories and tags"
    echo "  tags <repo>             List tags for a repository"
    echo "  inspect <repo:tag>      Show image details"
    echo "  delete <repo:tag>       Delete a tag"
    echo ""
    echo "Maintenance:"
    echo "  gc [--dry-run]          Run garbage collection"
    echo "  gc --schedule <freq>    Schedule GC (daily/weekly/monthly)"
    echo "  disk-usage              Show storage usage"
    echo ""
    echo "Users:"
    echo "  add-user <user> <pass>  Add or update a user"
    echo "  list-users              List all users"
    echo ""
    echo "Backup:"
    echo "  backup [file.tar.gz]    Backup registry data"
    echo "  restore <file.tar.gz>   Restore from backup"
    echo ""
    echo "Status:"
    echo "  status                  Show registry health"
    ;;
esac
