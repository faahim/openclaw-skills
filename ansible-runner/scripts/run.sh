#!/bin/bash
# Ansible Playbook Runner — Main Runner
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export ANSIBLE_CONFIG="${ANSIBLE_CONFIG:-$SCRIPT_DIR/ansible.cfg}"
INV_FILE="${ANSIBLE_INVENTORY:-$SCRIPT_DIR/inventory.ini}"

# Check ansible is installed
if ! command -v ansible &>/dev/null; then
  echo "❌ Ansible not found. Run: bash scripts/install.sh"
  exit 1
fi

usage() {
  echo "Usage:"
  echo "  $0 ping [--inventory FILE] [--limit GROUP]"
  echo "  $0 playbook <FILE.yml> [--inventory FILE] [--limit GROUP] [--check] [--extra-vars VARS] [-v|-vv|-vvv]"
  echo "  $0 command <CMD> [--inventory FILE] [--limit GROUP] [--module MODULE] [--become]"
  echo "  $0 facts [--inventory FILE] [--limit HOST]"
  echo ""
  echo "Examples:"
  echo "  $0 ping"
  echo "  $0 playbook deploy.yml --limit webservers --extra-vars 'version=2.1'"
  echo "  $0 command 'uptime' --limit webservers"
  echo "  $0 command 'name=nginx state=restarted' --module service --become"
  echo "  $0 facts --limit web1"
}

# Parse common flags from remaining args
parse_common() {
  INVENTORY="$INV_FILE"
  LIMIT=""
  CHECK=""
  BECOME=""
  EXTRA_VARS=""
  MODULE="shell"
  VERBOSE=""
  FORKS=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --inventory|-i) INVENTORY="$2"; shift 2 ;;
      --limit|-l) LIMIT="$2"; shift 2 ;;
      --check|-C) CHECK="--check"; shift ;;
      --become|-b) BECOME="--become"; shift ;;
      --extra-vars|-e) EXTRA_VARS="$2"; shift 2 ;;
      --module|-m) MODULE="$2"; shift 2 ;;
      --forks|-f) FORKS="$2"; shift 2 ;;
      --ask-vault-pass) VAULT_PASS="--ask-vault-pass"; shift ;;
      -v) VERBOSE="-v"; shift ;;
      -vv) VERBOSE="-vv"; shift ;;
      -vvv) VERBOSE="-vvv"; shift ;;
      *) shift ;;
    esac
  done
}

cmd_ping() {
  parse_common "$@"
  echo "🏓 Pinging all hosts..."
  local cmd="ansible all -i '$INVENTORY' -m ping"
  [ -n "$LIMIT" ] && cmd="$cmd -l '$LIMIT'"
  [ -n "$VERBOSE" ] && cmd="$cmd $VERBOSE"
  eval $cmd
}

cmd_playbook() {
  local playbook="$1"
  shift

  if [ ! -f "$playbook" ]; then
    # Check in examples dir
    if [ -f "$SCRIPT_DIR/examples/$playbook" ]; then
      playbook="$SCRIPT_DIR/examples/$playbook"
    else
      echo "❌ Playbook not found: $playbook"
      exit 1
    fi
  fi

  parse_common "$@"

  echo "📜 Running playbook: $playbook"
  local cmd="ansible-playbook -i '$INVENTORY' '$playbook'"
  [ -n "$LIMIT" ] && cmd="$cmd -l '$LIMIT'"
  [ -n "$CHECK" ] && cmd="$cmd $CHECK"
  [ -n "$BECOME" ] && cmd="$cmd $BECOME"
  [ -n "$EXTRA_VARS" ] && cmd="$cmd -e '$EXTRA_VARS'"
  [ -n "$VERBOSE" ] && cmd="$cmd $VERBOSE"
  [ -n "$FORKS" ] && cmd="$cmd -f '$FORKS'"
  [ -n "$VAULT_PASS" ] && cmd="$cmd $VAULT_PASS"

  echo "→ $cmd"
  eval $cmd

  local exit_code=$?
  if [ $exit_code -eq 0 ]; then
    echo ""
    echo "✅ Playbook completed successfully"
  else
    echo ""
    echo "❌ Playbook failed (exit code: $exit_code)"
  fi
  return $exit_code
}

cmd_command() {
  local ad_hoc_cmd="$1"
  shift

  parse_common "$@"

  echo "⚡ Running command: $ad_hoc_cmd"
  local cmd="ansible all -i '$INVENTORY' -m '$MODULE' -a '$ad_hoc_cmd'"
  [ -n "$LIMIT" ] && cmd="$cmd -l '$LIMIT'"
  [ -n "$BECOME" ] && cmd="$cmd $BECOME"
  [ -n "$VERBOSE" ] && cmd="$cmd $VERBOSE"

  eval $cmd
}

cmd_facts() {
  parse_common "$@"
  local target="${LIMIT:-all}"
  echo "📊 Gathering facts for: $target"
  ansible "$target" -i "$INVENTORY" -m setup $VERBOSE 2>&1 | head -100
}

# Main
case "${1:-}" in
  ping)
    shift
    cmd_ping "$@"
    ;;
  playbook)
    shift
    if [ $# -lt 1 ]; then usage; exit 1; fi
    cmd_playbook "$@"
    ;;
  command|cmd)
    shift
    if [ $# -lt 1 ]; then usage; exit 1; fi
    cmd_command "$@"
    ;;
  facts)
    shift
    cmd_facts "$@"
    ;;
  *)
    usage
    ;;
esac
