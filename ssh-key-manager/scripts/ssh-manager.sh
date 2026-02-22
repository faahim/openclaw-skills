#!/usr/bin/env bash
# SSH Key Manager — Generate, manage, and configure SSH keys
# Usage: bash ssh-manager.sh <command> [options]

set -euo pipefail

SSH_DIR="${SSH_DIR:-$HOME/.ssh}"
SSH_CONFIG="$SSH_DIR/config"
SSH_KEY_TYPE="${SSH_KEY_TYPE:-ed25519}"
SSH_BACKUP_CIPHER="${SSH_BACKUP_CIPHER:-aes-256-cbc}"
ARCHIVE_DIR="$SSH_DIR/archive"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_ok()   { echo -e "${GREEN}✅ $*${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_err()  { echo -e "${RED}❌ $*${NC}"; }
log_info() { echo -e "${BLUE}🔍 $*${NC}"; }

usage() {
  cat <<EOF
SSH Key Manager — Manage SSH keys, configs, and connections

Usage: bash ssh-manager.sh <command> [options]

Commands:
  init                     Initialize ~/.ssh with correct permissions
  generate                 Generate a new SSH key pair
  list                     List all SSH keys
  audit [--fix]            Audit file permissions (optionally fix)
  config-add               Add an SSH config entry
  config-list              List SSH config entries
  config-remove --alias X  Remove an SSH config entry
  test --alias X|--host H  Test SSH connection
  copy-id                  Copy public key to remote server
  rotate --name X          Rotate an SSH key
  backup --output FILE     Create encrypted backup
  restore --input FILE     Restore from encrypted backup
  known-hosts-add --host H       Add host to known_hosts
  known-hosts-remove --host H    Remove host from known_hosts
  known-hosts-verify             Verify known_hosts entries

Options:
  --name NAME       Key name (filename in ~/.ssh/)
  --email EMAIL     Email for key comment
  --comment TEXT    Custom comment for key
  --type TYPE       Key type: ed25519 (default) or rsa
  --bits N          RSA bits (default: 4096)
  --alias ALIAS     SSH config alias (Host)
  --host HOSTNAME   Remote hostname or IP
  --user USERNAME   Remote username
  --key KEYPATH     Path to private key
  --port PORT       SSH port (default: 22)
  --forward-agent   Enable agent forwarding
  --fix             Fix permission issues (audit)
  --output FILE     Backup output file
  --input FILE      Backup input file

EOF
  exit 1
}

cmd_init() {
  echo -e "🔧 Initializing SSH directory...\n"

  # Create directory
  if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    log_ok "Created $SSH_DIR (permissions: 700)"
  else
    local perms
    perms=$(stat -c '%a' "$SSH_DIR" 2>/dev/null || stat -f '%Lp' "$SSH_DIR" 2>/dev/null)
    if [ "$perms" = "700" ]; then
      log_ok "$SSH_DIR exists (permissions: 700)"
    else
      chmod 700 "$SSH_DIR"
      log_warn "$SSH_DIR permissions fixed: $perms → 700"
    fi
  fi

  # Create config
  if [ ! -f "$SSH_CONFIG" ]; then
    touch "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    log_ok "Created $SSH_CONFIG (permissions: 600)"
  else
    local perms
    perms=$(stat -c '%a' "$SSH_CONFIG" 2>/dev/null || stat -f '%Lp' "$SSH_CONFIG" 2>/dev/null)
    if [ "$perms" = "600" ]; then
      log_ok "$SSH_CONFIG exists (permissions: 600)"
    else
      chmod 600 "$SSH_CONFIG"
      log_warn "$SSH_CONFIG permissions fixed: $perms → 600"
    fi
  fi

  # Check SSH agent
  if [ -n "${SSH_AUTH_SOCK:-}" ] && ssh-add -l &>/dev/null; then
    log_ok "SSH agent is running ($(ssh-add -l 2>/dev/null | wc -l) keys loaded)"
  elif [ -n "${SSH_AUTH_SOCK:-}" ]; then
    log_ok "SSH agent is running (no keys loaded)"
  else
    log_warn "SSH agent not running. Start with: eval \"\$(ssh-agent -s)\""
  fi

  # Create archive directory
  mkdir -p "$ARCHIVE_DIR"
}

cmd_generate() {
  local name="" email="" comment="" key_type="$SSH_KEY_TYPE" bits="4096"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --email) email="$2"; shift 2 ;;
      --comment) comment="$2"; shift 2 ;;
      --type) key_type="$2"; shift 2 ;;
      --bits) bits="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$name" ] && { log_err "Missing --name"; exit 1; }

  local key_path="$SSH_DIR/$name"

  if [ -f "$key_path" ]; then
    log_err "Key already exists: $key_path"
    echo "Use 'rotate --name $name' to rotate, or choose a different name."
    exit 1
  fi

  # Build comment
  local key_comment="${comment:-${email:-$name}}"

  echo -e "🔑 Generating $key_type key: $name\n"

  if [ "$key_type" = "ed25519" ]; then
    ssh-keygen -t ed25519 -f "$key_path" -C "$key_comment" -N ""
  elif [ "$key_type" = "rsa" ]; then
    ssh-keygen -t rsa -b "$bits" -f "$key_path" -C "$key_comment" -N ""
  else
    log_err "Unsupported key type: $key_type (use ed25519 or rsa)"
    exit 1
  fi

  chmod 600 "$key_path"
  chmod 644 "${key_path}.pub"

  echo ""
  log_ok "Generated $key_type key: $key_path"
  echo -e "\n📋 Public key (copy to remote server):"
  cat "${key_path}.pub"
  echo ""
  echo -e "💾 Fingerprint: $(ssh-keygen -lf "$key_path" 2>/dev/null | awk '{print $2}')"
}

cmd_list() {
  echo -e "🔑 SSH Keys in $SSH_DIR:\n"

  printf "%-18s %-10s %-6s %-40s %s\n" "Name" "Type" "Bits" "Fingerprint" "Comment"
  printf '%.0s─' {1..100}; echo ""

  for pub in "$SSH_DIR"/*.pub; do
    [ -f "$pub" ] || continue
    local name
    name=$(basename "$pub" .pub)

    local info
    info=$(ssh-keygen -lf "$pub" 2>/dev/null) || continue

    local bits type fingerprint comment
    bits=$(echo "$info" | awk '{print $1}')
    fingerprint=$(echo "$info" | awk '{print $2}')
    type=$(echo "$info" | awk '{print $NF}' | tr -d '()')
    comment=$(echo "$info" | awk '{for(i=3;i<NF;i++) printf "%s ", $i}' | sed 's/ $//')

    printf "%-18s %-10s %-6s %-40s %s\n" "$name" "$type" "$bits" "$fingerprint" "$comment"
  done
}

cmd_audit() {
  local fix=false
  [ "${1:-}" = "--fix" ] && fix=true

  echo -e "🔍 SSH Security Audit:\n"

  local issues=0

  # Check directory
  _check_perms "$SSH_DIR" "700" "d" "$fix" && true || ((issues++))

  # Check config
  [ -f "$SSH_CONFIG" ] && { _check_perms "$SSH_CONFIG" "600" "f" "$fix" && true || ((issues++)); }

  # Check private keys
  for key in "$SSH_DIR"/*; do
    [ -f "$key" ] || continue
    [[ "$key" == *.pub ]] && continue
    [[ "$(basename "$key")" == "config" ]] && continue
    [[ "$(basename "$key")" == "known_hosts" ]] && continue
    [[ "$(basename "$key")" == "known_hosts.old" ]] && continue
    [[ "$(basename "$key")" == "authorized_keys" ]] && continue
    [[ -d "$key" ]] && continue

    # Check if it's actually a key file (contains BEGIN)
    if head -1 "$key" 2>/dev/null | grep -q "BEGIN\|OPENSSH"; then
      _check_perms "$key" "600" "f" "$fix" && true || ((issues++))
    fi
  done

  # Check authorized_keys
  [ -f "$SSH_DIR/authorized_keys" ] && { _check_perms "$SSH_DIR/authorized_keys" "600" "f" "$fix" && true || ((issues++)); }

  echo ""
  if [ "$issues" -eq 0 ]; then
    log_ok "All permissions correct."
  elif [ "$fix" = true ]; then
    log_ok "Fixed $issues permission issue(s)."
  else
    log_warn "$issues issue(s) found. Run with --fix to repair."
  fi
}

_check_perms() {
  local path="$1" expected="$2" type="$3" fix="$4"
  local actual
  actual=$(stat -c '%a' "$path" 2>/dev/null || stat -f '%Lp' "$path" 2>/dev/null)

  if [ "$actual" = "$expected" ]; then
    local mode_str
    mode_str=$(stat -c '%A' "$path" 2>/dev/null || stat -f '%Sp' "$path" 2>/dev/null)
    log_ok "$path ($mode_str)"
    return 0
  else
    if [ "$fix" = true ]; then
      chmod "$expected" "$path"
      log_warn "$path — FIXED: $actual → $expected"
      return 0
    else
      log_warn "$path (mode: $actual, expected: $expected)"
      return 1
    fi
  fi
}

cmd_config_add() {
  local alias="" host="" user="" key="" port="22" forward_agent=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --alias) alias="$2"; shift 2 ;;
      --host) host="$2"; shift 2 ;;
      --user) user="$2"; shift 2 ;;
      --key) key="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --forward-agent) forward_agent=true; shift ;;
      *) shift ;;
    esac
  done

  [ -z "$alias" ] && { log_err "Missing --alias"; exit 1; }
  [ -z "$host" ] && { log_err "Missing --host"; exit 1; }

  # Check for existing entry
  if grep -q "^Host $alias$" "$SSH_CONFIG" 2>/dev/null; then
    log_err "Config entry '$alias' already exists. Remove it first with: config-remove --alias $alias"
    exit 1
  fi

  # Build config block
  {
    echo ""
    echo "Host $alias"
    echo "    HostName $host"
    [ -n "$user" ] && echo "    User $user"
    [ -n "$key" ] && echo "    IdentityFile $key"
    [ "$port" != "22" ] && echo "    Port $port"
    [ -n "$key" ] && echo "    IdentitiesOnly yes"
    [ "$forward_agent" = true ] && echo "    ForwardAgent yes"
    echo "    AddKeysToAgent yes"
    echo "    ServerAliveInterval 60"
    echo "    ServerAliveCountMax 3"
  } >> "$SSH_CONFIG"

  log_ok "Added config entry: $alias → $host"
  echo -e "\nYou can now connect with: ${GREEN}ssh $alias${NC}"
}

cmd_config_list() {
  echo -e "📋 SSH Config Entries:\n"

  if [ ! -f "$SSH_CONFIG" ] || [ ! -s "$SSH_CONFIG" ]; then
    echo "No entries found."
    return
  fi

  awk '
    /^Host / && !/\*/ {
      if (alias) printf "%-18s %-30s %-15s %-10s %s\n", alias, hostname, user, port, keyfile
      alias=$2; hostname="-"; user="-"; port="22"; keyfile="-"
    }
    /HostName/ { hostname=$2 }
    /User/ { user=$2 }
    /Port/ { port=$2 }
    /IdentityFile/ { keyfile=$2 }
    END {
      if (alias) printf "%-18s %-30s %-15s %-10s %s\n", alias, hostname, user, port, keyfile
    }
  ' "$SSH_CONFIG" | (
    printf "%-18s %-30s %-15s %-10s %s\n" "Alias" "Host" "User" "Port" "Key"
    printf '%.0s─' {1..90}; echo ""
    cat
  )
}

cmd_config_remove() {
  local alias=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --alias) alias="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$alias" ] && { log_err "Missing --alias"; exit 1; }

  if ! grep -q "^Host $alias$" "$SSH_CONFIG" 2>/dev/null; then
    log_err "Config entry '$alias' not found."
    exit 1
  fi

  # Remove the Host block (from "Host alias" to next "Host " or EOF)
  local tmp
  tmp=$(mktemp)
  awk -v alias="$alias" '
    /^Host / { if ($2 == alias) { skip=1; next } else { skip=0 } }
    !skip { print }
  ' "$SSH_CONFIG" > "$tmp"
  mv "$tmp" "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"

  log_ok "Removed config entry: $alias"
}

cmd_test() {
  local alias="" host=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --alias) alias="$2"; shift 2 ;;
      --host) host="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local target="${alias:-$host}"
  [ -z "$target" ] && { log_err "Missing --alias or --host"; exit 1; }

  log_info "Testing connection to $target..."

  # Special case for GitHub
  if [[ "$target" == *"github.com"* ]] || [[ "$target" == "github" ]]; then
    local gh_host="${host:-github.com}"
    local result
    result=$(ssh -T "git@$gh_host" 2>&1 || true)
    if echo "$result" | grep -q "successfully authenticated"; then
      local gh_user
      gh_user=$(echo "$result" | grep -oP '(?<=Hi )\w+')
      log_ok "GitHub authenticated as: $gh_user"
    else
      log_err "GitHub authentication failed"
      echo "$result"
    fi
    return
  fi

  # General connection test
  if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$target" "echo CONNECTION_OK" 2>/dev/null; then
    log_ok "Connection successful to $target"
  else
    local exit_code=$?
    if [ $exit_code -eq 255 ]; then
      log_err "Connection failed (timeout or refused)"
    else
      log_warn "Connection returned exit code: $exit_code"
    fi
  fi
}

cmd_copy_id() {
  local key="" host="" user=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --key) key="$2"; shift 2 ;;
      --host) host="$2"; shift 2 ;;
      --user) user="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$key" ] && { log_err "Missing --key"; exit 1; }
  [ -z "$host" ] && { log_err "Missing --host"; exit 1; }

  local pub_key="${key}.pub"
  [ ! -f "$pub_key" ] && { log_err "Public key not found: $pub_key"; exit 1; }

  local target="${user:+$user@}$host"
  echo -e "📤 Copying public key to $target..."

  if command -v ssh-copy-id &>/dev/null; then
    ssh-copy-id -i "$pub_key" "$target"
  else
    cat "$pub_key" | ssh "$target" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
  fi

  log_ok "Key installed. You can now: ssh $target"
}

cmd_rotate() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$name" ] && { log_err "Missing --name"; exit 1; }

  local key_path="$SSH_DIR/$name"
  [ ! -f "$key_path" ] && { log_err "Key not found: $key_path"; exit 1; }

  echo -e "🔄 Rotating key: $name\n"

  # Archive old key
  mkdir -p "$ARCHIVE_DIR"
  local date_stamp
  date_stamp=$(date +%Y-%m-%d)
  cp "$key_path" "$ARCHIVE_DIR/${name}.${date_stamp}"
  cp "${key_path}.pub" "$ARCHIVE_DIR/${name}.${date_stamp}.pub"
  log_ok "Archived old key: $ARCHIVE_DIR/${name}.${date_stamp}"

  # Get old key comment
  local comment
  comment=$(ssh-keygen -lf "${key_path}.pub" 2>/dev/null | awk '{for(i=3;i<NF;i++) printf "%s ", $i}' | sed 's/ $//')

  # Remove old key
  rm -f "$key_path" "${key_path}.pub"

  # Generate new key
  ssh-keygen -t ed25519 -f "$key_path" -C "$comment" -N ""
  chmod 600 "$key_path"
  chmod 644 "${key_path}.pub"

  echo ""
  log_ok "Generated new key: $key_path"
  echo -e "\n📋 New public key:"
  cat "${key_path}.pub"
  echo ""
  log_warn "Remember to update this key on remote servers!"
}

cmd_backup() {
  local output=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --output) output="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$output" ] && output="$HOME/ssh-backup-$(date +%Y%m%d).tar.gz.enc"

  echo -e "📦 Backing up $SSH_DIR..."

  local tmp_tar
  tmp_tar=$(mktemp /tmp/ssh-backup-XXXXXX.tar.gz)

  tar czf "$tmp_tar" -C "$HOME" .ssh

  openssl enc -"$SSH_BACKUP_CIPHER" -salt -pbkdf2 -in "$tmp_tar" -out "$output"
  rm -f "$tmp_tar"

  local size
  size=$(du -h "$output" | awk '{print $1}')
  log_ok "Backup saved: $output ($size)"
}

cmd_restore() {
  local input=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --input) input="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$input" ] && { log_err "Missing --input"; exit 1; }
  [ ! -f "$input" ] && { log_err "File not found: $input"; exit 1; }

  echo -e "📥 Restoring from $input..."

  local tmp_tar
  tmp_tar=$(mktemp /tmp/ssh-restore-XXXXXX.tar.gz)

  openssl enc -d -"$SSH_BACKUP_CIPHER" -pbkdf2 -in "$input" -out "$tmp_tar"
  tar xzf "$tmp_tar" -C "$HOME"
  rm -f "$tmp_tar"

  # Fix permissions
  chmod 700 "$SSH_DIR"
  find "$SSH_DIR" -type f -name "*.pub" -exec chmod 644 {} \;
  find "$SSH_DIR" -type f ! -name "*.pub" ! -name "known_hosts*" -exec chmod 600 {} \;

  log_ok "Restored SSH directory from backup."
}

cmd_known_hosts_add() {
  local host=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --host) host="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$host" ] && { log_err "Missing --host"; exit 1; }

  ssh-keyscan -H "$host" >> "$SSH_DIR/known_hosts" 2>/dev/null
  log_ok "Added $host to known_hosts"
}

cmd_known_hosts_remove() {
  local host=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --host) host="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$host" ] && { log_err "Missing --host"; exit 1; }

  ssh-keygen -R "$host" 2>/dev/null
  log_ok "Removed $host from known_hosts"
}

cmd_known_hosts_verify() {
  echo -e "🔍 Verifying known_hosts...\n"

  local kh="$SSH_DIR/known_hosts"
  [ ! -f "$kh" ] && { echo "No known_hosts file."; return; }

  local total
  total=$(wc -l < "$kh")
  echo "Total entries: $total"

  # Check for duplicates
  local dupes
  dupes=$(awk '{print $1}' "$kh" | sort | uniq -d | wc -l)
  if [ "$dupes" -gt 0 ]; then
    log_warn "$dupes duplicate entries found"
  else
    log_ok "No duplicate entries"
  fi
}

# ── Main dispatcher ──

COMMAND="${1:-}"
shift || true

case "$COMMAND" in
  init)               cmd_init ;;
  generate)           cmd_generate "$@" ;;
  list)               cmd_list ;;
  audit)              cmd_audit "$@" ;;
  config-add)         cmd_config_add "$@" ;;
  config-list)        cmd_config_list ;;
  config-remove)      cmd_config_remove "$@" ;;
  test)               cmd_test "$@" ;;
  copy-id)            cmd_copy_id "$@" ;;
  rotate)             cmd_rotate "$@" ;;
  backup)             cmd_backup "$@" ;;
  restore)            cmd_restore "$@" ;;
  known-hosts-add)    cmd_known_hosts_add "$@" ;;
  known-hosts-remove) cmd_known_hosts_remove "$@" ;;
  known-hosts-verify) cmd_known_hosts_verify ;;
  help|"")            usage ;;
  *)                  log_err "Unknown command: $COMMAND"; usage ;;
esac
