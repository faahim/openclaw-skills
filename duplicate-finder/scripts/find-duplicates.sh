#!/usr/bin/env bash
# Duplicate File Finder — find and manage duplicate files by content hash
# Supports: report, hardlink, symlink, delete actions
# Falls back to pure bash if jdupes/fdupes not installed

set -euo pipefail

VERSION="1.0.0"

# Defaults
MIN_SIZE="1"
MAX_SIZE=""
HASH_ALGO="md5"
ACTION="report"
KEEP="newest"
DRY_RUN=false
INTERACTIVE=false
FORMAT="text"
OUTPUT=""
JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
QUIET=false
VERBOSE=false
HIDDEN=false
FOLLOW_LINKS=false
CROSS_ONLY=false
EXCLUDES=()
DIRS=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat <<EOF
Duplicate File Finder v${VERSION}

Usage: $(basename "$0") [OPTIONS] DIRECTORY [DIRECTORY...]

Options:
  --min-size SIZE      Minimum file size (1K, 1M, 1G). Default: 1
  --max-size SIZE      Maximum file size
  --hidden             Include hidden files
  --follow-links       Follow symlinks
  --exclude PATTERN    Exclude glob pattern (repeatable)
  --hash ALGO          md5 (default), sha256, sha1
  --action ACTION      report (default), hardlink, symlink, delete
  --keep STRATEGY      newest (default), oldest, shortest-path
  --dry-run            Preview without changes
  --interactive        Review each group
  --cross-only         Only show cross-directory duplicates
  --format FORMAT      text (default), json, csv
  --output FILE        Write to file
  -j, --jobs N         Parallel jobs (default: ${JOBS})
  -q, --quiet          Summary only
  -v, --verbose        Verbose output
  -h, --help           Show this help
EOF
  exit 0
}

parse_size() {
  local s="$1"
  case "${s}" in
    *[kK]) echo $(( ${s%[kK]} * 1024 )) ;;
    *[mM]) echo $(( ${s%[mM]} * 1048576 )) ;;
    *[gG]) echo $(( ${s%[gG]} * 1073741824 )) ;;
    *)     echo "${s}" ;;
  esac
}

hash_file() {
  local file="$1"
  local algo="${2:-md5}"
  case "$algo" in
    md5)    md5sum "$file" 2>/dev/null | cut -d' ' -f1 ;;
    sha256) sha256sum "$file" 2>/dev/null | cut -d' ' -f1 ;;
    sha1)   sha1sum "$file" 2>/dev/null | cut -d' ' -f1 ;;
  esac
}

partial_hash() {
  local file="$1"
  head -c 4096 "$file" 2>/dev/null | md5sum | cut -d' ' -f1
}

file_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --min-size)   MIN_SIZE=$(parse_size "$2"); shift 2 ;;
    --max-size)   MAX_SIZE=$(parse_size "$2"); shift 2 ;;
    --hidden)     HIDDEN=true; shift ;;
    --follow-links) FOLLOW_LINKS=true; shift ;;
    --exclude)    EXCLUDES+=("$2"); shift 2 ;;
    --hash)       HASH_ALGO="$2"; shift 2 ;;
    --action)     ACTION="$2"; shift 2 ;;
    --keep)       KEEP="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --interactive) INTERACTIVE=true; shift ;;
    --cross-only) CROSS_ONLY=true; shift ;;
    --format)     FORMAT="$2"; shift 2 ;;
    --output)     OUTPUT="$2"; shift 2 ;;
    -j|--jobs)    JOBS="$2"; shift 2 ;;
    -q|--quiet)   QUIET=true; shift ;;
    -v|--verbose) VERBOSE=true; shift ;;
    -h|--help)    usage ;;
    -*)           echo "Unknown option: $1"; exit 1 ;;
    *)            DIRS+=("$1"); shift ;;
  esac
done

if [[ ${#DIRS[@]} -eq 0 ]]; then
  echo "Error: No directory specified."
  usage
fi

# Validate dirs
for d in "${DIRS[@]}"; do
  if [[ ! -d "$d" ]]; then
    echo "Error: '$d' is not a directory"
    exit 1
  fi
done

# Check for fast tools
USE_JDUPES=false
USE_FDUPES=false
if command -v jdupes &>/dev/null; then
  USE_JDUPES=true
elif command -v fdupes &>/dev/null; then
  USE_FDUPES=true
fi

# Temp files
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Build find command
FIND_ARGS=()
for d in "${DIRS[@]}"; do
  FIND_ARGS+=("$d")
done
FIND_ARGS+=(-type f)

if [[ "$FOLLOW_LINKS" == true ]]; then
  FIND_ARGS=(-L "${FIND_ARGS[@]}")
fi

if [[ "$HIDDEN" != true ]]; then
  FIND_ARGS+=(-not -path '*/.*')
fi

FIND_ARGS+=(-size +"$((MIN_SIZE - 1))"c)

if [[ -n "$MAX_SIZE" ]]; then
  FIND_ARGS+=(-size -"$((MAX_SIZE + 1))"c)
fi

for pat in "${EXCLUDES[@]+"${EXCLUDES[@]}"}"; do
  FIND_ARGS+=(-not -path "$pat")
done

$QUIET || echo -e "${BLUE}🔍 Scanning ${DIRS[*]} ...${NC}"

# If jdupes available and action is report, use it directly
if [[ "$USE_JDUPES" == true && "$FORMAT" == "text" && "$ACTION" == "report" && "$INTERACTIVE" != true ]]; then
  JDUPES_ARGS=(-r)
  [[ "$HIDDEN" == true ]] && JDUPES_ARGS+=(-A)
  if [[ -n "$MIN_SIZE" && "$MIN_SIZE" -gt 1 ]]; then
    JDUPES_ARGS+=(-X size-:"$MIN_SIZE")
  fi
  JDUPES_ARGS+=(-S "${DIRS[@]}")

  if [[ -n "$OUTPUT" ]]; then
    jdupes "${JDUPES_ARGS[@]}" > "$OUTPUT" 2>/dev/null
    echo "Report written to $OUTPUT"
  else
    jdupes "${JDUPES_ARGS[@]}" 2>/dev/null
  fi
  exit 0
fi

# Pure bash implementation — 3-stage approach

# Stage 1: Group by size
$QUIET || echo -e "${BLUE}  Stage 1: Grouping files by size...${NC}"

find "${FIND_ARGS[@]}" -printf '%s %p\n' 2>/dev/null | sort -n > "$TMPDIR/all-files.txt"

TOTAL_FILES=$(wc -l < "$TMPDIR/all-files.txt")
TOTAL_SIZE=0

$QUIET || echo -e "  📊 Found ${TOTAL_FILES} files"

# Find sizes with >1 file
awk '{print $1}' "$TMPDIR/all-files.txt" | sort -n | uniq -d > "$TMPDIR/dup-sizes.txt"

DUP_SIZE_COUNT=$(wc -l < "$TMPDIR/dup-sizes.txt")

if [[ "$DUP_SIZE_COUNT" -eq 0 ]]; then
  $QUIET || echo -e "${GREEN}✅ No duplicate files found.${NC}"
  exit 0
fi

$QUIET || echo -e "${BLUE}  Stage 2: Partial hashing ${DUP_SIZE_COUNT} size groups...${NC}"

# Stage 2: Partial hash files with matching sizes
> "$TMPDIR/partial-hashes.txt"

while IFS= read -r size; do
  grep -E "^${size} " "$TMPDIR/all-files.txt" | while IFS=' ' read -r fsize fpath; do
    phash=$(partial_hash "$fpath")
    echo "${fsize}:${phash} ${fpath}" >> "$TMPDIR/partial-hashes.txt"
  done
done < "$TMPDIR/dup-sizes.txt"

# Find partial hash groups with >1 file
awk '{print $1}' "$TMPDIR/partial-hashes.txt" | sort | uniq -d > "$TMPDIR/dup-partial.txt"

PARTIAL_DUP_COUNT=$(wc -l < "$TMPDIR/dup-partial.txt")

if [[ "$PARTIAL_DUP_COUNT" -eq 0 ]]; then
  $QUIET || echo -e "${GREEN}✅ No duplicate files found after partial hash.${NC}"
  exit 0
fi

$QUIET || echo -e "${BLUE}  Stage 3: Full hashing ${PARTIAL_DUP_COUNT} candidate groups...${NC}"

# Stage 3: Full hash candidates
> "$TMPDIR/full-hashes.txt"

while IFS= read -r key; do
  grep -F "$key " "$TMPDIR/partial-hashes.txt" | while IFS=' ' read -r sizekey fpath; do
    fhash=$(hash_file "$fpath" "$HASH_ALGO")
    fsize="${sizekey%%:*}"
    echo "${fhash} ${fsize} ${fpath}" >> "$TMPDIR/full-hashes.txt"
  done
done < "$TMPDIR/dup-partial.txt"

# Group by full hash
sort "$TMPDIR/full-hashes.txt" > "$TMPDIR/full-sorted.txt"

# Extract duplicate groups
> "$TMPDIR/groups.txt"
GROUP_NUM=0
TOTAL_WASTED=0
TOTAL_DUP_FILES=0

awk '{print $1}' "$TMPDIR/full-sorted.txt" | sort | uniq -d > "$TMPDIR/dup-hashes.txt"

# Process groups
declare -A GROUP_DATA

while IFS= read -r hash; do
  GROUP_NUM=$((GROUP_NUM + 1))
  FILES=()
  FSIZE=0

  while IFS=' ' read -r fhash fsize fpath; do
    FILES+=("$fpath")
    FSIZE=$fsize
  done < <(grep "^${hash} " "$TMPDIR/full-sorted.txt")

  COUNT=${#FILES[@]}
  WASTED=$(( FSIZE * (COUNT - 1) ))
  TOTAL_WASTED=$((TOTAL_WASTED + WASTED))
  TOTAL_DUP_FILES=$((TOTAL_DUP_FILES + COUNT - 1))

  # Cross-only filter
  if [[ "$CROSS_ONLY" == true && ${#DIRS[@]} -gt 1 ]]; then
    FOUND_DIRS=()
    for f in "${FILES[@]}"; do
      for d in "${DIRS[@]}"; do
        if [[ "$f" == "$d"* ]]; then
          FOUND_DIRS+=("$d")
          break
        fi
      done
    done
    UNIQUE_DIRS=$(printf '%s\n' "${FOUND_DIRS[@]}" | sort -u | wc -l)
    if [[ "$UNIQUE_DIRS" -lt 2 ]]; then
      GROUP_NUM=$((GROUP_NUM - 1))
      TOTAL_WASTED=$((TOTAL_WASTED - WASTED))
      TOTAL_DUP_FILES=$((TOTAL_DUP_FILES - COUNT + 1))
      continue
    fi
  fi

  # Format size
  if [[ $FSIZE -ge 1073741824 ]]; then
    SIZE_FMT="$(echo "scale=1; $FSIZE/1073741824" | bc) GB"
  elif [[ $FSIZE -ge 1048576 ]]; then
    SIZE_FMT="$(echo "scale=1; $FSIZE/1048576" | bc) MB"
  elif [[ $FSIZE -ge 1024 ]]; then
    SIZE_FMT="$(echo "scale=1; $FSIZE/1024" | bc) KB"
  else
    SIZE_FMT="${FSIZE} B"
  fi

  # Output based on format
  if [[ "$FORMAT" == "text" ]]; then
    if [[ "$QUIET" != true ]]; then
      echo ""
      echo -e "${YELLOW}--- Group ${GROUP_NUM} [${COUNT} copies] ${SIZE_FMT} each ---${NC}"
      for f in "${FILES[@]}"; do
        MTIME=$(date -d "@$(file_mtime "$f")" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$(file_mtime "$f")" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")
        echo "  $f ($MTIME)"
      done
    fi
  fi

  # Handle actions
  if [[ "$ACTION" != "report" ]]; then
    # Determine which to keep
    KEEP_FILE=""
    case "$KEEP" in
      newest)
        BEST_TIME=0
        for f in "${FILES[@]}"; do
          T=$(file_mtime "$f")
          if [[ $T -gt $BEST_TIME ]]; then
            BEST_TIME=$T
            KEEP_FILE="$f"
          fi
        done
        ;;
      oldest)
        BEST_TIME=999999999999
        for f in "${FILES[@]}"; do
          T=$(file_mtime "$f")
          if [[ $T -lt $BEST_TIME ]]; then
            BEST_TIME=$T
            KEEP_FILE="$f"
          fi
        done
        ;;
      shortest-path)
        BEST_LEN=99999
        for f in "${FILES[@]}"; do
          L=${#f}
          if [[ $L -lt $BEST_LEN ]]; then
            BEST_LEN=$L
            KEEP_FILE="$f"
          fi
        done
        ;;
    esac

    if [[ "$INTERACTIVE" == true ]]; then
      echo ""
      echo -e "${YELLOW}--- Group ${GROUP_NUM} (${COUNT} files, wasted: ${SIZE_FMT}) ---${NC}"
      IDX=1
      for f in "${FILES[@]}"; do
        MTIME=$(date -d "@$(file_mtime "$f")" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")
        echo "  [$IDX] $f ($MTIME)"
        IDX=$((IDX + 1))
      done
      echo -n "Keep which? (1-${COUNT}/all/skip) > "
      read -r CHOICE
      case "$CHOICE" in
        all|skip) continue ;;
        *)
          if [[ "$CHOICE" =~ ^[0-9]+$ && "$CHOICE" -ge 1 && "$CHOICE" -le ${COUNT} ]]; then
            KEEP_FILE="${FILES[$((CHOICE - 1))]}"
          else
            continue
          fi
          ;;
      esac
    fi

    # Perform action on non-kept files
    for f in "${FILES[@]}"; do
      [[ "$f" == "$KEEP_FILE" ]] && continue
      case "$ACTION" in
        delete)
          if [[ "$DRY_RUN" == true ]]; then
            echo -e "  ${RED}[DRY RUN] Would delete: $f${NC}"
          else
            rm -f "$f"
            $QUIET || echo -e "  ${RED}Deleted: $f${NC}"
          fi
          ;;
        hardlink)
          if [[ "$DRY_RUN" == true ]]; then
            echo -e "  ${BLUE}[DRY RUN] Would hardlink: $f → $KEEP_FILE${NC}"
          else
            rm -f "$f"
            ln "$KEEP_FILE" "$f"
            $QUIET || echo -e "  ${GREEN}Hardlinked: $f → $KEEP_FILE${NC}"
          fi
          ;;
        symlink)
          if [[ "$DRY_RUN" == true ]]; then
            echo -e "  ${BLUE}[DRY RUN] Would symlink: $f → $KEEP_FILE${NC}"
          else
            rm -f "$f"
            ln -s "$(realpath "$KEEP_FILE")" "$f"
            $QUIET || echo -e "  ${GREEN}Symlinked: $f → $KEEP_FILE${NC}"
          fi
          ;;
      esac
    done
  fi
done < "$TMPDIR/dup-hashes.txt"

# Format wasted space
if [[ $TOTAL_WASTED -ge 1073741824 ]]; then
  WASTED_FMT="$(echo "scale=1; $TOTAL_WASTED/1073741824" | bc) GB"
elif [[ $TOTAL_WASTED -ge 1048576 ]]; then
  WASTED_FMT="$(echo "scale=1; $TOTAL_WASTED/1048576" | bc) MB"
elif [[ $TOTAL_WASTED -ge 1024 ]]; then
  WASTED_FMT="$(echo "scale=1; $TOTAL_WASTED/1024" | bc) KB"
else
  WASTED_FMT="${TOTAL_WASTED} B"
fi

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Summary${NC}"
echo -e "  Files scanned: ${TOTAL_FILES}"
echo -e "  Duplicate groups: ${GROUP_NUM}"
echo -e "  Duplicate files: ${TOTAL_DUP_FILES}"
echo -e "  ${RED}Wasted space: ${WASTED_FMT}${NC}"

if [[ "$ACTION" != "report" && "$DRY_RUN" != true ]]; then
  echo -e "  ${GREEN}✅ Action '${ACTION}' completed. Reclaimed: ${WASTED_FMT}${NC}"
elif [[ "$DRY_RUN" == true ]]; then
  echo -e "  ${YELLOW}⚠️  Dry run — no changes made${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# JSON output
if [[ "$FORMAT" == "json" ]]; then
  echo "{"
  echo "  \"total_files\": ${TOTAL_FILES},"
  echo "  \"duplicate_groups\": ${GROUP_NUM},"
  echo "  \"duplicate_files\": ${TOTAL_DUP_FILES},"
  echo "  \"wasted_bytes\": ${TOTAL_WASTED},"
  echo "  \"wasted_human\": \"${WASTED_FMT}\""
  echo "}"
fi

# CSV header
if [[ "$FORMAT" == "csv" ]]; then
  echo "group,hash,size,path"
  GROUP_IDX=0
  while IFS= read -r hash; do
    GROUP_IDX=$((GROUP_IDX + 1))
    while IFS=' ' read -r fhash fsize fpath; do
      echo "${GROUP_IDX},${fhash},${fsize},\"${fpath}\""
    done < <(grep "^${hash} " "$TMPDIR/full-sorted.txt")
  done < "$TMPDIR/dup-hashes.txt"
fi
