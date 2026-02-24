#!/bin/bash
# Add log source to CrowdSec acquisition
# Usage: bash add-log.sh <log-path> <type>
set -euo pipefail

LOG_PATH="${1:-}"
LOG_TYPE="${2:-}"

if [ -z "$LOG_PATH" ] || [ -z "$LOG_TYPE" ]; then
    echo "Usage: bash add-log.sh <log-path> <type>"
    echo ""
    echo "Types: syslog, nginx, apache2, mysql, postgresql, haproxy"
    echo "Example: bash add-log.sh /var/log/nginx/access.log nginx"
    exit 1
fi

if [ ! -f "$LOG_PATH" ] && ! ls $LOG_PATH &>/dev/null; then
    echo "⚠️  Log path not found: $LOG_PATH"
    echo "   Proceeding anyway (file may be created later)"
fi

ACQUIS_FILE="/etc/crowdsec/acquis.yaml"

# Check if already configured
if grep -q "$LOG_PATH" "$ACQUIS_FILE" 2>/dev/null; then
    echo "⚠️  $LOG_PATH already in acquisitions"
    exit 0
fi

# Append new acquisition
sudo tee -a "$ACQUIS_FILE" > /dev/null <<EOF
---
filenames:
  - $LOG_PATH
labels:
  type: $LOG_TYPE
EOF

# Install matching collection if available
echo "📚 Installing collection for $LOG_TYPE..."
sudo cscli collections install "crowdsecurity/$LOG_TYPE" 2>/dev/null || \
    echo "⚠️  No collection found for '$LOG_TYPE' — make sure parsers are installed"

sudo systemctl reload crowdsec
echo "✅ Added $LOG_PATH (type: $LOG_TYPE) to CrowdSec acquisitions"
