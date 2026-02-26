#!/bin/bash
# Aria2 RPC Daemon Manager
set -e

RPC_PORT="${ARIA2_RPC_PORT:-6800}"
RPC_SECRET="${ARIA2_RPC_SECRET:-opensesame}"
PID_FILE="$HOME/.aria2/aria2.pid"
LOG_FILE="$HOME/.aria2/aria2-daemon.log"
DIR="${ARIA2_DIR:-$HOME/Downloads}"

start() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "⚠️  Daemon already running (PID: $(cat "$PID_FILE"))"
        return 1
    fi

    mkdir -p ~/.aria2 "$DIR"
    touch ~/.aria2/aria2.session

    aria2c \
        --enable-rpc=true \
        --rpc-listen-port="$RPC_PORT" \
        --rpc-listen-all=false \
        --rpc-secret="$RPC_SECRET" \
        --dir="$DIR" \
        --continue=true \
        --split=16 \
        --max-connection-per-server=16 \
        --max-concurrent-downloads=5 \
        --min-split-size=1M \
        --file-allocation=falloc \
        --disk-cache=64M \
        --input-file="$HOME/.aria2/aria2.session" \
        --save-session="$HOME/.aria2/aria2.session" \
        --save-session-interval=30 \
        --enable-dht=true \
        --daemon=true \
        --log="$LOG_FILE" \
        --log-level=warn \
        --console-log-level=error

    # Find PID
    sleep 1
    PID=$(pgrep -f "aria2c.*rpc-listen-port=$RPC_PORT" | head -1)
    if [ -n "$PID" ]; then
        echo "$PID" > "$PID_FILE"
        echo "✅ Daemon started (PID: $PID, port: $RPC_PORT)"
        echo "   RPC URL: http://localhost:$RPC_PORT/jsonrpc"
        echo "   Secret:  $RPC_SECRET"
        echo "   Log:     $LOG_FILE"
    else
        echo "❌ Failed to start daemon. Check $LOG_FILE"
        return 1
    fi
}

stop() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            rm -f "$PID_FILE"
            echo "✅ Daemon stopped (PID: $PID)"
        else
            rm -f "$PID_FILE"
            echo "⚠️  PID file stale, cleaned up"
        fi
    else
        # Try to find and kill
        PID=$(pgrep -f "aria2c.*enable-rpc" | head -1)
        if [ -n "$PID" ]; then
            kill "$PID"
            echo "✅ Daemon stopped (PID: $PID)"
        else
            echo "ℹ️  No daemon running"
        fi
    fi
}

status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        PID=$(cat "$PID_FILE")
        echo "✅ Daemon running (PID: $PID, port: $RPC_PORT)"
        
        # Get global stat via RPC
        RESP=$(curl -s http://localhost:$RPC_PORT/jsonrpc \
            -d "{\"jsonrpc\":\"2.0\",\"id\":\"status\",\"method\":\"aria2.getGlobalStat\",\"params\":[\"token:$RPC_SECRET\"]}" \
            2>/dev/null)
        
        if [ -n "$RESP" ] && echo "$RESP" | jq -e '.result' &>/dev/null; then
            ACTIVE=$(echo "$RESP" | jq -r '.result.numActive')
            WAITING=$(echo "$RESP" | jq -r '.result.numWaiting')
            STOPPED=$(echo "$RESP" | jq -r '.result.numStopped')
            DL_SPEED=$(echo "$RESP" | jq -r '.result.downloadSpeed')
            UL_SPEED=$(echo "$RESP" | jq -r '.result.uploadSpeed')
            
            # Human-readable speed
            DL_HR=$(numfmt --to=iec-i --suffix=B/s "$DL_SPEED" 2>/dev/null || echo "${DL_SPEED}B/s")
            UL_HR=$(numfmt --to=iec-i --suffix=B/s "$UL_SPEED" 2>/dev/null || echo "${UL_SPEED}B/s")
            
            echo "   Active: $ACTIVE | Waiting: $WAITING | Stopped: $STOPPED"
            echo "   Down: $DL_HR | Up: $UL_HR"
        fi
    else
        echo "❌ Daemon not running"
        return 1
    fi
}

case "${1:-}" in
    start)  start ;;
    stop)   stop ;;
    restart) stop; sleep 1; start ;;
    status) status ;;
    *)
        echo "Usage: bash daemon.sh {start|stop|restart|status}"
        exit 1
        ;;
esac
