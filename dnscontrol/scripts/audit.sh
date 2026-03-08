#!/bin/bash
# Audit DNS configuration — detect drift between config and live records
set -euo pipefail

LOG_DIR="${LOG_DIR:-./logs}"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG_FILE="${LOG_DIR}/audit-$(date -u +%Y%m%d).log"

echo "🔍 DNS Audit — ${TIMESTAMP}" | tee -a "$LOG_FILE"
echo "---" | tee -a "$LOG_FILE"

# Validate config syntax first
echo "Checking config syntax..." | tee -a "$LOG_FILE"
if ! dnscontrol check 2>&1 | tee -a "$LOG_FILE"; then
    echo "❌ Config validation failed!" | tee -a "$LOG_FILE"
    exit 1
fi
echo "✅ Config syntax OK" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Preview changes (drift detection)
echo "Checking for drift..." | tee -a "$LOG_FILE"
PREVIEW_OUTPUT=$(dnscontrol preview 2>&1)
echo "$PREVIEW_OUTPUT" | tee -a "$LOG_FILE"

# Count corrections needed
CORRECTIONS=$(echo "$PREVIEW_OUTPUT" | grep -c "correction" || true)

echo "" | tee -a "$LOG_FILE"
if [ "$CORRECTIONS" -eq 0 ]; then
    echo "✅ No drift detected — DNS is in sync with config" | tee -a "$LOG_FILE"
else
    echo "⚠️  ${CORRECTIONS} correction(s) needed — DNS has drifted from config" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Run 'dnscontrol push' to sync, or update dnsconfig.js to match live state." | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "Audit log: ${LOG_FILE}" | tee -a "$LOG_FILE"
