#!/bin/bash
# Duplicate File Finder — clean.sh
# Removes duplicate files based on scan report
set -euo pipefail

REPORT_FILE=""
DRY_RUN=false
TRASH_DIR=""
VERBOSE=false

usage() {
    echo "Usage: clean.sh <report-file> [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run         Show what would be deleted without deleting"
    echo "  --trash <dir>     Move duplicates to trash directory instead of deleting"
    echo "  -v, --verbose     Show each file being processed"
    echo "  -h, --help        Show this help"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --trash) TRASH_DIR="$2"; shift 2 ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1"; usage ;;
        *) REPORT_FILE="$1"; shift ;;
    esac
done

if [[ -z "$REPORT_FILE" ]]; then
    echo "Error: No report file specified"
    usage
fi

if [[ ! -f "$REPORT_FILE" ]]; then
    echo "Error: Report file not found: $REPORT_FILE"
    exit 1
fi

# Create trash dir if needed
if [[ -n "$TRASH_DIR" ]]; then
    mkdir -p "$TRASH_DIR"
fi

DELETED=0
FREED=0
ERRORS=0

echo "🧹 Duplicate Cleaner"
if $DRY_RUN; then
    echo "   Mode: DRY RUN (no files will be deleted)"
else
    if [[ -n "$TRASH_DIR" ]]; then
        echo "   Mode: Move to trash ($TRASH_DIR)"
    else
        echo "   Mode: DELETE (permanent)"
    fi
fi
echo ""

# Parse report and delete DUP: lines
while IFS= read -r line; do
    if [[ "$line" =~ ^DUP:\ +(.+)$ ]]; then
        filepath="${BASH_REMATCH[1]}"
        
        if [[ ! -f "$filepath" ]]; then
            if $VERBOSE; then
                echo "   SKIP (missing): $filepath"
            fi
            continue
        fi
        
        file_size=$(stat -c%s "$filepath" 2>/dev/null || stat -f%z "$filepath" 2>/dev/null || echo 0)
        
        if $DRY_RUN; then
            size_human=$(numfmt --to=iec-i --suffix=B "$file_size" 2>/dev/null || echo "${file_size}B")
            echo "   WOULD DELETE: $filepath ($size_human)"
            DELETED=$((DELETED + 1))
            FREED=$((FREED + file_size))
        else
            if [[ -n "$TRASH_DIR" ]]; then
                # Preserve directory structure in trash
                rel_path="${filepath#/}"
                trash_path="$TRASH_DIR/$rel_path"
                mkdir -p "$(dirname "$trash_path")"
                if mv "$filepath" "$trash_path" 2>/dev/null; then
                    DELETED=$((DELETED + 1))
                    FREED=$((FREED + file_size))
                    if $VERBOSE; then
                        echo "   MOVED: $filepath → $trash_path"
                    fi
                else
                    ERRORS=$((ERRORS + 1))
                    echo "   ERROR: Could not move $filepath"
                fi
            else
                if rm "$filepath" 2>/dev/null; then
                    DELETED=$((DELETED + 1))
                    FREED=$((FREED + file_size))
                    if $VERBOSE; then
                        echo "   DELETED: $filepath"
                    fi
                else
                    ERRORS=$((ERRORS + 1))
                    echo "   ERROR: Could not delete $filepath"
                fi
            fi
        fi
    fi
done < "$REPORT_FILE"

FREED_HUMAN=$(numfmt --to=iec-i --suffix=B "$FREED" 2>/dev/null || echo "${FREED} bytes")

echo ""
if $DRY_RUN; then
    echo "📋 Dry run complete:"
    echo "   Would remove: $DELETED files"
    echo "   Would free: $FREED_HUMAN"
    echo ""
    echo "Run without --dry-run to actually clean."
else
    echo "✅ Cleanup complete:"
    echo "   Removed: $DELETED files"
    echo "   Freed: $FREED_HUMAN"
    if [[ $ERRORS -gt 0 ]]; then
        echo "   Errors: $ERRORS"
    fi
fi
