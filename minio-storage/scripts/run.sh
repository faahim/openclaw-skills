#!/bin/bash
# MinIO Object Storage Manager — Main Script
# Usage: bash run.sh <command> [options]

set -euo pipefail

CREDS_FILE="${HOME}/.minio-creds"
PID_FILE="${HOME}/.minio.pid"
MC_ALIAS="${MC_ALIAS:-local}"
DEFAULT_PORT=9000
DEFAULT_CONSOLE_PORT=9001
DEFAULT_DATA_DIR="${MINIO_DATA_DIR:-/data/minio}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✅ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
err()  { echo -e "${RED}❌ $*${NC}" >&2; }

load_creds() {
  if [ -f "$CREDS_FILE" ]; then
    source "$CREDS_FILE"
  fi
}

save_creds() {
  cat > "$CREDS_FILE" <<EOF
export MINIO_ROOT_USER="$MINIO_ROOT_USER"
export MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD"
export MINIO_PORT="$MINIO_PORT"
export MINIO_CONSOLE_PORT="$MINIO_CONSOLE_PORT"
export MINIO_DATA_DIR="$MINIO_DATA_DIR"
EOF
  chmod 600 "$CREDS_FILE"
}

ensure_mc_alias() {
  load_creds
  local endpoint="http://localhost:${MINIO_PORT:-$DEFAULT_PORT}"
  mc alias set "$MC_ALIAS" "$endpoint" "${MINIO_ROOT_USER:-minioadmin}" "${MINIO_ROOT_PASSWORD:-minioadmin}" --api S3v4 &>/dev/null 2>&1 || true
}

# ─── COMMANDS ───

cmd_start() {
  local data_dir="$DEFAULT_DATA_DIR"
  local port=$DEFAULT_PORT
  local console_port=$DEFAULT_CONSOLE_PORT
  local root_user="${MINIO_ROOT_USER:-minioadmin}"
  local root_password="${MINIO_ROOT_PASSWORD:-}"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --data-dir)       data_dir="$2"; shift 2 ;;
      --port)           port="$2"; shift 2 ;;
      --console-port)   console_port="$2"; shift 2 ;;
      --root-user)      root_user="$2"; shift 2 ;;
      --root-password)  root_password="$2"; shift 2 ;;
      *) err "Unknown option: $1"; exit 1 ;;
    esac
  done

  # Generate password if not set
  if [ -z "$root_password" ]; then
    root_password=$(openssl rand -base64 24)
    echo "🔐 Generated root password (saved to $CREDS_FILE)"
  fi

  # Create data directory
  mkdir -p "$data_dir"

  # Export for MinIO
  export MINIO_ROOT_USER="$root_user"
  export MINIO_ROOT_PASSWORD="$root_password"
  export MINIO_PORT="$port"
  export MINIO_CONSOLE_PORT="$console_port"
  export MINIO_DATA_DIR="$data_dir"

  # Save credentials
  save_creds

  # Check if already running
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    warn "MinIO is already running (PID: $(cat "$PID_FILE"))"
    return 0
  fi

  # Start MinIO
  nohup minio server "$data_dir" \
    --address ":$port" \
    --console-address ":$console_port" \
    > "${HOME}/.minio.log" 2>&1 &

  echo $! > "$PID_FILE"
  sleep 2

  if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    ensure_mc_alias
    ok "MinIO server started"
    echo "   API:     http://localhost:$port"
    echo "   Console: http://localhost:$console_port"
    echo "   Root user: $root_user"
    echo "   Credentials saved to: $CREDS_FILE"
  else
    err "MinIO failed to start. Check ~/.minio.log"
    exit 1
  fi
}

cmd_stop() {
  if [ -f "$PID_FILE" ]; then
    local pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid"
      rm -f "$PID_FILE"
      ok "MinIO server stopped"
    else
      rm -f "$PID_FILE"
      warn "MinIO was not running (stale PID file removed)"
    fi
  else
    warn "No MinIO PID file found"
  fi
}

cmd_status() {
  load_creds
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    ok "MinIO is running (PID: $(cat "$PID_FILE"))"
    echo "   API:     http://localhost:${MINIO_PORT:-$DEFAULT_PORT}"
    echo "   Console: http://localhost:${MINIO_CONSOLE_PORT:-$DEFAULT_CONSOLE_PORT}"
    echo "   Data:    ${MINIO_DATA_DIR:-$DEFAULT_DATA_DIR}"
    ensure_mc_alias
    mc admin info "$MC_ALIAS" 2>/dev/null || true
  else
    warn "MinIO is not running"
  fi
}

cmd_create_bucket() {
  local bucket="${1:?Usage: run.sh create-bucket <name>}"
  ensure_mc_alias
  mc mb "${MC_ALIAS}/${bucket}" 2>/dev/null && ok "Bucket '$bucket' created" || err "Failed to create bucket '$bucket'"
}

cmd_delete_bucket() {
  local bucket="${1:?Usage: run.sh delete-bucket <name>}"
  ensure_mc_alias
  mc rb "${MC_ALIAS}/${bucket}" 2>/dev/null && ok "Bucket '$bucket' deleted" || err "Failed to delete bucket '$bucket'"
}

cmd_list_buckets() {
  ensure_mc_alias
  mc ls "$MC_ALIAS" 2>/dev/null
}

cmd_list() {
  local path="${1:?Usage: run.sh list <bucket>[/prefix]}"
  ensure_mc_alias
  mc ls "${MC_ALIAS}/${path}" 2>/dev/null
}

cmd_bucket_info() {
  local bucket="${1:?Usage: run.sh bucket-info <name>}"
  ensure_mc_alias
  mc stat "${MC_ALIAS}/${bucket}" 2>/dev/null
  echo ""
  echo "Disk usage:"
  mc du "${MC_ALIAS}/${bucket}" 2>/dev/null
}

cmd_upload() {
  local bucket="${1:?Usage: run.sh upload <bucket> <file/dir> [--recursive]}"
  local source="${2:?Usage: run.sh upload <bucket> <file/dir>}"
  shift 2
  local recursive=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --recursive|-r) recursive="--recursive"; shift ;;
      *) shift ;;
    esac
  done

  ensure_mc_alias
  mc cp $recursive "$source" "${MC_ALIAS}/${bucket}/" && ok "Uploaded to $bucket" || err "Upload failed"
}

cmd_download() {
  local source="${1:?Usage: run.sh download <bucket/file> <local-path>}"
  local dest="${2:?Usage: run.sh download <bucket/file> <local-path>}"
  ensure_mc_alias
  mc cp "${MC_ALIAS}/${source}" "$dest" && ok "Downloaded to $dest" || err "Download failed"
}

cmd_delete() {
  local path="${1:?Usage: run.sh delete <bucket/file>}"
  ensure_mc_alias
  mc rm "${MC_ALIAS}/${path}" && ok "Deleted $path" || err "Delete failed"
}

cmd_presign() {
  local path="${1:?Usage: run.sh presign <bucket/file> [--expires 7d]}"
  shift
  local expires="7d"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --expires) expires="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  ensure_mc_alias
  mc share download --expire "$expires" "${MC_ALIAS}/${path}" 2>/dev/null
}

cmd_set_policy() {
  local bucket="${1:?Usage: run.sh set-policy <bucket> <public-read|private|public-readwrite|--custom file.json>}"
  local policy="${2:?Usage: run.sh set-policy <bucket> <policy>}"
  ensure_mc_alias

  case "$policy" in
    public-read)      mc anonymous set download "${MC_ALIAS}/${bucket}" ;;
    public-readwrite) mc anonymous set public "${MC_ALIAS}/${bucket}" ;;
    private)          mc anonymous set none "${MC_ALIAS}/${bucket}" ;;
    --custom)         mc anonymous set-json "${3:?Provide policy JSON file}" "${MC_ALIAS}/${bucket}" ;;
    *) err "Unknown policy: $policy. Use: public-read, private, public-readwrite, --custom" ;;
  esac
}

cmd_create_user() {
  local user="${1:?Usage: run.sh create-user <username> <password>}"
  local pass="${2:?Usage: run.sh create-user <username> <password>}"
  ensure_mc_alias
  mc admin user add "$MC_ALIAS" "$user" "$pass" && ok "User '$user' created" || err "Failed to create user"
}

cmd_assign_policy() {
  local user="${1:?Usage: run.sh assign-policy <username> <policy>}"
  local policy="${2:?Usage: run.sh assign-policy <username> <readwrite|readonly|writeonly>}"
  ensure_mc_alias
  mc admin policy attach "$MC_ALIAS" "$policy" --user "$user" && ok "Policy '$policy' assigned to '$user'" || err "Failed to assign policy"
}

cmd_list_users() {
  ensure_mc_alias
  mc admin user list "$MC_ALIAS" 2>/dev/null
}

cmd_delete_user() {
  local user="${1:?Usage: run.sh delete-user <username>}"
  ensure_mc_alias
  mc admin user remove "$MC_ALIAS" "$user" && ok "User '$user' deleted" || err "Failed to delete user"
}

cmd_lifecycle() {
  local bucket="${1:?Usage: run.sh lifecycle <bucket> [--expire-days N] [--show] [--remove]}"
  shift
  local expire_days=""
  local show=false
  local remove=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --expire-days)  expire_days="$2"; shift 2 ;;
      --show)         show=true; shift ;;
      --remove)       remove=true; shift ;;
      *) shift ;;
    esac
  done

  ensure_mc_alias

  if $show; then
    mc ilm rule list "${MC_ALIAS}/${bucket}" 2>/dev/null
  elif $remove; then
    mc ilm rule remove "${MC_ALIAS}/${bucket}" --all && ok "Lifecycle rules removed" || err "Failed to remove rules"
  elif [ -n "$expire_days" ]; then
    mc ilm rule add "${MC_ALIAS}/${bucket}" --expire-days "$expire_days" && ok "Lifecycle: expire after ${expire_days} days" || err "Failed to set lifecycle"
  else
    err "Specify --expire-days N, --show, or --remove"
  fi
}

cmd_disk_usage() {
  ensure_mc_alias
  mc du "$MC_ALIAS" 2>/dev/null
}

cmd_info() {
  ensure_mc_alias
  mc admin info "$MC_ALIAS" 2>/dev/null
}

cmd_mirror() {
  local source="${1:?Usage: run.sh mirror <source> <target>}"
  local target="${2:?Usage: run.sh mirror <source> <target>}"
  ensure_mc_alias
  mc mirror "${MC_ALIAS}/${source}" "${MC_ALIAS}/${target}" 2>/dev/null && ok "Mirror complete" || err "Mirror failed"
}

cmd_export() {
  local output="${1:?Usage: run.sh export <output.tar.gz>}"
  load_creds
  local data_dir="${MINIO_DATA_DIR:-$DEFAULT_DATA_DIR}"
  tar -czf "$output" -C "$(dirname "$data_dir")" "$(basename "$data_dir")" && ok "Exported to $output" || err "Export failed"
}

cmd_import() {
  local input="${1:?Usage: run.sh import <backup.tar.gz>}"
  load_creds
  local data_dir="${MINIO_DATA_DIR:-$DEFAULT_DATA_DIR}"
  tar -xzf "$input" -C "$(dirname "$data_dir")" && ok "Imported from $input" || err "Import failed"
}

cmd_install_service() {
  load_creds
  local service_file="/etc/systemd/system/minio.service"

  cat > /tmp/minio.service <<EOF
[Unit]
Description=MinIO Object Storage
After=network.target

[Service]
User=$(whoami)
Group=$(id -gn)
Environment="MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}"
Environment="MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-minioadmin}"
ExecStart=$(which minio) server ${MINIO_DATA_DIR:-$DEFAULT_DATA_DIR} --address :${MINIO_PORT:-$DEFAULT_PORT} --console-address :${MINIO_CONSOLE_PORT:-$DEFAULT_CONSOLE_PORT}
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  sudo mv /tmp/minio.service "$service_file"
  sudo systemctl daemon-reload
  sudo systemctl enable minio
  sudo systemctl start minio
  ok "MinIO systemd service installed and started"
}

# ─── DISPATCH ───

CMD="${1:-help}"
shift || true

case "$CMD" in
  start)          cmd_start "$@" ;;
  stop)           cmd_stop "$@" ;;
  status)         cmd_status "$@" ;;
  create-bucket)  cmd_create_bucket "$@" ;;
  delete-bucket)  cmd_delete_bucket "$@" ;;
  list-buckets)   cmd_list_buckets "$@" ;;
  list)           cmd_list "$@" ;;
  bucket-info)    cmd_bucket_info "$@" ;;
  upload)         cmd_upload "$@" ;;
  download)       cmd_download "$@" ;;
  delete)         cmd_delete "$@" ;;
  presign)        cmd_presign "$@" ;;
  set-policy)     cmd_set_policy "$@" ;;
  create-user)    cmd_create_user "$@" ;;
  assign-policy)  cmd_assign_policy "$@" ;;
  list-users)     cmd_list_users "$@" ;;
  delete-user)    cmd_delete_user "$@" ;;
  lifecycle)      cmd_lifecycle "$@" ;;
  disk-usage)     cmd_disk_usage "$@" ;;
  info)           cmd_info "$@" ;;
  mirror)         cmd_mirror "$@" ;;
  export)         cmd_export "$@" ;;
  import)         cmd_import "$@" ;;
  install-service) cmd_install_service "$@" ;;
  help|--help|-h)
    echo "MinIO Object Storage Manager"
    echo ""
    echo "Usage: bash run.sh <command> [options]"
    echo ""
    echo "Server:"
    echo "  start             Start MinIO server"
    echo "  stop              Stop MinIO server"
    echo "  status            Show server status"
    echo "  info              Show server info"
    echo "  install-service   Install systemd service"
    echo ""
    echo "Buckets:"
    echo "  create-bucket     Create a new bucket"
    echo "  delete-bucket     Delete a bucket"
    echo "  list-buckets      List all buckets"
    echo "  bucket-info       Show bucket stats"
    echo ""
    echo "Files:"
    echo "  upload            Upload file/directory to bucket"
    echo "  download          Download file from bucket"
    echo "  list              List objects in bucket"
    echo "  delete            Delete object"
    echo "  presign           Generate presigned download URL"
    echo ""
    echo "Access:"
    echo "  set-policy        Set bucket access policy"
    echo "  create-user       Create access user"
    echo "  assign-policy     Assign policy to user"
    echo "  list-users        List all users"
    echo "  delete-user       Delete user"
    echo ""
    echo "Management:"
    echo "  lifecycle         Manage object lifecycle rules"
    echo "  disk-usage        Show disk usage"
    echo "  mirror            Mirror buckets"
    echo "  export            Export all data"
    echo "  import            Import from backup"
    ;;
  *) err "Unknown command: $CMD. Run 'bash run.sh help' for usage." ;;
esac
