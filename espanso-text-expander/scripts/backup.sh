#!/bin/bash
set -euo pipefail

BACKUP_DIR="${1:-$HOME/.espanso-backups}"

CONFIG_DIR="${ESPANSO_CONFIG:-}"
if [ -z "$CONFIG_DIR" ]; then
    if command -v espanso &>/dev/null; then
        CONFIG_DIR="$(espanso path config 2>/dev/null || echo "")"
    fi
fi
[ -z "$CONFIG_DIR" ] && CONFIG_DIR="$HOME/.config/espanso"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "❌ Espanso config not found at: $CONFIG_DIR"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DEST="$BACKUP_DIR/espanso_$TIMESTAMP"

mkdir -p "$DEST"
cp -r "$CONFIG_DIR"/* "$DEST/"

# Count snippets
SNIPPET_COUNT=$(grep -r "trigger:" "$DEST" 2>/dev/null | wc -l)
FILE_COUNT=$(find "$DEST" -name "*.yml" | wc -l)

echo "✅ Backup created: $DEST"
echo "   Files: $FILE_COUNT"
echo "   Snippets: $SNIPPET_COUNT"

# Cleanup old backups (keep last 10)
ls -dt "$BACKUP_DIR"/espanso_* 2>/dev/null | tail -n +11 | xargs rm -rf 2>/dev/null || true
