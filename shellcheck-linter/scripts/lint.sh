#!/bin/bash
# ShellCheck Linter — lint scripts, directories, generate reports
set -eu

# Defaults
SEVERITY="style"
FORMAT="tty"
SHELL_DIALECT=""
EXCLUDE=""
RECURSIVE=false
WATCH=false
DIR=""
FILES=()

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [FILE...]

Lint shell scripts with ShellCheck.

Options:
  --dir DIR          Lint all .sh files in DIR
  --recursive, -r    Include subdirectories (with --dir)
  --severity LEVEL   Minimum severity: error, warning, info, style (default: style)
  --format FMT       Output format: tty, json, gcc, checkstyle, diff (default: tty)
  --shell DIALECT    Force shell dialect: sh, bash, dash, ksh (default: auto-detect)
  --exclude CODES    Comma-separated SC codes to ignore (e.g. SC2086,SC2034)
  --watch            Re-lint on file changes (single file only)
  -h, --help         Show this help

Examples:
  $(basename "$0") script.sh
  $(basename "$0") --dir ./scripts --recursive
  $(basename "$0") --severity error --dir ./project
  $(basename "$0") --format json --dir ./scripts > report.json
  $(basename "$0") --exclude SC2086,SC2034 deploy.sh
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)       DIR="$2"; shift 2 ;;
        --recursive|-r) RECURSIVE=true; shift ;;
        --severity)  SEVERITY="$2"; shift 2 ;;
        --format)    FORMAT="$2"; shift 2 ;;
        --shell)     SHELL_DIALECT="$2"; shift 2 ;;
        --exclude)   EXCLUDE="$2"; shift 2 ;;
        --watch)     WATCH=true; shift ;;
        -h|--help)   usage ;;
        -*)          echo "❌ Unknown option: $1"; usage ;;
        *)           FILES+=("$1"); shift ;;
    esac
done

# Check shellcheck is installed
if ! command -v shellcheck &>/dev/null; then
    echo "❌ ShellCheck not found. Run: bash scripts/install.sh"
    exit 1
fi

# Build shellcheck args
SC_ARGS=("--severity=$SEVERITY" "--format=$FORMAT")
[[ -n "$SHELL_DIALECT" ]] && SC_ARGS+=("--shell=$SHELL_DIALECT")
[[ -n "$EXCLUDE" ]] && SC_ARGS+=("--exclude=$EXCLUDE")

# Collect files
collect_files() {
    if [[ -n "$DIR" ]]; then
        if [[ "$RECURSIVE" == true ]]; then
            find "$DIR" -type f \( -name "*.sh" -o -name "*.bash" -o -name "*.ksh" \) 2>/dev/null | sort
        else
            find "$DIR" -maxdepth 1 -type f \( -name "*.sh" -o -name "*.bash" -o -name "*.ksh" \) 2>/dev/null | sort
        fi
    fi
    # Also check files with shell shebangs (no extension)
    if [[ -n "$DIR" ]]; then
        if [[ "$RECURSIVE" == true ]]; then
            find "$DIR" -type f ! -name "*.*" 2>/dev/null | while read -r f; do
                head -1 "$f" 2>/dev/null | grep -qE '^#!.*(bash|sh|ksh|dash)' && echo "$f"
            done | sort
        fi
    fi
}

# Watch mode
if [[ "$WATCH" == true ]]; then
    if [[ ${#FILES[@]} -ne 1 ]]; then
        echo "❌ Watch mode requires exactly one file"
        exit 1
    fi
    FILE="${FILES[0]}"
    echo "👀 Watching $FILE for changes (Ctrl+C to stop)"
    echo ""

    lint_file() {
        clear
        echo "📋 ShellCheck Report: $FILE ($(date '+%H:%M:%S'))"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        shellcheck "${SC_ARGS[@]}" "$FILE" 2>&1 || true
        echo ""
        echo "👀 Waiting for changes..."
    }

    lint_file

    if command -v inotifywait &>/dev/null; then
        while inotifywait -qq -e modify "$FILE" 2>/dev/null; do
            lint_file
        done
    elif command -v fswatch &>/dev/null; then
        fswatch -o "$FILE" | while read -r _; do
            lint_file
        done
    else
        echo "⚠️  No file watcher found. Install inotifywait (inotify-tools) or fswatch."
        echo "   Falling back to polling (every 2 seconds)..."
        LAST_MOD=$(stat -c %Y "$FILE" 2>/dev/null || stat -f %m "$FILE" 2>/dev/null)
        while true; do
            sleep 2
            CUR_MOD=$(stat -c %Y "$FILE" 2>/dev/null || stat -f %m "$FILE" 2>/dev/null)
            if [[ "$CUR_MOD" != "$LAST_MOD" ]]; then
                LAST_MOD="$CUR_MOD"
                lint_file
            fi
        done
    fi
    exit 0
fi

# Collect all target files
ALL_FILES=()
if [[ -n "$DIR" ]]; then
    while IFS= read -r f; do
        [[ -n "$f" ]] && ALL_FILES+=("$f")
    done < <(collect_files)
fi
ALL_FILES+=("${FILES[@]}")

if [[ ${#ALL_FILES[@]} -eq 0 ]]; then
    echo "❌ No files specified. Use: $(basename "$0") file.sh or --dir ./path"
    exit 1
fi

# JSON format: pass directly to shellcheck
if [[ "$FORMAT" == "json" || "$FORMAT" == "checkstyle" || "$FORMAT" == "gcc" || "$FORMAT" == "diff" ]]; then
    shellcheck "${SC_ARGS[@]}" "${ALL_FILES[@]}" 2>/dev/null
    exit $?
fi

# TTY format: pretty output
if [[ ${#ALL_FILES[@]} -eq 1 ]]; then
    # Single file mode
    FILE="${ALL_FILES[0]}"
    echo "📋 ShellCheck Report: $(basename "$FILE")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    shellcheck "${SC_ARGS[@]}" "$FILE" 2>&1
    EXIT_CODE=$?
    echo ""
    if [[ $EXIT_CODE -eq 0 ]]; then
        echo "✅ No issues found!"
    fi
    exit $EXIT_CODE
else
    # Batch mode
    echo "📋 ShellCheck Batch Report"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    TOTAL_ERRORS=0
    TOTAL_WARNINGS=0
    TOTAL_INFO=0
    TOTAL_FILES=0
    CLEAN_FILES=0
    FAILED_FILES=()

    for FILE in "${ALL_FILES[@]}"; do
        TOTAL_FILES=$((TOTAL_FILES + 1))
        # Get JSON output for counting
        SC_JSON_ARGS=("--format=json" "--severity=$SEVERITY")
        [[ -n "$SHELL_DIALECT" ]] && SC_JSON_ARGS+=("--shell=$SHELL_DIALECT")
        [[ -n "$EXCLUDE" ]] && SC_JSON_ARGS+=("--exclude=$EXCLUDE")
        RESULT=$(shellcheck "${SC_JSON_ARGS[@]}" "$FILE" 2>/dev/null || true)

        if [[ -z "$RESULT" || "$RESULT" == "[]" ]]; then
            CLEAN_FILES=$((CLEAN_FILES + 1))
            printf "  %-50s ✅ clean\n" "$(basename "$FILE")"
        else
            count_level() { local n; n=$(echo "$RESULT" | grep -c "\"level\":\"$1\"") || n=0; echo "$n"; }
            ERRORS=$(count_level error)
            WARNINGS=$(count_level warning)
            INFOS=$(count_level info)
            STYLE=$(count_level style)

            TOTAL_ERRORS=$((TOTAL_ERRORS + ERRORS))
            TOTAL_WARNINGS=$((TOTAL_WARNINGS + WARNINGS))
            TOTAL_INFO=$((TOTAL_INFO + INFOS + STYLE))

            ISSUES=""
            [[ $ERRORS -gt 0 ]] && ISSUES+="${ERRORS} error(s) "
            [[ $WARNINGS -gt 0 ]] && ISSUES+="${WARNINGS} warning(s) "
            [[ $((INFOS + STYLE)) -gt 0 ]] && ISSUES+="$((INFOS + STYLE)) info "

            printf "  %-50s ⚠️  %s\n" "$(basename "$FILE")" "$ISSUES"
            FAILED_FILES+=("$FILE")
        fi
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total: ${TOTAL_FILES} files | ${CLEAN_FILES} clean | ${TOTAL_ERRORS} errors | ${TOTAL_WARNINGS} warnings | ${TOTAL_INFO} info"

    # Show details for failed files
    if [[ ${#FAILED_FILES[@]} -gt 0 ]]; then
        echo ""
        echo "━━━━━━━━━━━━ Details ━━━━━━━━━━━━━━━━"
        for FILE in "${FAILED_FILES[@]}"; do
            echo ""
            echo "📄 $(basename "$FILE")"
            echo "──────────────────────────────────"
            shellcheck "${SC_ARGS[@]}" "$FILE" 2>&1 || true
        done
    fi

    [[ $TOTAL_ERRORS -gt 0 ]] && exit 1
    exit 0
fi
