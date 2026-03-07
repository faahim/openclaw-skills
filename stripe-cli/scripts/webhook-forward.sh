#!/bin/bash
# Stripe Webhook Forwarder — wraps `stripe listen` with logging and defaults
set -e

PORT=3000
PATH_SUFFIX="/api/webhooks/stripe"
EVENTS=""
CONNECT=false
LOG_FILE="$HOME/.stripe/webhook.log"

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --port PORT          Local server port (default: 3000)"
  echo "  --path PATH          Webhook endpoint path (default: /api/webhooks/stripe)"
  echo "  --events EVENTS      Comma-separated event filter (e.g. checkout.session.completed)"
  echo "  --connect            Enable Connect webhook forwarding"
  echo "  --log FILE           Log file path (default: ~/.stripe/webhook.log)"
  echo "  -h, --help           Show this help"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --port) PORT="$2"; shift 2 ;;
    --path) PATH_SUFFIX="$2"; shift 2 ;;
    --events) EVENTS="$2"; shift 2 ;;
    --connect) CONNECT=true; shift ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Ensure stripe CLI is available
if ! command -v stripe &>/dev/null; then
  echo "❌ Stripe CLI not found. Run: bash scripts/install.sh"
  exit 1
fi

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

FORWARD_URL="http://localhost:${PORT}${PATH_SUFFIX}"

echo "✅ Webhook forwarding active"
echo "🔗 Forwarding to: $FORWARD_URL"
echo "📝 Logging to: $LOG_FILE"
echo ""

# Build command
CMD="stripe listen --forward-to $FORWARD_URL"

if [[ -n "$EVENTS" ]]; then
  CMD="$CMD --events $EVENTS"
  echo "🎯 Filtering events: $EVENTS"
fi

if [[ "$CONNECT" == "true" ]]; then
  CMD="$CMD --forward-connect-to $FORWARD_URL"
  echo "🔌 Connect forwarding enabled"
fi

echo ""
echo "Ready. Listening for events... (Ctrl+C to stop)"
echo "---"

# Run with logging
$CMD 2>&1 | tee -a "$LOG_FILE"
