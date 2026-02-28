#!/bin/bash
# Duplicate File Finder — Content-based duplicate detection
# Uses 3-stage hashing: size → partial hash → full hash
# Auto-detects jdupes/fdupes for faster scanning if available

set -euo pipefail

VERSION="1.0.0"

# --- Defaults ---
DIRS=()
DELETE=false
DRY_RUN=false
KEEP="oldest"
CONFIRM=false
MIN_SIZE=1  # bytes
EXTENSIONS=""
EXCLUDE_PATTERNS=""
FORMAT="text"
CROSS_ONLY=false
HASH_CMD=""
SKIP_HIDDEN="${DUPES_SKIP_HIDDEN:-false}"
REPORT_DIR="${DUPES_REPORT_DIR:-.}"
HASH_ALGO="${DUPES_HASH_ALGO:-md5}"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --delete) DELETE=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --keep) KEEP="$2"; shift 2 ;;
    --confirm) CONFIRM=true; shift ;;
    --min-size) MIN_SIZE="$2"; shift 2 ;;
    --ext) EXTENSIONS="$2"; shift 2 ;;
    --exclude) EXCLUDE_PATTERNS="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --cross-only) CROSS_ONLY=true; shift ;;
    --version) echo "duplicate-finder v${VERSION}"; exit 0 ;;
    --help|-h)
      echo "Usage: find-dupes.sh [DIRS...] [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --delete          Remove duplicates (keeps one per group)"
      echo "  --dry-run         Show what would be deleted"
      echo "  --keep MODE       Which file to keep: oldest|newest|first|shortest"
      echo "  --confirm         Require y/n before each deletion"
      echo "  --min-size SIZE   Minimum file size (e.g., 1M, 100K, 500)"
      echo "  --ext EXTS        Filter by extensions (comma-separated: jpg,png,gif)"
      echo "  --exclude PATS    Exclude patterns (comma-separated: node_modules,.git)"
      echo "  --format FMT      Output format: text|json|paths-only"
      echo "  --cross-only      Only show duplicates spanning multiple input dirs"
      echo "  --version         Show version"
      echo "  --help            Show this help"
      exit 0
      ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *) DIRS+=("$1"); shift ;;
  esac
done

# Default to current directory
if [[ ${#DIRS[@]} -eq 0 ]]; then
  DIRS=(".")
fi

# --- Detect hash command ---
detect_hash_cmd() {
  if [[ "$HASH_ALGO" == "sha256" ]]; then
    if command -v sha256sum &>/dev/null; then
      HASH_CMD="sha256sum"
    elif command -v shasum &>/dev/null; then
      HASH_CMD="shasum -a 256"
    fi
  else
    if command -v md5sum &>/dev/null; then
      HASH_CMD="md5sum"
    elif command -v md5 &>/dev/null; then
      HASH_CMD="md5 -q"
    fi
  fi

  if [[ -z "$HASH_CMD" ]]; then
    echo "Error: No hash command found. Install md5sum or md5." >&2
    exit 1
  fi
}

# --- Convert human-readable size to bytes ---
parse_size() {
  local size="$1"
  local num="${size//[^0-9.]/}"
  local unit="${size//[0-9.]/}"
  unit="${unit^^}"

  case "$unit" in
    K|KB) echo "$(echo "$num * 1024" | bc | cut -d. -f1)" ;;
    M|MB) echo "$(echo "$num * 1048576" | bc | cut -d. -f1)" ;;
    G|GB) echo "$(echo "$num * 1073741824" | bc | cut -d. -f1)" ;;
    *) echo "${num%.*}" ;;
  esac
}

# --- Check for jdupes/fdupes ---
check_fast_tools() {
  if command -v jdupes &>/dev/null; then
    echo "jdupes"
  elif command -v fdupes &>/dev/null; then
    echo "fdupes"
  else
    echo ""
  fi
}

# --- Build find command args ---
build_find_args() {
  local args=()
  
  # Add directories
  for dir in "${DIRS[@]}"; do
    args+=("$dir")
  done

  # File type
  args+=("-type" "f")

  # Skip hidden
  if [[ "$SKIP_HIDDEN" == "true" ]]; then
    args+=("-not" "-path" "*/.*")
  fi

  # Exclude patterns
  if [[ -n "$EXCLUDE_PATTERNS" ]]; then
    IFS=',' read -ra EXCLUDES <<< "$EXCLUDE_PATTERNS"
    for pattern in "${EXCLUDES[@]}"; do
      args+=("-not" "-path" "*/${pattern}/*" "-not" "-name" "${pattern}")
    done
  fi

  # Extensions filter
  if [[ -n "$EXTENSIONS" ]]; then
    IFS=',' read -ra EXTS <<< "$EXTENSIONS"
    args+=("(")
    local first=true
    for ext in "${EXTS[@]}"; do
      ext="${ext#.}"  # Remove leading dot if present
      if [[ "$first" == "true" ]]; then
        first=false
      else
        args+=("-o")
      fi
      args+=("-iname" "*.${ext}")
    done
    args+=(")")
  fi

  # Min size
  local min_bytes
  min_bytes=$(parse_size "$MIN_SIZE")
  if [[ "$min_bytes" -gt 1 ]]; then
    args+=("-size" "+${min_bytes}c")
  fi

  echo "${args[@]}"
}

# --- Hash a file (full or partial) ---
hash_file() {
  local file="$1"
  local partial="${2:-false}"

  if [[ "$partial" == "true" ]]; then
    head -c 4096 "$file" 2>/dev/null | $HASH_CMD 2>/dev/null | awk '{print $1}'
  else
    $HASH_CMD "$file" 2>/dev/null | awk '{print $1}'
  fi
}

# --- Get file modification time (epoch) ---
get_mtime() {
  local file="$1"
  if stat --version &>/dev/null 2>&1; then
    # GNU stat
    stat -c %Y "$file" 2>/dev/null
  else
    # BSD stat (macOS)
    stat -f %m "$file" 2>/dev/null
  fi
}

# --- Get file size ---
get_size() {
  local file="$1"
  if stat --version &>/dev/null 2>&1; then
    stat -c %s "$file" 2>/dev/null
  else
    stat -f %z "$file" 2>/dev/null
  fi
}

# --- Human-readable size ---
human_size() {
  local bytes=$1
  if [[ $bytes -ge 1073741824 ]]; then
    echo "$(echo "scale=1; $bytes / 1073741824" | bc) GB"
  elif [[ $bytes -ge 1048576 ]]; then
    echo "$(echo "scale=1; $bytes / 1048576" | bc) MB"
  elif [[ $bytes -ge 1024 ]]; then
    echo "$(echo "scale=1; $bytes / 1024" | bc) KB"
  else
    echo "${bytes} B"
  fi
}

# --- Select file to keep from a group ---
select_keeper() {
  local keep_mode="$1"
  shift
  local files=("$@")
  local keeper=""
  local keeper_val=""

  for file in "${files[@]}"; do
    case "$keep_mode" in
      oldest)
        local mtime
        mtime=$(get_mtime "$file")
        if [[ -z "$keeper_val" ]] || [[ "$mtime" -lt "$keeper_val" ]]; then
          keeper="$file"
          keeper_val="$mtime"
        fi
        ;;
      newest)
        local mtime
        mtime=$(get_mtime "$file")
        if [[ -z "$keeper_val" ]] || [[ "$mtime" -gt "$keeper_val" ]]; then
          keeper="$file"
          keeper_val="$mtime"
        fi
        ;;
      first)
        if [[ -z "$keeper" ]]; then
          keeper="$file"
        elif [[ "$file" < "$keeper" ]]; then
          keeper="$file"
        fi
        ;;
      shortest)
        local len=${#file}
        if [[ -z "$keeper_val" ]] || [[ "$len" -lt "$keeper_val" ]]; then
          keeper="$file"
          keeper_val="$len"
        fi
        ;;
    esac
  done

  echo "$keeper"
}

# --- Main ---
detect_hash_cmd

FAST_TOOL=$(check_fast_tools)

# Use jdupes/fdupes if available (much faster for large dirs)
if [[ -n "$FAST_TOOL" && "$FORMAT" == "text" && "$CROSS_ONLY" == "false" && -z "$EXTENSIONS" ]]; then
  echo -e "${BLUE}🔍 Using ${FAST_TOOL} for fast scanning...${NC}"
  
  FAST_ARGS=("-r")
  if [[ "$FAST_TOOL" == "jdupes" ]]; then
    FAST_ARGS+=("-S")  # print sizes
    if [[ "$DELETE" == "true" && "$DRY_RUN" == "false" ]]; then
      case "$KEEP" in
        oldest) FAST_ARGS+=("-dO") ;;
        newest) FAST_ARGS+=("-dN") ;;
        *) FAST_ARGS+=("-d") ;;
      esac
    fi
  fi
  
  $FAST_TOOL "${FAST_ARGS[@]}" "${DIRS[@]}"
  exit $?
fi

echo -e "${BLUE}🔍 Scanning ${DIRS[*]} ...${NC}"

# Step 1: Collect files and group by size
declare -A SIZE_FILES
TOTAL_FILES=0
TOTAL_BYTES=0

FIND_ARGS=$(build_find_args)

while IFS= read -r -d '' file; do
  size=$(get_size "$file") || continue
  [[ -z "$size" || "$size" == "0" ]] && continue
  
  TOTAL_FILES=$((TOTAL_FILES + 1))
  TOTAL_BYTES=$((TOTAL_BYTES + size))
  
  if [[ -n "${SIZE_FILES[$size]:-}" ]]; then
    SIZE_FILES[$size]="${SIZE_FILES[$size]}"$'\n'"$file"
  else
    SIZE_FILES[$size]="$file"
  fi
done < <(eval find "${FIND_ARGS}" -print0 2>/dev/null)

echo -e "   Found ${TOTAL_FILES} files ($(human_size $TOTAL_BYTES) total)"

# Step 2: For size-matched files, compute partial then full hashes
echo -e "   Computing checksums..."

declare -A DUPE_GROUPS
GROUP_COUNT=0
DUPE_FILE_COUNT=0
WASTED_BYTES=0

for size in "${!SIZE_FILES[@]}"; do
  # Skip unique sizes
  file_count=$(echo "${SIZE_FILES[$size]}" | wc -l)
  [[ "$file_count" -lt 2 ]] && continue
  
  # Partial hash pass
  declare -A PARTIAL_HASH_FILES
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    phash=$(hash_file "$file" true) || continue
    [[ -z "$phash" ]] && continue
    
    if [[ -n "${PARTIAL_HASH_FILES[$phash]:-}" ]]; then
      PARTIAL_HASH_FILES[$phash]="${PARTIAL_HASH_FILES[$phash]}"$'\n'"$file"
    else
      PARTIAL_HASH_FILES[$phash]="$file"
    fi
  done <<< "${SIZE_FILES[$size]}"
  
  # Full hash pass (only for partial hash matches)
  for phash in "${!PARTIAL_HASH_FILES[@]}"; do
    pcount=$(echo "${PARTIAL_HASH_FILES[$phash]}" | wc -l)
    [[ "$pcount" -lt 2 ]] && continue
    
    declare -A FULL_HASH_FILES
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      fhash=$(hash_file "$file" false) || continue
      [[ -z "$fhash" ]] && continue
      
      if [[ -n "${FULL_HASH_FILES[$fhash]:-}" ]]; then
        FULL_HASH_FILES[$fhash]="${FULL_HASH_FILES[$fhash]}"$'\n'"$file"
      else
        FULL_HASH_FILES[$fhash]="$file"
      fi
    done <<< "${PARTIAL_HASH_FILES[$phash]}"
    
    # Record confirmed duplicate groups
    for fhash in "${!FULL_HASH_FILES[@]}"; do
      fcount=$(echo "${FULL_HASH_FILES[$fhash]}" | wc -l)
      [[ "$fcount" -lt 2 ]] && continue
      
      # Cross-only filter
      if [[ "$CROSS_ONLY" == "true" && ${#DIRS[@]} -gt 1 ]]; then
        local dirs_seen=()
        local cross=false
        while IFS= read -r file; do
          for i in "${!DIRS[@]}"; do
            if [[ "$file" == "${DIRS[$i]}"* ]]; then
              if [[ ! " ${dirs_seen[*]} " =~ " $i " ]]; then
                dirs_seen+=("$i")
              fi
            fi
          done
        done <<< "${FULL_HASH_FILES[$fhash]}"
        [[ ${#dirs_seen[@]} -lt 2 ]] && continue
      fi
      
      GROUP_COUNT=$((GROUP_COUNT + 1))
      DUPE_FILE_COUNT=$((DUPE_FILE_COUNT + fcount - 1))
      WASTED_BYTES=$((WASTED_BYTES + size * (fcount - 1)))
      DUPE_GROUPS["group_${GROUP_COUNT}"]="${FULL_HASH_FILES[$fhash]}"
    done
    unset FULL_HASH_FILES
  done
  unset PARTIAL_HASH_FILES
done

echo -e "   ${GREEN}✅ Scan complete!${NC}"
echo ""
echo -e "${YELLOW}📊 Results:${NC}"
echo -e "   Duplicate groups: ${GROUP_COUNT}"
echo -e "   Duplicate files:  ${DUPE_FILE_COUNT}"
echo -e "   Wasted space:     $(human_size $WASTED_BYTES)"

if [[ "$GROUP_COUNT" -eq 0 ]]; then
  echo -e "\n${GREEN}No duplicates found! 🎉${NC}"
  exit 0
fi

# --- Output ---
REPORT_FILE="${REPORT_DIR}/dupes-report-$(date +%Y-%m-%d).txt"
DELETED_COUNT=0
FREED_BYTES=0

if [[ "$FORMAT" == "json" ]]; then
  echo "{"
  echo '  "scan_date": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",'
  echo '  "directories": ['$(printf '"%s",' "${DIRS[@]}" | sed 's/,$//')'],'
  echo "  \"total_files\": ${TOTAL_FILES},"
  echo "  \"total_bytes\": ${TOTAL_BYTES},"
  echo "  \"duplicate_groups\": ${GROUP_COUNT},"
  echo "  \"duplicate_files\": ${DUPE_FILE_COUNT},"
  echo "  \"wasted_bytes\": ${WASTED_BYTES},"
  echo '  "groups": ['
  
  first_group=true
  for key in "${!DUPE_GROUPS[@]}"; do
    [[ "$first_group" == "true" ]] && first_group=false || echo ","
    echo "    {"
    first_file=true
    echo '      "files": ['
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      local fsize
      fsize=$(get_size "$file")
      [[ "$first_file" == "true" ]] && first_file=false || echo ","
      printf '        {"path": "%s", "size": %s}' "$file" "$fsize"
    done <<< "${DUPE_GROUPS[$key]}"
    echo ""
    echo "      ],"
    # Get size from first file
    first_f=$(echo "${DUPE_GROUPS[$key]}" | head -1)
    fsize=$(get_size "$first_f")
    fcount=$(echo "${DUPE_GROUPS[$key]}" | wc -l)
    echo "      \"wasted_bytes\": $((fsize * (fcount - 1)))"
    echo -n "    }"
  done
  echo ""
  echo "  ]"
  echo "}"
  exit 0
fi

if [[ "$FORMAT" == "paths-only" ]]; then
  for key in "${!DUPE_GROUPS[@]}"; do
    mapfile -t files <<< "${DUPE_GROUPS[$key]}"
    keeper=$(select_keeper "$KEEP" "${files[@]}")
    for file in "${files[@]}"; do
      [[ "$file" == "$keeper" ]] && continue
      [[ -z "$file" ]] && continue
      echo "$file"
    done
  done
  exit 0
fi

# Text format — write report
{
  echo "═══════════════════════════════════════════════════════════"
  echo "  DUPLICATE FILE REPORT"
  echo "  Generated: $(date)"
  echo "  Directories: ${DIRS[*]}"
  echo "  Total files scanned: ${TOTAL_FILES}"
  echo "  Total size: $(human_size $TOTAL_BYTES)"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "  Duplicate groups: ${GROUP_COUNT}"
  echo "  Duplicate files:  ${DUPE_FILE_COUNT}"
  echo "  Wasted space:     $(human_size $WASTED_BYTES)"
  echo ""
  echo "───────────────────────────────────────────────────────────"
  
  group_num=0
  for key in "${!DUPE_GROUPS[@]}"; do
    group_num=$((group_num + 1))
    first_f=$(echo "${DUPE_GROUPS[$key]}" | head -1)
    fsize=$(get_size "$first_f")
    fcount=$(echo "${DUPE_GROUPS[$key]}" | wc -l)
    
    echo ""
    echo "  Group ${group_num} — $(human_size $fsize) each × ${fcount} copies ($(human_size $((fsize * (fcount - 1)))) wasted)"
    
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      mtime=$(date -d @"$(get_mtime "$file")" "+%Y-%m-%d %H:%M" 2>/dev/null || date -r "$(get_mtime "$file")" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
      echo "    📄 $file  (modified: $mtime)"
    done <<< "${DUPE_GROUPS[$key]}"
  done
  
  echo ""
  echo "═══════════════════════════════════════════════════════════"
} | tee "$REPORT_FILE"

echo ""
echo -e "${GREEN}Report saved to: ${REPORT_FILE}${NC}"

# --- Deletion ---
if [[ "$DELETE" == "true" ]]; then
  echo ""
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}🔍 DRY RUN — showing what would be deleted:${NC}"
  else
    echo -e "${RED}🗑️  Deleting duplicates (keeping ${KEEP} copy)...${NC}"
  fi
  
  for key in "${!DUPE_GROUPS[@]}"; do
    mapfile -t files <<< "${DUPE_GROUPS[$key]}"
    keeper=$(select_keeper "$KEEP" "${files[@]}")
    
    for file in "${files[@]}"; do
      [[ "$file" == "$keeper" ]] && continue
      [[ -z "$file" ]] && continue
      
      fsize=$(get_size "$file")
      
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would delete: $file ($(human_size $fsize))"
      else
        if [[ "$CONFIRM" == "true" ]]; then
          echo -n "  Delete $file? (y/N) "
          read -r answer
          [[ "$answer" != "y" && "$answer" != "Y" ]] && continue
        fi
        
        rm -f "$file"
        DELETED_COUNT=$((DELETED_COUNT + 1))
        FREED_BYTES=$((FREED_BYTES + fsize))
        echo "  ✅ Deleted: $file"
      fi
    done
    echo "  📌 Kept: $keeper"
  done
  
  if [[ "$DRY_RUN" == "false" ]]; then
    echo ""
    echo -e "${GREEN}🎉 Cleanup complete!${NC}"
    echo -e "   Files deleted: ${DELETED_COUNT}"
    echo -e "   Space freed:   $(human_size $FREED_BYTES)"
  fi
fi
