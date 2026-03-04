#!/bin/bash
set -e
CONTAINER="${GOTENBERG_CONTAINER:-gotenberg}"
echo "🛑 Stopping Gotenberg..."
docker rm -f "$CONTAINER" >/dev/null 2>&1 && echo "✅ Stopped." || echo "⚠️  Container not running."
