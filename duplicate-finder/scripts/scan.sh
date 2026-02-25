#!/bin/bash
# Duplicate File Finder — scan.sh
# Scans directories for duplicate files using checksums
set -euo pipefail

# Defaults
HASH_CMD="${DUPFINDER_HASH:-sha256sum}"
JOBS="${DUPFINDER_JOBS:-4}"
EXCLUDE_DEFAULT="${DUPFINDER_EXCLUDE:-.git,.DS_Store,node_modules,__pycache__}"
REPORT_DIR="${DUPFINDER_REPORT_DIR:-/tmp}"

# Parse arguments
DIRS=()
EXTENSIONS=""
MIN_SIZE=""
MAX_SIZE=""
DETAILS=false
CROSS_ONLY=false
JSON_OUTPUT=false
EXCLUDE_PATTERNS="$EXCLUDE_DEFAULT"
OUTPUT_FILE=""
QUIET=false

usage() {
    echo "Usage: scan.sh <dir1> [dir2...] [options]"
    echo ""
    echo "Options:"
    echo "  --ext <extensions>    Filter by file extensions (comma-separated)"
    echo "  --min-size <size>     Minimum file size (e.g., 1K, 10M, 1G)"
    echo "  --max-size <size>     Maximum file size"
    echo "  --details             Show full paths for all duplicates"
    echo "  --cross-only          Only show cross-directory duplicates"
    echo "  --json                Output as JSON"
    echo "  --hash <algo>         Hash algorithm (sha256sum, md5sum, b2sum)"
    echo "  --jobs <n>            Parallel hash jobs"
    echo "  --exclude <pattern>   Exclude glob patterns (comma-separated)"
    echo "  -o, --output <file>   Output report file path"
    echo "  -q, --quiet           Minimal output (just summary)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --ext) EXTENSIONS="$2"; shift 2 ;;
        --min-size) MIN_SIZE="$2"; shift 2 ;;
        --max-size) MAX_SIZE="$2"; shift 2 ;;
        --details) DETAILS=true; shift ;;
        --cross-only) CROSS_ONLY=true; shift ;;
        --json) JSON_OUTPUT=true; shift ;;
        --hash) HASH_CMD="$2"; shift 2 ;;
        --jobs) JOBS="$2"; shift 2 ;;
        --exclude) EXCLUDE_PATTERNS="$2"; shift 2 ;;
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        -q|--quiet) QUIET=true; shift ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1"; usage ;;
        *) DIRS+=("$1"); shift ;;
    esac
done

if [[ ${#DIRS[@]} -eq 0 ]]; then
    echo "Error: No directories specified"
    usage
fi

# Validate directories
for dir in "${DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        echo "Error: '$dir' is not a directory"
        exit 1
    fi
done

# Check dependencies
if ! command -v "$HASH_CMD" &>/dev/null; then
    echo "Error: $HASH_CMD not found. Install coreutils."
    exit 1
fi

# Build find command
FIND_ARGS=()
for dir in "${DIRS[@]}"; do
    FIND_ARGS+=("$dir")
done
FIND_ARGS+=(-type f)

# Exclude patterns
IFS=',' read -ra EXCL_ARR <<< "$EXCLUDE_PATTERNS"
for pat in "${EXCL_ARR[@]}"; do
    pat=$(echo "$pat" | xargs)  # trim whitespace
    FIND_ARGS+=(-not -path "*/$pat/*" -not -name "$pat")
done

# Extension filter
if [[ -n "$EXTENSIONS" ]]; then
    IFS=',' read -ra EXT_ARR <<< "$EXTENSIONS"
    FIND_ARGS+=("(")
    first=true
    for ext in "${EXT_ARR[@]}"; do
        ext=$(echo "$ext" | xargs | sed 's/^\.//')
        if $first; then
            first=false
        else
            FIND_ARGS+=(-o)
        fi
        FIND_ARGS+=(-iname "*.${ext}")
    done
    FIND_ARGS+=(")")
fi

# Size filters
if [[ -n "$MIN_SIZE" ]]; then
    FIND_ARGS+=(-size "+${MIN_SIZE}")
fi
if [[ -n "$MAX_SIZE" ]]; then
    FIND_ARGS+=(-size "-${MAX_SIZE}")
fi

# Timestamp for report
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="${OUTPUT_FILE:-${REPORT_DIR}/dupfinder-report-${TIMESTAMP}.txt}"
TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

# Phase 1: Find files and group by size
if ! $QUIET; then
    echo "🔍 Scanning ${DIRS[*]}..." >&2
fi

find "${FIND_ARGS[@]}" -printf '%s %p\n' 2>/dev/null | sort -n > "$TEMP_DIR/all-files.txt"

TOTAL_FILES=$(wc -l < "$TEMP_DIR/all-files.txt")
TOTAL_BYTES=$(awk '{s+=$1} END {print s+0}' "$TEMP_DIR/all-files.txt")

if ! $QUIET; then
    echo "   Found $(printf "%'d" "$TOTAL_FILES") files ($(numfmt --to=iec-i --suffix=B "$TOTAL_BYTES" 2>/dev/null || echo "${TOTAL_BYTES} bytes"))" >&2
fi

if [[ $TOTAL_FILES -eq 0 ]]; then
    echo "   No files found matching criteria." >&2
    exit 0
fi

# Phase 2: Group by size (only sizes with >1 file are potential dupes)
awk '{print $1}' "$TEMP_DIR/all-files.txt" | sort -n | uniq -d > "$TEMP_DIR/dup-sizes.txt"

DUP_SIZE_COUNT=$(wc -l < "$TEMP_DIR/dup-sizes.txt")
if [[ $DUP_SIZE_COUNT -eq 0 ]]; then
    if ! $QUIET; then
        echo ""
        echo "✅ No duplicates found! All files are unique."
    fi
    exit 0
fi

# Extract files with duplicate sizes
while IFS= read -r size; do
    grep "^${size} " "$TEMP_DIR/all-files.txt" >> "$TEMP_DIR/candidates.txt"
done < "$TEMP_DIR/dup-sizes.txt"

CANDIDATE_COUNT=$(wc -l < "$TEMP_DIR/candidates.txt")

if ! $QUIET; then
    echo "   $(printf "%'d" "$CANDIDATE_COUNT") files with matching sizes — computing checksums..." >&2
fi

# Phase 3: Compute checksums for candidates
while IFS=' ' read -r size filepath; do
    echo "$filepath"
done < "$TEMP_DIR/candidates.txt" | xargs -P "$JOBS" -I{} "$HASH_CMD" "{}" 2>/dev/null > "$TEMP_DIR/hashes.txt" || true

if [[ ! -s "$TEMP_DIR/hashes.txt" ]]; then
    echo "   No checksums computed (permission issues?)."
    exit 1
fi

if ! $QUIET; then
    echo "   Checksums computed." >&2
fi

# Phase 4: Find duplicate hashes
awk '{print $1}' "$TEMP_DIR/hashes.txt" | sort | uniq -d > "$TEMP_DIR/dup-hashes.txt"

DUP_HASH_COUNT=$(wc -l < "$TEMP_DIR/dup-hashes.txt")

if [[ $DUP_HASH_COUNT -eq 0 ]]; then
    if ! $QUIET; then
        echo ""
        echo "✅ No duplicates found! Files with same sizes have different content."
    fi
    exit 0
fi

# Phase 5: Build duplicate groups
GROUP_NUM=0
TOTAL_REDUNDANT=0
TOTAL_WASTED=0

# Write report header
{
    echo "# Duplicate File Report"
    echo "# Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "# Directories: ${DIRS[*]}"
    echo "# Hash: $HASH_CMD"
    echo "#"
} > "$REPORT_FILE"

# JSON array start
if $JSON_OUTPUT; then
    JSON_GROUPS="["
fi

while IFS= read -r hash; do
    GROUP_NUM=$((GROUP_NUM + 1))
    
    # Get all files with this hash
    mapfile -t group_files < <(grep "^${hash} " "$TEMP_DIR/hashes.txt" | sed "s/^${hash}  //")
    
    COUNT=${#group_files[@]}
    if [[ $COUNT -lt 2 ]]; then
        continue
    fi
    
    # Cross-only filter
    if $CROSS_ONLY && [[ ${#DIRS[@]} -gt 1 ]]; then
        dir_count=0
        for dir in "${DIRS[@]}"; do
            for f in "${group_files[@]}"; do
                if [[ "$f" == "$dir"* ]]; then
                    dir_count=$((dir_count + 1))
                    break
                fi
            done
        done
        if [[ $dir_count -lt 2 ]]; then
            GROUP_NUM=$((GROUP_NUM - 1))
            continue
        fi
    fi
    
    # Get file size
    FILE_SIZE=$(stat -c%s "${group_files[0]}" 2>/dev/null || stat -f%z "${group_files[0]}" 2>/dev/null || echo 0)
    REDUNDANT=$((COUNT - 1))
    WASTED=$((FILE_SIZE * REDUNDANT))
    TOTAL_REDUNDANT=$((TOTAL_REDUNDANT + REDUNDANT))
    TOTAL_WASTED=$((TOTAL_WASTED + WASTED))
    
    SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B "$FILE_SIZE" 2>/dev/null || echo "${FILE_SIZE} bytes")
    WASTED_HUMAN=$(numfmt --to=iec-i --suffix=B "$WASTED" 2>/dev/null || echo "${WASTED} bytes")
    
    # Write to report
    {
        echo ""
        echo "GROUP $GROUP_NUM | $hash | $SIZE_HUMAN × $COUNT copies | $WASTED_HUMAN wasted"
        echo "KEEP: ${group_files[0]}"
        for ((i=1; i<COUNT; i++)); do
            echo "DUP:  ${group_files[$i]}"
        done
    } >> "$REPORT_FILE"
    
    # JSON output
    if $JSON_OUTPUT; then
        files_json=""
        for f in "${group_files[@]}"; do
            files_json="$files_json\"$(echo "$f" | sed 's/"/\\"/g')\","
        done
        files_json="[${files_json%,}]"
        
        if [[ $GROUP_NUM -gt 1 ]]; then
            JSON_GROUPS="$JSON_GROUPS,"
        fi
        JSON_GROUPS="$JSON_GROUPS{\"hash\":\"$hash\",\"size\":$FILE_SIZE,\"copies\":$COUNT,\"wasted\":$WASTED,\"files\":$files_json}"
    fi
done < "$TEMP_DIR/dup-hashes.txt"

# Summary
WASTED_HUMAN=$(numfmt --to=iec-i --suffix=B "$TOTAL_WASTED" 2>/dev/null || echo "${TOTAL_WASTED} bytes")

{
    echo ""
    echo "# SUMMARY"
    echo "# Groups: $GROUP_NUM"
    echo "# Redundant files: $TOTAL_REDUNDANT"
    echo "# Wasted space: $WASTED_HUMAN"
} >> "$REPORT_FILE"

if $JSON_OUTPUT; then
    JSON_GROUPS="$JSON_GROUPS]"
    TOTAL_HUMAN=$(numfmt --to=iec-i --suffix=B "$TOTAL_BYTES" 2>/dev/null || echo "$TOTAL_BYTES")
    cat <<EOF
{
  "scanned": {"dirs": ${#DIRS[@]}, "files": $TOTAL_FILES, "total_bytes": $TOTAL_BYTES},
  "duplicates": {"groups": $GROUP_NUM, "redundant_files": $TOTAL_REDUNDANT, "wasted_bytes": $TOTAL_WASTED},
  "groups": $JSON_GROUPS,
  "report_file": "$REPORT_FILE"
}
EOF
else
    echo ""
    echo "📊 Duplicate Report:"
    echo "   $GROUP_NUM duplicate groups found"
    echo "   $TOTAL_REDUNDANT redundant files"
    echo "   $WASTED_HUMAN wasted space"
    
    if $DETAILS; then
        echo ""
        cat "$REPORT_FILE" | grep -v "^#"
    else
        # Show top 5 by wasted space
        echo ""
        echo "Top duplicates by wasted space:"
        grep "^GROUP" "$REPORT_FILE" | sort -t'|' -k4 -h -r | head -5 | while IFS='|' read -r group hash size wasted; do
            group_num=$(echo "$group" | awk '{print $2}')
            echo "   [$group_num] $(echo "$wasted" | xargs)"
        done
    fi
    
    echo ""
    echo "Full report: $REPORT_FILE"
    echo "To clean: bash scripts/clean.sh $REPORT_FILE --dry-run"
fi
