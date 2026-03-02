#!/bin/bash
# tmate session sharing manager
set -e

TMATE_LOG="/tmp/tmate-session.log"
TMATE_SOCK="/tmp/tmate.sock"
ACTION="${1:-help}"
shift 2>/dev/null || true

# Parse flags
TIMEOUT=""
NOTIFY=""
SESSION_NAME=""
CMD=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --notify) NOTIFY="$2"; shift 2 ;;
        --name) SESSION_NAME="$2"; shift 2 ;;
        --cmd) CMD="$2"; shift 2 ;;
        *) shift ;;
    esac
done

send_telegram() {
    local msg="$1"
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${msg}" \
            -d "parse_mode=Markdown" >/dev/null 2>&1
        echo "📱 Telegram notification sent"
    fi
}

get_session_info() {
    # Wait for tmate to establish connection
    local retries=0
    while [[ $retries -lt 15 ]]; do
        if tmate -S "$TMATE_SOCK" display -p '#{tmate_ssh}' 2>/dev/null | grep -q '@'; then
            break
        fi
        sleep 1
        retries=$((retries + 1))
    done

    local rw_ssh rw_web ro_ssh ro_web
    rw_ssh=$(tmate -S "$TMATE_SOCK" display -p '#{tmate_ssh}' 2>/dev/null || echo "unavailable")
    rw_web=$(tmate -S "$TMATE_SOCK" display -p '#{tmate_web}' 2>/dev/null || echo "unavailable")
    ro_ssh=$(tmate -S "$TMATE_SOCK" display -p '#{tmate_ssh_ro}' 2>/dev/null || echo "unavailable")
    ro_web=$(tmate -S "$TMATE_SOCK" display -p '#{tmate_web_ro}' 2>/dev/null || echo "unavailable")

    echo ""
    echo "🔗 tmate session started!"
    echo ""
    echo "Read-Write (full access):"
    echo "  SSH:  $rw_ssh"
    echo "  Web:  $rw_web"
    echo ""
    echo "Read-Only (view only):"
    echo "  SSH:  $ro_ssh"
    echo "  Web:  $ro_web"
    echo ""
    echo "Session log: $TMATE_LOG"

    # Save to log
    {
        echo "--- tmate session $(date -u +%Y-%m-%dT%H:%M:%SZ) ---"
        echo "RW SSH: $rw_ssh"
        echo "RW Web: $rw_web"
        echo "RO SSH: $ro_ssh"
        echo "RO Web: $ro_web"
    } >> "$TMATE_LOG"

    # Telegram notification
    if [[ "$NOTIFY" == "telegram" ]]; then
        local msg="🔗 *tmate session started*%0A%0A"
        msg+="*Read-Write:* \`$rw_ssh\`%0A"
        msg+="*Read-Only:* \`$ro_ssh\`%0A"
        msg+="*Web:* $rw_web"
        send_telegram "$msg"
    fi
}

case "$ACTION" in
    start)
        # Check if already running
        if [[ -S "$TMATE_SOCK" ]]; then
            echo "⚠️  tmate session already active. Use 'stop' first or 'status' to see links."
            get_session_info
            exit 0
        fi

        echo "🚀 Starting tmate session..."

        # Build tmate command
        TMATE_CMD="tmate -S $TMATE_SOCK"

        if [[ -n "$SESSION_NAME" ]]; then
            TMATE_CMD+=" -n $SESSION_NAME"
        fi

        # Start in detached mode
        $TMATE_CMD new-session -d ${CMD:+-s "$CMD"}

        get_session_info

        # Auto-timeout
        if [[ -n "$TIMEOUT" ]]; then
            echo ""
            echo "⏱️  Session will auto-terminate in ${TIMEOUT} minutes"
            (sleep $((TIMEOUT * 60)) && tmate -S "$TMATE_SOCK" kill-server 2>/dev/null && echo "⏱️  Session expired after ${TIMEOUT} minutes" >> "$TMATE_LOG") &
        fi
        ;;

    stop)
        if [[ -S "$TMATE_SOCK" ]]; then
            tmate -S "$TMATE_SOCK" kill-server 2>/dev/null
            rm -f "$TMATE_SOCK"
            echo "🛑 tmate session terminated"
        else
            echo "ℹ️  No active tmate session found"
        fi
        ;;

    status)
        if [[ -S "$TMATE_SOCK" ]]; then
            local pid
            pid=$(tmate -S "$TMATE_SOCK" display -p '#{pid}' 2>/dev/null || echo "unknown")
            echo "✅ tmate session active (PID: $pid)"

            # Get start time from log
            if [[ -f "$TMATE_LOG" ]]; then
                local started
                started=$(grep "^--- tmate session" "$TMATE_LOG" | tail -1 | sed 's/--- tmate session \(.*\) ---/\1/')
                echo "Started: $started"
            fi

            get_session_info
        else
            echo "❌ No active tmate session"
        fi
        ;;

    list)
        echo "Active tmate sockets:"
        find /tmp -name "tmate*" -type s 2>/dev/null | while read -r sock; do
            local pid
            pid=$(tmate -S "$sock" display -p '#{pid}' 2>/dev/null || echo "dead")
            local ssh
            ssh=$(tmate -S "$sock" display -p '#{tmate_ssh}' 2>/dev/null || echo "unknown")
            echo "  Socket: $sock  PID: $pid  SSH: $ssh"
        done
        ;;

    help|*)
        echo "tmate Session Sharing"
        echo ""
        echo "Usage: bash run.sh <action> [options]"
        echo ""
        echo "Actions:"
        echo "  start   Start a new shared session"
        echo "  stop    End the current session"
        echo "  status  Show session info and links"
        echo "  list    List all active sessions"
        echo ""
        echo "Options:"
        echo "  --timeout <min>      Auto-terminate after N minutes"
        echo "  --notify telegram    Send session links via Telegram"
        echo "  --name <name>        Named session (requires API key)"
        echo "  --cmd <command>      Run command in the session"
        echo ""
        echo "Examples:"
        echo "  bash run.sh start"
        echo "  bash run.sh start --timeout 30 --notify telegram"
        echo "  bash run.sh stop"
        ;;
esac
