#!/bin/bash
# PDF OCR — Main script
# Makes scanned PDFs searchable using ocrmypdf + tesseract
set -e

# Defaults
LANG_OPT="${PDF_OCR_LANG:-eng}"
OPTIMIZE="${PDF_OCR_OPTIMIZE:-1}"
JOBS="${PDF_OCR_JOBS:-4}"
SKIP_TEXT="${PDF_OCR_SKIP_TEXT:-true}"
MODE="single"
CLEAN=false
DESKEW=false
FORCE=false
EXTRACT_TEXT=false
WATCH=false

usage() {
    cat <<EOF
Usage: bash scripts/run.sh [OPTIONS] <input> [output]

Modes:
  <input.pdf> <output.pdf>         OCR a single PDF
  --batch <input-dir/> <output-dir/>  OCR all PDFs in a directory
  --watch <input-dir/> <output-dir/>  Watch directory for new PDFs
  --extract-text <input.pdf>       OCR and output text to stdout

Options:
  --lang LANG       Tesseract language(s) (default: eng). Combine: eng+deu
  --clean           Clean pages before OCR (remove noise)
  --deskew          Deskew rotated pages
  --force           Force re-OCR even if text layer exists
  --optimize N      Optimization level: 0=none, 1=lossless, 2=lossy, 3=aggressive
  --jobs N          Parallel jobs for batch mode (default: 4)
  -h, --help        Show this help

Examples:
  bash scripts/run.sh scan.pdf searchable.pdf
  bash scripts/run.sh --lang eng+fra --clean invoice.pdf invoice-ocr.pdf
  bash scripts/run.sh --batch ./scans/ ./output/
  bash scripts/run.sh --extract-text document.pdf | grep "total"
EOF
    exit 0
}

# Parse arguments
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --batch) MODE="batch"; shift ;;
        --watch) MODE="watch"; shift ;;
        --extract-text) EXTRACT_TEXT=true; shift ;;
        --lang) LANG_OPT="$2"; shift 2 ;;
        --clean) CLEAN=true; shift ;;
        --deskew) DESKEW=true; shift ;;
        --force) FORCE=true; shift ;;
        --optimize) OPTIMIZE="$2"; shift 2 ;;
        --jobs) JOBS="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "[PDF-OCR] Unknown option: $1"; exit 1 ;;
        *) POSITIONAL+=("$1"); shift ;;
    esac
done

# Check dependencies
if ! command -v ocrmypdf &>/dev/null; then
    echo "[PDF-OCR] ❌ ocrmypdf not found. Run: bash scripts/install.sh"
    exit 1
fi

# Build ocrmypdf flags
build_flags() {
    local flags="-l $LANG_OPT --optimize $OPTIMIZE"
    [[ "$CLEAN" == true ]] && flags="$flags --clean"
    [[ "$DESKEW" == true ]] && flags="$flags --deskew"
    [[ "$FORCE" == true ]] && flags="$flags --force-ocr"
    [[ "$SKIP_TEXT" == true && "$FORCE" != true ]] && flags="$flags --skip-text"
    echo "$flags"
}

# OCR a single file
ocr_single() {
    local input="$1"
    local output="$2"
    local flags=$(build_flags)

    if [[ ! -f "$input" ]]; then
        echo "[PDF-OCR] ❌ File not found: $input"
        return 1
    fi

    local pages=$(pdfinfo "$input" 2>/dev/null | grep "^Pages:" | awk '{print $2}' || echo "?")
    local size_before=$(stat -c%s "$input" 2>/dev/null || stat -f%z "$input" 2>/dev/null)

    echo "[PDF-OCR] Processing: $input"
    echo "[PDF-OCR] Pages: $pages | Language: $LANG_OPT"

    if eval ocrmypdf $flags "$input" "$output" 2>&1; then
        local size_after=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null)
        local mb_before=$(echo "scale=1; $size_before / 1048576" | bc 2>/dev/null || echo "?")
        local mb_after=$(echo "scale=1; $size_after / 1048576" | bc 2>/dev/null || echo "?")
        echo "[PDF-OCR] ✅ Done: $output (${mb_before}MB → ${mb_after}MB)"
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 6 ]]; then
            echo "[PDF-OCR] ⏭️ Already has text layer: $input (use --force to re-OCR)"
            return 0
        fi
        echo "[PDF-OCR] ❌ Failed: $input (exit code: $exit_code)"
        return 1
    fi
}

# Extract text mode
extract_text() {
    local input="${POSITIONAL[0]}"
    if [[ -z "$input" ]]; then
        echo "[PDF-OCR] ❌ No input file specified"
        exit 1
    fi

    local tmpfile=$(mktemp /tmp/pdf-ocr-XXXXXX.pdf)
    trap "rm -f $tmpfile" EXIT

    # OCR to temp file
    local flags=$(build_flags)
    eval ocrmypdf $flags "$input" "$tmpfile" 2>/dev/null

    # Extract text
    if command -v pdftotext &>/dev/null; then
        pdftotext "$tmpfile" -
    else
        echo "[PDF-OCR] ❌ pdftotext not found. Install: sudo apt-get install poppler-utils"
        exit 1
    fi
}

# Batch mode
batch_process() {
    local input_dir="${POSITIONAL[0]}"
    local output_dir="${POSITIONAL[1]}"

    if [[ -z "$input_dir" || -z "$output_dir" ]]; then
        echo "[PDF-OCR] ❌ Batch mode requires: --batch <input-dir> <output-dir>"
        exit 1
    fi

    mkdir -p "$output_dir"

    local total=0
    local processed=0
    local skipped=0
    local failed=0

    # Count PDFs
    local pdfs=()
    while IFS= read -r -d '' f; do
        pdfs+=("$f")
    done < <(find "$input_dir" -maxdepth 1 -iname "*.pdf" -print0 | sort -z)

    total=${#pdfs[@]}
    echo "[PDF-OCR] Batch mode: $total PDFs found in $input_dir"
    echo ""

    for i in "${!pdfs[@]}"; do
        local f="${pdfs[$i]}"
        local basename=$(basename "$f")
        local outfile="$output_dir/$basename"
        local n=$((i + 1))

        printf "[PDF-OCR] [%d/%d] %s → " "$n" "$total" "$basename"

        local flags=$(build_flags)
        local pages=$(pdfinfo "$f" 2>/dev/null | grep "^Pages:" | awk '{print $2}' || echo "?")
        local start=$(date +%s%N)

        if eval ocrmypdf $flags "$f" "$outfile" 2>/dev/null; then
            local end=$(date +%s%N)
            local elapsed=$(echo "scale=1; ($end - $start) / 1000000000" | bc 2>/dev/null || echo "?")
            echo "✅ ($pages pages, ${elapsed}s)"
            ((processed++))
        else
            local exit_code=$?
            if [[ $exit_code -eq 6 ]]; then
                echo "⏭️ Already has text layer"
                ((skipped++))
            else
                echo "❌ Failed (exit $exit_code)"
                ((failed++))
            fi
        fi
    done

    echo ""
    echo "[PDF-OCR] ✅ Complete: $processed processed, $skipped skipped, $failed failed"
}

# Watch mode
watch_process() {
    local input_dir="${POSITIONAL[0]}"
    local output_dir="${POSITIONAL[1]}"

    if [[ -z "$input_dir" || -z "$output_dir" ]]; then
        echo "[PDF-OCR] ❌ Watch mode requires: --watch <input-dir> <output-dir>"
        exit 1
    fi

    mkdir -p "$output_dir"
    echo "[PDF-OCR] Watching $input_dir for new PDFs..."
    echo "[PDF-OCR] Output: $output_dir"
    echo "[PDF-OCR] Press Ctrl+C to stop"
    echo ""

    # Track processed files
    local processed_file="/tmp/pdf-ocr-watched.txt"
    touch "$processed_file"

    while true; do
        find "$input_dir" -maxdepth 1 -iname "*.pdf" -print0 | while IFS= read -r -d '' f; do
            local basename=$(basename "$f")
            if ! grep -qF "$basename" "$processed_file" 2>/dev/null; then
                local outfile="$output_dir/$basename"
                echo "[PDF-OCR] New file: $basename"
                local flags=$(build_flags)
                if eval ocrmypdf $flags "$f" "$outfile" 2>/dev/null; then
                    echo "[PDF-OCR] ✅ Processed: $basename"
                else
                    local ec=$?
                    [[ $ec -eq 6 ]] && echo "[PDF-OCR] ⏭️ Already searchable: $basename" || echo "[PDF-OCR] ❌ Failed: $basename"
                fi
                echo "$basename" >> "$processed_file"
            fi
        done
        sleep 10
    done
}

# Main
if [[ "$EXTRACT_TEXT" == true ]]; then
    extract_text
elif [[ "$MODE" == "batch" ]]; then
    batch_process
elif [[ "$MODE" == "watch" ]]; then
    watch_process
else
    # Single file mode
    local_input="${POSITIONAL[0]}"
    local_output="${POSITIONAL[1]}"

    if [[ -z "$local_input" ]]; then
        echo "[PDF-OCR] ❌ No input file. Run with -h for help."
        exit 1
    fi

    if [[ -z "$local_output" ]]; then
        # Auto-generate output name
        local_output="${local_input%.pdf}-ocr.pdf"
    fi

    ocr_single "$local_input" "$local_output"
fi
