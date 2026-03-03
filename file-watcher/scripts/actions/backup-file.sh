#!/bin/bash
# Create timestamped backup of a file
set -euo pipefail

FILE="${1:-$WATCH_FILE}"
[[ -f "$FILE" ]] || { echo "File not found: $FILE"; exit 1; }

TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
BACKUP="${FILE}.${TIMESTAMP}.bak"

cp "$FILE" "$BACKUP"
echo "💾 Backup: $BACKUP"
