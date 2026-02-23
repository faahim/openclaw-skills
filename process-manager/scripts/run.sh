#!/bin/bash
# Process Manager — Wrapper around PM2 with convenience features
set -e

# Check PM2 installed
if ! command -v pm2 &>/dev/null; then
  echo "❌ PM2 not installed. Run: bash scripts/install.sh"
  exit 1
fi

ACTION="${1:-status}"
shift 2>/dev/null || true

case "$ACTION" in
  start)
    NAME=""
    CMD=""
    CWD=""
    ENV_VARS=""
    MAX_MEMORY=""
    INSTANCES=""
    WATCH=""
    CRON=""

    while [[ $# -gt 0 ]]; do
      case $1 in
        --name) NAME="$2"; shift 2 ;;
        --cmd) CMD="$2"; shift 2 ;;
        --cwd) CWD="$2"; shift 2 ;;
        --env) ENV_VARS="$2"; shift 2 ;;
        --max-memory) MAX_MEMORY="$2"; shift 2 ;;
        --instances) INSTANCES="$2"; shift 2 ;;
        --watch) WATCH="true"; shift ;;
        --cron) CRON="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
      esac
    done

    if [[ -z "$CMD" ]]; then
      echo "Usage: $0 start --name <name> --cmd <command> [--cwd <dir>] [--env KEY=VAL,KEY2=VAL2] [--max-memory <MB>] [--instances <N>] [--watch] [--cron <expr>]"
      exit 1
    fi

    PM2_ARGS=""
    [[ -n "$NAME" ]] && PM2_ARGS="$PM2_ARGS --name \"$NAME\""
    [[ -n "$CWD" ]] && PM2_ARGS="$PM2_ARGS --cwd \"$CWD\""
    [[ -n "$MAX_MEMORY" ]] && PM2_ARGS="$PM2_ARGS --max-memory-restart ${MAX_MEMORY}M"
    [[ -n "$INSTANCES" ]] && PM2_ARGS="$PM2_ARGS -i $INSTANCES"
    [[ -n "$WATCH" ]] && PM2_ARGS="$PM2_ARGS --watch"
    [[ -n "$CRON" ]] && PM2_ARGS="$PM2_ARGS --cron-restart \"$CRON\""

    # Handle env vars
    if [[ -n "$ENV_VARS" ]]; then
      IFS=',' read -ra PAIRS <<< "$ENV_VARS"
      for pair in "${PAIRS[@]}"; do
        key="${pair%%=*}"
        val="${pair#*=}"
        export "$key"="$val"
      done
    fi

    eval pm2 start "$CMD" $PM2_ARGS
    echo ""
    pm2 save --force 2>/dev/null || true
    echo "✅ Process started and saved."
    ;;

  stop)
    PROC="${1:-all}"
    pm2 stop "$PROC"
    echo "✅ Stopped: $PROC"
    ;;

  restart)
    PROC="${1:-all}"
    pm2 restart "$PROC"
    echo "✅ Restarted: $PROC"
    ;;

  reload)
    PROC="${1:-all}"
    pm2 reload "$PROC"
    echo "✅ Reloaded: $PROC (zero-downtime)"
    ;;

  delete)
    PROC="${1:?Usage: $0 delete <name|id>}"
    pm2 delete "$PROC"
    pm2 save --force 2>/dev/null || true
    echo "✅ Deleted: $PROC"
    ;;

  status)
    pm2 status
    ;;

  logs)
    PROC="${1:-}"
    LINES=""
    [[ "$2" == "--lines" ]] && LINES="--lines $3"
    if [[ -n "$PROC" ]]; then
      eval pm2 logs "$PROC" $LINES --nostream 2>/dev/null || pm2 logs "$PROC" $LINES
    else
      pm2 logs --nostream --lines 50 2>/dev/null || pm2 logs
    fi
    ;;

  flush)
    PROC="${1:-all}"
    pm2 flush "$PROC"
    echo "✅ Logs flushed: $PROC"
    ;;

  monit)
    pm2 monit
    ;;

  describe)
    PROC="${1:?Usage: $0 describe <name|id>}"
    pm2 describe "$PROC"
    ;;

  save)
    pm2 save --force
    echo "✅ Process list saved (will restore on reboot)."
    ;;

  startup)
    pm2 startup
    echo ""
    echo "⚠️  Run the sudo command above if prompted, then: pm2 save"
    ;;

  ecosystem)
    CONFIG="${1:?Usage: $0 ecosystem <config-file>}"
    pm2 start "$CONFIG"
    pm2 save --force 2>/dev/null || true
    echo "✅ Ecosystem started from $CONFIG"
    ;;

  *)
    echo "Process Manager — PM2 Wrapper"
    echo ""
    echo "Usage: $0 <action> [options]"
    echo ""
    echo "Actions:"
    echo "  start       Start a process (--name, --cmd, --cwd, --env, --max-memory, --instances, --watch, --cron)"
    echo "  stop        Stop a process (name or 'all')"
    echo "  restart     Restart a process"
    echo "  reload      Zero-downtime reload (cluster mode)"
    echo "  delete      Remove a process from PM2"
    echo "  status      List all managed processes"
    echo "  logs        View process logs"
    echo "  flush       Clear log files"
    echo "  monit       Real-time monitoring dashboard"
    echo "  describe    Detailed process info"
    echo "  save        Persist process list for reboot"
    echo "  startup     Generate boot startup script"
    echo "  ecosystem   Start from ecosystem config file"
    exit 1
    ;;
esac
