#!/bin/bash
# Archive Manager — Universal archive tool
# Usage: bash run.sh <command> [args...]
# Commands: create, extract, list, test, batch-extract, batch-create, batch-test, convert

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}✅ $*${NC}"; }
log_err()  { echo -e "${RED}❌ $*${NC}" >&2; }
log_warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }

# Check if tool exists
need() {
  if ! command -v "$1" &>/dev/null; then
    log_err "$1 not found. Run: bash scripts/install.sh"
    exit 1
  fi
}

# Detect archive format from extension
detect_format() {
  local file="$1"
  case "$file" in
    *.tar.gz|*.tgz)     echo "tar.gz" ;;
    *.tar.bz2|*.tbz2)   echo "tar.bz2" ;;
    *.tar.xz|*.txz)     echo "tar.xz" ;;
    *.tar.zst|*.tzst)    echo "tar.zst" ;;
    *.tar)               echo "tar" ;;
    *.zip)               echo "zip" ;;
    *.7z)                echo "7z" ;;
    *.rar)               echo "rar" ;;
    *)                   echo "unknown" ;;
  esac
}

# Parse common flags from remaining args
parse_flags() {
  PASSWORD=""
  OUTPUT=""
  LEVEL=""
  SPLIT=""
  DRY_RUN=false
  EXCLUDES=()
  FORMAT=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --password)  PASSWORD="$2"; shift 2 ;;
      --output|-o) OUTPUT="$2"; shift 2 ;;
      --level)     LEVEL="$2"; shift 2 ;;
      --split)     SPLIT="$2"; shift 2 ;;
      --dry-run)   DRY_RUN=true; shift ;;
      --exclude)   EXCLUDES+=("$2"); shift 2 ;;
      --format)    FORMAT="$2"; shift 2 ;;
      --to)        FORMAT="$2"; shift 2 ;;
      *)           EXTRA_ARGS+=("$1"); shift ;;
    esac
  done
}

# ─── CREATE ───────────────────────────────────────────────────────────

cmd_create() {
  local archive="$1"; shift
  local source="$1"; shift
  EXTRA_ARGS=()
  parse_flags "$@"
  
  if [ ! -e "$source" ]; then
    log_err "Source not found: $source"
    exit 1
  fi
  
  local fmt
  fmt=$(detect_format "$archive")
  
  # Build exclude args
  local tar_excludes=()
  for ex in "${EXCLUDES[@]}"; do
    tar_excludes+=("--exclude=$ex")
  done
  
  if $DRY_RUN; then
    log_info "DRY RUN — would create $archive from $source ($fmt format)"
    if [ ${#EXCLUDES[@]} -gt 0 ]; then
      log_info "Excluding: ${EXCLUDES[*]}"
    fi
    return 0
  fi
  
  local start_time
  start_time=$(date +%s)
  
  case "$fmt" in
    tar.gz)
      need tar; need gzip
      tar czf "$archive" "${tar_excludes[@]}" -C "$(dirname "$source")" "$(basename "$source")"
      ;;
    tar.bz2)
      need tar; need bzip2
      tar cjf "$archive" "${tar_excludes[@]}" -C "$(dirname "$source")" "$(basename "$source")"
      ;;
    tar.xz)
      need tar; need xz
      tar cJf "$archive" "${tar_excludes[@]}" -C "$(dirname "$source")" "$(basename "$source")"
      ;;
    tar.zst)
      need tar; need zstd
      local zst_level=""
      [ -n "$LEVEL" ] && zst_level="--zstd=--${LEVEL}"
      tar --zstd $zst_level -cf "$archive" "${tar_excludes[@]}" -C "$(dirname "$source")" "$(basename "$source")"
      ;;
    tar)
      need tar
      tar cf "$archive" "${tar_excludes[@]}" -C "$(dirname "$source")" "$(basename "$source")"
      ;;
    zip)
      need zip
      local zip_args=(-r)
      [ -n "$PASSWORD" ] && zip_args+=(-P "$PASSWORD")
      [ -n "$LEVEL" ] && zip_args+=("-$LEVEL")
      for ex in "${EXCLUDES[@]}"; do
        zip_args+=(-x "$ex")
      done
      (cd "$(dirname "$source")" && zip "${zip_args[@]}" "$(cd "$OLDPWD" && realpath "$archive")" "$(basename "$source")")
      ;;
    7z)
      need 7z
      local sz_args=(a)
      [ -n "$PASSWORD" ] && sz_args+=("-p$PASSWORD" "-mhe=on")
      [ -n "$LEVEL" ] && sz_args+=("-mx=$LEVEL")
      [ -n "$SPLIT" ] && sz_args+=("-v$SPLIT")
      for ex in "${EXCLUDES[@]}"; do
        sz_args+=("-xr!$ex")
      done
      7z "${sz_args[@]}" "$archive" "$source"
      ;;
    *)
      log_err "Unsupported format for creation: $archive"
      exit 1
      ;;
  esac
  
  local end_time elapsed size
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  size=$(du -h "$archive" 2>/dev/null | cut -f1)
  
  log_ok "Created $archive ($size) in ${elapsed}s"
}

# ─── EXTRACT ──────────────────────────────────────────────────────────

cmd_extract() {
  local archive="$1"; shift
  EXTRA_ARGS=()
  parse_flags "$@"
  
  if [ ! -f "$archive" ]; then
    log_err "Archive not found: $archive"
    exit 1
  fi
  
  local fmt
  fmt=$(detect_format "$archive")
  local dest="${OUTPUT:-.}"
  mkdir -p "$dest"
  
  local start_time
  start_time=$(date +%s)
  
  case "$fmt" in
    tar.gz)  need tar; tar xzf "$archive" -C "$dest" ;;
    tar.bz2) need tar; tar xjf "$archive" -C "$dest" ;;
    tar.xz)  need tar; tar xJf "$archive" -C "$dest" ;;
    tar.zst) need tar; need zstd; tar --zstd -xf "$archive" -C "$dest" ;;
    tar)     need tar; tar xf "$archive" -C "$dest" ;;
    zip)
      need unzip
      local uz_args=(-o)
      [ -n "$PASSWORD" ] && uz_args+=(-P "$PASSWORD")
      unzip "${uz_args[@]}" "$archive" -d "$dest"
      ;;
    7z)
      need 7z
      local sz_args=(x "-o$dest" -y)
      [ -n "$PASSWORD" ] && sz_args+=("-p$PASSWORD")
      7z "${sz_args[@]}" "$archive"
      ;;
    rar)
      need unrar
      local rar_args=(x -y)
      [ -n "$PASSWORD" ] && rar_args+=("-p$PASSWORD")
      unrar "${rar_args[@]}" "$archive" "$dest/"
      ;;
    *)
      log_err "Unsupported format: $archive"
      exit 1
      ;;
  esac
  
  local end_time elapsed
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  
  log_ok "Extracted $archive → $dest (${elapsed}s)"
}

# ─── LIST ─────────────────────────────────────────────────────────────

cmd_list() {
  local archive="$1"; shift
  EXTRA_ARGS=()
  parse_flags "$@"
  
  if [ ! -f "$archive" ]; then
    log_err "Archive not found: $archive"
    exit 1
  fi
  
  local fmt
  fmt=$(detect_format "$archive")
  
  case "$fmt" in
    tar.gz)  tar tzf "$archive" ;;
    tar.bz2) tar tjf "$archive" ;;
    tar.xz)  tar tJf "$archive" ;;
    tar.zst) tar --zstd -tf "$archive" ;;
    tar)     tar tf "$archive" ;;
    zip)     unzip -l "$archive" ;;
    7z)
      local sz_args=(l)
      [ -n "$PASSWORD" ] && sz_args+=("-p$PASSWORD")
      7z "${sz_args[@]}" "$archive"
      ;;
    rar)
      local rar_args=(l)
      [ -n "$PASSWORD" ] && rar_args+=("-p$PASSWORD")
      unrar "${rar_args[@]}" "$archive"
      ;;
    *)
      log_err "Unsupported format: $archive"
      exit 1
      ;;
  esac
}

# ─── TEST ─────────────────────────────────────────────────────────────

cmd_test() {
  local archive="$1"; shift
  EXTRA_ARGS=()
  parse_flags "$@"
  
  if [ ! -f "$archive" ]; then
    log_err "Archive not found: $archive"
    exit 1
  fi
  
  local fmt
  fmt=$(detect_format "$archive")
  
  case "$fmt" in
    tar.gz)  tar tzf "$archive" > /dev/null && log_ok "Archive OK: $archive" || log_err "Archive CORRUPT: $archive" ;;
    tar.bz2) tar tjf "$archive" > /dev/null && log_ok "Archive OK: $archive" || log_err "Archive CORRUPT: $archive" ;;
    tar.xz)  tar tJf "$archive" > /dev/null && log_ok "Archive OK: $archive" || log_err "Archive CORRUPT: $archive" ;;
    tar.zst) tar --zstd -tf "$archive" > /dev/null && log_ok "Archive OK: $archive" || log_err "Archive CORRUPT: $archive" ;;
    tar)     tar tf "$archive" > /dev/null && log_ok "Archive OK: $archive" || log_err "Archive CORRUPT: $archive" ;;
    zip)     unzip -t "$archive" > /dev/null && log_ok "Archive OK: $archive" || log_err "Archive CORRUPT: $archive" ;;
    7z)
      local sz_args=(t)
      [ -n "$PASSWORD" ] && sz_args+=("-p$PASSWORD")
      7z "${sz_args[@]}" "$archive" > /dev/null && log_ok "Archive OK: $archive" || log_err "Archive CORRUPT: $archive"
      ;;
    rar)
      local rar_args=(t)
      [ -n "$PASSWORD" ] && rar_args+=("-p$PASSWORD")
      unrar "${rar_args[@]}" "$archive" > /dev/null && log_ok "Archive OK: $archive" || log_err "Archive CORRUPT: $archive"
      ;;
    *)
      log_err "Unsupported format: $archive"
      exit 1
      ;;
  esac
}

# ─── BATCH EXTRACT ────────────────────────────────────────────────────

cmd_batch_extract() {
  local dir="$1"; shift
  EXTRA_ARGS=()
  parse_flags "$@"
  
  if [ ! -d "$dir" ]; then
    log_err "Directory not found: $dir"
    exit 1
  fi
  
  local dest="${OUTPUT:-$dir/extracted}"
  mkdir -p "$dest"
  
  local count=0 ok=0 fail=0
  
  while IFS= read -r -d '' f; do
    count=$((count + 1))
    
    local name
    name=$(basename "$f")
    local sub_dir="$dest/${name%.*}"
    sub_dir="${sub_dir%.tar}"
    mkdir -p "$sub_dir"
    
    log_info "Extracting: $name"
    if cmd_extract "$f" --output "$sub_dir" 2>/dev/null; then
      ok=$((ok + 1))
    else
      fail=$((fail + 1))
      log_err "Failed: $name"
    fi
  done < <(find "$dir" -maxdepth 1 -type f \( -name '*.tar.gz' -o -name '*.tgz' -o -name '*.tar.bz2' -o -name '*.tar.xz' -o -name '*.tar.zst' -o -name '*.tar' -o -name '*.zip' -o -name '*.7z' -o -name '*.rar' \) -print0)
  
  echo ""
  log_ok "Batch extract complete: $ok/$count succeeded"
  [ $fail -gt 0 ] && log_warn "$fail failed"
}

# ─── BATCH CREATE ─────────────────────────────────────────────────────

cmd_batch_create() {
  local dir="$1"; shift
  EXTRA_ARGS=()
  parse_flags "$@"
  
  if [ ! -d "$dir" ]; then
    log_err "Directory not found: $dir"
    exit 1
  fi
  
  local fmt="${FORMAT:-tar.gz}"
  local dest="${OUTPUT:-$dir}"
  mkdir -p "$dest"
  
  local count=0
  
  for sub in "$dir"/*/; do
    [ -d "$sub" ] || continue
    local name
    name=$(basename "$sub")
    local archive="$dest/$name.$fmt"
    
    log_info "Compressing: $name → $name.$fmt"
    cmd_create "$archive" "$sub"
    count=$((count + 1))
  done
  
  log_ok "Batch create complete: $count archives created"
}

# ─── BATCH TEST ───────────────────────────────────────────────────────

cmd_batch_test() {
  local dir="$1"; shift
  EXTRA_ARGS=()
  parse_flags "$@"
  
  local count=0 ok=0 fail=0
  
  while IFS= read -r -d '' f; do
    count=$((count + 1))
    if cmd_test "$f" 2>/dev/null; then
      ok=$((ok + 1))
    else
      fail=$((fail + 1))
    fi
  done < <(find "$dir" -maxdepth 1 -type f \( -name '*.tar.gz' -o -name '*.tgz' -o -name '*.tar.bz2' -o -name '*.tar.xz' -o -name '*.tar.zst' -o -name '*.tar' -o -name '*.zip' -o -name '*.7z' -o -name '*.rar' \) -print0)
  
  echo ""
  log_ok "Batch test: $ok/$count OK"
  [ $fail -gt 0 ] && log_err "$fail corrupt archives found"
}

# ─── CONVERT ──────────────────────────────────────────────────────────

cmd_convert() {
  local archive="$1"; shift
  EXTRA_ARGS=()
  parse_flags "$@"
  
  if [ -z "$FORMAT" ]; then
    log_err "Specify target format with --to <format>"
    exit 1
  fi
  
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf $tmpdir" EXIT
  
  log_info "Extracting $archive..."
  cmd_extract "$archive" --output "$tmpdir"
  
  local base
  base=$(basename "$archive")
  base="${base%%.*}"
  local new_archive="${base}.${FORMAT}"
  
  log_info "Creating $new_archive..."
  cmd_create "$new_archive" "$tmpdir"
  
  log_ok "Converted: $archive → $new_archive"
}

# ─── MAIN ─────────────────────────────────────────────────────────────

usage() {
  cat <<EOF
🗃️  Archive Manager v${VERSION}

Usage: bash run.sh <command> [arguments] [flags]

Commands:
  create <archive> <source>     Create an archive
  extract <archive>             Extract an archive
  list <archive>                List archive contents
  test <archive>                Verify archive integrity
  batch-extract <dir>           Extract all archives in a directory
  batch-create <dir>            Compress all subdirectories
  batch-test <dir>              Test all archives in a directory
  convert <archive> --to <fmt>  Convert between formats

Flags:
  --password <pass>   Encrypt/decrypt (7z, zip, rar)
  --output <dir>      Output directory for extraction
  --level <1-9>       Compression level
  --split <size>      Split archive (7z only, e.g. 100m)
  --exclude <pattern> Exclude files (repeatable)
  --format <fmt>      Archive format for batch-create
  --dry-run           Preview without creating

Formats: tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z, rar (extract only)
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 0
fi

COMMAND="$1"; shift

case "$COMMAND" in
  create)        cmd_create "$@" ;;
  extract)       cmd_extract "$@" ;;
  list)          cmd_list "$@" ;;
  test)          cmd_test "$@" ;;
  batch-extract) cmd_batch_extract "$@" ;;
  batch-create)  cmd_batch_create "$@" ;;
  batch-test)    cmd_batch_test "$@" ;;
  convert)       cmd_convert "$@" ;;
  -h|--help|help) usage ;;
  *)
    log_err "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac
