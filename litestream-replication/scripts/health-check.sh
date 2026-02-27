#!/bin/bash
set -euo pipefail

# Health check for Litestream replication
# Usage: bash health-check.sh [config-path]

CONFIG="${1:-/etc/litestream.yml}"
EXIT_CODE=0

echo "🔍 Litestream Health Check"
echo "=========================="
echo ""

# Check if litestream is installed
if ! command -v litestream &>/dev/null; then
  echo "❌ Litestream not installed"
  exit 1
fi
echo "✅ Litestream $(litestream version)"

# Check if process is running
if pgrep -x litestream > /dev/null; then
  PID=$(pgrep -x litestream)
  UPTIME=$(ps -o etime= -p "$PID" | xargs)
  echo "✅ Process running (PID: $PID, uptime: $UPTIME)"
else
  echo "❌ Litestream process not running"
  EXIT_CODE=1
fi

# Check if systemd service exists and is active
if systemctl is-active --quiet litestream 2>/dev/null; then
  echo "✅ Systemd service active"
elif systemctl is-enabled --quiet litestream 2>/dev/null; then
  echo "⚠️ Systemd service enabled but not active"
  EXIT_CODE=1
else
  echo "ℹ️ No systemd service (running manually or via Docker)"
fi

# Check config
if [ -f "$CONFIG" ]; then
  echo "✅ Config found at $CONFIG"
  
  # Count databases being replicated
  DB_COUNT=$(grep -c "^  - path:" "$CONFIG" 2>/dev/null || echo "0")
  echo "   📊 Databases configured: $DB_COUNT"
else
  echo "❌ Config not found at $CONFIG"
  EXIT_CODE=1
fi

# Check generations for each database
if [ -f "$CONFIG" ]; then
  echo ""
  echo "📋 Replica Status:"
  
  # Extract database paths from config
  grep "^  - path:" "$CONFIG" 2>/dev/null | sed 's/.*path: //' | while read -r DB_PATH; do
    if [ -f "$DB_PATH" ]; then
      DB_SIZE=$(du -h "$DB_PATH" | cut -f1)
      echo "   📁 $DB_PATH ($DB_SIZE)"
      
      # Check WAL mode
      JOURNAL=$(sqlite3 "$DB_PATH" "PRAGMA journal_mode;" 2>/dev/null || echo "error")
      if [ "$JOURNAL" = "wal" ]; then
        echo "      ✅ WAL mode enabled"
      else
        echo "      ❌ Not in WAL mode (current: $JOURNAL)"
      fi
      
      # Check generations
      GEN_OUTPUT=$(litestream generations -config "$CONFIG" "$DB_PATH" 2>&1 || true)
      GEN_COUNT=$(echo "$GEN_OUTPUT" | grep -c "^" || echo "0")
      if [ "$GEN_COUNT" -gt 1 ]; then
        echo "      ✅ $((GEN_COUNT - 1)) generation(s) found"
      else
        echo "      ⚠️ No generations found (new or not replicating)"
      fi
    else
      echo "   ❌ $DB_PATH does not exist"
    fi
  done
fi

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ All checks passed"
else
  echo "⚠️ Some checks failed (exit code: $EXIT_CODE)"
fi

exit $EXIT_CODE
