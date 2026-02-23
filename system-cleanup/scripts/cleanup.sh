#!/usr/bin/env bash
# System Cleanup & Maintenance Script
# Reclaims disk space by purging temp files, logs, caches, Docker artifacts, and journal bloat.

set -euo pipefail

# ─── Defaults ───────────────────────────────────────────────────────────────
LOG_AGE="${CLEANUP_LOG_AGE:-30}"
JOURNAL_MAX="${CLEANUP_JOURNAL_MAX:-500M}"
MIN_AGE="${CLEANUP_MIN_AGE:-7}"
EXCLUDE_PATTERNS=()
DRY_RUN=false
QUIET=false
AGGRESSIVE=false
REPORT_FILE=""
TARGETS=()

# ─── Colors (disabled in quiet/pipe mode) ───────────────────────────────────
if [[ -t 1 ]] && [[ "$QUIET" != true ]]; then
  GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''
fi

# ─── Helpers ────────────────────────────────────────────────────────────────
log() { [[ "$QUIET" == true ]] && return; echo -e "$@"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}" >&2; }

bytes_to_human() {
  local bytes=$1
  if (( bytes >= 1073741824 )); then
    echo "$(echo "scale=1; $bytes / 1073741824" | bc) GB"
  elif (( bytes >= 1048576 )); then
    echo "$(echo "scale=0; $bytes / 1048576" | bc) MB"
  elif (( bytes >= 1024 )); then
    echo "$(echo "scale=0; $bytes / 1024" | bc) KB"
  else
    echo "${bytes} B"
  fi
}

disk_usage_bytes() {
  local path="$1"
  if [[ -e "$path" ]]; then
    du -sb "$path" 2>/dev/null | awk '{print $1}' || echo 0
  else
    echo 0
  fi
}

dir_size_bytes() {
  local path="$1"
  if [[ -d "$path" ]]; then
    du -sb "$path" 2>/dev/null | awk '{print $1}' || echo 0
  else
    echo 0
  fi
}

is_excluded() {
  local path="$1"
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    if [[ "$path" == *"$pattern"* ]]; then
      return 0
    fi
  done
  return 1
}

has_cmd() { command -v "$1" &>/dev/null; }

# ─── Parse Args ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --all)        TARGETS=(temp packages logs docker journal trash npm pip cargo); shift ;;
    --temp)       TARGETS+=(temp); shift ;;
    --packages)   TARGETS+=(packages); shift ;;
    --logs)       TARGETS+=(logs); shift ;;
    --docker)     TARGETS+=(docker); shift ;;
    --journal)    TARGETS+=(journal); shift ;;
    --trash)      TARGETS+=(trash); shift ;;
    --npm)        TARGETS+=(npm); shift ;;
    --pip)        TARGETS+=(pip); shift ;;
    --cargo)      TARGETS+=(cargo); shift ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --quiet)      QUIET=true; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''; shift ;;
    --aggressive) AGGRESSIVE=true; TARGETS=(temp packages logs docker journal trash npm pip cargo); shift ;;
    --log-age)    LOG_AGE="$2"; shift 2 ;;
    --journal-max) JOURNAL_MAX="$2"; shift 2 ;;
    --min-age)    MIN_AGE="$2"; shift 2 ;;
    --report)     REPORT_FILE="$2"; shift 2 ;;
    --exclude)    EXCLUDE_PATTERNS+=("$2"); shift 2 ;;
    -h|--help)
      echo "Usage: cleanup.sh [OPTIONS]"
      echo ""
      echo "Targets: --all --temp --packages --logs --docker --journal --trash --npm --pip --cargo"
      echo "Options: --dry-run --quiet --aggressive --log-age DAYS --journal-max SIZE"
      echo "         --min-age DAYS --report FILE --exclude PATTERN"
      exit 0
      ;;
    *) warn "Unknown option: $1"; shift ;;
  esac
done

# Add excludes from env
if [[ -n "${CLEANUP_EXCLUDE:-}" ]]; then
  IFS=',' read -ra ENV_EXCLUDES <<< "$CLEANUP_EXCLUDE"
  EXCLUDE_PATTERNS+=("${ENV_EXCLUDES[@]}")
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "No targets specified. Use --all or pick specific targets (--temp, --packages, etc.)"
  echo "Run with --help for full usage."
  exit 1
fi

# ─── State ──────────────────────────────────────────────────────────────────
declare -A FREED
TOTAL_FREED=0
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
HOSTNAME=$(hostname)

# ─── Disk before ────────────────────────────────────────────────────────────
DISK_BEFORE=$(df / --output=used -B1 2>/dev/null | tail -1 | tr -d ' ' || echo 0)

# ─── Header ─────────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == true ]]; then
  log "${BOLD}🔍 System Cleanup DRY RUN — $TIMESTAMP${NC}"
else
  log "${BOLD}🧹 System Cleanup — $TIMESTAMP${NC}"
fi
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Clean: Temp Files ──────────────────────────────────────────────────────
clean_temp() {
  local freed=0
  local count=0
  local dirs=(/tmp /var/tmp)
  [[ -d "$HOME/.cache/thumbnails" ]] && dirs+=("$HOME/.cache/thumbnails")

  for dir in "${dirs[@]}"; do
    if is_excluded "$dir"; then continue; fi
    if [[ ! -d "$dir" ]]; then continue; fi

    while IFS= read -r -d '' file; do
      if is_excluded "$file"; then continue; fi
      local size
      size=$(stat -c%s "$file" 2>/dev/null || echo 0)
      freed=$((freed + size))
      count=$((count + 1))
      if [[ "$DRY_RUN" == false ]]; then
        rm -f "$file" 2>/dev/null || true
      fi
    done < <(timeout 30 find "$dir" -maxdepth 3 -type f -atime +"$MIN_AGE" -print0 2>/dev/null || true)
  done

  FREED[temp]=$freed
  TOTAL_FREED=$((TOTAL_FREED + freed))
  log "📁 Temp files:          $(bytes_to_human $freed) ($count files)"
}

# ─── Clean: Package Caches ──────────────────────────────────────────────────
clean_packages() {
  local freed=0

  # APT
  if has_cmd apt-get; then
    local before
    before=$(dir_size_bytes /var/cache/apt 2>/dev/null)
    if [[ "$DRY_RUN" == false ]]; then
      sudo apt-get clean -y 2>/dev/null || apt-get clean -y 2>/dev/null || true
      sudo apt-get autoremove -y 2>/dev/null || true
    fi
    local after
    after=$(dir_size_bytes /var/cache/apt 2>/dev/null)
    freed=$((freed + before - after))
  fi

  # YUM/DNF
  if has_cmd dnf; then
    if [[ "$DRY_RUN" == false ]]; then
      sudo dnf clean all 2>/dev/null || dnf clean all 2>/dev/null || true
    fi
  elif has_cmd yum; then
    if [[ "$DRY_RUN" == false ]]; then
      sudo yum clean all 2>/dev/null || yum clean all 2>/dev/null || true
    fi
  fi

  # Pacman
  if has_cmd pacman; then
    if [[ "$DRY_RUN" == false ]]; then
      sudo pacman -Sc --noconfirm 2>/dev/null || true
    fi
  fi

  # Homebrew
  if has_cmd brew; then
    local before_brew=0
    [[ -d "$(brew --cache 2>/dev/null)" ]] && before_brew=$(dir_size_bytes "$(brew --cache)")
    if [[ "$DRY_RUN" == false ]]; then
      brew cleanup --prune=all 2>/dev/null || true
    fi
    local after_brew=0
    [[ -d "$(brew --cache 2>/dev/null)" ]] && after_brew=$(dir_size_bytes "$(brew --cache)")
    freed=$((freed + before_brew - after_brew))
  fi

  # Ensure non-negative
  (( freed < 0 )) && freed=0

  FREED[packages]=$freed
  TOTAL_FREED=$((TOTAL_FREED + freed))
  log "📦 Package cache:       $(bytes_to_human $freed)"
}

# ─── Clean: Old Logs ────────────────────────────────────────────────────────
clean_logs() {
  local freed=0
  local count=0
  local log_dirs=(/var/log)

  for dir in "${log_dirs[@]}"; do
    if is_excluded "$dir"; then continue; fi
    if [[ ! -d "$dir" ]]; then continue; fi

    # Remove rotated logs older than LOG_AGE days
    while IFS= read -r -d '' file; do
      if is_excluded "$file"; then continue; fi
      local size
      size=$(stat -c%s "$file" 2>/dev/null || echo 0)
      freed=$((freed + size))
      count=$((count + 1))
      if [[ "$DRY_RUN" == false ]]; then
        sudo rm -f "$file" 2>/dev/null || rm -f "$file" 2>/dev/null || true
      fi
    done < <(find "$dir" -type f \( -name "*.gz" -o -name "*.old" -o -name "*.1" -o -name "*.2" -o -name "*.[3-9]" \) -mtime +"$LOG_AGE" -print0 2>/dev/null || true)

    # Aggressive: truncate large active logs
    if [[ "$AGGRESSIVE" == true ]]; then
      while IFS= read -r -d '' file; do
        if is_excluded "$file"; then continue; fi
        local size
        size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        if (( size > 104857600 )); then  # >100MB
          freed=$((freed + size))
          if [[ "$DRY_RUN" == false ]]; then
            sudo truncate -s 0 "$file" 2>/dev/null || truncate -s 0 "$file" 2>/dev/null || true
          fi
        fi
      done < <(find "$dir" -type f -name "*.log" -print0 2>/dev/null || true)
    fi
  done

  FREED[logs]=$freed
  TOTAL_FREED=$((TOTAL_FREED + freed))
  log "📜 Old logs (>${LOG_AGE}d):    $(bytes_to_human $freed) ($count files)"
}

# ─── Clean: Docker ──────────────────────────────────────────────────────────
clean_docker() {
  local freed=0

  if ! has_cmd docker; then
    log "🐳 Docker:              skipped (not installed)"
    FREED[docker]=0
    return
  fi

  # Get space before
  local before
  before=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1 || echo "0B")

  if [[ "$DRY_RUN" == false ]]; then
    # Remove stopped containers
    docker container prune -f 2>/dev/null || true
    # Remove unused images
    if [[ "$AGGRESSIVE" == true ]]; then
      docker image prune -a -f 2>/dev/null || true
    else
      docker image prune -f 2>/dev/null || true
    fi
    # Remove unused volumes
    docker volume prune -f 2>/dev/null || true
    # Remove unused networks
    docker network prune -f 2>/dev/null || true
    # Build cache
    docker builder prune -f 2>/dev/null || true
  fi

  # Estimate freed space from df diff
  local disk_after
  disk_after=$(df / --output=used -B1 2>/dev/null | tail -1 | tr -d ' ' || echo 0)
  freed=$((DISK_BEFORE - disk_after - TOTAL_FREED))
  (( freed < 0 )) && freed=0

  FREED[docker]=$freed
  TOTAL_FREED=$((TOTAL_FREED + freed))
  log "🐳 Docker prune:        $(bytes_to_human $freed)"
}

# ─── Clean: Journal ─────────────────────────────────────────────────────────
clean_journal() {
  local freed=0

  if ! has_cmd journalctl; then
    log "📓 Journal:             skipped (no journalctl)"
    FREED[journal]=0
    return
  fi

  local before
  before=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+[KMGT]?' | head -1 || echo "0")

  if [[ "$DRY_RUN" == false ]]; then
    sudo journalctl --vacuum-size="$JOURNAL_MAX" 2>/dev/null || \
      journalctl --vacuum-size="$JOURNAL_MAX" 2>/dev/null || true
    sudo journalctl --vacuum-time=7d 2>/dev/null || \
      journalctl --vacuum-time=7d 2>/dev/null || true
  fi

  # Rough estimate
  FREED[journal]=0
  log "📓 Journal (→${JOURNAL_MAX}): vacuumed"
}

# ─── Clean: Trash ───────────────────────────────────────────────────────────
clean_trash() {
  local freed=0
  local trash_dir="$HOME/.local/share/Trash"

  if [[ -d "$trash_dir" ]]; then
    freed=$(dir_size_bytes "$trash_dir")
    if [[ "$DRY_RUN" == false ]]; then
      rm -rf "${trash_dir:?}/files"/* "${trash_dir:?}/info"/* 2>/dev/null || true
    fi
  fi

  FREED[trash]=$freed
  TOTAL_FREED=$((TOTAL_FREED + freed))
  log "🗑️  Trash:              $(bytes_to_human $freed)"
}

# ─── Clean: npm cache ──────────────────────────────────────────────────────
clean_npm() {
  local freed=0

  if has_cmd npm; then
    local cache_dir
    cache_dir=$(npm config get cache 2>/dev/null || echo "$HOME/.npm")
    if [[ -d "$cache_dir" ]]; then
      freed=$(dir_size_bytes "$cache_dir")
      if [[ "$DRY_RUN" == false ]]; then
        npm cache clean --force 2>/dev/null || true
      fi
    fi
  fi

  FREED[npm]=$freed
  TOTAL_FREED=$((TOTAL_FREED + freed))
  [[ $freed -gt 0 ]] && log "📦 npm cache:           $(bytes_to_human $freed)"
}

# ─── Clean: pip cache ──────────────────────────────────────────────────────
clean_pip() {
  local freed=0

  if has_cmd pip3 || has_cmd pip; then
    local pip_cmd
    pip_cmd=$(has_cmd pip3 && echo pip3 || echo pip)
    local cache_dir
    cache_dir=$($pip_cmd cache dir 2>/dev/null || echo "$HOME/.cache/pip")
    if [[ -d "$cache_dir" ]]; then
      freed=$(dir_size_bytes "$cache_dir")
      if [[ "$DRY_RUN" == false ]]; then
        $pip_cmd cache purge 2>/dev/null || true
      fi
    fi
  fi

  FREED[pip]=$freed
  TOTAL_FREED=$((TOTAL_FREED + freed))
  [[ $freed -gt 0 ]] && log "🐍 pip cache:           $(bytes_to_human $freed)"
}

# ─── Clean: cargo cache ────────────────────────────────────────────────────
clean_cargo() {
  local freed=0
  local cargo_cache="$HOME/.cargo/registry/cache"

  if [[ -d "$cargo_cache" ]]; then
    freed=$(dir_size_bytes "$cargo_cache")
    if [[ "$DRY_RUN" == false ]]; then
      rm -rf "${cargo_cache:?}"/* 2>/dev/null || true
    fi
  fi

  FREED[cargo]=$freed
  TOTAL_FREED=$((TOTAL_FREED + freed))
  [[ $freed -gt 0 ]] && log "🦀 cargo cache:         $(bytes_to_human $freed)"
}

# ─── Aggressive Extras ─────────────────────────────────────────────────────
clean_aggressive() {
  if [[ "$AGGRESSIVE" != true ]]; then return; fi

  log ""
  log "${YELLOW}⚡ Aggressive mode extras:${NC}"

  # Old kernels (Debian/Ubuntu)
  if has_cmd dpkg && has_cmd apt-get; then
    local current_kernel
    current_kernel=$(uname -r)
    local old_kernels
    old_kernels=$(dpkg -l 'linux-image-*' 2>/dev/null | grep '^ii' | awk '{print $2}' | grep -v "$current_kernel" | grep -v 'linux-image-generic' || true)
    if [[ -n "$old_kernels" ]]; then
      log "   🐧 Old kernels found: $(echo "$old_kernels" | wc -l)"
      if [[ "$DRY_RUN" == false ]]; then
        echo "$old_kernels" | xargs sudo apt-get remove -y 2>/dev/null || true
      fi
    fi
  fi

  # Orphaned packages
  if has_cmd apt-get; then
    if [[ "$DRY_RUN" == false ]]; then
      sudo apt-get autoremove --purge -y 2>/dev/null || true
    fi
    log "   📦 Orphaned packages removed"
  fi
}

# ─── Execute ────────────────────────────────────────────────────────────────
for target in "${TARGETS[@]}"; do
  case $target in
    temp)     clean_temp ;;
    packages) clean_packages ;;
    logs)     clean_logs ;;
    docker)   clean_docker ;;
    journal)  clean_journal ;;
    trash)    clean_trash ;;
    npm)      clean_npm ;;
    pip)      clean_pip ;;
    cargo)    clean_cargo ;;
  esac
done

clean_aggressive

# ─── Summary ────────────────────────────────────────────────────────────────
log ""
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$DRY_RUN" == true ]]; then
  log "${BOLD}🔍 Would free:          $(bytes_to_human $TOTAL_FREED)${NC}"
else
  log "${GREEN}${BOLD}✅ Total freed:         $(bytes_to_human $TOTAL_FREED)${NC}"
fi

# Disk status
DISK_USED=$(df / --output=used -B1 2>/dev/null | tail -1 | tr -d ' ' || echo 0)
DISK_TOTAL=$(df / --output=size -B1 2>/dev/null | tail -1 | tr -d ' ' || echo 1)
DISK_PERCENT=$((DISK_USED * 100 / DISK_TOTAL))
log "💾 Disk:                $(bytes_to_human $DISK_USED) / $(bytes_to_human $DISK_TOTAL) (${DISK_PERCENT}%)"

if (( DISK_PERCENT > 80 )); then
  warn "Disk usage above 80%! Consider --aggressive or adding more storage."
fi

# ─── JSON Report ────────────────────────────────────────────────────────────
if [[ -n "$REPORT_FILE" ]]; then
  cat > "$REPORT_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "hostname": "$HOSTNAME",
  "dry_run": $DRY_RUN,
  "cleaned": {
    "temp": {"bytes_freed": ${FREED[temp]:-0}},
    "packages": {"bytes_freed": ${FREED[packages]:-0}},
    "logs": {"bytes_freed": ${FREED[logs]:-0}},
    "docker": {"bytes_freed": ${FREED[docker]:-0}},
    "journal": {"bytes_freed": ${FREED[journal]:-0}},
    "trash": {"bytes_freed": ${FREED[trash]:-0}},
    "npm": {"bytes_freed": ${FREED[npm]:-0}},
    "pip": {"bytes_freed": ${FREED[pip]:-0}},
    "cargo": {"bytes_freed": ${FREED[cargo]:-0}}
  },
  "total_freed": $TOTAL_FREED,
  "disk_after": {"used": $DISK_USED, "total": $DISK_TOTAL, "percent": $DISK_PERCENT}
}
EOF
  log "📊 Report saved to: $REPORT_FILE"
fi
