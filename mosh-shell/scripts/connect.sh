#!/bin/bash
# Mosh connection profile manager
set -euo pipefail

PROFILES_DIR="${HOME}/.config/mosh-profiles"
mkdir -p "$PROFILES_DIR"

usage() {
  echo "Usage: $0 [PROFILE|--save|--list|--delete]"
  echo ""
  echo "Commands:"
  echo "  <profile>                    Connect using saved profile"
  echo "  --save NAME --host USER@HOST Connect and save profile"
  echo "  --list                       List saved profiles"
  echo "  --delete NAME                Delete a profile"
  echo ""
  echo "Save options:"
  echo "  --host USER@HOST       Remote host (required)"
  echo "  --ssh-port PORT        SSH port (default: 22)"
  echo "  --key PATH             SSH key file"
  echo "  --mosh-port PORT       Mosh UDP port"
  echo "  --tmux                 Auto-attach tmux session"
  exit 1
}

ACTION=""
PROFILE_NAME=""
HOST=""
SSH_PORT=""
KEY=""
MOSH_PORT=""
TMUX=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --save) ACTION="save"; PROFILE_NAME="$2"; shift 2 ;;
    --list) ACTION="list"; shift ;;
    --delete) ACTION="delete"; PROFILE_NAME="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --ssh-port) SSH_PORT="$2"; shift 2 ;;
    --key) KEY="$2"; shift 2 ;;
    --mosh-port) MOSH_PORT="$2"; shift 2 ;;
    --tmux) TMUX="1"; shift ;;
    -h|--help) usage ;;
    *)
      if [[ -z "$ACTION" ]]; then
        ACTION="connect"
        PROFILE_NAME="$1"
      fi
      shift
      ;;
  esac
done

[[ -z "$ACTION" ]] && usage

case "$ACTION" in
  save)
    [[ -z "$HOST" ]] && { echo "❌ --host required"; exit 1; }
    
    cat > "$PROFILES_DIR/$PROFILE_NAME" <<EOF
HOST=$HOST
SSH_PORT=${SSH_PORT:-22}
KEY=${KEY:-}
MOSH_PORT=${MOSH_PORT:-}
TMUX=${TMUX:-}
EOF
    echo "✅ Profile '$PROFILE_NAME' saved"
    echo "   Connect: $0 $PROFILE_NAME"
    ;;
    
  list)
    if [[ -z "$(ls -A "$PROFILES_DIR" 2>/dev/null)" ]]; then
      echo "No saved profiles. Create one:"
      echo "  $0 --save myserver --host user@example.com"
      exit 0
    fi
    
    printf "%-15s %-30s %-6s %-5s\n" "PROFILE" "HOST" "PORT" "TMUX"
    printf "%-15s %-30s %-6s %-5s\n" "-------" "----" "----" "----"
    
    for f in "$PROFILES_DIR"/*; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      source "$f"
      tmux_flag=""
      [[ "${TMUX:-}" == "1" ]] && tmux_flag="✓"
      printf "%-15s %-30s %-6s %-5s\n" "$name" "${HOST:-?}" "${SSH_PORT:-22}" "$tmux_flag"
    done
    ;;
    
  delete)
    if [[ -f "$PROFILES_DIR/$PROFILE_NAME" ]]; then
      rm "$PROFILES_DIR/$PROFILE_NAME"
      echo "✅ Profile '$PROFILE_NAME' deleted"
    else
      echo "❌ Profile not found: $PROFILE_NAME"
      exit 1
    fi
    ;;
    
  connect)
    if [[ ! -f "$PROFILES_DIR/$PROFILE_NAME" ]]; then
      echo "❌ Profile not found: $PROFILE_NAME"
      echo "   List profiles: $0 --list"
      exit 1
    fi
    
    source "$PROFILES_DIR/$PROFILE_NAME"
    
    # Build mosh command
    CMD="mosh"
    
    SSH_OPTS=""
    [[ -n "${SSH_PORT:-}" && "${SSH_PORT:-}" != "22" ]] && SSH_OPTS="-p $SSH_PORT"
    [[ -n "${KEY:-}" ]] && SSH_OPTS="$SSH_OPTS -i $KEY"
    [[ -n "$SSH_OPTS" ]] && CMD="$CMD --ssh=\"ssh $SSH_OPTS\""
    
    [[ -n "${MOSH_PORT:-}" ]] && CMD="$CMD -p $MOSH_PORT"
    
    CMD="$CMD $HOST"
    
    [[ "${TMUX:-}" == "1" ]] && CMD="$CMD -- tmux new-session -A -s main"
    
    echo "→ $CMD"
    eval "$CMD"
    ;;
esac
