#!/bin/bash
set -euo pipefail

# Git LFS Manager — Management Script
# Usage: bash manage.sh <command> [args...]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Ensure git-lfs is available
check_lfs() {
    if ! command -v git-lfs &>/dev/null; then
        echo -e "${RED}❌ git-lfs not found. Run: bash scripts/install.sh${NC}"
        exit 1
    fi
    if ! git rev-parse --git-dir &>/dev/null 2>&1; then
        echo -e "${RED}❌ Not in a git repository${NC}"
        exit 1
    fi
}

# ── TRACK DEFAULTS ──────────────────────────────────────────────
cmd_track_defaults() {
    check_lfs
    echo -e "${BOLD}📎 Tracking default LFS patterns${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local patterns=(
        # Design
        "*.psd" "*.ai" "*.sketch" "*.fig" "*.xd"
        # Video
        "*.mp4" "*.mov" "*.avi" "*.mkv" "*.webm"
        # Audio
        "*.wav" "*.flac" "*.aac"
        # Archives
        "*.zip" "*.tar.gz" "*.tar.bz2" "*.7z" "*.rar"
        # 3D
        "*.fbx" "*.obj" "*.blend" "*.stl"
        # Binary
        "*.dll" "*.so" "*.dylib" "*.exe"
    )

    for pattern in "${patterns[@]}"; do
        git lfs track "$pattern"
    done

    echo ""
    echo -e "${GREEN}✅ Tracked ${#patterns[@]} default patterns${NC}"
    echo -e "   Don't forget to commit .gitattributes!"
}

# ── TRACK CUSTOM ────────────────────────────────────────────────
cmd_track() {
    check_lfs
    if [[ $# -eq 0 ]]; then
        echo "Usage: manage.sh track <pattern> [pattern...]"
        echo "Example: manage.sh track '*.psd' '*.mp4' 'assets/**/*.png'"
        exit 1
    fi

    for pattern in "$@"; do
        git lfs track "$pattern"
        echo -e "${GREEN}  Tracked: $pattern${NC}"
    done
    echo -e "\n   Don't forget to commit .gitattributes!"
}

# ── STATUS ──────────────────────────────────────────────────────
cmd_status() {
    check_lfs
    echo -e "${BOLD}📊 Git LFS Status${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo ""
    echo -e "${BLUE}Tracked Patterns:${NC}"
    git lfs track | sed 's/^/  /'

    echo ""
    echo -e "${BLUE}LFS Environment:${NC}"
    git lfs env 2>/dev/null | head -5 | sed 's/^/  /'

    echo ""
    echo -e "${BLUE}LFS Objects (local):${NC}"
    local lfs_dir=".git/lfs/objects"
    if [[ -d "$lfs_dir" ]]; then
        local count=$(find "$lfs_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
        local size=$(du -sh "$lfs_dir" 2>/dev/null | cut -f1)
        echo "  Objects: $count"
        echo "  Size:    $size"
    else
        echo "  No LFS objects stored locally"
    fi

    echo ""
    echo -e "${BLUE}LFS Files in Working Tree:${NC}"
    git lfs ls-files 2>/dev/null | head -20 | sed 's/^/  /'
    local total=$(git lfs ls-files 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$total" -gt 20 ]]; then
        echo "  ... and $((total - 20)) more"
    fi
    echo "  Total: $total files"
}

# ── FIND LARGE FILES ────────────────────────────────────────────
cmd_find_large() {
    check_lfs
    local min_size="5M"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --min-size) min_size="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    echo -e "${BOLD}🔍 Finding files larger than $min_size in git history${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Convert size to bytes for comparison
    local min_bytes
    case "$min_size" in
        *K) min_bytes=$(( ${min_size%K} * 1024 )) ;;
        *M) min_bytes=$(( ${min_size%M} * 1024 * 1024 )) ;;
        *G) min_bytes=$(( ${min_size%G} * 1024 * 1024 * 1024 )) ;;
        *)  min_bytes=$min_size ;;
    esac

    echo ""
    git rev-list --objects --all | \
        git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
        awk -v min="$min_bytes" '$1 == "blob" && $3 >= min {print $3, $4}' | \
        sort -rn | \
        head -30 | \
        while read size path; do
            if [[ $size -ge 1073741824 ]]; then
                human=$(awk "BEGIN {printf \"%.1f GB\", $size/1073741824}")
            elif [[ $size -ge 1048576 ]]; then
                human=$(awk "BEGIN {printf \"%.1f MB\", $size/1048576}")
            elif [[ $size -ge 1024 ]]; then
                human=$(awk "BEGIN {printf \"%.1f KB\", $size/1024}")
            else
                human="${size} B"
            fi
            printf "  %10s  %s\n" "$human" "$path"
        done

    echo ""
    echo -e "${YELLOW}💡 To migrate these to LFS: bash scripts/manage.sh migrate '<pattern>'${NC}"
}

# ── MIGRATE ─────────────────────────────────────────────────────
cmd_migrate() {
    check_lfs
    if [[ $# -eq 0 ]]; then
        echo "Usage: manage.sh migrate <pattern> [pattern...]"
        echo "Example: manage.sh migrate '*.mp4' '*.psd'"
        echo ""
        echo -e "${RED}⚠️  WARNING: This rewrites git history!${NC}"
        echo "   All collaborators will need to re-clone."
        exit 1
    fi

    echo -e "${BOLD}🔄 Migrating files to LFS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${RED}⚠️  This rewrites git history! Make a backup first.${NC}"
    echo ""

    read -p "Continue? (y/N) " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi

    local include_args=""
    for pattern in "$@"; do
        include_args="$include_args --include=$pattern"
    done

    git lfs migrate import $include_args --everything
    echo ""
    echo -e "${GREEN}✅ Migration complete${NC}"
    echo -e "   Run 'git push --force-with-lease' to update remote"
}

# ── MIGRATE BY SIZE ─────────────────────────────────────────────
cmd_migrate_by_size() {
    check_lfs
    local threshold="${1:-10M}"

    echo -e "${BOLD}🔄 Migrating files larger than $threshold to LFS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${RED}⚠️  This rewrites git history! Make a backup first.${NC}"
    echo ""

    read -p "Continue? (y/N) " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi

    git lfs migrate import --above="$threshold" --everything
    echo ""
    echo -e "${GREEN}✅ Migration complete${NC}"
}

# ── QUOTA ───────────────────────────────────────────────────────
cmd_quota() {
    check_lfs
    echo -e "${BOLD}📦 Git LFS Storage Report${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local lfs_dir=".git/lfs/objects"
    if [[ -d "$lfs_dir" ]]; then
        local count=$(find "$lfs_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
        local size=$(du -sh "$lfs_dir" 2>/dev/null | cut -f1)
        local size_bytes=$(du -sb "$lfs_dir" 2>/dev/null | cut -f1)

        echo ""
        echo "  Local LFS objects:  $count files"
        echo "  Local LFS size:     $size"

        # Show tracked patterns count
        local patterns=$(git lfs track 2>/dev/null | grep -c "Tracking" || echo 0)
        echo "  Tracked patterns:   $patterns"

        # Working tree LFS files
        local wt_count=$(git lfs ls-files 2>/dev/null | wc -l | tr -d ' ')
        echo "  Working tree files: $wt_count"
    else
        echo "  No LFS objects stored locally"
    fi

    echo ""
    echo -e "${BLUE}Top 10 Largest LFS Objects:${NC}"
    git lfs ls-files -s 2>/dev/null | \
        sort -k3 -rn | \
        head -10 | \
        awk '{
            size=$3;
            if (size >= 1073741824) printf "  %8.1f GB  %s\n", size/1073741824, $4;
            else if (size >= 1048576) printf "  %8.1f MB  %s\n", size/1048576, $4;
            else if (size >= 1024) printf "  %8.1f KB  %s\n", size/1024, $4;
            else printf "  %8d B   %s\n", size, $4;
        }'

    echo ""
    echo -e "${YELLOW}💡 GitHub free tier: 1 GB storage, 1 GB/mo bandwidth${NC}"
    echo -e "${YELLOW}   GitLab free tier: 5 GB total LFS storage${NC}"
}

# ── OBJECTS ─────────────────────────────────────────────────────
cmd_objects() {
    check_lfs
    echo -e "${BOLD}📋 All LFS Objects${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    git lfs ls-files -s 2>/dev/null | \
        awk '{printf "  %-12s %s %s\n", $3 >= 1048576 ? sprintf("%.1f MB", $3/1048576) : sprintf("%.1f KB", $3/1024), $1, $4}'
}

# ── PRUNE ───────────────────────────────────────────────────────
cmd_prune() {
    check_lfs
    echo -e "${BOLD}🧹 Pruning old LFS objects${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo "Dry run first..."
    git lfs prune --dry-run

    echo ""
    read -p "Proceed with prune? (y/N) " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        git lfs prune
        echo -e "${GREEN}✅ Prune complete${NC}"
    else
        echo "Aborted."
    fi
}

# ── CLEAN ───────────────────────────────────────────────────────
cmd_clean() {
    check_lfs
    echo -e "${BOLD}🧹 Deep cleaning LFS storage${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Prune + dedup
    git lfs prune
    git lfs dedup 2>/dev/null || echo "  (dedup not supported on this filesystem)"

    echo -e "${GREEN}✅ Clean complete${NC}"
}

# ── INSTALL HOOK ────────────────────────────────────────────────
cmd_install_hook() {
    check_lfs
    local max_size="5M"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --max-size) max_size="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local hook_path=".git/hooks/pre-commit"

    cat > "$hook_path" << 'HOOKEOF'
#!/bin/bash
# Git LFS Manager — Pre-commit hook
# Blocks large files not tracked by LFS

MAX_SIZE_BYTES=PLACEHOLDER_BYTES

# Get staged files
while IFS= read -r -d '' file; do
    if [[ -f "$file" ]]; then
        size=$(wc -c < "$file" 2>/dev/null || echo 0)
        if [[ $size -gt $MAX_SIZE_BYTES ]]; then
            # Check if tracked by LFS
            if ! git lfs track 2>/dev/null | grep -qF "$(echo "$file" | sed 's/.*\./\*\./')"; then
                human=$(awk "BEGIN {printf \"%.1f MB\", $size/1048576}")
                echo "❌ BLOCKED: $file ($human) — not tracked by Git LFS"
                echo "   Run: git lfs track '*.${file##*.}'"
                echo "   Or:  bash scripts/manage.sh track '*.${file##*.}'"
                exit 1
            fi
        fi
    fi
done < <(git diff --cached --name-only -z)

exit 0
HOOKEOF

    # Replace placeholder with actual bytes
    local max_bytes
    case "$max_size" in
        *K) max_bytes=$(( ${max_size%K} * 1024 )) ;;
        *M) max_bytes=$(( ${max_size%M} * 1024 * 1024 )) ;;
        *G) max_bytes=$(( ${max_size%G} * 1024 * 1024 * 1024 )) ;;
        *)  max_bytes=$max_size ;;
    esac

    sed -i "s/PLACEHOLDER_BYTES/$max_bytes/" "$hook_path"
    chmod +x "$hook_path"

    echo -e "${GREEN}✅ Pre-commit hook installed${NC}"
    echo "   Blocks files > $max_size not tracked by LFS"
}

# ── FIX POINTERS ────────────────────────────────────────────────
cmd_fix_pointers() {
    check_lfs
    echo -e "${BOLD}🔧 Fixing LFS pointer issues${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Find files that should be pointers but aren't
    git lfs fsck 2>&1 | head -20

    echo ""
    echo "Attempting to fix..."
    git lfs checkout
    echo -e "${GREEN}✅ Done${NC}"
}

# ── FETCH RECENT ────────────────────────────────────────────────
cmd_fetch_recent() {
    check_lfs
    local days=30

    while [[ $# -gt 0 ]]; do
        case $1 in
            --days) days="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    echo -e "${BOLD}📥 Fetching LFS objects from last $days days${NC}"
    git lfs fetch --recent --recent-refs-days="$days"
    echo -e "${GREEN}✅ Done${NC}"
}

# ── LOCK/UNLOCK ─────────────────────────────────────────────────
cmd_lock() {
    check_lfs
    if [[ $# -eq 0 ]]; then
        echo "Usage: manage.sh lock <file>"
        exit 1
    fi
    git lfs lock "$1"
    echo -e "${GREEN}🔒 Locked: $1${NC}"
}

cmd_unlock() {
    check_lfs
    if [[ $# -eq 0 ]]; then
        echo "Usage: manage.sh unlock <file>"
        exit 1
    fi
    git lfs unlock "$1"
    echo -e "${GREEN}🔓 Unlocked: $1${NC}"
}

cmd_locks() {
    check_lfs
    echo -e "${BOLD}🔒 Active LFS Locks${NC}"
    git lfs locks 2>/dev/null || echo "  No locks found"
}

# ── EXPORT CSV ──────────────────────────────────────────────────
cmd_export_csv() {
    check_lfs
    echo "oid,size_bytes,path"
    git lfs ls-files -s 2>/dev/null | awk '{print $1","$3","$4}'
}

# ── MAIN ROUTER ─────────────────────────────────────────────────
case "${1:-help}" in
    track-defaults)  cmd_track_defaults ;;
    track)           shift; cmd_track "$@" ;;
    status)          cmd_status ;;
    find-large)      shift; cmd_find_large "$@" ;;
    migrate)         shift; cmd_migrate "$@" ;;
    migrate-by-size) shift; cmd_migrate_by_size "$@" ;;
    quota)           cmd_quota ;;
    objects)         cmd_objects ;;
    prune)           cmd_prune ;;
    clean)           cmd_clean ;;
    install-hook)    shift; cmd_install_hook "$@" ;;
    fix-pointers)    cmd_fix_pointers ;;
    fetch-recent)    shift; cmd_fetch_recent "$@" ;;
    lock)            shift; cmd_lock "$@" ;;
    unlock)          shift; cmd_unlock "$@" ;;
    locks)           cmd_locks ;;
    export-csv)      cmd_export_csv ;;
    help|--help|-h)
        echo "Git LFS Manager"
        echo ""
        echo "Usage: bash manage.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  track-defaults          Track common binary file patterns"
        echo "  track <pattern...>      Track custom patterns"
        echo "  status                  Show LFS status overview"
        echo "  find-large [--min-size] Find large files in git history"
        echo "  migrate <pattern...>    Migrate files to LFS (rewrites history!)"
        echo "  migrate-by-size <size>  Migrate all files above size threshold"
        echo "  quota                   Show LFS storage usage"
        echo "  objects                 List all LFS objects"
        echo "  prune                   Remove old LFS objects"
        echo "  clean                   Deep clean LFS storage"
        echo "  install-hook [--max-size] Install pre-commit size guard"
        echo "  fix-pointers            Fix LFS pointer issues"
        echo "  fetch-recent [--days N] Fetch only recent LFS objects"
        echo "  lock <file>             Lock a file"
        echo "  unlock <file>           Unlock a file"
        echo "  locks                   List active locks"
        echo "  export-csv              Export LFS inventory as CSV"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'bash manage.sh help' for usage"
        exit 1
        ;;
esac
