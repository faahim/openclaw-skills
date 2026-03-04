#!/bin/bash
# Graphviz Diagram Renderer
# Renders DOT files to PNG/SVG/PDF with templates and batch support
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

# Defaults
FORMAT="png"
DPI=150
OUTPUT=""
ENGINE="dot"
THEME=""
BG=""
BATCH_DIR=""
WATCH_DIR=""
OUTPUT_DIR="."
TEMPLATE=""
VARS=""
LIST_TEMPLATES=false

usage() {
  cat <<EOF
Usage: render.sh [OPTIONS] [< input.dot]

Options:
  --format FORMAT     Output format: png, svg, pdf (default: png)
  --dpi DPI           Resolution for raster formats (default: 150)
  --output FILE       Output file path
  --engine ENGINE     Layout engine: dot, neato, fdp, sfdp, circo, twopi (default: dot)
  --theme THEME       Color theme: light, dark, minimal
  --bg COLOR          Background color (hex, e.g. "#ffffff")
  --template NAME     Use a built-in template
  --var "KEY=VALUE"   Set template variable (repeatable)
  --list-templates    List available templates
  --batch DIR         Render all .dot files in directory
  --watch DIR         Watch directory and auto-render on changes
  --output-dir DIR    Output directory for batch/watch (default: .)
  --type TYPE         Alias for documentation (ignored by renderer)
  -h, --help          Show this help

Examples:
  echo 'digraph { A -> B }' | bash render.sh --output simple.png
  bash render.sh --template microservices --var "services=A,B,C" --output arch.png
  bash render.sh --batch ./diagrams/ --format svg --output-dir ./images/
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --format) FORMAT="$2"; shift 2 ;;
    --dpi) DPI="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --engine) ENGINE="$2"; shift 2 ;;
    --theme) THEME="$2"; shift 2 ;;
    --bg) BG="$2"; shift 2 ;;
    --template) TEMPLATE="$2"; shift 2 ;;
    --var) VARS="$VARS|$2"; shift 2 ;;
    --list-templates) LIST_TEMPLATES=true; shift ;;
    --batch) BATCH_DIR="$2"; shift 2 ;;
    --watch) WATCH_DIR="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --type) shift 2 ;;  # Ignored, for SKILL.md documentation clarity
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Check graphviz installed
if ! command -v dot &>/dev/null; then
  echo "❌ Graphviz not installed. Run: bash scripts/install.sh"
  exit 1
fi

# List templates
if [ "$LIST_TEMPLATES" = true ]; then
  echo "📋 Available templates:"
  if [ -d "$TEMPLATE_DIR" ]; then
    for tmpl in "$TEMPLATE_DIR"/*.dot; do
      [ -f "$tmpl" ] || continue
      name=$(basename "$tmpl" .dot)
      desc=$(head -1 "$tmpl" | sed 's|^// *||')
      printf "  %-20s %s\n" "$name" "$desc"
    done
  else
    echo "  No templates found. Create them in $TEMPLATE_DIR/"
  fi
  exit 0
fi

# Apply theme to DOT content
apply_theme() {
  local dot_content="$1"
  local themed="$dot_content"
  
  case "$THEME" in
    dark)
      # Inject dark theme attributes after first {
      themed=$(echo "$themed" | sed 's/{/{\n  bgcolor="#1e1e2e"\n  node [fontcolor="#cdd6f4" color="#585b70" fillcolor="#313244" style=filled fontname="Arial"]\n  edge [color="#585b70" fontcolor="#a6adc8" fontname="Arial"]/')
      ;;
    minimal)
      themed=$(echo "$themed" | sed 's/{/{\n  node [shape=plaintext fontname="Helvetica" fontsize=11]\n  edge [arrowsize=0.7 color="#94a3b8" fontname="Helvetica" fontsize=9]/')
      ;;
    light)
      themed=$(echo "$themed" | sed 's/{/{\n  bgcolor="#ffffff"\n  node [fillcolor="#f1f5f9" style=filled fontname="Arial" color="#cbd5e1"]\n  edge [color="#94a3b8" fontname="Arial"]/')
      ;;
  esac
  
  if [ -n "$BG" ]; then
    if echo "$themed" | grep -q 'bgcolor='; then
      themed=$(echo "$themed" | sed "s/bgcolor=\"[^\"]*\"/bgcolor=\"$BG\"/")
    else
      themed=$(echo "$themed" | sed "s/{/{\n  bgcolor=\"$BG\"/")
    fi
  fi
  
  echo "$themed"
}

# Render a single DOT string to file
render_dot() {
  local dot_content="$1"
  local outfile="$2"
  
  # Apply theme
  dot_content=$(apply_theme "$dot_content")
  
  # Build graphviz command
  local cmd="$ENGINE -T$FORMAT"
  [ "$FORMAT" = "png" ] && cmd="$cmd -Gdpi=$DPI"
  
  echo "$dot_content" | $cmd -o "$outfile"
  
  local size=$(du -h "$outfile" | cut -f1)
  echo "✅ Rendered: $outfile ($size, ${FORMAT^^})"
}

# Template rendering
if [ -n "$TEMPLATE" ]; then
  TMPL_FILE="$TEMPLATE_DIR/${TEMPLATE}.dot"
  if [ ! -f "$TMPL_FILE" ]; then
    echo "❌ Template not found: $TEMPLATE"
    echo "Available templates:"
    ls "$TEMPLATE_DIR"/*.dot 2>/dev/null | xargs -I{} basename {} .dot | sed 's/^/  /'
    exit 1
  fi
  
  DOT_CONTENT=$(cat "$TMPL_FILE")
  
  # Substitute variables
  IFS='|' read -ra VAR_PAIRS <<< "$VARS"
  for pair in "${VAR_PAIRS[@]}"; do
    [ -z "$pair" ] && continue
    key="${pair%%=*}"
    value="${pair#*=}"
    DOT_CONTENT=$(echo "$DOT_CONTENT" | sed "s|{{${key}}}|${value}|g")
  done
  
  [ -z "$OUTPUT" ] && OUTPUT="${TEMPLATE}.${FORMAT}"
  render_dot "$DOT_CONTENT" "$OUTPUT"
  exit 0
fi

# Batch rendering
if [ -n "$BATCH_DIR" ]; then
  if [ ! -d "$BATCH_DIR" ]; then
    echo "❌ Directory not found: $BATCH_DIR"
    exit 1
  fi
  
  mkdir -p "$OUTPUT_DIR"
  count=0
  
  for dotfile in "$BATCH_DIR"/*.dot; do
    [ -f "$dotfile" ] || continue
    name=$(basename "$dotfile" .dot)
    outfile="$OUTPUT_DIR/${name}.${FORMAT}"
    dot_content=$(cat "$dotfile")
    render_dot "$dot_content" "$outfile"
    count=$((count + 1))
  done
  
  echo "📊 Rendered $count diagrams to $OUTPUT_DIR/"
  exit 0
fi

# Watch mode
if [ -n "$WATCH_DIR" ]; then
  if ! command -v inotifywait &>/dev/null; then
    echo "❌ inotifywait not found. Install: sudo apt-get install inotify-tools"
    exit 1
  fi
  
  mkdir -p "$OUTPUT_DIR"
  echo "👀 Watching $WATCH_DIR for .dot file changes (Ctrl+C to stop)..."
  
  # Initial render
  for dotfile in "$WATCH_DIR"/*.dot; do
    [ -f "$dotfile" ] || continue
    name=$(basename "$dotfile" .dot)
    render_dot "$(cat "$dotfile")" "$OUTPUT_DIR/${name}.${FORMAT}"
  done
  
  # Watch for changes
  inotifywait -m -e modify -e create --include '\.dot$' "$WATCH_DIR" |
  while read -r dir event file; do
    name=$(basename "$file" .dot)
    echo "🔄 Change detected: $file"
    render_dot "$(cat "$WATCH_DIR/$file")" "$OUTPUT_DIR/${name}.${FORMAT}"
  done
  exit 0
fi

# Single file from stdin
DOT_CONTENT=$(cat)

if [ -z "$DOT_CONTENT" ]; then
  echo "❌ No DOT input provided. Pipe DOT content or use --template."
  usage
fi

[ -z "$OUTPUT" ] && OUTPUT="diagram.${FORMAT}"
render_dot "$DOT_CONTENT" "$OUTPUT"
