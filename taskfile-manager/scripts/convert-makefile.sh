#!/bin/bash
# Convert a Makefile to Taskfile.yml (best-effort)
set -euo pipefail

MAKEFILE="${1:-Makefile}"
OUTPUT="Taskfile.yml"

if [[ ! -f "$MAKEFILE" ]]; then
  echo "❌ Makefile not found: $MAKEFILE"
  exit 1
fi

if [[ -f "$OUTPUT" ]]; then
  echo "⚠️  Taskfile.yml already exists."
  read -r -p "Overwrite? [y/N] " REPLY
  [[ "$REPLY" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

echo "🔄 Converting $MAKEFILE → $OUTPUT"

# Start building Taskfile
cat > "$OUTPUT" << 'HEADER'
# Auto-generated from Makefile — review and adjust as needed
version: '3'

tasks:
HEADER

# Parse Makefile targets
CURRENT_TARGET=""
CURRENT_DESC=""
CURRENT_DEPS=""
IN_RECIPE=false

while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip empty lines outside recipes
  if [[ -z "$line" ]] && [[ "$IN_RECIPE" == "false" ]]; then
    continue
  fi

  # Comment before target = description
  if [[ "$line" =~ ^#[[:space:]]*(.*) ]] && [[ "$IN_RECIPE" == "false" ]]; then
    CURRENT_DESC="${BASH_REMATCH[1]}"
    continue
  fi

  # Target line: name: deps
  if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_.-]*)[[:space:]]*:[[:space:]]*(.*) ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
    TARGET="${BASH_REMATCH[1]}"
    DEPS="${BASH_REMATCH[2]}"

    # Skip .PHONY and similar
    [[ "$TARGET" =~ ^\. ]] && continue

    CURRENT_TARGET="$TARGET"
    CURRENT_DEPS="$DEPS"
    IN_RECIPE=true

    echo "  ${TARGET}:" >> "$OUTPUT"
    if [[ -n "$CURRENT_DESC" ]]; then
      echo "    desc: \"${CURRENT_DESC}\"" >> "$OUTPUT"
    fi
    if [[ -n "$DEPS" ]]; then
      # Convert space-separated deps to YAML list
      DEP_LIST=$(echo "$DEPS" | tr ' ' '\n' | grep -v '^\.' | sed 's/^/      - /' | head -10)
      if [[ -n "$DEP_LIST" ]]; then
        echo "    deps:" >> "$OUTPUT"
        echo "$DEP_LIST" >> "$OUTPUT"
      fi
    fi
    echo "    cmds:" >> "$OUTPUT"
    CURRENT_DESC=""
    continue
  fi

  # Recipe line (starts with tab or spaces)
  if [[ "$IN_RECIPE" == "true" ]] && [[ "$line" =~ ^[[:space:]]+(.*) ]]; then
    CMD="${BASH_REMATCH[1]}"
    # Strip leading @ (silent prefix in Make)
    CMD="${CMD#@}"
    # Escape single quotes for YAML
    CMD="${CMD//\'/\'\'}"
    echo "      - '${CMD}'" >> "$OUTPUT"
    continue
  fi

  # End of recipe
  if [[ "$IN_RECIPE" == "true" ]]; then
    IN_RECIPE=false
    echo "" >> "$OUTPUT"
  fi

done < "$MAKEFILE"

TARGETS=$(grep -c '^  [a-zA-Z]' "$OUTPUT" 2>/dev/null || echo "0")
echo ""
echo "✅ Converted ${TARGETS} targets to ${OUTPUT}"
echo "⚠️  Review the output — variable substitution (\$(VAR) → {{.VAR}}) needs manual adjustment"
echo ""
echo "Common manual fixes:"
echo "  \$(VAR)     → {{.VAR}}"
echo "  \$@         → (remove or replace with explicit name)"
echo "  \$<, \$^    → (replace with explicit file references)"
