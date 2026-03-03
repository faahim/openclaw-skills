#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${STATE_DIR:-./state}"
mkdir -p "$STATE_DIR"

need_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Run as root: sudo bash scripts/ufw-manager.sh $*" >&2
    exit 1
  fi
}

timestamp() { date -u +%Y%m%dT%H%M%SZ; }

backup_state() {
  local tag="$1"
  local file="$STATE_DIR/ufw-${tag}.txt"
  {
    echo "# created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    ufw status numbered || true
  } > "$file"
  echo "Saved backup: $file"
}

status_cmd() {
  ufw status verbose
}

audit_cmd() {
  echo "== UFW Status =="
  ufw status verbose || true
  echo
  echo "== Listening Ports =="
  ss -tulpen || true
}

baseline_cmd() {
  local ssh_port="22"
  while [ $# -gt 0 ]; do
    case "$1" in
      --ssh-port) ssh_port="$2"; shift 2;;
      *) echo "Unknown option: $1"; exit 1;;
    esac
  done

  backup_state "baseline-$(timestamp)"
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow "${ssh_port}/tcp"
  ufw --force enable
  echo "Baseline applied (SSH ${ssh_port}/tcp allowed)."
}

allow_cmd() {
  [ $# -eq 1 ] || { echo "Usage: allow <rule> (e.g. 443/tcp)"; exit 1; }
  ufw allow "$1"
}

deny_cmd() {
  [ $# -eq 1 ] || { echo "Usage: deny <rule>"; exit 1; }
  ufw deny "$1"
}

rollback_cmd() {
  local tag=""
  local latest=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --tag) tag="$2"; shift 2;;
      --latest) latest=1; shift;;
      *) echo "Unknown option: $1"; exit 1;;
    esac
  done

  local file=""
  if [ "$latest" -eq 1 ]; then
    file=$(ls -1t "$STATE_DIR"/ufw-*.txt 2>/dev/null | head -n1 || true)
  elif [ -n "$tag" ]; then
    file="$STATE_DIR/ufw-${tag}.txt"
  fi

  [ -n "$file" ] && [ -f "$file" ] || { echo "Backup not found"; exit 1; }

  ufw --force reset
  awk '/^\[/{print}' "$file" | sed -E 's/^\[[0-9]+\]\s+//' | while IFS= read -r line; do
    # best-effort restore from numbered status lines
    if echo "$line" | grep -q 'ALLOW'; then
      rule=$(echo "$line" | awk '{print $1}')
      ufw allow "$rule" || true
    elif echo "$line" | grep -q 'DENY'; then
      rule=$(echo "$line" | awk '{print $1}')
      ufw deny "$rule" || true
    fi
  done
  ufw --force enable
  echo "Rollback applied from $file"
}

main() {
  need_root "$@"
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    status) status_cmd "$@" ;;
    audit) audit_cmd "$@" ;;
    backup)
      [ "${1:-}" = "--tag" ] || { echo "Usage: backup --tag <name>"; exit 1; }
      backup_state "$2"
      ;;
    baseline) baseline_cmd "$@" ;;
    allow) allow_cmd "$@" ;;
    deny) deny_cmd "$@" ;;
    rollback) rollback_cmd "$@" ;;
    *)
      cat <<USAGE
Usage: $0 <command>
  status
  audit
  backup --tag <name>
  baseline [--ssh-port 22]
  allow <rule>
  deny <rule>
  rollback (--latest | --tag <name>)
USAGE
      exit 1
      ;;
  esac
}

main "$@"
