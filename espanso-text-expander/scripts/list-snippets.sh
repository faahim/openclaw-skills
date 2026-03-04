#!/bin/bash
set -euo pipefail

SEARCH="${1:-}"
SHOW_FILE=false

# Parse flags
while [[ $# -gt 0 ]]; do
    case $1 in
        --search) SEARCH="$2"; shift 2 ;;
        --file) SHOW_FILE=true; shift ;;
        *) [ -z "$SEARCH" ] && SEARCH="$1"; shift ;;
    esac
done

# Find config dir
CONFIG_DIR="${ESPANSO_CONFIG:-}"
if [ -z "$CONFIG_DIR" ]; then
    if command -v espanso &>/dev/null; then
        CONFIG_DIR="$(espanso path config 2>/dev/null || echo "")"
    fi
fi
[ -z "$CONFIG_DIR" ] && CONFIG_DIR="$HOME/.config/espanso"

MATCH_DIR="$CONFIG_DIR/match"

if [ ! -d "$MATCH_DIR" ]; then
    echo "No snippets found. Config dir: $CONFIG_DIR"
    exit 0
fi

echo "📝 Espanso Snippets"
echo "==================="
echo ""

COUNT=0

for file in "$MATCH_DIR"/*.yml; do
    [ ! -f "$file" ] && continue
    BASENAME=$(basename "$file" .yml)
    
    # Extract triggers and replacements
    while IFS= read -r line; do
        if [[ "$line" =~ trigger:\ *\"?([^\"]*)\"? ]]; then
            TRIGGER="${BASH_REMATCH[1]}"
            # Read next line for replace
            read -r next_line || true
            if [[ "$next_line" =~ replace:\ *\"?([^\"]*)\"? ]]; then
                REPLACE="${BASH_REMATCH[1]}"
                # Truncate long replacements
                [ ${#REPLACE} -gt 60 ] && REPLACE="${REPLACE:0:60}..."
                
                # Filter by search
                if [ -n "$SEARCH" ]; then
                    if [[ ! "$TRIGGER" == *"$SEARCH"* ]] && [[ ! "$REPLACE" == *"$SEARCH"* ]]; then
                        continue
                    fi
                fi
                
                COUNT=$((COUNT + 1))
                if $SHOW_FILE; then
                    printf "  %-15s → %-50s [%s]\n" "$TRIGGER" "$REPLACE" "$BASENAME"
                else
                    printf "  %-15s → %s\n" "$TRIGGER" "$REPLACE"
                fi
            fi
        fi
    done < "$file"
done

echo ""
echo "Total: $COUNT snippets"
[ -n "$SEARCH" ] && echo "Filter: '$SEARCH'"
