#!/usr/bin/env bash
# Sysctl Tuner — Profile-based Linux kernel parameter optimizer
# Usage: bash sysctl-tuner.sh --profile <name> [--apply|--dry-run|--persist|--audit|--backup|--rollback <id>]

set -euo pipefail

BACKUP_DIR="${SYSCTL_BACKUP_DIR:-/var/backups/sysctl-tuner}"
PERSIST_FILE="${SYSCTL_PERSIST_FILE:-/etc/sysctl.d/99-tuner.conf}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# ── Profile Definitions ──
declare -A WEBSERVER_PARAMS=(
  [net.core.somaxconn]=65535
  [net.core.netdev_max_backlog]=65535
  [net.core.rmem_max]=16777216
  [net.core.wmem_max]=16777216
  [net.core.rmem_default]=1048576
  [net.core.wmem_default]=1048576
  [net.ipv4.tcp_max_syn_backlog]=65535
  [net.ipv4.tcp_rmem]="4096 1048576 16777216"
  [net.ipv4.tcp_wmem]="4096 1048576 16777216"
  [net.ipv4.tcp_fin_timeout]=15
  [net.ipv4.tcp_tw_reuse]=1
  [net.ipv4.tcp_keepalive_time]=300
  [net.ipv4.tcp_keepalive_intvl]=30
  [net.ipv4.tcp_keepalive_probes]=5
  [net.ipv4.tcp_syncookies]=1
  [net.ipv4.tcp_fastopen]=3
  [net.ipv4.ip_local_port_range]="1024 65535"
  [fs.file-max]=2097152
)

declare -A DATABASE_PARAMS=(
  [vm.swappiness]=10
  [vm.dirty_ratio]=15
  [vm.dirty_background_ratio]=5
  [vm.dirty_expire_centisecs]=500
  [vm.dirty_writeback_centisecs]=100
  [kernel.shmmax]=17179869184
  [kernel.shmall]=4194304
  [kernel.sem]="250 32000 100 128"
  [fs.file-max]=2097152
  [fs.aio-max-nr]=1048576
  [net.core.somaxconn]=65535
  [net.ipv4.tcp_keepalive_time]=300
  [net.ipv4.tcp_keepalive_intvl]=30
  [net.ipv4.tcp_keepalive_probes]=5
)

declare -A CONTAINER_PARAMS=(
  [net.ipv4.ip_forward]=1
  [net.bridge.bridge-nf-call-iptables]=1
  [net.bridge.bridge-nf-call-ip6tables]=1
  [net.netfilter.nf_conntrack_max]=1048576
  [fs.inotify.max_user_watches]=1048576
  [fs.inotify.max_user_instances]=8192
  [kernel.pid_max]=4194304
  [vm.max_map_count]=262144
  [net.core.somaxconn]=65535
  [net.ipv4.tcp_keepalive_time]=600
  [fs.file-max]=2097152
  [net.ipv4.ip_local_port_range]="1024 65535"
  [net.ipv4.conf.all.forwarding]=1
)

declare -A DESKTOP_PARAMS=(
  [vm.swappiness]=10
  [vm.dirty_ratio]=20
  [vm.dirty_background_ratio]=5
  [vm.vfs_cache_pressure]=50
  [fs.inotify.max_user_watches]=524288
  [fs.inotify.max_user_instances]=1024
  [kernel.sysrq]=1
  [kernel.sched_autogroup_enabled]=1
  [net.ipv4.tcp_fastopen]=3
  [net.ipv4.tcp_keepalive_time]=300
  [fs.file-max]=1048576
)

declare -A SECURITY_PARAMS=(
  [net.ipv4.conf.all.accept_redirects]=0
  [net.ipv4.conf.default.accept_redirects]=0
  [net.ipv6.conf.all.accept_redirects]=0
  [net.ipv6.conf.default.accept_redirects]=0
  [net.ipv4.conf.all.accept_source_route]=0
  [net.ipv4.conf.default.accept_source_route]=0
  [net.ipv4.conf.all.rp_filter]=1
  [net.ipv4.conf.default.rp_filter]=1
  [net.ipv4.conf.all.send_redirects]=0
  [net.ipv4.conf.default.send_redirects]=0
  [net.ipv4.icmp_echo_ignore_broadcasts]=1
  [net.ipv4.icmp_ignore_bogus_error_responses]=1
  [net.ipv4.tcp_syncookies]=1
  [kernel.randomize_va_space]=2
  [kernel.dmesg_restrict]=1
  [kernel.kptr_restrict]=2
  [fs.protected_hardlinks]=1
  [fs.protected_symlinks]=1
  [fs.suid_dumpable]=0
)

# ── Helpers ──

get_current_value() {
  local key="$1"
  local proc_path="/proc/sys/$(echo "$key" | tr '.' '/')"
  if [[ -f "$proc_path" ]]; then
    cat "$proc_path" 2>/dev/null | tr '\t' ' '
  else
    echo "N/A"
  fi
}

get_profile_params() {
  local profile="$1"
  case "$profile" in
    webserver) declare -n params=WEBSERVER_PARAMS ;;
    database)  declare -n params=DATABASE_PARAMS ;;
    container) declare -n params=CONTAINER_PARAMS ;;
    desktop)   declare -n params=DESKTOP_PARAMS ;;
    security)  declare -n params=SECURITY_PARAMS ;;
    *) echo "Unknown profile: $profile" >&2; return 1 ;;
  esac
  for key in "${!params[@]}"; do
    echo "$key=${params[$key]}"
  done
}

do_backup() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H-%M-%S)"
  mkdir -p "$BACKUP_DIR"
  sysctl -a 2>/dev/null > "$BACKUP_DIR/sysctl-backup-${ts}.conf"
  echo -e "${GREEN}✅ Backup saved: $BACKUP_DIR/sysctl-backup-${ts}.conf${NC}"
}

do_apply() {
  local key="$1" val="$2"
  local proc_path="/proc/sys/$(echo "$key" | tr '.' '/')"
  if [[ -f "$proc_path" ]]; then
    sysctl -w "$key=$val" >/dev/null 2>&1 && return 0
  fi
  return 1
}

do_persist() {
  local params_file="$1"
  cp "$params_file" "$PERSIST_FILE"
  echo -e "${GREEN}✅ Persisted to $PERSIST_FILE${NC}"
  echo -e "${CYAN}ℹ️  Run 'sysctl --system' or reboot to verify persistence.${NC}"
}

parse_yaml_config() {
  local file="$1"
  if command -v yq &>/dev/null; then
    yq -r '.parameters | to_entries[] | "\(.key)=\(.value)"' "$file"
  else
    # Simple YAML parser fallback (key: value under parameters:)
    local in_params=0
    while IFS= read -r line; do
      if [[ "$line" =~ ^parameters: ]]; then
        in_params=1; continue
      fi
      if [[ $in_params -eq 1 ]]; then
        if [[ "$line" =~ ^[[:space:]]+ ]]; then
          local k v
          k="$(echo "$line" | sed 's/^[[:space:]]*//' | cut -d: -f1)"
          v="$(echo "$line" | sed 's/^[^:]*:[[:space:]]*//')"
          [[ -n "$k" && -n "$v" ]] && echo "$k=$v"
        else
          in_params=0
        fi
      fi
    done < "$file"
  fi
}

# ── Main ──

PROFILES=()
ACTION=""
CONFIG_FILE=""
ROLLBACK_ID=""
ALERT_DRIFT=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --profile)     PROFILES+=("$2"); shift 2 ;;
    --dry-run)     ACTION="dry-run"; shift ;;
    --apply)       ACTION="apply"; shift ;;
    --persist)     ACTION="persist"; shift ;;
    --audit)       ACTION="audit"; shift ;;
    --backup)      ACTION="backup"; shift ;;
    --rollback)    ACTION="rollback"; ROLLBACK_ID="$2"; shift 2 ;;
    --list-backups) ACTION="list-backups"; shift ;;
    --verify)      ACTION="verify"; shift ;;
    --export)      ACTION="export"; shift ;;
    --config)      CONFIG_FILE="$2"; shift 2 ;;
    --alert-drift) ALERT_DRIFT=1; shift ;;
    --diff)        ACTION="diff"; CONFIG_FILE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: sysctl-tuner.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --profile <name>    Apply profile (webserver|database|container|desktop|security)"
      echo "  --config <file>     Use custom YAML config"
      echo "  --dry-run           Preview changes without applying"
      echo "  --apply             Apply changes (requires root)"
      echo "  --persist           Write to sysctl.d for persistence across reboots"
      echo "  --audit             Compare current vs recommended settings"
      echo "  --backup            Backup current sysctl values"
      echo "  --rollback <id>     Rollback to a backup (timestamp or 'latest')"
      echo "  --list-backups      List available backups"
      echo "  --verify            Verify last applied changes are active"
      echo "  --export            Export current settings as YAML"
      echo "  --diff <file>       Compare current settings to exported file"
      echo "  --alert-drift       Exit non-zero if settings differ from profile"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Show current profile
if [[ "$ACTION" == "" && ${#PROFILES[@]} -eq 0 && -z "$CONFIG_FILE" ]]; then
  echo -e "${CYAN}Sysctl Tuner — Linux kernel parameter optimizer${NC}"
  echo ""
  echo "Available profiles: webserver, database, container, desktop, security"
  echo ""
  echo "Usage:"
  echo "  bash sysctl-tuner.sh --profile webserver --dry-run    # Preview"
  echo "  sudo bash sysctl-tuner.sh --profile webserver --apply # Apply"
  echo "  bash sysctl-tuner.sh --help                           # Full help"
  exit 0
fi

# Collect all parameters from profiles + config
declare -A ALL_PARAMS
for profile in "${PROFILES[@]}"; do
  while IFS='=' read -r key val; do
    ALL_PARAMS["$key"]="$val"
  done < <(get_profile_params "$profile")
done

if [[ -n "$CONFIG_FILE" ]]; then
  while IFS='=' read -r key val; do
    ALL_PARAMS["$key"]="$val"
  done < <(parse_yaml_config "$CONFIG_FILE")
fi

case "$ACTION" in
  backup)
    do_backup
    ;;

  list-backups)
    if [[ -d "$BACKUP_DIR" ]]; then
      echo -e "${CYAN}Available backups:${NC}"
      ls -1t "$BACKUP_DIR"/sysctl-backup-*.conf 2>/dev/null | while read -r f; do
        local_ts="$(basename "$f" | sed 's/sysctl-backup-//;s/\.conf//')"
        local_size="$(du -h "$f" | cut -f1)"
        echo "  $local_ts ($local_size)"
      done
    else
      echo "No backups found."
    fi
    ;;

  rollback)
    if [[ "$ROLLBACK_ID" == "latest" ]]; then
      ROLLBACK_FILE="$(ls -1t "$BACKUP_DIR"/sysctl-backup-*.conf 2>/dev/null | head -1)"
    else
      ROLLBACK_FILE="$BACKUP_DIR/sysctl-backup-${ROLLBACK_ID}.conf"
    fi
    if [[ ! -f "$ROLLBACK_FILE" ]]; then
      echo -e "${RED}❌ Backup not found: $ROLLBACK_FILE${NC}" >&2
      exit 1
    fi
    echo -e "${YELLOW}Rolling back to: $(basename "$ROLLBACK_FILE")${NC}"
    sysctl -p "$ROLLBACK_FILE" 2>/dev/null
    echo -e "${GREEN}✅ Rollback complete.${NC}"
    ;;

  dry-run)
    echo -e "${CYAN}[DRY RUN] Would set:${NC}"
    changed=0; unchanged=0
    for key in $(echo "${!ALL_PARAMS[@]}" | tr ' ' '\n' | sort); do
      current="$(get_current_value "$key")"
      target="${ALL_PARAMS[$key]}"
      if [[ "$current" == "$target" ]]; then
        ((unchanged++))
      else
        echo -e "  ${YELLOW}$key${NC} = ${GREEN}$target${NC} (current: ${RED}$current${NC})"
        ((changed++))
      fi
    done
    echo ""
    echo -e "Total: ${GREEN}$changed changed${NC}, $unchanged already set"
    ;;

  apply)
    do_backup
    echo -e "${CYAN}Applying kernel parameters...${NC}"
    applied=0; failed=0; skipped=0
    for key in $(echo "${!ALL_PARAMS[@]}" | tr ' ' '\n' | sort); do
      target="${ALL_PARAMS[$key]}"
      if do_apply "$key" "$target"; then
        echo -e "  ${GREEN}✅${NC} $key = $target"
        ((applied++))
      else
        current="$(get_current_value "$key")"
        if [[ "$current" == "N/A" ]]; then
          echo -e "  ${YELLOW}⏭️${NC}  $key — parameter not available on this kernel"
          ((skipped++))
        else
          echo -e "  ${RED}❌${NC} $key — failed to set"
          ((failed++))
        fi
      fi
    done
    echo ""
    echo -e "Applied: ${GREEN}$applied${NC} | Skipped: ${YELLOW}$skipped${NC} | Failed: ${RED}$failed${NC}"
    ;;

  persist)
    TMPFILE="$(mktemp)"
    echo "# Sysctl Tuner — Generated $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TMPFILE"
    echo "# Profiles: ${PROFILES[*]}" >> "$TMPFILE"
    echo "" >> "$TMPFILE"
    for key in $(echo "${!ALL_PARAMS[@]}" | tr ' ' '\n' | sort); do
      echo "$key = ${ALL_PARAMS[$key]}" >> "$TMPFILE"
    done
    do_persist "$TMPFILE"
    rm -f "$TMPFILE"
    ;;

  audit)
    echo -e "${CYAN}System Audit — Profiles: ${PROFILES[*]}${NC}"
    echo ""
    optimal=0; suboptimal=0; unavailable=0
    for key in $(echo "${!ALL_PARAMS[@]}" | tr ' ' '\n' | sort); do
      current="$(get_current_value "$key")"
      target="${ALL_PARAMS[$key]}"
      if [[ "$current" == "N/A" ]]; then
        echo -e "  ${YELLOW}—${NC}  $key — not available"
        ((unavailable++))
      elif [[ "$current" == "$target" ]]; then
        echo -e "  ${GREEN}✅${NC} $key = $current"
        ((optimal++))
      else
        echo -e "  ${RED}⚠️${NC}  $key = $current (recommended: $target)"
        ((suboptimal++))
      fi
    done
    total=$((optimal + suboptimal))
    if [[ $total -gt 0 ]]; then
      pct=$((optimal * 100 / total))
      echo ""
      echo -e "Score: ${GREEN}$optimal${NC}/$total parameters optimized (${pct}%)"
      [[ $unavailable -gt 0 ]] && echo -e "${YELLOW}$unavailable parameters unavailable on this kernel${NC}"
    fi
    if [[ $ALERT_DRIFT -eq 1 && $suboptimal -gt 0 ]]; then
      exit 1
    fi
    ;;

  verify)
    if [[ ! -f "$PERSIST_FILE" ]]; then
      echo "No persist file found at $PERSIST_FILE"
      exit 1
    fi
    echo -e "${CYAN}Verifying persisted settings...${NC}"
    ok=0; drift=0
    while IFS= read -r line; do
      [[ "$line" =~ ^# ]] && continue
      [[ -z "$line" ]] && continue
      key="$(echo "$line" | cut -d= -f1 | xargs)"
      expected="$(echo "$line" | cut -d= -f2- | xargs)"
      current="$(get_current_value "$key")"
      if [[ "$current" == "$expected" ]]; then
        ((ok++))
      else
        echo -e "  ${RED}DRIFT${NC} $key: expected=$expected actual=$current"
        ((drift++))
      fi
    done < "$PERSIST_FILE"
    echo -e "Verified: ${GREEN}$ok OK${NC}, ${RED}$drift drifted${NC}"
    ;;

  export)
    echo "# Sysctl Export — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# Host: $(hostname)"
    echo "# Kernel: $(uname -r)"
    echo "parameters:"
    sysctl -a 2>/dev/null | sort | while IFS= read -r line; do
      key="$(echo "$line" | cut -d= -f1 | xargs)"
      val="$(echo "$line" | cut -d= -f2- | xargs)"
      echo "  $key: $val"
    done
    ;;

  diff)
    if [[ ! -f "$CONFIG_FILE" ]]; then
      echo "File not found: $CONFIG_FILE" >&2; exit 1
    fi
    echo -e "${CYAN}Comparing current system to: $CONFIG_FILE${NC}"
    while IFS='=' read -r key val; do
      current="$(get_current_value "$key")"
      if [[ "$current" != "$val" ]]; then
        echo -e "  ${YELLOW}DIFF${NC} $key: local=$current remote=$val"
      fi
    done < <(parse_yaml_config "$CONFIG_FILE")
    ;;

  *)
    echo "Specify an action: --dry-run, --apply, --persist, --audit, --backup, --rollback, --verify, --export"
    exit 1
    ;;
esac
