#!/bin/bash
# Disk Usage Analyzer — Automated Cleanup Script
set -e

DRY_RUN=true
CONFIG_FILE=""
TOTAL_FREED=0

usage() {
    cat <<EOF
Disk Cleanup Tool

Usage: bash cleanup.sh [options]

Options:
  --dry-run     Show what would be cleaned (default)
  --execute     Actually delete files
  --config FILE Use custom cleanup config (YAML)
  --help        Show this help

Examples:
  bash cleanup.sh --dry-run           # Preview cleanup
  bash cleanup.sh --execute           # Run cleanup
  bash cleanup.sh --config cleanup.yaml --execute
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)   DRY_RUN=true; shift ;;
        --execute)   DRY_RUN=false; shift ;;
        --config)    CONFIG_FILE="$2"; shift 2 ;;
        --help)      usage; exit 0 ;;
        *)           echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Calculate size of files matching criteria
calc_size() {
    local total=0
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            size=$(stat --format=%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
            total=$((total + size))
        fi
    done
    echo "$total"
}

human_size() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(echo "scale=1; $bytes/1073741824" | bc)G"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(echo "scale=1; $bytes/1048576" | bc)M"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(echo "scale=1; $bytes/1024" | bc)K"
    else
        echo "${bytes}B"
    fi
}

clean_path() {
    local path="$1"
    local max_age_days="${2:-7}"
    local pattern="${3:-*}"
    local description="${4:-files}"
    
    # Expand ~ to home
    path="${path/#\~/$HOME}"
    
    if [ ! -d "$path" ]; then
        return 0
    fi
    
    local files
    files=$(timeout 10 find "$path" -maxdepth 3 -name "$pattern" -type f -mtime +"$max_age_days" 2>/dev/null || true)
    
    if [ -z "$files" ]; then
        log "  ✅ $description: nothing to clean"
        return 0
    fi
    
    local count
    count=$(echo "$files" | wc -l)
    local size
    size=$(echo "$files" | xargs -d'\n' du -cb 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)
    local human=$(human_size "${size:-0}")
    
    if $DRY_RUN; then
        log "  🔍 $description: would free $human ($count files)"
    else
        echo "$files" | xargs rm -f 2>/dev/null
        log "  🗑️  $description: freed $human ($count files)"
    fi
    
    TOTAL_FREED=$((TOTAL_FREED + size))
}

clean_directory() {
    local path="$1"
    local description="${2:-cache}"
    
    path="${path/#\~/$HOME}"
    
    if [ ! -d "$path" ]; then
        return 0
    fi
    
    local size
    size=$(du -sb "$path" 2>/dev/null | awk '{print $1}')
    local human=$(human_size "${size:-0}")
    
    if $DRY_RUN; then
        log "  🔍 $description ($path): would free $human"
    else
        rm -rf "$path"/* 2>/dev/null
        log "  🗑️  $description: freed $human"
    fi
    
    TOTAL_FREED=$((TOTAL_FREED + ${size:-0}))
}

echo "═══════════════════════════════════════════════"
if $DRY_RUN; then
    echo "  DISK CLEANUP — DRY RUN ($(date '+%Y-%m-%d %H:%M:%S'))"
    echo "  Nothing will be deleted. Use --execute to clean."
else
    echo "  DISK CLEANUP — EXECUTING ($(date '+%Y-%m-%d %H:%M:%S'))"
fi
echo "═══════════════════════════════════════════════"
echo ""

# 1. Temp files
log "📁 Temporary files"
clean_path "/tmp" 7 "*" "System temp (/tmp, >7 days)"
clean_path "/var/tmp" 30 "*" "Persistent temp (/var/tmp, >30 days)"
echo ""

# 2. Logs
log "📋 Log files"
clean_path "/var/log" 30 "*.gz" "Compressed logs (>30 days)"
clean_path "/var/log" 30 "*.old" "Old logs (>30 days)"
clean_path "/var/log" 90 "*.log.*" "Rotated logs (>90 days)"

if command -v journalctl &>/dev/null; then
    if $DRY_RUN; then
        journal_size=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+[KMGT]' || echo "unknown")
        log "  🔍 Journald: currently $journal_size (would vacuum to 500M)"
    else
        journalctl --vacuum-size=500M --vacuum-time=7d 2>/dev/null
        log "  🗑️  Journald: vacuumed to 500M / 7 days"
    fi
fi
echo ""

# 3. Package manager caches
log "📦 Package manager caches"
if command -v apt-get &>/dev/null; then
    if $DRY_RUN; then
        cache_size=$(du -sh /var/cache/apt 2>/dev/null | awk '{print $1}')
        log "  🔍 APT cache: would free ~$cache_size"
    else
        sudo apt-get clean 2>/dev/null
        log "  🗑️  APT cache cleaned"
    fi
fi
echo ""

# 4. Developer caches
log "🛠️  Developer caches"
clean_directory "~/.cache/pip" "Pip cache"
clean_directory "~/.npm/_cacache" "NPM cache"
clean_directory "~/.cache/yarn" "Yarn cache"
clean_directory "~/.cache/go-build" "Go build cache"

# node_modules caches (only .cache subdirs, not node_modules itself)
find "$HOME" -maxdepth 4 -type d -name ".cache" -path "*/node_modules/*" 2>/dev/null | while read -r cache_dir; do
    if $DRY_RUN; then
        size=$(du -sh "$cache_dir" 2>/dev/null | awk '{print $1}')
        log "  🔍 $cache_dir: would free $size"
    else
        rm -rf "$cache_dir"
        log "  🗑️  Cleaned: $cache_dir"
    fi
done
echo ""

# 5. Docker cleanup
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    log "🐳 Docker cleanup"
    if $DRY_RUN; then
        log "  🔍 Would remove dangling images and unused networks"
        docker images -f "dangling=true" -q 2>/dev/null | wc -l | xargs -I{} echo "    Dangling images: {}"
    else
        docker image prune -f 2>/dev/null
        docker network prune -f 2>/dev/null
        docker builder prune -f 2>/dev/null
        log "  🗑️  Docker: pruned images, networks, build cache"
    fi
    echo ""
fi

# 6. Trash
if [ -d "$HOME/.local/share/Trash" ]; then
    log "🗑️  Trash"
    trash_size=$(du -sh "$HOME/.local/share/Trash" 2>/dev/null | awk '{print $1}')
    if $DRY_RUN; then
        log "  🔍 Trash: would free $trash_size"
    else
        rm -rf "$HOME/.local/share/Trash"/* 2>/dev/null
        log "  🗑️  Trash emptied: freed $trash_size"
    fi
    echo ""
fi

# Summary
echo "═══════════════════════════════════════════════"
total_human=$(human_size "$TOTAL_FREED")
if $DRY_RUN; then
    echo "  📊 Estimated space to free: ~$total_human"
    echo "  Run with --execute to clean"
else
    echo "  ✅ Total freed: ~$total_human"
fi
echo "═══════════════════════════════════════════════"
