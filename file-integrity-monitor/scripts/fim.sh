#!/usr/bin/env bash
# File Integrity Monitor (FIM) — Lightweight file change detection
# Uses SHA-256 hashing to detect modifications, additions, and deletions
set -euo pipefail

VERSION="1.0.0"
DB_DIR="${FIM_DB_DIR:-$HOME/.fim/databases}"
LOG_FILE="${FIM_LOG:-$HOME/.fim/fim.log}"
MAX_SIZE="${FIM_MAX_SIZE:-50M}"
PARALLEL_JOBS=4

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
log_file() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true; }

usage() {
    cat << 'EOF'
File Integrity Monitor v1.0.0

Usage: fim.sh <command> [options]

Commands:
  init      Create baseline hash database
  check     Compare current state against baseline
  update    Update baseline to current state
  verify    Check a single file against baseline
  report    Show database summary
  diff      Compare two database snapshots
  export    Export database as JSON

Options:
  --path <dir>       Directory to monitor (repeatable)
  --db <file>        Database file path
  --config <file>    Config file (YAML-style)
  --exclude <pat>    Comma-separated exclude patterns
  --max-size <size>  Skip files larger than this (default: 50M)
  --alert <type>     Alert type: telegram, webhook, email
  --severity <lvl>   Alert severity: info, warning, critical
  --format <fmt>     Export format: json, csv
  --check-perms      Include permissions/ownership in checks
  --file <path>      Specific file (for verify command)
  -q, --quiet        Suppress normal output
  -h, --help         Show this help

Examples:
  fim.sh init --path /etc --db ~/.fim/etc.db
  fim.sh check --db ~/.fim/etc.db --alert telegram
  fim.sh update --db ~/.fim/etc.db
  fim.sh report --db ~/.fim/etc.db
EOF
    exit 0
}

# Parse size string to bytes
parse_size() {
    local size="$1"
    local num="${size%[KkMmGg]*}"
    local unit="${size: -1}"
    case "$unit" in
        K|k) echo $((num * 1024)) ;;
        M|m) echo $((num * 1024 * 1024)) ;;
        G|g) echo $((num * 1024 * 1024 * 1024)) ;;
        *) echo "$num" ;;
    esac
}

# Compute hash entry for a file: HASH|PATH|SIZE|PERMS|MTIME
compute_entry() {
    local file="$1"
    local check_perms="${2:-false}"
    
    if [[ ! -f "$file" ]] || [[ ! -r "$file" ]]; then
        return
    fi
    
    local max_bytes
    max_bytes=$(parse_size "$MAX_SIZE")
    local fsize
    fsize=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null || echo 0)
    
    if [[ "$fsize" -gt "$max_bytes" ]]; then
        return
    fi
    
    local hash
    hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1) || return
    
    local perms="---"
    local mtime="0"
    if [[ "$check_perms" == "true" ]]; then
        perms=$(stat -c '%a:%U:%G' "$file" 2>/dev/null || stat -f '%Lp:%Su:%Sg' "$file" 2>/dev/null || echo "---")
        mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo "0")
    fi
    
    echo "${hash}|${file}|${fsize}|${perms}|${mtime}"
}

# Build exclude arguments for find
build_find_excludes() {
    local excludes="$1"
    local args=""
    IFS=',' read -ra pats <<< "$excludes"
    for pat in "${pats[@]}"; do
        pat=$(echo "$pat" | xargs)  # trim
        if [[ -n "$pat" ]]; then
            args="$args -not -name '$pat' -not -path '*/$pat/*'"
        fi
    done
    echo "$args"
}

# Initialize baseline database
cmd_init() {
    local paths=()
    local db=""
    local excludes=""
    local check_perms="false"
    local quiet="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path) paths+=("$2"); shift 2 ;;
            --db) db="$2"; shift 2 ;;
            --exclude) excludes="$2"; shift 2 ;;
            --max-size) MAX_SIZE="$2"; shift 2 ;;
            --check-perms) check_perms="true"; shift ;;
            -q|--quiet) quiet="true"; shift ;;
            *) shift ;;
        esac
    done
    
    if [[ ${#paths[@]} -eq 0 ]]; then
        echo "Error: --path is required" >&2
        exit 1
    fi
    
    if [[ -z "$db" ]]; then
        mkdir -p "$DB_DIR"
        db="$DB_DIR/default.db"
    fi
    
    mkdir -p "$(dirname "$db")"
    
    [[ "$quiet" != "true" ]] && log "${BLUE}🔍 Initializing baseline...${NC}"
    
    # Write header
    {
        echo "# FIM Database v1"
        echo "# Created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        echo "# Paths: ${paths[*]}"
        echo "# Excludes: $excludes"
        echo "# Format: HASH|PATH|SIZE|PERMS|MTIME"
        echo "---"
    } > "$db"
    
    local count=0
    for dir in "${paths[@]}"; do
        if [[ ! -d "$dir" ]] && [[ ! -f "$dir" ]]; then
            echo "Warning: $dir does not exist, skipping" >&2
            continue
        fi
        
        # Build find command
        local find_cmd="find '$dir' -type f"
        if [[ -n "$excludes" ]]; then
            IFS=',' read -ra pats <<< "$excludes"
            for pat in "${pats[@]}"; do
                pat=$(echo "$pat" | xargs)
                [[ -n "$pat" ]] && find_cmd="$find_cmd -not -name '$pat' -not -path '*/$pat/*'"
            done
        fi
        
        while IFS= read -r file; do
            local entry
            entry=$(compute_entry "$file" "$check_perms")
            if [[ -n "$entry" ]]; then
                echo "$entry" >> "$db"
                count=$((count + 1))
            fi
        done < <(eval "$find_cmd" 2>/dev/null | sort)
    done
    
    [[ "$quiet" != "true" ]] && log "${GREEN}✅ Baseline created: $count files hashed${NC}"
    [[ "$quiet" != "true" ]] && log "   Database: $db ($(du -h "$db" | cut -f1))"
    log_file "INIT: $count files baselined -> $db"
}

# Check current state against baseline
cmd_check() {
    local db=""
    local alert=""
    local severity="warning"
    local quiet="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --db) db="$2"; shift 2 ;;
            --alert) alert="$2"; shift 2 ;;
            --severity) severity="$2"; shift 2 ;;
            --max-size) MAX_SIZE="$2"; shift 2 ;;
            -q|--quiet) quiet="true"; shift ;;
            *) shift ;;
        esac
    done
    
    if [[ -z "$db" ]]; then
        db="$DB_DIR/default.db"
    fi
    
    if [[ ! -f "$db" ]]; then
        echo "Error: Database not found: $db" >&2
        echo "Run 'fim.sh init' first." >&2
        exit 1
    fi
    
    # Parse baseline
    declare -A baseline_hashes
    declare -A baseline_sizes
    declare -A baseline_perms
    local total=0
    
    while IFS='|' read -r hash path size perms mtime; do
        [[ "$hash" =~ ^#.*$ ]] && continue
        [[ "$hash" == "---" ]] && continue
        [[ -z "$hash" ]] && continue
        baseline_hashes["$path"]="$hash"
        baseline_sizes["$path"]="$size"
        baseline_perms["$path"]="$perms"
        total=$((total + 1))
    done < "$db"
    
    [[ "$quiet" != "true" ]] && log "${BLUE}🔍 Scanning $total files...${NC}"
    
    local modified=()
    local added=()
    local deleted=()
    local checked=0
    
    # Check all baselined files
    declare -A current_seen
    for path in "${!baseline_hashes[@]}"; do
        if [[ ! -f "$path" ]]; then
            deleted+=("$path")
        else
            local current_hash
            current_hash=$(sha256sum "$path" 2>/dev/null | cut -d' ' -f1) || continue
            current_seen["$path"]=1
            
            if [[ "$current_hash" != "${baseline_hashes[$path]}" ]]; then
                modified+=("MODIFIED: $path|Old: ${baseline_hashes[$path]:0:16}...|New: ${current_hash:0:16}...")
            fi
        fi
        checked=$((checked + 1))
    done
    
    # Check for new files in monitored paths
    local paths_line
    paths_line=$(grep "^# Paths:" "$db" | sed 's/^# Paths: //')
    local excludes_line
    excludes_line=$(grep "^# Excludes:" "$db" | sed 's/^# Excludes: //')
    
    if [[ -n "$paths_line" ]]; then
        IFS=' ' read -ra scan_paths <<< "$paths_line"
        for dir in "${scan_paths[@]}"; do
            [[ ! -d "$dir" ]] && continue
            local find_cmd="find '$dir' -type f"
            if [[ -n "$excludes_line" ]]; then
                IFS=',' read -ra pats <<< "$excludes_line"
                for pat in "${pats[@]}"; do
                    pat=$(echo "$pat" | xargs)
                    [[ -n "$pat" ]] && find_cmd="$find_cmd -not -name '$pat' -not -path '*/$pat/*'"
                done
            fi
            
            while IFS= read -r file; do
                if [[ -z "${baseline_hashes[$file]+x}" ]]; then
                    local new_hash
                    new_hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1) || continue
                    added+=("ADDED: $file|Hash: ${new_hash:0:16}...")
                fi
            done < <(eval "$find_cmd" 2>/dev/null | sort)
        done
    fi
    
    local total_changes=$(( ${#modified[@]} + ${#added[@]} + ${#deleted[@]} ))
    
    if [[ $total_changes -eq 0 ]]; then
        [[ "$quiet" != "true" ]] && log "${GREEN}✅ No changes detected ($total files verified)${NC}"
        log_file "CHECK OK: $total files verified, 0 changes"
        exit 0
    fi
    
    # Report changes
    [[ "$quiet" != "true" ]] && log "${RED}⚠️  $total_changes changes detected:${NC}"
    echo ""
    
    local alert_text="🚨 File Integrity Alert ($severity)\n\n$total_changes changes detected:\n\n"
    
    for entry in "${modified[@]}"; do
        IFS='|' read -r line old new <<< "$entry"
        [[ "$quiet" != "true" ]] && echo -e "  ${YELLOW}${line}${NC}"
        [[ "$quiet" != "true" ]] && echo -e "    ${old}"
        [[ "$quiet" != "true" ]] && echo -e "    ${new}"
        [[ "$quiet" != "true" ]] && echo ""
        alert_text+="📝 ${line}\n"
    done
    
    for entry in "${added[@]}"; do
        IFS='|' read -r line hash <<< "$entry"
        [[ "$quiet" != "true" ]] && echo -e "  ${GREEN}${line}${NC}"
        [[ "$quiet" != "true" ]] && echo -e "    ${hash}"
        [[ "$quiet" != "true" ]] && echo ""
        alert_text+="➕ ${line}\n"
    done
    
    for path in "${deleted[@]}"; do
        [[ "$quiet" != "true" ]] && echo -e "  ${RED}DELETED: ${path}${NC}"
        [[ "$quiet" != "true" ]] && echo ""
        alert_text+="❌ DELETED: ${path}\n"
    done
    
    log_file "CHECK ALERT: $total_changes changes (${#modified[@]} modified, ${#added[@]} added, ${#deleted[@]} deleted)"
    
    # Send alerts
    if [[ -n "$alert" ]]; then
        send_alert "$alert" "$alert_text" "$severity"
    fi
    
    exit 1  # Non-zero exit on changes (useful for cron/CI)
}

# Send alert via configured channel
send_alert() {
    local type="$1"
    local text="$2"
    local severity="$3"
    
    case "$type" in
        telegram)
            if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] || [[ -z "${TELEGRAM_CHAT_ID:-}" ]]; then
                echo "Warning: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set" >&2
                return
            fi
            local escaped_text
            escaped_text=$(echo -e "$text" | sed 's/[&<>]/\\&/g')
            curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
                -d chat_id="${TELEGRAM_CHAT_ID}" \
                -d text="$(echo -e "$text")" \
                -d parse_mode="" > /dev/null 2>&1
            log "${GREEN}🚨 Alert sent via Telegram${NC}"
            ;;
        webhook)
            if [[ -z "${FIM_WEBHOOK_URL:-}" ]]; then
                echo "Warning: FIM_WEBHOOK_URL not set" >&2
                return
            fi
            curl -s -X POST "$FIM_WEBHOOK_URL" \
                -H "Content-Type: application/json" \
                -d "{\"text\":\"$(echo -e "$text" | sed 's/"/\\"/g')\",\"severity\":\"$severity\"}" > /dev/null 2>&1
            log "${GREEN}🚨 Alert sent via webhook${NC}"
            ;;
        email)
            if command -v mail &>/dev/null && [[ -n "${FIM_EMAIL_TO:-}" ]]; then
                echo -e "$text" | mail -s "FIM Alert ($severity)" "$FIM_EMAIL_TO"
                log "${GREEN}🚨 Alert sent via email${NC}"
            else
                echo "Warning: mail command not found or FIM_EMAIL_TO not set" >&2
            fi
            ;;
    esac
}

# Update baseline to current state
cmd_update() {
    local db=""
    local specific_path=""
    local quiet="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --db) db="$2"; shift 2 ;;
            --path) specific_path="$2"; shift 2 ;;
            -q|--quiet) quiet="true"; shift ;;
            *) shift ;;
        esac
    done
    
    if [[ -z "$db" ]]; then
        db="$DB_DIR/default.db"
    fi
    
    if [[ ! -f "$db" ]]; then
        echo "Error: Database not found: $db" >&2
        exit 1
    fi
    
    # Backup old database
    cp "$db" "${db}.bak.$(date +%Y%m%d%H%M%S)"
    
    if [[ -n "$specific_path" ]]; then
        # Update single file
        local new_hash
        new_hash=$(sha256sum "$specific_path" 2>/dev/null | cut -d' ' -f1)
        local fsize
        fsize=$(stat -c %s "$specific_path" 2>/dev/null || stat -f %z "$specific_path" 2>/dev/null)
        
        # Replace or add entry
        if grep -q "|${specific_path}|" "$db"; then
            sed -i "s|^[^|]*|${specific_path}|.*|${new_hash}|${specific_path}|${fsize}|---|0|" "$db"
        else
            echo "${new_hash}|${specific_path}|${fsize}|---|0" >> "$db"
        fi
        [[ "$quiet" != "true" ]] && log "${GREEN}✅ Updated baseline for: $specific_path${NC}"
    else
        # Re-init from same paths
        local paths_line
        paths_line=$(grep "^# Paths:" "$db" | sed 's/^# Paths: //')
        local excludes_line
        excludes_line=$(grep "^# Excludes:" "$db" | sed 's/^# Excludes: //')
        
        local init_args=()
        for p in $paths_line; do
            init_args+=(--path "$p")
        done
        [[ -n "$excludes_line" ]] && init_args+=(--exclude "$excludes_line")
        init_args+=(--db "$db")
        [[ "$quiet" == "true" ]] && init_args+=(-q)
        
        cmd_init "${init_args[@]}"
    fi
    
    log_file "UPDATE: Baseline updated for $db"
}

# Verify single file
cmd_verify() {
    local db=""
    local file=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --db) db="$2"; shift 2 ;;
            --file) file="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [[ -z "$db" ]] || [[ -z "$file" ]]; then
        echo "Error: --db and --file are required" >&2
        exit 1
    fi
    
    local baseline_hash
    baseline_hash=$(grep "|${file}|" "$db" | head -1 | cut -d'|' -f1)
    
    if [[ -z "$baseline_hash" ]]; then
        echo "File not in baseline: $file"
        exit 1
    fi
    
    local current_hash
    current_hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
    
    if [[ "$current_hash" == "$baseline_hash" ]]; then
        log "${GREEN}✅ VERIFIED: $file (hash matches)${NC}"
        exit 0
    else
        log "${RED}❌ MISMATCH: $file${NC}"
        echo "  Baseline: $baseline_hash"
        echo "  Current:  $current_hash"
        exit 1
    fi
}

# Report database summary
cmd_report() {
    local db=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --db) db="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [[ -z "$db" ]]; then
        db="$DB_DIR/default.db"
    fi
    
    if [[ ! -f "$db" ]]; then
        echo "Error: Database not found: $db" >&2
        exit 1
    fi
    
    local created
    created=$(grep "^# Created:" "$db" | sed 's/^# Created: //')
    local paths
    paths=$(grep "^# Paths:" "$db" | sed 's/^# Paths: //')
    local file_count
    file_count=$(grep -c "^[a-f0-9]" "$db" || echo 0)
    local db_size
    db_size=$(du -h "$db" | cut -f1)
    
    echo ""
    echo "=== File Integrity Report ==="
    echo "Database:      $db"
    echo "Created:       $created"
    echo "Paths:         $paths"
    echo "Files tracked: $file_count"
    echo "Database size: $db_size"
    echo ""
    
    # Show top directories
    echo "Top directories:"
    grep "^[a-f0-9]" "$db" | cut -d'|' -f2 | xargs -I{} dirname {} | sort | uniq -c | sort -rn | head -10 | while read -r count dir; do
        printf "  %5d files  %s\n" "$count" "$dir"
    done
    echo ""
}

# Export database
cmd_export() {
    local db=""
    local format="json"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --db) db="$2"; shift 2 ;;
            --format) format="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [[ -z "$db" ]]; then
        db="$DB_DIR/default.db"
    fi
    
    case "$format" in
        json)
            echo "["
            local first=true
            while IFS='|' read -r hash path size perms mtime; do
                [[ "$hash" =~ ^#.*$ ]] && continue
                [[ "$hash" == "---" ]] && continue
                [[ -z "$hash" ]] && continue
                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    echo ","
                fi
                printf '  {"hash":"%s","path":"%s","size":%s,"perms":"%s","mtime":%s}' \
                    "$hash" "$path" "$size" "$perms" "$mtime"
            done < "$db"
            echo ""
            echo "]"
            ;;
        csv)
            echo "hash,path,size,perms,mtime"
            while IFS='|' read -r hash path size perms mtime; do
                [[ "$hash" =~ ^#.*$ ]] && continue
                [[ "$hash" == "---" ]] && continue
                [[ -z "$hash" ]] && continue
                echo "$hash,$path,$size,$perms,$mtime"
            done < "$db"
            ;;
    esac
}

# Main dispatcher
main() {
    if [[ $# -eq 0 ]]; then
        usage
    fi
    
    mkdir -p "$DB_DIR" "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    local cmd="$1"
    shift
    
    case "$cmd" in
        init) cmd_init "$@" ;;
        check) cmd_check "$@" ;;
        update) cmd_update "$@" ;;
        verify) cmd_verify "$@" ;;
        report) cmd_report "$@" ;;
        export) cmd_export "$@" ;;
        -h|--help|help) usage ;;
        -v|--version) echo "File Integrity Monitor v${VERSION}" ;;
        *) echo "Unknown command: $cmd" >&2; usage ;;
    esac
}

main "$@"
