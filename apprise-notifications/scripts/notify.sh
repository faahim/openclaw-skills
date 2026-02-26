#!/bin/bash
# Quick notification sender — supports stdin piping
# Usage: 
#   notify.sh --tag team --title "Deploy" --body "Done"
#   echo "output" | notify.sh --tag team --title "Result"
set -e

TAG="personal"
TITLE="Notification"
BODY=""
CONFIG="${APPRISE_CONFIG:-$HOME/.apprise.yml}"
FORMAT="text"

while [[ $# -gt 0 ]]; do
  case $1 in
    --tag|-t) TAG="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --body|-b) BODY="$2"; shift 2 ;;
    --config|-c) CONFIG="$2"; shift 2 ;;
    --html) FORMAT="html"; shift ;;
    --attach|-a) ATTACH="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# Read from stdin if no body provided
if [[ -z "$BODY" ]]; then
  if [ ! -t 0 ]; then
    BODY=$(cat)
  else
    echo "❌ No body provided. Use --body or pipe stdin."
    exit 1
  fi
fi

CMD=(apprise --config="$CONFIG" --tag="$TAG" -t "$TITLE" -b "$BODY" --input-format="$FORMAT")
[[ -n "$ATTACH" ]] && CMD+=(--attach="$ATTACH")

"${CMD[@]}" 2>/dev/null && echo "✅ Sent to [$TAG]" || echo "⚠️ No services matched tag '$TAG'"
