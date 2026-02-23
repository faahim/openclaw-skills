#!/bin/bash
# Wrapper to run a command and send ntfy notification on success/failure
# Usage: bash notify.sh --topic my-alerts --title "Backup" -- /path/to/script.sh
set -e

# Defaults
SERVER="${NTFY_SERVER:-https://ntfy.sh}"
TOPIC="${NTFY_TOPIC:-alerts}"
TOKEN="${NTFY_TOKEN:-}"
TITLE=""
ON_SUCCESS="Command completed successfully ✅"
ON_FAIL="Command failed ❌"
PRIORITY_SUCCESS="default"
PRIORITY_FAIL="high"

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --server) SERVER="$2"; shift 2 ;;
        --topic) TOPIC="$2"; shift 2 ;;
        --token) TOKEN="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --on-success) ON_SUCCESS="$2"; shift 2 ;;
        --on-fail) ON_FAIL="$2"; shift 2 ;;
        --) shift; break ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ $# -eq 0 ]; then
    echo "Usage: notify.sh [options] -- <command> [args...]"
    echo "Options:"
    echo "  --server URL      ntfy server (default: \$NTFY_SERVER or https://ntfy.sh)"
    echo "  --topic TOPIC     notification topic (default: \$NTFY_TOPIC or 'alerts')"
    echo "  --token TOKEN     auth token (default: \$NTFY_TOKEN)"
    echo "  --title TITLE     notification title"
    echo "  --on-success MSG  message on success"
    echo "  --on-fail MSG     message on failure"
    exit 1
fi

COMMAND="$*"

send_notification() {
    local msg="$1"
    local priority="$2"
    local tags="$3"
    
    HEADERS=(-H "Priority: $priority" -H "Tags: $tags")
    [ -n "$TITLE" ] && HEADERS+=(-H "Title: $TITLE")
    [ -n "$TOKEN" ] && HEADERS+=(-H "Authorization: Bearer $TOKEN")
    
    curl -s "${HEADERS[@]}" -d "$msg" "${SERVER}/${TOPIC}" >/dev/null 2>&1 || true
}

# Run the command
START=$(date +%s)
set +e
eval "$COMMAND"
EXIT_CODE=$?
set -e
END=$(date +%s)
DURATION=$((END - START))

# Send notification
if [ $EXIT_CODE -eq 0 ]; then
    send_notification "${ON_SUCCESS} (${DURATION}s)" "$PRIORITY_SUCCESS" "white_check_mark"
else
    send_notification "${ON_FAIL} (exit code: ${EXIT_CODE}, ${DURATION}s)" "$PRIORITY_FAIL" "rotating_light"
fi

exit $EXIT_CODE
