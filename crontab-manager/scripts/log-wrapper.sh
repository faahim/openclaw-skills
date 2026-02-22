#!/bin/bash
# Log wrapper for cron jobs — captures stdout, stderr, exit code, and duration
COMMAND="$1"
LOG_DIR="$2"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M)
LOG_FILE="$LOG_DIR/${TIMESTAMP}.log"

echo "# Command: $COMMAND" > "$LOG_FILE"
echo "# Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG_FILE"

START=$(date +%s)
eval "$COMMAND" >> "$LOG_FILE" 2>&1
CODE=$?
END=$(date +%s)
DURATION=$((END - START))

echo "" >> "$LOG_FILE"
echo "# Finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG_FILE"
echo "# Duration: ${DURATION}s" >> "$LOG_FILE"
echo "EXIT_CODE=$CODE" >> "$LOG_FILE"

# Prune logs older than retention
find "$LOG_DIR" -name "*.log" -mtime +${CRONTAB_MANAGER_LOG_DAYS:-90} -delete 2>/dev/null
