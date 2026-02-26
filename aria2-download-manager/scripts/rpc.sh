#!/bin/bash
# Aria2 RPC Client — Control downloads via JSON-RPC
set -e

RPC_URL="http://localhost:${ARIA2_RPC_PORT:-6800}/jsonrpc"
RPC_SECRET="${ARIA2_RPC_SECRET:-opensesame}"

rpc_call() {
    local method=$1
    shift
    local params="\"token:$RPC_SECRET\""
    for p in "$@"; do
        params="$params,$p"
    done
    
    curl -s "$RPC_URL" \
        -d "{\"jsonrpc\":\"2.0\",\"id\":\"cmd\",\"method\":\"aria2.$method\",\"params\":[$params]}"
}

format_bytes() {
    numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "${1}B"
}

cmd_add() {
    local url=$1
    shift
    local opts="{}"
    if [ $# -gt 0 ]; then
        opts="$1"
    fi
    RESP=$(rpc_call "addUri" "[\"$url\"]" "$opts")
    GID=$(echo "$RESP" | jq -r '.result // .error.message')
    echo "✅ Added: $url (GID: $GID)"
}

cmd_status() {
    # Get active downloads
    ACTIVE=$(rpc_call "tellActive" "[]" "[\"gid\",\"status\",\"totalLength\",\"completedLength\",\"downloadSpeed\",\"files\"]")
    WAITING=$(rpc_call "tellWaiting" "0" "100" "[]" "[\"gid\",\"status\",\"totalLength\",\"completedLength\",\"files\"]")
    
    echo "=== Active Downloads ==="
    echo "$ACTIVE" | jq -r '.result[]? | 
        "  [\(.gid)] \(.status) | \(.completedLength)/\(.totalLength) bytes | \(.downloadSpeed) B/s | \(.files[0].path // .files[0].uris[0].uri // "unknown")"'
    
    if [ "$(echo "$ACTIVE" | jq '.result | length')" = "0" ]; then
        echo "  (none)"
    fi
    
    echo ""
    echo "=== Waiting Downloads ==="
    echo "$WAITING" | jq -r '.result[]? |
        "  [\(.gid)] \(.status) | \(.files[0].path // .files[0].uris[0].uri // "unknown")"'
    
    if [ "$(echo "$WAITING" | jq '.result | length')" = "0" ]; then
        echo "  (none)"
    fi
}

cmd_pause() {
    local gid=$1
    RESP=$(rpc_call "pause" "\"$gid\"")
    echo "⏸️  Paused: $gid"
}

cmd_resume() {
    local gid=$1
    RESP=$(rpc_call "unpause" "\"$gid\"")
    echo "▶️  Resumed: $gid"
}

cmd_remove() {
    local gid=$1
    RESP=$(rpc_call "remove" "\"$gid\"")
    echo "🗑️  Removed: $gid"
}

cmd_pause_all() {
    rpc_call "pauseAll" > /dev/null
    echo "⏸️  All downloads paused"
}

cmd_resume_all() {
    rpc_call "unpauseAll" > /dev/null
    echo "▶️  All downloads resumed"
}

cmd_purge() {
    rpc_call "purgeDownloadResult" > /dev/null
    echo "🧹 Cleared completed/error results"
}

case "${1:-}" in
    add)     cmd_add "$2" "${3:-}" ;;
    status)  cmd_status ;;
    pause)   cmd_pause "$2" ;;
    resume)  cmd_resume "$2" ;;
    remove)  cmd_remove "$2" ;;
    pause-all)  cmd_pause_all ;;
    resume-all) cmd_resume_all ;;
    purge)   cmd_purge ;;
    *)
        echo "Usage: bash rpc.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  add <URL>        Add a download"
        echo "  status           List all downloads"
        echo "  pause <GID>      Pause a download"
        echo "  resume <GID>     Resume a download"
        echo "  remove <GID>     Remove a download"
        echo "  pause-all        Pause everything"
        echo "  resume-all       Resume everything"
        echo "  purge            Clear completed/errored results"
        exit 1
        ;;
esac
