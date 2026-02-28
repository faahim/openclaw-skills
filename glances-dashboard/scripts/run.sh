#!/bin/bash
# Run Glances with various modes
set -e

# Defaults
MODE="terminal"
PORT=61208
BIND="0.0.0.0"
CONFIG=""
DOCKER=false
EXPORT=""
EXPORT_FILE=""
PASSWORD=""
EXTRA_ARGS=""
REFRESH=2

usage() {
    echo "Usage: bash run.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --web              Start web dashboard (default port 61208)"
    echo "  --server           Start in server mode (for client-server)"
    echo "  --port PORT        Web/server port (default: 61208)"
    echo "  --bind ADDR        Bind address (default: 0.0.0.0)"
    echo "  --config FILE      Path to config file"
    echo "  --docker           Enable Docker container monitoring"
    echo "  --password PASS    Set web dashboard password"
    echo "  --refresh SEC      Refresh interval in seconds (default: 2)"
    echo "  --export TYPE      Export metrics (csv, prometheus, influxdb2)"
    echo "  --export-csv-file  CSV export file path"
    echo "  -h, --help         Show this help"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --web) MODE="web"; shift ;;
        --server) MODE="server"; shift ;;
        --port) PORT="$2"; shift 2 ;;
        --bind) BIND="$2"; shift 2 ;;
        --config) CONFIG="$2"; shift 2 ;;
        --docker) DOCKER=true; shift ;;
        --password) PASSWORD="$2"; shift 2 ;;
        --refresh) REFRESH="$2"; shift 2 ;;
        --export) EXPORT="$2"; shift 2 ;;
        --export-csv-file) EXPORT_FILE="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) EXTRA_ARGS="$EXTRA_ARGS $1"; shift ;;
    esac
done

# Find glances binary
GLANCES_BIN=""
if command -v glances &>/dev/null; then
    GLANCES_BIN="glances"
elif [ -f "$HOME/.local/bin/glances" ]; then
    GLANCES_BIN="$HOME/.local/bin/glances"
else
    echo "❌ Glances not found. Run: bash scripts/install.sh"
    exit 1
fi

# Build command
CMD="$GLANCES_BIN --time $REFRESH"

case $MODE in
    web)
        CMD="$CMD -w -p $PORT -B $BIND"
        echo "🌐 Starting Glances web dashboard on http://$BIND:$PORT"
        ;;
    server)
        CMD="$CMD -s -B $BIND -p $PORT"
        echo "📡 Starting Glances server on $BIND:$PORT"
        ;;
    terminal)
        echo "📊 Starting Glances terminal dashboard"
        ;;
esac

if [ -n "$CONFIG" ]; then
    CMD="$CMD -C $CONFIG"
fi

if [ "$DOCKER" = true ]; then
    CMD="$CMD --enable-plugin docker"
fi

if [ -n "$PASSWORD" ]; then
    CMD="$CMD --password"
    export GLANCES_PASSWORD="$PASSWORD"
fi

if [ -n "$EXPORT" ]; then
    CMD="$CMD --export $EXPORT"
    if [ -n "$EXPORT_FILE" ] && [ "$EXPORT" = "csv" ]; then
        CMD="$CMD --export-csv-file $EXPORT_FILE"
    fi
fi

CMD="$CMD $EXTRA_ARGS"

echo "Running: $CMD"
echo "Press Ctrl+C to stop"
echo ""

exec $CMD
