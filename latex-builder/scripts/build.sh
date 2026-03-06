#!/bin/bash
# LaTeX Builder — Compile LaTeX to PDF
set -e

LATEX_ENGINE="${LATEX_ENGINE:-pdflatex}"
PASSES=1
CLEAN=false
WATCH=false
AUTO_INSTALL=false
BIB=false
TEMPLATE=""
OUTPUT=""
DIR=""
OPEN=false
INPUT=""

usage() {
  echo "Usage: $0 [OPTIONS] [input.tex]"
  echo ""
  echo "Options:"
  echo "  --template NAME    Generate from template (resume|letter|report|paper|slides)"
  echo "  --output FILE      Output filename for template"
  echo "  --list-templates   List available templates"
  echo "  --bib              Run BibTeX/Biber pipeline"
  echo "  --passes N         Number of LaTeX passes (default: 1)"
  echo "  --clean            Remove auxiliary files after build"
  echo "  --watch            Recompile on file changes"
  echo "  --auto-install     Auto-install missing packages"
  echo "  --dir DIR          Batch compile all .tex in directory"
  echo "  --open             Open PDF after compilation"
  echo "  -h, --help         Show this help"
}

list_templates() {
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  TEMPLATE_DIR="$SCRIPT_DIR/../templates"
  echo "Available templates:"
  echo ""
  for f in "$TEMPLATE_DIR"/*.tex; do
    name=$(basename "$f" .tex)
    desc=$(head -1 "$f" | sed 's/^% *//')
    echo "  $name — $desc"
  done
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --template) TEMPLATE="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --list-templates) list_templates; exit 0 ;;
    --bib) BIB=true; shift ;;
    --passes) PASSES="$2"; shift 2 ;;
    --clean) CLEAN=true; shift ;;
    --watch) WATCH=true; shift ;;
    --auto-install) AUTO_INSTALL=true; shift ;;
    --dir) DIR="$2"; shift 2 ;;
    --open) OPEN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1"; usage; exit 1 ;;
    *) INPUT="$1"; shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates"

# Template mode
if [[ -n "$TEMPLATE" ]]; then
  TMPL_FILE="$TEMPLATE_DIR/${TEMPLATE}.tex"
  if [[ ! -f "$TMPL_FILE" ]]; then
    echo "❌ Template '$TEMPLATE' not found."
    list_templates
    exit 1
  fi
  OUT="${OUTPUT:-${TEMPLATE}.tex}"
  if [[ -f "$OUT" ]]; then
    echo "❌ File '$OUT' already exists. Use a different --output name."
    exit 1
  fi
  cp "$TMPL_FILE" "$OUT"
  echo "✅ Template '$TEMPLATE' → $OUT"
  echo "   Edit $OUT, then run: bash $0 $OUT"
  exit 0
fi

# Check for input
if [[ -z "$INPUT" && -z "$DIR" ]]; then
  echo "❌ No input file specified."
  usage
  exit 1
fi

# Check TeX is installed
if ! command -v "$LATEX_ENGINE" &>/dev/null; then
  echo "❌ $LATEX_ENGINE not found. Run: bash scripts/install.sh"
  exit 1
fi

compile_file() {
  local texfile="$1"
  local texdir=$(dirname "$texfile")
  local texbase=$(basename "$texfile" .tex)

  echo "🔨 Compiling $texfile with $LATEX_ENGINE..."

  # First pass
  $LATEX_ENGINE -interaction=nonstopmode -output-directory="$texdir" "$texfile" 2>&1 | tail -5

  # Check for missing packages
  if [[ $? -ne 0 && "$AUTO_INSTALL" == true ]]; then
    echo "⚠️  Compilation failed. Checking for missing packages..."
    # Extract missing package names from log
    local logfile="$texdir/$texbase.log"
    if [[ -f "$logfile" ]]; then
      local missing=$(grep -oP "File \`\K[^']+(?=\.sty)" "$logfile" 2>/dev/null | sort -u)
      if [[ -n "$missing" ]]; then
        echo "📦 Auto-installing: $missing"
        for pkg in $missing; do
          tlmgr install "$pkg" 2>/dev/null || echo "   ⚠️  Could not install $pkg"
        done
        # Retry
        echo "🔄 Retrying compilation..."
        $LATEX_ENGINE -interaction=nonstopmode -output-directory="$texdir" "$texfile" 2>&1 | tail -5
      fi
    fi
  fi

  # BibTeX/Biber pass
  if $BIB; then
    echo "📚 Running bibliography..."
    if grep -q "biblatex" "$texfile" 2>/dev/null; then
      (cd "$texdir" && biber "$texbase" 2>&1 | tail -3)
    else
      (cd "$texdir" && bibtex "$texbase" 2>&1 | tail -3)
    fi
    # Re-run LaTeX twice for bibliography cross-refs
    $LATEX_ENGINE -interaction=nonstopmode -output-directory="$texdir" "$texfile" >/dev/null 2>&1
    $LATEX_ENGINE -interaction=nonstopmode -output-directory="$texdir" "$texfile" 2>&1 | tail -3
  fi

  # Additional passes
  for ((i=2; i<=PASSES; i++)); do
    echo "🔄 Pass $i/$PASSES..."
    $LATEX_ENGINE -interaction=nonstopmode -output-directory="$texdir" "$texfile" 2>&1 | tail -3
  done

  # Check output
  local pdffile="$texdir/$texbase.pdf"
  if [[ -f "$pdffile" ]]; then
    local size=$(du -h "$pdffile" | cut -f1)
    echo "✅ $pdffile ($size)"
  else
    echo "❌ Compilation failed. Check $texdir/$texbase.log for details."
    return 1
  fi

  # Clean auxiliary files
  if $CLEAN; then
    echo "🧹 Cleaning auxiliary files..."
    rm -f "$texdir/$texbase".{aux,log,out,toc,lof,lot,bbl,blg,bcf,run.xml,nav,snm,vrb,fdb_latexmk,fls,synctex.gz}
  fi

  # Open PDF
  if $OPEN; then
    local viewer="${PDF_VIEWER:-xdg-open}"
    $viewer "$pdffile" 2>/dev/null &
  fi
}

# Batch mode
if [[ -n "$DIR" ]]; then
  echo "📁 Batch compiling .tex files in $DIR..."
  count=0
  for f in "$DIR"/*.tex; do
    [[ -f "$f" ]] || continue
    compile_file "$f"
    ((count++))
  done
  echo "✅ Compiled $count files."
  exit 0
fi

# Watch mode
if $WATCH; then
  if ! command -v inotifywait &>/dev/null; then
    echo "⚠️  inotifywait not found. Install: sudo apt install inotify-tools"
    echo "   Falling back to polling (every 2s)..."
    compile_file "$INPUT"
    LAST_MOD=$(stat -c %Y "$INPUT" 2>/dev/null || stat -f %m "$INPUT" 2>/dev/null)
    while true; do
      sleep 2
      CUR_MOD=$(stat -c %Y "$INPUT" 2>/dev/null || stat -f %m "$INPUT" 2>/dev/null)
      if [[ "$CUR_MOD" != "$LAST_MOD" ]]; then
        LAST_MOD="$CUR_MOD"
        echo ""
        echo "📝 File changed. Recompiling..."
        compile_file "$INPUT"
      fi
    done
  else
    compile_file "$INPUT"
    echo "👀 Watching $INPUT for changes (Ctrl+C to stop)..."
    while inotifywait -qq -e modify "$INPUT" 2>/dev/null; do
      echo ""
      echo "📝 File changed. Recompiling..."
      compile_file "$INPUT"
    done
  fi
  exit 0
fi

# Single file mode
compile_file "$INPUT"
