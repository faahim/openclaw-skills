#!/bin/bash
set -euo pipefail

BACKUP_PATH="${1:-}"

if [ -z "$BACKUP_PATH" ]; then
    echo "Usage: bash scripts/restore.sh <backup-path>"
    echo ""
    # List available backups
    BACKUP_DIR="$HOME/.espanso-backups"
    if [ -d "$BACKUP_DIR" ]; then
        echo "Available backups:"
        ls -dt "$BACKUP_DIR"/espanso_* 2>/dev/null | while read -r dir; do
            COUNT=$(grep -r "trigger:" "$dir" 2>/dev/null | wc -l)
            echo "  $(basename "$dir") ($COUNT snippets)"
        done
    fi
    exit 1
fi

if [ ! -d "$BACKUP_PATH" ]; then
    echo "❌ Backup not found: $BACKUP_PATH"
    exit 1
fi

CONFIG_DIR="${ESPANSO_CONFIG:-}"
if [ -z "$CONFIG_DIR" ]; then
    if command -v espanso &>/dev/null; then
        CONFIG_DIR="$(espanso path config 2>/dev/null || echo "")"
    fi
fi
[ -z "$CONFIG_DIR" ] && CONFIG_DIR="$HOME/.config/espanso"

echo "⚠️  This will overwrite: $CONFIG_DIR"
read -p "Continue? [y/N] " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

# Backup current before restore
bash "$(dirname "$0")/backup.sh" 2>/dev/null || true

# Restore
mkdir -p "$CONFIG_DIR"
cp -r "$BACKUP_PATH"/* "$CONFIG_DIR/"

SNIPPET_COUNT=$(grep -r "trigger:" "$CONFIG_DIR" 2>/dev/null | wc -l)
echo "✅ Restored $SNIPPET_COUNT snippets from $(basename "$BACKUP_PATH")"

if command -v espanso &>/dev/null && espanso status 2>/dev/null | grep -q "running"; then
    espanso restart 2>/dev/null && echo "🔄 Espanso restarted" || true
fi
