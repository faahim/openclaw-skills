#!/bin/bash
# Ebook metadata viewer/editor using Calibre's ebook-meta
set -e

if ! command -v ebook-meta &>/dev/null; then
  echo "❌ ebook-meta not found. Run: bash scripts/install.sh"
  exit 1
fi

ACTION="${1:-}"
shift 2>/dev/null || true

usage() {
  cat <<EOF
Usage:
  $(basename "$0") info <file>
  $(basename "$0") set <file> [--title T] [--author A] [--cover C] [--tags T] [--series S] [--series-index N]
  $(basename "$0") extract-cover <file> <output.jpg>
  $(basename "$0") batch <dir> [--author A] [--tags T] [--publisher P]
EOF
  exit 1
}

case "$ACTION" in
  info)
    FILE="$1"
    [[ -z "$FILE" || ! -f "$FILE" ]] && { echo "❌ File required"; exit 1; }
    
    echo "📖 Metadata: $(basename "$FILE")"
    ebook-meta "$FILE" 2>/dev/null | while IFS= read -r line; do
      echo "   $line"
    done
    SIZE=$(du -h "$FILE" | cut -f1)
    echo "   Size:      $SIZE"
    ;;
    
  set)
    FILE="$1"; shift
    [[ -z "$FILE" || ! -f "$FILE" ]] && { echo "❌ File required"; exit 1; }
    
    ARGS=()
    while [[ $# -gt 0 ]]; do
      case $1 in
        --title) ARGS+=("--title=$2"); shift 2 ;;
        --author) ARGS+=("--authors=$2"); shift 2 ;;
        --cover) ARGS+=("--cover=$2"); shift 2 ;;
        --tags) ARGS+=("--tags=$2"); shift 2 ;;
        --series) ARGS+=("--series=$2"); shift 2 ;;
        --series-index) ARGS+=("--index=$2"); shift 2 ;;
        --publisher) ARGS+=("--publisher=$2"); shift 2 ;;
        --date) ARGS+=("--date=$2"); shift 2 ;;
        --language) ARGS+=("--language=$2"); shift 2 ;;
        --isbn) ARGS+=("--isbn=$2"); shift 2 ;;
        *) shift ;;
      esac
    done
    
    [[ ${#ARGS[@]} -eq 0 ]] && { echo "❌ No metadata options provided"; usage; }
    
    echo "✏️  Updating metadata: $(basename "$FILE")"
    ebook-meta "$FILE" "${ARGS[@]}"
    echo "✅ Metadata updated"
    ;;
    
  extract-cover)
    FILE="$1"
    OUTPUT="${2:-cover.jpg}"
    [[ -z "$FILE" || ! -f "$FILE" ]] && { echo "❌ File required"; exit 1; }
    
    echo "🖼️  Extracting cover from: $(basename "$FILE")"
    ebook-meta "$FILE" --get-cover="$OUTPUT"
    if [[ -f "$OUTPUT" ]]; then
      echo "✅ Cover saved: $OUTPUT"
    else
      echo "❌ No cover found in ebook"
      exit 1
    fi
    ;;
    
  batch)
    DIR="$1"; shift
    [[ -z "$DIR" || ! -d "$DIR" ]] && { echo "❌ Directory required"; exit 1; }
    
    ARGS=()
    while [[ $# -gt 0 ]]; do
      case $1 in
        --author) ARGS+=("--authors=$2"); shift 2 ;;
        --tags) ARGS+=("--tags=$2"); shift 2 ;;
        --publisher) ARGS+=("--publisher=$2"); shift 2 ;;
        --language) ARGS+=("--language=$2"); shift 2 ;;
        *) shift ;;
      esac
    done
    
    [[ ${#ARGS[@]} -eq 0 ]] && { echo "❌ No metadata options provided"; usage; }
    
    COUNT=0
    for f in "$DIR"/*.{epub,mobi,azw3,pdf,fb2} 2>/dev/null; do
      [[ -f "$f" ]] || continue
      echo "✏️  $(basename "$f")"
      ebook-meta "$f" "${ARGS[@]}" >/dev/null 2>&1
      ((COUNT++))
    done
    
    echo "✅ Updated metadata for $COUNT files"
    ;;
    
  *)
    usage
    ;;
esac
