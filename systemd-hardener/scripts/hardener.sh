#!/usr/bin/env bash
# Systemd Security Hardener — Audit and harden systemd service units
# Usage: bash hardener.sh <command> [options]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
MODE="conservative"
DRY_RUN=false
THRESHOLD=7.0
TOP_N=0
SORT_BY="exposure"
OUTPUT_DIR=""
SERVICE=""
OUTPUT_FILE=""
DIRECTIVES=""

usage() {
  cat <<EOF
Systemd Security Hardener

USAGE:
  $(basename "$0") <command> [options]

COMMANDS:
  audit         Audit service(s) security exposure
  harden        Generate hardening override for a service
  harden-all    Generate overrides for all services above threshold
  compare       Compare before/after scores with an override

AUDIT OPTIONS:
  --service <name>      Audit specific service (default: all running)
  --sort <field>        Sort by: exposure, name (default: exposure)
  --top <n>             Show top N results only

HARDEN OPTIONS:
  --service <name>      Service to harden (required)
  --mode <mode>         conservative | aggressive (default: conservative)
  --enable <list>       Comma-separated directives to enable
  --output <path>       Write override to file (default: stdout)
  --dry-run             Show what would be generated without writing

HARDEN-ALL OPTIONS:
  --threshold <score>   Minimum exposure score to harden (default: 7.0)
  --mode <mode>         conservative | aggressive
  --output-dir <path>   Directory for override files (required)

COMPARE OPTIONS:
  --service <name>      Service to compare
  --override <path>     Override file to test

EOF
  exit 1
}

# --- Rating helper ---
get_rating() {
  local score=$1
  if (( $(echo "$score <= 2.0" | bc -l) )); then echo -e "${GREEN}GOOD${NC}"
  elif (( $(echo "$score <= 5.0" | bc -l) )); then echo -e "${BLUE}OK${NC}"
  elif (( $(echo "$score <= 7.0" | bc -l) )); then echo -e "${YELLOW}MEDIUM${NC}"
  elif (( $(echo "$score <= 8.5" | bc -l) )); then echo -e "${YELLOW}EXPOSED${NC}"
  else echo -e "${RED}UNSAFE${NC}"
  fi
}

# --- Audit all services ---
audit_all() {
  echo -e "${BLUE}=== Systemd Security Audit ===${NC}"
  echo ""
  printf "%-45s %-10s %s\n" "SERVICE" "EXPOSURE" "RATING"
  printf "%-45s %-10s %s\n" "-------" "--------" "------"

  local tmpfile
  tmpfile=$(mktemp)

  # Get security scores for all loaded services
  systemd-analyze security --no-pager 2>/dev/null | tail -n +2 | while IFS= read -r line; do
    local svc score
    svc=$(echo "$line" | awk '{print $1}')
    score=$(echo "$line" | awk '{print $2}')

    # Skip non-numeric scores
    if [[ "$score" =~ ^[0-9]+\.?[0-9]*$ ]]; then
      echo "$score $svc" >> "$tmpfile"
    fi
  done

  # Sort and display
  if [[ "$SORT_BY" == "exposure" ]]; then
    sort -rn "$tmpfile"
  else
    sort -k2 "$tmpfile"
  fi | {
    local count=0
    while read -r score svc; do
      if [[ $TOP_N -gt 0 && $count -ge $TOP_N ]]; then break; fi
      local rating
      rating=$(get_rating "$score")
      printf "%-45s %-10s %b\n" "$svc" "$score" "$rating"
      count=$((count + 1))
    done
  }

  rm -f "$tmpfile"
}

# --- Audit single service ---
audit_service() {
  local svc="$1"

  echo -e "${BLUE}=== Security Audit: $svc ===${NC}"

  # Get the exposure score
  local score
  score=$(systemd-analyze security "$svc" --no-pager 2>/dev/null | grep "Overall exposure" | awk '{print $NF}' || echo "N/A")

  if [[ "$score" == "N/A" ]]; then
    # Try alternate parsing
    score=$(systemd-analyze security --no-pager 2>/dev/null | grep "^$svc" | awk '{print $2}')
  fi

  local rating
  rating=$(get_rating "${score:-10}")
  echo -e "Current Score: ${score}/10 ($rating)"
  echo ""

  # Get detailed analysis
  systemd-analyze security "$svc" --no-pager 2>/dev/null | while IFS= read -r line; do
    if echo "$line" | grep -qE "^✓|^✗|^→"; then
      if echo "$line" | grep -q "^✗"; then
        echo -e "${RED}❌${NC} $(echo "$line" | sed 's/^✗//')"
      elif echo "$line" | grep -q "^✓"; then
        echo -e "${GREEN}✅${NC} $(echo "$line" | sed 's/^✓//')"
      else
        echo "  $line"
      fi
    fi
  done
}

# --- Conservative hardening directives ---
get_conservative_directives() {
  cat <<'DIRECTIVES'
[Service]
# === Filesystem Protections ===
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes

# === Privilege Restrictions ===
NoNewPrivileges=yes
RestrictRealtime=yes
LockPersonality=yes

# === Device Access ===
PrivateDevices=yes

# === Namespace Restrictions ===
RestrictNamespaces=yes

# === Misc ===
RemoveIPC=yes
DIRECTIVES
}

# --- Aggressive hardening directives ---
get_aggressive_directives() {
  cat <<'DIRECTIVES'
[Service]
# === Filesystem Protections ===
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes

# === Privilege Restrictions ===
NoNewPrivileges=yes
RestrictRealtime=yes
LockPersonality=yes
CapabilityBoundingSet=~CAP_SYS_ADMIN CAP_SYS_PTRACE CAP_SYS_MODULE CAP_SYS_RAWIO CAP_SYS_BOOT CAP_SYS_CHROOT CAP_MKNOD CAP_AUDIT_CONTROL CAP_AUDIT_READ CAP_AUDIT_WRITE CAP_BLOCK_SUSPEND CAP_LINUX_IMMUTABLE CAP_MAC_ADMIN CAP_MAC_OVERRIDE CAP_SYSLOG CAP_WAKE_ALARM

# === Memory Protections ===
MemoryDenyWriteExecute=yes

# === Device Access ===
PrivateDevices=yes

# === Network Restrictions ===
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

# === Namespace Restrictions ===
RestrictNamespaces=yes

# === System Call Filtering ===
SystemCallArchitectures=native
SystemCallFilter=@system-service
SystemCallFilter=~@privileged @resources @mount @swap @reboot @module @raw-io @clock @cpu-emulation @debug @obsolete

# === Misc ===
RemoveIPC=yes
UMask=0077
DIRECTIVES
}

# --- Generate hardening override ---
harden_service() {
  local svc="$1"

  local header="# Hardening override for $svc
# Generated by systemd-hardener on $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Mode: $MODE
#
# To apply:
#   sudo mkdir -p /etc/systemd/system/${svc}.d/
#   sudo cp this-file /etc/systemd/system/${svc}.d/hardening.conf
#   sudo systemctl daemon-reload
#   sudo systemctl restart $svc
"

  local content
  if [[ -n "$DIRECTIVES" ]]; then
    # Custom directives
    content="[Service]"$'\n'
    IFS=',' read -ra dirs <<< "$DIRECTIVES"
    for d in "${dirs[@]}"; do
      content+="${d}=yes"$'\n'
    done
  elif [[ "$MODE" == "aggressive" ]]; then
    content=$(get_aggressive_directives)
  else
    content=$(get_conservative_directives)
  fi

  local output="${header}${content}"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[DRY RUN] Would generate:${NC}"
    echo "$output"
  elif [[ -n "$OUTPUT_FILE" ]]; then
    echo "$output" > "$OUTPUT_FILE"
    echo -e "${GREEN}✅ Override written to: $OUTPUT_FILE${NC}"
  else
    echo "$output"
  fi
}

# --- Harden all services above threshold ---
harden_all_services() {
  if [[ -z "$OUTPUT_DIR" ]]; then
    echo -e "${RED}Error: --output-dir required for harden-all${NC}"
    exit 1
  fi

  mkdir -p "$OUTPUT_DIR"

  echo -e "${BLUE}=== Batch Hardening (threshold: $THRESHOLD) ===${NC}"

  local count=0
  systemd-analyze security --no-pager 2>/dev/null | tail -n +2 | while IFS= read -r line; do
    local svc score
    svc=$(echo "$line" | awk '{print $1}')
    score=$(echo "$line" | awk '{print $2}')

    if [[ "$score" =~ ^[0-9]+\.?[0-9]*$ ]] && (( $(echo "$score >= $THRESHOLD" | bc -l) )); then
      local svc_dir="$OUTPUT_DIR/${svc}.d"
      mkdir -p "$svc_dir"
      OUTPUT_FILE="$svc_dir/hardening.conf" harden_service "$svc"
      echo -e "  ${GREEN}✅${NC} $svc (score: $score) → $svc_dir/hardening.conf"
      count=$((count + 1))
    fi
  done

  echo ""
  echo -e "${GREEN}Generated overrides for services above $THRESHOLD exposure.${NC}"
  echo "Review files in: $OUTPUT_DIR"
  echo ""
  echo "To apply all:"
  echo "  sudo cp -r $OUTPUT_DIR/* /etc/systemd/system/"
  echo "  sudo systemctl daemon-reload"
}

# --- Compare before/after ---
compare_service() {
  local svc="$1"
  local override="$2"

  echo -e "${BLUE}=== Comparing: $svc ===${NC}"

  # Before score
  local before
  before=$(systemd-analyze security --no-pager 2>/dev/null | grep "^$svc" | awk '{print $2}')
  local before_rating
  before_rating=$(get_rating "$before")

  echo -e "Before: ${before}/10 ($before_rating)"

  # Apply temporarily and check
  local tmpdir
  tmpdir=$(mktemp -d)
  local svc_dir="$tmpdir/${svc}.d"
  mkdir -p "$svc_dir"
  cp "$override" "$svc_dir/hardening.conf"

  echo -e "Override: $override"
  echo ""
  echo "Note: Full before/after comparison requires applying the override."
  echo "Use 'audit --service $svc' after applying to see new score."

  rm -rf "$tmpdir"
}

# --- Parse args ---
COMMAND="${1:-}"
shift 2>/dev/null || true

if [[ -z "$COMMAND" ]]; then usage; fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service) SERVICE="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --sort) SORT_BY="$2"; shift 2 ;;
    --top) TOP_N="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --enable) DIRECTIVES="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --override) OVERRIDE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# --- Execute command ---
case "$COMMAND" in
  audit)
    if [[ -n "$SERVICE" ]]; then
      audit_service "$SERVICE"
    else
      audit_all
    fi
    ;;
  harden)
    if [[ -z "$SERVICE" ]]; then
      echo -e "${RED}Error: --service required${NC}"
      exit 1
    fi
    harden_service "$SERVICE"
    ;;
  harden-all)
    harden_all_services
    ;;
  compare)
    if [[ -z "$SERVICE" || -z "${OVERRIDE:-}" ]]; then
      echo -e "${RED}Error: --service and --override required${NC}"
      exit 1
    fi
    compare_service "$SERVICE" "$OVERRIDE"
    ;;
  *)
    echo "Unknown command: $COMMAND"
    usage
    ;;
esac
