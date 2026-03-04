#!/bin/bash
set -euo pipefail

TRIGGER="${1:-}"
FILE="${2:-}"

if [ -z "$TRIGGER" ]; then
    echo "Usage: bash scripts/remove-snippet.sh <trigger> [file]"
    exit 1
fi

CONFIG_DIR="${ESPANSO_CONFIG:-}"
if [ -z "$CONFIG_DIR" ]; then
    if command -v espanso &>/dev/null; then
        CONFIG_DIR="$(espanso path config 2>/dev/null || echo "")"
    fi
fi
[ -z "$CONFIG_DIR" ] && CONFIG_DIR="$HOME/.config/espanso"

MATCH_DIR="$CONFIG_DIR/match"

if [ -n "$FILE" ]; then
    FILES=("$MATCH_DIR/${FILE}.yml")
else
    FILES=("$MATCH_DIR"/*.yml)
fi

FOUND=false

for file in "${FILES[@]}"; do
    [ ! -f "$file" ] && continue
    
    if grep -q "trigger: \"$TRIGGER\"" "$file" 2>/dev/null; then
        # Use python for safe YAML manipulation if available
        if command -v python3 &>/dev/null; then
            python3 -c "
import yaml, sys

with open('$file', 'r') as f:
    data = yaml.safe_load(f)

if data and 'matches' in data:
    data['matches'] = [m for m in data['matches'] if m.get('trigger') != '$TRIGGER']
    
    with open('$file', 'w') as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
    print('✅ Removed: $TRIGGER from $(basename "$file")')
else:
    print('⚠️  No matches found in $(basename "$file")')
" 2>/dev/null && FOUND=true && break
        fi
        
        # Fallback: use sed (less safe but works)
        # Remove the trigger block (trigger line + next replace line)
        sed -i "/trigger: \"$TRIGGER\"/,+1d" "$file"
        echo "✅ Removed: $TRIGGER from $(basename "$file")"
        FOUND=true
        break
    fi
done

if ! $FOUND; then
    echo "⚠️  Trigger '$TRIGGER' not found"
    exit 1
fi

if command -v espanso &>/dev/null && espanso status 2>/dev/null | grep -q "running"; then
    espanso restart 2>/dev/null && echo "🔄 Espanso restarted" || true
fi
