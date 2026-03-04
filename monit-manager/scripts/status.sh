#!/bin/bash
# Show Monit status
set -e

ALL=false
[ "$1" = "--all" ] && ALL=true

if ! command -v monit &>/dev/null; then
  echo "❌ Monit not installed. Run: bash scripts/install.sh"
  exit 1
fi

if $ALL; then
  sudo monit status
else
  sudo monit summary 2>/dev/null || sudo monit status
fi
