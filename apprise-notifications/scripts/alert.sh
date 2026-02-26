#!/bin/bash
# Severity-based multi-channel alert router
# Usage: alert.sh <severity> <title> <body>
#   severity: info | warning | critical
set -e

SEVERITY="${1:-info}"
TITLE="${2:-Alert}"
BODY="${3:-No details provided}"
CONFIG="${APPRISE_CONFIG:-$HOME/.apprise.yml}"

if ! command -v apprise &>/dev/null; then
  echo "❌ Apprise not installed. Run: pip3 install apprise"
  exit 1
fi

if [ ! -f "$CONFIG" ]; then
  echo "❌ No config at $CONFIG. Run scripts/install.sh first."
  exit 1
fi

case "$SEVERITY" in
  info)
    apprise --config="$CONFIG" --tag=team \
      -t "ℹ️ $TITLE" -b "$BODY" 2>/dev/null && \
      echo "✅ Info alert sent to team" || echo "⚠️ No 'team' tagged services configured"
    ;;
  warning)
    apprise --config="$CONFIG" --tag=team,email \
      -t "⚠️ $TITLE" -b "$BODY" 2>/dev/null && \
      echo "✅ Warning sent to team + email" || echo "⚠️ No 'team'/'email' tagged services"
    ;;
  critical)
    apprise --config="$CONFIG" --tag=team,email,urgent \
      -t "🚨 $TITLE" -b "$BODY" 2>/dev/null && \
      echo "✅ Critical alert sent to team + email + urgent" || echo "⚠️ No tagged services"
    ;;
  *)
    echo "Usage: $0 <info|warning|critical> <title> <body>"
    exit 1
    ;;
esac
