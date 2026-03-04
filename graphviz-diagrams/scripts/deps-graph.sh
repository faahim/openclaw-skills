#!/bin/bash
# Generate dependency graphs from package.json or requirements.txt
set -e

INPUT=""
OUTPUT="deps.png"
FORMAT="png"
DPI=150
ENGINE="dot"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [[ $# -gt 0 ]]; do
  case $1 in
    --input) INPUT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --dpi) DPI="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$INPUT" ] || [ ! -f "$INPUT" ]; then
  echo "❌ Input file required: --input <package.json|requirements.txt|go.mod|Cargo.toml>"
  exit 1
fi

FILENAME=$(basename "$INPUT")
DOT=""

case "$FILENAME" in
  package.json)
    if ! command -v jq &>/dev/null; then
      echo "❌ jq required for package.json parsing. Install: sudo apt-get install jq"
      exit 1
    fi
    
    PKG_NAME=$(jq -r '.name // "project"' "$INPUT")
    
    DOT="digraph deps {
  rankdir=LR
  node [shape=box style=\"filled,rounded\" fontname=\"Arial\" fontsize=10]
  edge [color=\"#94a3b8\"]
  
  \"$PKG_NAME\" [fillcolor=\"#93c5fd\" fontsize=12 penwidth=2]
"
    
    # Dependencies
    DEPS=$(jq -r '.dependencies // {} | keys[]' "$INPUT" 2>/dev/null)
    if [ -n "$DEPS" ]; then
      DOT+="  subgraph cluster_deps {
    label=\"dependencies\" style=filled fillcolor=\"#f0fdf4\"
"
      while IFS= read -r dep; do
        DOT+="    \"$dep\" [fillcolor=\"#86efac\"]
"
      done <<< "$DEPS"
      DOT+="  }
"
      while IFS= read -r dep; do
        DOT+="  \"$PKG_NAME\" -> \"$dep\"
"
      done <<< "$DEPS"
    fi
    
    # Dev dependencies
    DEV_DEPS=$(jq -r '.devDependencies // {} | keys[]' "$INPUT" 2>/dev/null)
    if [ -n "$DEV_DEPS" ]; then
      DOT+="  subgraph cluster_devdeps {
    label=\"devDependencies\" style=filled fillcolor=\"#fef9c3\"
"
      while IFS= read -r dep; do
        DOT+="    \"$dep\" [fillcolor=\"#fde68a\"]
"
      done <<< "$DEV_DEPS"
      DOT+="  }
"
      while IFS= read -r dep; do
        DOT+="  \"$PKG_NAME\" -> \"$dep\" [style=dashed]
"
      done <<< "$DEV_DEPS"
    fi
    
    DOT+="}"
    ;;
    
  requirements*.txt)
    DOT="digraph deps {
  rankdir=LR
  node [shape=box style=\"filled,rounded\" fontname=\"Arial\" fontsize=10 fillcolor=\"#dbeafe\"]
  edge [color=\"#94a3b8\"]
  
  project [label=\"Project\" fillcolor=\"#93c5fd\" fontsize=12 penwidth=2]
"
    while IFS= read -r line; do
      # Skip comments and empty lines
      [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
      # Extract package name (before ==, >=, <=, ~=, etc.)
      pkg=$(echo "$line" | sed 's/[><=~!].*//' | sed 's/\[.*//' | xargs)
      [ -z "$pkg" ] && continue
      DOT+="  \"$pkg\" [fillcolor=\"#86efac\"]
  project -> \"$pkg\"
"
    done < "$INPUT"
    DOT+="}"
    ;;
    
  *)
    echo "❌ Unsupported file format: $FILENAME"
    echo "Supported: package.json, requirements.txt"
    exit 1
    ;;
esac

# Render
echo "$DOT" | $ENGINE -T$FORMAT -Gdpi=$DPI -o "$OUTPUT"
SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "✅ Dependency graph: $OUTPUT ($SIZE)"
