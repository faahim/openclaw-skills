#!/bin/bash
# Linux User Manager — Create, manage, and audit Linux users, groups, and SSH keys
# Requires: root/sudo privileges

set -euo pipefail

VERSION="1.0.0"
LOG_FILE="/var/log/user-manager.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true; }
info() { echo -e "${GREEN}✅${NC} $*"; log "INFO: $*"; }
warn() { echo -e "${YELLOW}⚠️${NC} $*"; log "WARN: $*"; }
error() { echo -e "${RED}❌${NC} $*"; log "ERROR: $*"; }

check_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
  fi
}

usage() {
  cat <<EOF
Linux User Manager v${VERSION}

Usage: $0 <command> [options]

Commands:
  create            Create a new user
  remove            Remove a user
  lock              Lock a user account
  unlock            Unlock a user account
  audit             Audit all users
  ssh-add           Add SSH public key to user
  ssh-list          List SSH keys for a user
  ssh-remove        Remove all SSH keys for a user
  group-create      Create a new group
  group-add         Add user to group
  group-remove      Remove user from group
  group-list        List members of a group
  password-policy   Set password aging policy
  bulk-create       Create users from CSV file
  sudo-log          Show recent sudo activity
  expire-inactive   Lock users inactive for N days
  list              List all human users
  info              Show detailed info for a user

Options:
  --user <name>       Username
  --shell <path>      Login shell (default: /bin/bash)
  --groups <g1,g2>    Comma-separated groups
  --key <pubkey>      SSH public key string
  --expire-days <n>   Password expiry in days
  --file <path>       CSV file for bulk operations
  --group <name>      Group name
  --lines <n>         Number of log lines (default: 50)
  --days <n>          Days threshold
  --purge             Also remove home directory
  --force             Skip confirmation prompts
  --max-days <n>      Max password age
  --min-days <n>      Min password age
  --warn-days <n>     Warning days before expiry

EOF
}

# Parse arguments
COMMAND="${1:-}"
shift || true

USER=""
SHELL_PATH="/bin/bash"
GROUPS=""
SSH_KEY=""
EXPIRE_DAYS=""
FILE=""
GROUP=""
LINES=50
DAYS=30
PURGE=false
FORCE=false
MAX_DAYS=""
MIN_DAYS=""
WARN_DAYS=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --user) USER="$2"; shift 2 ;;
    --shell) SHELL_PATH="$2"; shift 2 ;;
    --groups) GROUPS="$2"; shift 2 ;;
    --key) SSH_KEY="$2"; shift 2 ;;
    --ssh-key) SSH_KEY="$2"; shift 2 ;;
    --expire-days) EXPIRE_DAYS="$2"; shift 2 ;;
    --file) FILE="$2"; shift 2 ;;
    --group) GROUP="$2"; shift 2 ;;
    --lines) LINES="$2"; shift 2 ;;
    --days) DAYS="$2"; shift 2 ;;
    --purge) PURGE=true; shift ;;
    --force) FORCE=true; shift ;;
    --max-days) MAX_DAYS="$2"; shift 2 ;;
    --min-days) MIN_DAYS="$2"; shift 2 ;;
    --warn-days) WARN_DAYS="$2"; shift 2 ;;
    *) error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

cmd_create() {
  check_root
  [[ -z "$USER" ]] && { error "Missing --user"; exit 1; }

  if id "$USER" &>/dev/null; then
    if [[ "$FORCE" == "true" ]]; then
      warn "User '$USER' already exists, skipping creation"
      return 0
    fi
    error "User '$USER' already exists (use --force to skip)"
    exit 1
  fi

  # Create user
  useradd -m -s "$SHELL_PATH" "$USER"
  info "User '$USER' created"
  echo "   Home: /home/$USER"
  echo "   Shell: $SHELL_PATH"

  # Add to groups
  if [[ -n "$GROUPS" ]]; then
    IFS=',' read -ra GRP_ARR <<< "$GROUPS"
    for g in "${GRP_ARR[@]}"; do
      g=$(echo "$g" | tr -d ' ' | tr ';' ',')
      if ! getent group "$g" &>/dev/null; then
        groupadd "$g"
        info "Group '$g' created"
      fi
      usermod -aG "$g" "$USER"
    done
    echo "   Groups: $USER, $GROUPS"
  fi

  # Set password expiry
  if [[ -n "$EXPIRE_DAYS" ]]; then
    chage -M "$EXPIRE_DAYS" "$USER"
    echo "   Password expires: $EXPIRE_DAYS days"
  fi

  # Add SSH key
  if [[ -n "$SSH_KEY" ]]; then
    local ssh_dir="/home/$USER/.ssh"
    mkdir -p "$ssh_dir"
    echo "$SSH_KEY" >> "$ssh_dir/authorized_keys"
    chmod 700 "$ssh_dir"
    chmod 600 "$ssh_dir/authorized_keys"
    chown -R "$USER:$USER" "$ssh_dir"
    echo "   SSH key: installed"
  fi

  log "Created user $USER (shell=$SHELL_PATH, groups=$GROUPS)"
}

cmd_remove() {
  check_root
  [[ -z "$USER" ]] && { error "Missing --user"; exit 1; }

  if ! id "$USER" &>/dev/null; then
    error "User '$USER' does not exist"
    exit 1
  fi

  if [[ "$PURGE" == "true" ]]; then
    userdel -r "$USER" 2>/dev/null || userdel "$USER"
    info "User '$USER' removed (home directory deleted)"
  else
    userdel "$USER"
    info "User '$USER' removed (home directory preserved at /home/$USER)"
  fi
  log "Removed user $USER (purge=$PURGE)"
}

cmd_lock() {
  check_root
  [[ -z "$USER" ]] && { error "Missing --user"; exit 1; }
  usermod -L "$USER"
  info "User '$USER' locked (login disabled)"
  log "Locked user $USER"
}

cmd_unlock() {
  check_root
  [[ -z "$USER" ]] && { error "Missing --user"; exit 1; }
  usermod -U "$USER"
  info "User '$USER' unlocked (login enabled)"
  log "Unlocked user $USER"
}

cmd_ssh_add() {
  check_root
  [[ -z "$USER" ]] && { error "Missing --user"; exit 1; }
  [[ -z "$SSH_KEY" ]] && { error "Missing --key"; exit 1; }

  local ssh_dir="/home/$USER/.ssh"
  mkdir -p "$ssh_dir"
  echo "$SSH_KEY" >> "$ssh_dir/authorized_keys"
  chmod 700 "$ssh_dir"
  chmod 600 "$ssh_dir/authorized_keys"
  chown -R "$USER:$(id -gn "$USER")" "$ssh_dir"

  local count
  count=$(wc -l < "$ssh_dir/authorized_keys")
  info "SSH key added for '$USER'"
  echo "   Keys: $count authorized key(s)"
  log "Added SSH key for $USER"
}

cmd_ssh_list() {
  [[ -z "$USER" ]] && { error "Missing --user"; exit 1; }
  local keyfile="/home/$USER/.ssh/authorized_keys"

  if [[ ! -f "$keyfile" ]]; then
    warn "No SSH keys found for '$USER'"
    return
  fi

  echo -e "${BLUE}=== SSH Keys for '$USER' ===${NC}"
  local i=1
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    local type key comment
    type=$(echo "$line" | awk '{print $1}')
    key=$(echo "$line" | awk '{print substr($2, 1, 20)}')
    comment=$(echo "$line" | awk '{print $3}')
    echo "  $i. $type ${key}... ${comment:-"(no comment)"}"
    ((i++))
  done < "$keyfile"
}

cmd_ssh_remove() {
  check_root
  [[ -z "$USER" ]] && { error "Missing --user"; exit 1; }
  local keyfile="/home/$USER/.ssh/authorized_keys"
  if [[ -f "$keyfile" ]]; then
    rm "$keyfile"
    info "All SSH keys removed for '$USER'"
  else
    warn "No SSH keys found for '$USER'"
  fi
}

cmd_audit() {
  check_root
  echo -e "${BLUE}=== User Audit Report ($(date '+%Y-%m-%d')) ===${NC}"
  echo ""

  # Human users
  echo -e "${BLUE}HUMAN USERS (UID >= 1000):${NC}"
  local found=false
  while IFS=: read -r username _ uid _ _ home shell; do
    [[ $uid -lt 1000 || "$username" == "nobody" || "$shell" == "/usr/sbin/nologin" || "$shell" == "/bin/false" ]] && continue
    found=true

    local groups_str last_login
    groups_str=$(groups "$username" 2>/dev/null | cut -d: -f2 | tr -s ' ' | sed 's/^ //')
    last_login=$(lastlog -u "$username" 2>/dev/null | tail -1 | awk '{if($2=="**Never") print "Never"; else print $4,$5,$6,$7,$9}')

    local login_warn=""
    if [[ "$last_login" == "Never" ]]; then
      login_warn=" ⚠️ (never logged in)"
    fi

    printf "  %-12s | Groups: %-30s | Shell: %s | Last: %s%s\n" \
      "$username" "$groups_str" "$shell" "$last_login" "$login_warn"
  done < /etc/passwd

  [[ "$found" == "false" ]] && echo "  (no human users found)"

  # Sudo users
  echo ""
  echo -e "${BLUE}SUDO USERS:${NC}"
  local sudo_users=""
  while IFS=: read -r username _ uid _ _ _ shell; do
    [[ $uid -lt 1000 || "$shell" == "/usr/sbin/nologin" || "$shell" == "/bin/false" ]] && continue
    if groups "$username" 2>/dev/null | grep -qE '\b(sudo|wheel|admin)\b'; then
      sudo_users="${sudo_users:+$sudo_users, }$username"
    fi
  done < /etc/passwd
  echo "  ${sudo_users:-none}"

  # SSH key status
  echo ""
  echo -e "${BLUE}SSH KEY STATUS:${NC}"
  while IFS=: read -r username _ uid _ _ home shell; do
    [[ $uid -lt 1000 || "$shell" == "/usr/sbin/nologin" || "$shell" == "/bin/false" ]] && continue
    local keyfile="$home/.ssh/authorized_keys"
    if [[ -f "$keyfile" ]]; then
      local count
      count=$(grep -c '^ssh-' "$keyfile" 2>/dev/null || echo 0)
      printf "  %-12s : %d authorized key(s)\n" "$username" "$count"
    else
      printf "  %-12s : 0 authorized keys ⚠️ (password-only)\n" "$username"
    fi
  done < /etc/passwd

  # Password status
  echo ""
  echo -e "${BLUE}PASSWORD STATUS:${NC}"
  while IFS=: read -r username _ uid _ _ _ shell; do
    [[ $uid -lt 1000 || "$shell" == "/usr/sbin/nologin" || "$shell" == "/bin/false" ]] && continue
    local max_days
    max_days=$(chage -l "$username" 2>/dev/null | grep "Maximum" | awk -F: '{print $2}' | tr -d ' ')
    if [[ "$max_days" == "99999" || -z "$max_days" ]]; then
      printf "  %-12s : never expires ⚠️\n" "$username"
    else
      local last_change expire_date
      expire_date=$(chage -l "$username" 2>/dev/null | grep "Password expires" | awk -F: '{print $2}' | tr -d ' ')
      printf "  %-12s : expires %s\n" "$username" "$expire_date"
    fi
  done < /etc/passwd

  # Locked accounts
  echo ""
  echo -e "${BLUE}LOCKED ACCOUNTS:${NC}"
  local locked=""
  while IFS=: read -r username passwd _; do
    [[ "$passwd" == "!"* ]] && locked="${locked:+$locked, }$username"
  done < /etc/shadow 2>/dev/null || true
  echo "  ${locked:-none}"

  # System accounts count
  local sys_count
  sys_count=$(grep -c '/usr/sbin/nologin\|/bin/false' /etc/passwd)
  echo ""
  echo -e "${BLUE}SYSTEM ACCOUNTS:${NC} $sys_count (nologin/false shell)"

  log "Audit completed"
}

cmd_group_create() {
  check_root
  [[ -z "$GROUP" ]] && { error "Missing --group"; exit 1; }
  if getent group "$GROUP" &>/dev/null; then
    warn "Group '$GROUP' already exists"
    return
  fi
  groupadd "$GROUP"
  info "Group '$GROUP' created"
}

cmd_group_add() {
  check_root
  [[ -z "$USER" ]] && { error "Missing --user"; exit 1; }
  [[ -z "$GROUP" ]] && { error "Missing --group"; exit 1; }
  usermod -aG "$GROUP" "$USER"
  info "User '$USER' added to group '$GROUP'"
}

cmd_group_remove() {
  check_root
  [[ -z "$USER" ]] && { error "Missing --user"; exit 1; }
  [[ -z "$GROUP" ]] && { error "Missing --group"; exit 1; }
  gpasswd -d "$USER" "$GROUP"
  info "User '$USER' removed from group '$GROUP'"
}

cmd_group_list() {
  [[ -z "$GROUP" ]] && { error "Missing --group"; exit 1; }
  if ! getent group "$GROUP" &>/dev/null; then
    error "Group '$GROUP' does not exist"
    exit 1
  fi
  local members
  members=$(getent group "$GROUP" | cut -d: -f4)
  echo -e "${BLUE}=== Group '$GROUP' Members ===${NC}"
  if [[ -z "$members" ]]; then
    echo "  (no members)"
  else
    echo "  $members" | tr ',' '\n' | sed 's/^/  /'
  fi
}

cmd_password_policy() {
  check_root
  [[ -z "$USER" ]] && { error "Missing --user"; exit 1; }

  [[ -n "$MAX_DAYS" ]] && chage -M "$MAX_DAYS" "$USER"
  [[ -n "$MIN_DAYS" ]] && chage -m "$MIN_DAYS" "$USER"
  [[ -n "$WARN_DAYS" ]] && chage -W "$WARN_DAYS" "$USER"

  info "Password policy updated for '$USER'"
  chage -l "$USER" | head -6 | sed 's/^/   /'
  log "Password policy updated for $USER (max=$MAX_DAYS min=$MIN_DAYS warn=$WARN_DAYS)"
}

cmd_bulk_create() {
  check_root
  [[ -z "$FILE" ]] && { error "Missing --file"; exit 1; }
  [[ ! -f "$FILE" ]] && { error "File not found: $FILE"; exit 1; }

  local count=0
  while IFS=, read -r username shell groups ssh_key; do
    [[ -z "$username" || "$username" =~ ^# ]] && continue
    username=$(echo "$username" | tr -d ' ')
    shell=$(echo "${shell:-/bin/bash}" | tr -d ' ')
    groups=$(echo "$groups" | tr ';' ',' | tr -d ' ')

    USER="$username"
    SHELL_PATH="$shell"
    GROUPS="$groups"
    SSH_KEY="$ssh_key"
    FORCE=true

    if id "$username" &>/dev/null; then
      warn "User '$username' already exists, skipping"
      continue
    fi

    cmd_create
    ((count++))
  done < "$FILE"

  info "Bulk create complete: $count users created"
}

cmd_sudo_log() {
  echo -e "${BLUE}=== Recent Sudo Activity (last $LINES entries) ===${NC}"
  if [[ -f /var/log/auth.log ]]; then
    grep -i 'sudo' /var/log/auth.log | tail -n "$LINES"
  elif [[ -f /var/log/secure ]]; then
    grep -i 'sudo' /var/log/secure | tail -n "$LINES"
  else
    journalctl _COMM=sudo --no-pager -n "$LINES" 2>/dev/null || echo "  No sudo logs found"
  fi
}

cmd_expire_inactive() {
  check_root
  echo -e "${BLUE}=== Expiring users inactive for $DAYS+ days ===${NC}"

  local today
  today=$(date +%s)
  local threshold=$((DAYS * 86400))

  while IFS=: read -r username _ uid _ _ _ shell; do
    [[ $uid -lt 1000 || "$shell" == "/usr/sbin/nologin" || "$shell" == "/bin/false" ]] && continue

    local last_ts
    last_ts=$(lastlog -u "$username" 2>/dev/null | tail -1)

    if echo "$last_ts" | grep -q "Never logged in"; then
      warn "$username: never logged in — locking"
      usermod -L "$username"
      continue
    fi

    # Parse last login date
    local last_date
    last_date=$(echo "$last_ts" | awk '{print $4,$5,$6,$9}')
    local last_epoch
    last_epoch=$(date -d "$last_date" +%s 2>/dev/null || echo 0)

    if [[ $last_epoch -gt 0 ]]; then
      local diff=$((today - last_epoch))
      if [[ $diff -gt $threshold ]]; then
        local days_ago=$((diff / 86400))
        warn "$username: last login $days_ago days ago — locking"
        usermod -L "$username"
      fi
    fi
  done < /etc/passwd
}

cmd_list() {
  echo -e "${BLUE}=== Human Users ===${NC}"
  printf "  %-15s %-8s %-25s %s\n" "USERNAME" "UID" "GROUPS" "SHELL"
  printf "  %-15s %-8s %-25s %s\n" "--------" "---" "------" "-----"
  while IFS=: read -r username _ uid _ _ _ shell; do
    [[ $uid -lt 1000 || "$username" == "nobody" || "$shell" == "/usr/sbin/nologin" || "$shell" == "/bin/false" ]] && continue
    local grps
    grps=$(groups "$username" 2>/dev/null | cut -d: -f2 | tr -s ' ' | sed 's/^ //' | cut -c1-24)
    printf "  %-15s %-8s %-25s %s\n" "$username" "$uid" "$grps" "$shell"
  done < /etc/passwd
}

cmd_info() {
  [[ -z "$USER" ]] && { error "Missing --user"; exit 1; }
  if ! id "$USER" &>/dev/null; then
    error "User '$USER' does not exist"
    exit 1
  fi

  echo -e "${BLUE}=== User Info: $USER ===${NC}"
  echo ""
  echo "  UID:      $(id -u "$USER")"
  echo "  GID:      $(id -g "$USER")"
  echo "  Groups:   $(groups "$USER" 2>/dev/null | cut -d: -f2 | tr -s ' ')"
  echo "  Home:     $(eval echo "~$USER")"
  echo "  Shell:    $(getent passwd "$USER" | cut -d: -f7)"
  echo ""

  echo "  Password Policy:"
  chage -l "$USER" 2>/dev/null | sed 's/^/    /'
  echo ""

  local keyfile="/home/$USER/.ssh/authorized_keys"
  if [[ -f "$keyfile" ]]; then
    local kc
    kc=$(grep -c '^ssh-' "$keyfile" 2>/dev/null || echo 0)
    echo "  SSH Keys: $kc authorized key(s)"
  else
    echo "  SSH Keys: none"
  fi

  echo ""
  echo "  Last Login:"
  lastlog -u "$USER" 2>/dev/null | tail -1 | sed 's/^/    /'

  # Check if locked
  local status
  status=$(passwd -S "$USER" 2>/dev/null | awk '{print $2}')
  echo ""
  if [[ "$status" == "L" ]]; then
    echo -e "  Status:   ${RED}LOCKED${NC}"
  else
    echo -e "  Status:   ${GREEN}ACTIVE${NC}"
  fi
}

# Route commands
case "${COMMAND}" in
  create)          cmd_create ;;
  remove)          cmd_remove ;;
  lock)            cmd_lock ;;
  unlock)          cmd_unlock ;;
  audit)           cmd_audit ;;
  ssh-add)         cmd_ssh_add ;;
  ssh-list)        cmd_ssh_list ;;
  ssh-remove)      cmd_ssh_remove ;;
  group-create)    cmd_group_create ;;
  group-add)       cmd_group_add ;;
  group-remove)    cmd_group_remove ;;
  group-list)      cmd_group_list ;;
  password-policy) cmd_password_policy ;;
  bulk-create)     cmd_bulk_create ;;
  sudo-log)        cmd_sudo_log ;;
  expire-inactive) cmd_expire_inactive ;;
  list)            cmd_list ;;
  info)            cmd_info ;;
  -h|--help|help)  usage ;;
  "")              usage ;;
  *)               error "Unknown command: $COMMAND"; usage; exit 1 ;;
esac
