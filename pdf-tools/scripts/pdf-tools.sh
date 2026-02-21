#!/bin/bash
# PDF Tools — Main Script
# Merge, split, compress, extract text, rotate, watermark, and inspect PDFs.
set -euo pipefail

VERSION="1.0.0"
QUALITY="${PDF_TOOLS_QUALITY:-default}"

usage() {
  cat <<EOF
PDF Tools v${VERSION}

Usage: bash pdf-tools.sh <command> [options]

Commands:
  merge    <output.pdf> <input1.pdf> <input2.pdf> ...   Merge multiple PDFs
  split    <input.pdf> <output-dir/>                     Split into individual pages
  compress <input.pdf> <output.pdf> [--quality LEVEL]    Compress PDF
  text     <input.pdf> [--pages N-M]                     Extract text
  pages    <input.pdf>                                   Count pages
  info     <input.pdf>                                   Show PDF metadata
  rotate   <input.pdf> <output.pdf> <degrees>            Rotate pages (90/180/270)
  extract  <input.pdf> <output.pdf> <page-range>         Extract page range (e.g. 3-7)
  watermark <input.pdf> <output.pdf> <text>              Add text watermark

Quality levels (for compress): default, printer, ebook, screen

Examples:
  bash pdf-tools.sh merge report.pdf ch1.pdf ch2.pdf ch3.pdf
  bash pdf-tools.sh compress big.pdf small.pdf --quality ebook
  bash pdf-tools.sh text document.pdf --pages 1-5
  bash pdf-tools.sh extract manual.pdf chapter.pdf 10-25
EOF
  exit 0
}

check_dep() {
  if ! command -v "$1" &>/dev/null; then
    echo "❌ Missing dependency: $1"
    echo "   Run: bash scripts/install.sh"
    exit 1
  fi
}

file_size_human() {
  local bytes
  bytes=$(stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null)
  if [ "$bytes" -ge 1048576 ]; then
    echo "$((bytes / 1048576)).$((bytes % 1048576 * 10 / 1048576))MB"
  elif [ "$bytes" -ge 1024 ]; then
    echo "$((bytes / 1024)).$((bytes % 1024 * 10 / 1024))KB"
  else
    echo "${bytes}B"
  fi
}

get_pages() {
  check_dep pdfinfo
  pdfinfo "$1" 2>/dev/null | grep "^Pages:" | awk '{print $2}'
}

# ── MERGE ──
cmd_merge() {
  if [ $# -lt 3 ]; then
    echo "Usage: pdf-tools.sh merge <output.pdf> <input1.pdf> <input2.pdf> ..."
    exit 1
  fi
  check_dep pdfunite
  local output="$1"; shift
  local count=$#
  pdfunite "$@" "$output"
  local pages; pages=$(get_pages "$output")
  local size; size=$(file_size_human "$output")
  echo "✅ Merged ${count} files → ${output} (${pages} pages, ${size})"
}

# ── SPLIT ──
cmd_split() {
  if [ $# -lt 2 ]; then
    echo "Usage: pdf-tools.sh split <input.pdf> <output-dir/>"
    exit 1
  fi
  check_dep pdfseparate
  local input="$1" outdir="$2"
  mkdir -p "$outdir"
  pdfseparate "$input" "${outdir}/page-%03d.pdf"
  local count; count=$(ls "${outdir}"/page-*.pdf 2>/dev/null | wc -l)
  echo "✅ Split into ${count} pages → ${outdir}/"
}

# ── COMPRESS ──
cmd_compress() {
  if [ $# -lt 2 ]; then
    echo "Usage: pdf-tools.sh compress <input.pdf> <output.pdf> [--quality LEVEL]"
    exit 1
  fi
  check_dep gs
  local input="$1" output="$2"; shift 2
  local quality="$QUALITY"
  while [ $# -gt 0 ]; do
    case "$1" in
      --quality) quality="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  # Map quality names to Ghostscript settings
  local gs_quality
  case "$quality" in
    screen)  gs_quality="/screen" ;;
    ebook)   gs_quality="/ebook" ;;
    printer) gs_quality="/printer" ;;
    *)       gs_quality="/default" ;;
  esac

  local size_before; size_before=$(stat -c%s "$input" 2>/dev/null || stat -f%z "$input" 2>/dev/null)

  gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 \
     -dPDFSETTINGS="$gs_quality" \
     -dNOPAUSE -dQUIET -dBATCH \
     -sOutputFile="$output" "$input"

  local size_after; size_after=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null)
  local reduction=0
  if [ "$size_before" -gt 0 ]; then
    reduction=$(( (size_before - size_after) * 100 / size_before ))
  fi

  echo "✅ Compressed: $(file_size_human "$input") → $(file_size_human "$output") (${reduction}% reduction) → ${output}"
}

# ── TEXT ──
cmd_text() {
  if [ $# -lt 1 ]; then
    echo "Usage: pdf-tools.sh text <input.pdf> [--pages N-M]"
    exit 1
  fi
  check_dep pdftotext
  local input="$1"; shift
  local page_first="" page_last=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --pages)
        page_first="${2%%-*}"
        page_last="${2##*-}"
        shift 2 ;;
      *) shift ;;
    esac
  done

  local args=()
  [ -n "$page_first" ] && args+=(-f "$page_first")
  [ -n "$page_last" ] && args+=(-l "$page_last")
  args+=(-layout "$input" -)

  pdftotext "${args[@]}"
}

# ── PAGES ──
cmd_pages() {
  if [ $# -lt 1 ]; then
    echo "Usage: pdf-tools.sh pages <input.pdf>"
    exit 1
  fi
  local pages; pages=$(get_pages "$1")
  echo "$pages"
}

# ── INFO ──
cmd_info() {
  if [ $# -lt 1 ]; then
    echo "Usage: pdf-tools.sh info <input.pdf>"
    exit 1
  fi
  check_dep pdfinfo
  local input="$1"
  local size; size=$(file_size_human "$input")
  echo "📄 ${input}"
  echo "   Size: ${size}"
  pdfinfo "$input" 2>/dev/null | grep -E "^(Title|Author|Creator|Pages|CreationDate):" | while IFS=: read -r key val; do
    echo "   ${key}:${val}"
  done
}

# ── ROTATE ──
cmd_rotate() {
  if [ $# -lt 3 ]; then
    echo "Usage: pdf-tools.sh rotate <input.pdf> <output.pdf> <degrees>"
    exit 1
  fi
  check_dep qpdf
  local input="$1" output="$2" degrees="$3"
  qpdf "$input" "$output" --rotate=+"${degrees}" 2>/dev/null || true
  local pages; pages=$(get_pages "$output")
  echo "✅ Rotated ${pages} pages by ${degrees}° → ${output}"
}

# ── EXTRACT ──
cmd_extract() {
  if [ $# -lt 3 ]; then
    echo "Usage: pdf-tools.sh extract <input.pdf> <output.pdf> <page-range>"
    exit 1
  fi
  check_dep qpdf
  local input="$1" output="$2" range="$3"
  qpdf "$input" --pages "$input" "${range}" -- "$output" 2>/dev/null || true
  local pages; pages=$(get_pages "$output")
  echo "✅ Extracted pages ${range} → ${output} (${pages} pages)"
}

# ── WATERMARK ──
cmd_watermark() {
  if [ $# -lt 3 ]; then
    echo "Usage: pdf-tools.sh watermark <input.pdf> <output.pdf> <text>"
    exit 1
  fi
  check_dep gs
  local input="$1" output="$2" text="$3"
  local pages; pages=$(get_pages "$input")

  # Create a PostScript watermark overlay
  local tmpdir; tmpdir=$(mktemp -d)
  local watermark_ps="${tmpdir}/watermark.ps"
  local watermark_pdf="${tmpdir}/watermark.pdf"

  # Get page size from first page
  local width height
  width=$(pdfinfo "$input" 2>/dev/null | grep "^Page size:" | awk '{print $3}')
  height=$(pdfinfo "$input" 2>/dev/null | grep "^Page size:" | awk '{print $5}')
  width="${width:-612}"
  height="${height:-792}"

  cat > "$watermark_ps" <<PSEOF
%!PS
<<
/EndPage {
  2 eq { pop false }{
    gsave
    0.85 setgray
    /Helvetica-Bold findfont 60 scalefont setfont
    ${width} 2 div ${height} 2 div moveto
    45 rotate
    (${text}) dup stringwidth pop -2 div -20 rmoveto show
    grestore
    true
  } ifelse
} bind
>> setpagedevice
PSEOF

  gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 \
     -dNOPAUSE -dQUIET -dBATCH \
     -sOutputFile="$output" "$watermark_ps" "$input"

  rm -rf "$tmpdir"
  echo "✅ Watermarked ${pages} pages with '${text}' → ${output}"
}

# ── MAIN ──
[ $# -eq 0 ] && usage

case "$1" in
  merge)     shift; cmd_merge "$@" ;;
  split)     shift; cmd_split "$@" ;;
  compress)  shift; cmd_compress "$@" ;;
  text)      shift; cmd_text "$@" ;;
  pages)     shift; cmd_pages "$@" ;;
  info)      shift; cmd_info "$@" ;;
  rotate)    shift; cmd_rotate "$@" ;;
  extract)   shift; cmd_extract "$@" ;;
  watermark) shift; cmd_watermark "$@" ;;
  --help|-h) usage ;;
  *)         echo "❌ Unknown command: $1"; usage ;;
esac
