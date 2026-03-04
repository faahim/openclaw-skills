#!/bin/bash
# Manage Zellij sessions — list, attach, kill
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
log() { echo -e "${GREEN}[zellij-session]${NC} $1"; }
err() { echo -e "${RED}[zellij-session]${NC} $1" >&2; }

check_zellij() {
    if ! command -v zellij &>/dev/null; then
        err "Zellij not found. Run: bash scripts/install.sh"
        exit 1
    fi
}

ACTION="${1:-}"
SESSION="${2:-}"

case "$ACTION" in
    list|ls)
        check_zellij
        log "Active Zellij sessions:"
        zellij list-sessions 2>/dev/null || echo "  (no active sessions)"
        ;;
    attach|a)
        check_zellij
        if [[ -z "$SESSION" ]]; then
            log "Attaching to most recent session..."
            zellij attach
        else
            log "Attaching to session: $SESSION"
            zellij attach "$SESSION" 2>/dev/null || {
                log "Session '$SESSION' not found. Creating new session..."
                zellij -s "$SESSION"
            }
        fi
        ;;
    new|n)
        check_zellij
        if [[ -z "$SESSION" ]]; then
            err "Usage: $0 new <session-name> [--layout <layout>]"
            exit 1
        fi
        LAYOUT=""
        if [[ "${3:-}" == "--layout" ]]; then
            LAYOUT="${4:-}"
        fi
        if [[ -n "$LAYOUT" ]]; then
            log "Creating session '$SESSION' with layout '$LAYOUT'"
            zellij -s "$SESSION" --layout "$LAYOUT"
        else
            log "Creating session '$SESSION'"
            zellij -s "$SESSION"
        fi
        ;;
    kill|k)
        check_zellij
        if [[ -z "$SESSION" ]]; then
            err "Usage: $0 kill <session-name>"
            exit 1
        fi
        log "Killing session: $SESSION"
        zellij kill-session "$SESSION"
        log "✅ Session '$SESSION' killed"
        ;;
    kill-all|ka)
        check_zellij
        log "Killing all Zellij sessions..."
        zellij kill-all-sessions 2>/dev/null && log "✅ All sessions killed" || log "No sessions to kill"
        ;;
    *)
        echo "Usage: $0 <command> [session-name]"
        echo ""
        echo "Commands:"
        echo "  list (ls)              List active sessions"
        echo "  attach (a) [name]      Attach to session (or most recent)"
        echo "  new (n) <name>         Create new named session"
        echo "  kill (k) <name>        Kill a specific session"
        echo "  kill-all (ka)          Kill all sessions"
        exit 1
        ;;
esac
