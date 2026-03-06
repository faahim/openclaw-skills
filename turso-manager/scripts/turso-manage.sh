#!/bin/bash
# Turso Database Manager — Main Script
# Manage Turso (libSQL) databases from the command line

set -euo pipefail

# Configuration
CONFIG_FILE="${HOME}/.turso-manager.conf"
DEFAULT_BACKUP_DIR="${TURSO_BACKUP_DIR:-${HOME}/.turso-backups}"
DEFAULT_GROUP="${TURSO_DEFAULT_GROUP:-default}"
DEFAULT_REGION="${TURSO_DEFAULT_REGION:-}"

# Load config file if exists
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    DEFAULT_BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
    DEFAULT_GROUP="${DEFAULT_GROUP:-default}"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helpers
info()  { echo -e "${BLUE}ℹ️  $*${NC}"; }
ok()    { echo -e "${GREEN}✅ $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $*${NC}"; }
fail()  { echo -e "${RED}❌ $*${NC}" >&2; exit 1; }

check_turso() {
    if ! command -v turso &>/dev/null; then
        # Check common install locations
        if [[ -f "$HOME/.turso/turso" ]]; then
            export PATH="$HOME/.turso:$PATH"
        else
            fail "Turso CLI not found. Run: bash scripts/install.sh"
        fi
    fi
}

check_auth() {
    if [[ -n "${TURSO_API_TOKEN:-}" ]]; then
        return 0
    fi
    if ! turso auth status &>/dev/null 2>&1; then
        fail "Not authenticated. Run: turso auth login"
    fi
}

usage() {
    cat <<EOF
Turso Database Manager

USAGE:
    $(basename "$0") <command> [args] [options]

DATABASE COMMANDS:
    create <name> [--group <g>] [--region <r>]   Create a new database
    list [--usage]                                 List all databases
    info <name>                                    Show database details
    usage <name>                                   Show usage statistics
    destroy <name> [--yes]                         Delete a database
    clone <source> <target>                        Clone a database

QUERY COMMANDS:
    shell <name>                                   Open interactive SQL shell
    query <name> "<sql>"                           Execute a SQL query
    migrate <name> --file <path>                   Run SQL migration file

AUTH COMMANDS:
    token <name> [--read-only] [--expiration <d>]  Generate auth token
    env <name>                                      Print .env format connection

GROUP COMMANDS:
    group-create <name> [--region <r>]             Create a group
    group-list                                      List all groups
    group-add-region <name> --region <r>            Add replica region
    group-remove-region <name> --region <r>         Remove replica region

BACKUP COMMANDS:
    backup <name> [--output <dir>]                 Backup to local SQLite
    backup-all [--output <dir>]                    Backup all databases
    restore <name> --from <file>                   Restore from backup
    setup-cron [--interval daily|hourly]           Set up scheduled backups

OPTIONS:
    -h, --help     Show this help
    -v, --verbose  Verbose output
    --json         JSON output (where supported)

EXAMPLES:
    $(basename "$0") create myapp --region sjc
    $(basename "$0") token myapp --read-only --expiration 30d
    $(basename "$0") query myapp "SELECT count(*) FROM users"
    $(basename "$0") backup myapp --output ./backups/
EOF
}

# ── Database Commands ──────────────────────────────────────────

cmd_create() {
    local name="" group="$DEFAULT_GROUP" region="$DEFAULT_REGION"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --group) group="$2"; shift 2 ;;
            --region) region="$2"; shift 2 ;;
            -*) fail "Unknown option: $1" ;;
            *) name="$1"; shift ;;
        esac
    done
    
    [[ -z "$name" ]] && fail "Usage: create <db-name> [--group <g>] [--region <r>]"
    
    info "Creating database '$name'..."
    
    local cmd="turso db create $name --group $group"
    [[ -n "$region" ]] && cmd+=" --location $region"
    
    if eval "$cmd"; then
        echo ""
        ok "Database '$name' created"
        
        # Show connection info
        local url
        url=$(turso db show "$name" --url 2>/dev/null || echo "")
        if [[ -n "$url" ]]; then
            echo "   URL: $url"
        fi
        
        local loc
        loc=$(turso db show "$name" 2>/dev/null | grep -i "region\|location" | head -1 || echo "")
        [[ -n "$loc" ]] && echo "   $loc"
    else
        fail "Failed to create database '$name'"
    fi
}

cmd_list() {
    local show_usage=false
    [[ "${1:-}" == "--usage" ]] && show_usage=true
    
    info "Databases:"
    echo ""
    turso db list
    
    if $show_usage; then
        echo ""
        info "Fetching usage for each database..."
        for db in $(turso db list 2>/dev/null | tail -n +2 | awk '{print $1}'); do
            [[ -z "$db" || "$db" == "Name" ]] && continue
            echo ""
            echo "  📊 $db:"
            turso db inspect "$db" 2>/dev/null | head -5 | sed 's/^/     /'
        done
    fi
}

cmd_info() {
    local name="${1:?Usage: info <db-name>}"
    turso db show "$name"
}

cmd_usage() {
    local name="${1:?Usage: usage <db-name>}"
    info "Usage stats for '$name':"
    echo ""
    turso db inspect "$name"
}

cmd_destroy() {
    local name="" force=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes|-y) force=true; shift ;;
            -*) fail "Unknown option: $1" ;;
            *) name="$1"; shift ;;
        esac
    done
    
    [[ -z "$name" ]] && fail "Usage: destroy <db-name> [--yes]"
    
    if ! $force; then
        echo -n "⚠️  Are you sure you want to destroy '$name'? This cannot be undone. [y/N] "
        read -r confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "Cancelled."; exit 0; }
    fi
    
    info "Destroying database '$name'..."
    if turso db destroy "$name" --yes; then
        ok "Database '$name' destroyed"
    else
        fail "Failed to destroy database '$name'"
    fi
}

cmd_clone() {
    local source="${1:?Usage: clone <source-db> <target-db>}"
    local target="${2:?Usage: clone <source-db> <target-db>}"
    
    info "Cloning '$source' → '$target'..."
    
    # Backup source first
    local tmpfile
    tmpfile=$(mktemp /tmp/turso-clone-XXXXXX.db)
    
    if turso db shell "$source" .dump > "${tmpfile}.sql" 2>/dev/null; then
        # Create target database
        turso db create "$target" --group "$DEFAULT_GROUP"
        
        # Restore dump to target
        turso db shell "$target" < "${tmpfile}.sql"
        
        rm -f "${tmpfile}" "${tmpfile}.sql"
        ok "Cloned '$source' → '$target'"
    else
        rm -f "${tmpfile}" "${tmpfile}.sql"
        fail "Failed to clone '$source'"
    fi
}

# ── Query Commands ──────────────────────────────────────────

cmd_shell() {
    local name="${1:?Usage: shell <db-name>}"
    info "Opening SQL shell for '$name'..."
    turso db shell "$name"
}

cmd_query() {
    local name="${1:?Usage: query <db-name> \"<sql>\"}"
    local sql="${2:?Usage: query <db-name> \"<sql>\"}"
    
    turso db shell "$name" "$sql"
}

cmd_migrate() {
    local name="" file=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file) file="$2"; shift 2 ;;
            -*) fail "Unknown option: $1" ;;
            *) name="$1"; shift ;;
        esac
    done
    
    [[ -z "$name" ]] && fail "Usage: migrate <db-name> --file <path>"
    [[ -z "$file" ]] && fail "Usage: migrate <db-name> --file <path>"
    [[ ! -f "$file" ]] && fail "File not found: $file"
    
    info "Running migration on '$name' from $file..."
    
    if turso db shell "$name" < "$file"; then
        ok "Migration complete"
    else
        fail "Migration failed"
    fi
}

# ── Auth Commands ──────────────────────────────────────────

cmd_token() {
    local name="" readonly=false expiration=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --read-only) readonly=true; shift ;;
            --expiration) expiration="$2"; shift 2 ;;
            -*) fail "Unknown option: $1" ;;
            *) name="$1"; shift ;;
        esac
    done
    
    [[ -z "$name" ]] && fail "Usage: token <db-name> [--read-only] [--expiration <duration>]"
    
    local cmd="turso db tokens create $name"
    $readonly && cmd+=" --read-only"
    [[ -n "$expiration" ]] && cmd+=" --expiration $expiration"
    
    local token
    token=$(eval "$cmd" 2>/dev/null)
    
    if [[ -n "$token" ]]; then
        local url
        url=$(turso db show "$name" --url 2>/dev/null || echo "libsql://${name}-<org>.turso.io")
        
        echo -e "${GREEN}🔑 Auth token for '$name':${NC}"
        echo "   $token"
        echo ""
        echo "   Permissions: $($readonly && echo "read-only" || echo "full-access")"
        [[ -n "$expiration" ]] && echo "   Expires in: $expiration"
        echo ""
        echo "   Set in your app:"
        echo "   TURSO_DATABASE_URL=$url"
        echo "   TURSO_AUTH_TOKEN=$token"
    else
        fail "Failed to generate token for '$name'"
    fi
}

cmd_env() {
    local name="${1:?Usage: env <db-name>}"
    
    local url
    url=$(turso db show "$name" --url 2>/dev/null || echo "")
    [[ -z "$url" ]] && fail "Could not get URL for '$name'"
    
    local token
    token=$(turso db tokens create "$name" 2>/dev/null || echo "")
    [[ -z "$token" ]] && fail "Could not generate token for '$name'"
    
    echo "TURSO_DATABASE_URL=$url"
    echo "TURSO_AUTH_TOKEN=$token"
}

# ── Group Commands ──────────────────────────────────────────

cmd_group_create() {
    local name="" region="$DEFAULT_REGION"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --region) region="$2"; shift 2 ;;
            -*) fail "Unknown option: $1" ;;
            *) name="$1"; shift ;;
        esac
    done
    
    [[ -z "$name" ]] && fail "Usage: group-create <name> [--region <r>]"
    
    local cmd="turso group create $name"
    [[ -n "$region" ]] && cmd+=" --location $region"
    
    if eval "$cmd"; then
        ok "Group '$name' created"
    else
        fail "Failed to create group '$name'"
    fi
}

cmd_group_list() {
    turso group list
}

cmd_group_add_region() {
    local name="" region=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --region) region="$2"; shift 2 ;;
            -*) fail "Unknown option: $1" ;;
            *) name="$1"; shift ;;
        esac
    done
    
    [[ -z "$name" || -z "$region" ]] && fail "Usage: group-add-region <name> --region <r>"
    
    if turso group locations add "$name" "$region"; then
        ok "Region '$region' added to group '$name'"
    else
        fail "Failed to add region"
    fi
}

cmd_group_remove_region() {
    local name="" region=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --region) region="$2"; shift 2 ;;
            -*) fail "Unknown option: $1" ;;
            *) name="$1"; shift ;;
        esac
    done
    
    [[ -z "$name" || -z "$region" ]] && fail "Usage: group-remove-region <name> --region <r>"
    
    if turso group locations remove "$name" "$region"; then
        ok "Region '$region' removed from group '$name'"
    else
        fail "Failed to remove region"
    fi
}

# ── Backup Commands ──────────────────────────────────────────

cmd_backup() {
    local name="" output="$DEFAULT_BACKUP_DIR" stream=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --output) output="$2"; shift 2 ;;
            --stream) stream=true; shift ;;
            -*) fail "Unknown option: $1" ;;
            *) name="$1"; shift ;;
        esac
    done
    
    [[ -z "$name" ]] && fail "Usage: backup <db-name> [--output <dir>]"
    
    mkdir -p "$output"
    
    local timestamp
    timestamp=$(date +%Y-%m-%d-%H%M%S)
    local backup_file="${output}/${name}-${timestamp}.db"
    local dump_file="${output}/${name}-${timestamp}.sql"
    
    info "Backing up '$name'..."
    
    # Dump SQL
    if turso db shell "$name" .dump > "$dump_file" 2>/dev/null; then
        local size
        size=$(du -h "$dump_file" | cut -f1)
        local tables
        tables=$(grep -c "^CREATE TABLE" "$dump_file" || echo "0")
        
        ok "Backup complete: $dump_file ($size)"
        echo "   Tables: $tables"
        
        # Also create SQLite binary if sqlite3 available
        if command -v sqlite3 &>/dev/null; then
            sqlite3 "$backup_file" < "$dump_file" 2>/dev/null && {
                local binsize
                binsize=$(du -h "$backup_file" | cut -f1)
                echo "   Binary: $backup_file ($binsize)"
            }
        fi
    else
        fail "Backup failed for '$name'"
    fi
}

cmd_backup_all() {
    local output="$DEFAULT_BACKUP_DIR"
    [[ "${1:-}" == "--output" ]] && output="${2:-$output}"
    
    mkdir -p "$output"
    
    info "Backing up all databases..."
    echo ""
    
    local count=0
    local failed=0
    
    for db in $(turso db list 2>/dev/null | tail -n +2 | awk '{print $1}'); do
        [[ -z "$db" || "$db" == "Name" ]] && continue
        
        if cmd_backup "$db" --output "$output" 2>/dev/null; then
            ((count++))
        else
            warn "Failed to backup: $db"
            ((failed++))
        fi
    done
    
    echo ""
    ok "Backup complete: $count databases backed up, $failed failed"
    
    # Clean old backups
    local retention="${BACKUP_RETENTION_DAYS:-30}"
    local cleaned
    cleaned=$(find "$output" -name "*.sql" -mtime +"$retention" -delete -print 2>/dev/null | wc -l)
    find "$output" -name "*.db" -mtime +"$retention" -delete 2>/dev/null
    [[ "$cleaned" -gt 0 ]] && info "Cleaned $cleaned backups older than ${retention} days"
}

cmd_restore() {
    local name="" from=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --from) from="$2"; shift 2 ;;
            -*) fail "Unknown option: $1" ;;
            *) name="$1"; shift ;;
        esac
    done
    
    [[ -z "$name" || -z "$from" ]] && fail "Usage: restore <db-name> --from <file>"
    [[ ! -f "$from" ]] && fail "File not found: $from"
    
    warn "This will overwrite data in '$name'. Continue? [y/N] "
    read -r confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "Cancelled."; exit 0; }
    
    info "Restoring '$name' from $from..."
    
    local ext="${from##*.}"
    
    if [[ "$ext" == "sql" ]]; then
        turso db shell "$name" < "$from"
    elif [[ "$ext" == "db" ]]; then
        # Convert SQLite to SQL dump first
        if command -v sqlite3 &>/dev/null; then
            sqlite3 "$from" .dump | turso db shell "$name"
        else
            fail "sqlite3 required to restore from .db files"
        fi
    else
        fail "Unsupported backup format: .$ext (use .sql or .db)"
    fi
    
    ok "Restore complete"
}

cmd_setup_cron() {
    local interval="daily" time="02:00"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --interval) interval="$2"; shift 2 ;;
            --time) time="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    local hour minute
    hour=$(echo "$time" | cut -d: -f1)
    minute=$(echo "$time" | cut -d: -f2)
    
    local script_path
    script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    
    local cron_expr
    case "$interval" in
        daily)  cron_expr="$minute $hour * * *" ;;
        hourly) cron_expr="$minute * * * *" ;;
        weekly) cron_expr="$minute $hour * * 0" ;;
        *) fail "Unknown interval: $interval (use daily, hourly, weekly)" ;;
    esac
    
    local cron_line="$cron_expr bash $script_path backup-all --output $DEFAULT_BACKUP_DIR >> /tmp/turso-backup.log 2>&1"
    
    # Add to crontab (avoiding duplicates)
    (crontab -l 2>/dev/null | grep -v "turso-manage.sh backup-all"; echo "$cron_line") | crontab -
    
    ok "Cron job added: $interval backups at $time"
    echo "   $cron_line"
    echo "   Logs: /tmp/turso-backup.log"
}

# ── Main ──────────────────────────────────────────

main() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true
    
    case "$cmd" in
        create)              check_turso; check_auth; cmd_create "$@" ;;
        list|ls)             check_turso; check_auth; cmd_list "$@" ;;
        info|show)           check_turso; check_auth; cmd_info "$@" ;;
        usage|inspect)       check_turso; check_auth; cmd_usage "$@" ;;
        destroy|delete|rm)   check_turso; check_auth; cmd_destroy "$@" ;;
        clone)               check_turso; check_auth; cmd_clone "$@" ;;
        shell)               check_turso; check_auth; cmd_shell "$@" ;;
        query|sql)           check_turso; check_auth; cmd_query "$@" ;;
        migrate)             check_turso; check_auth; cmd_migrate "$@" ;;
        token)               check_turso; check_auth; cmd_token "$@" ;;
        env)                 check_turso; check_auth; cmd_env "$@" ;;
        group-create)        check_turso; check_auth; cmd_group_create "$@" ;;
        group-list)          check_turso; check_auth; cmd_group_list "$@" ;;
        group-add-region)    check_turso; check_auth; cmd_group_add_region "$@" ;;
        group-remove-region) check_turso; check_auth; cmd_group_remove_region "$@" ;;
        backup)              check_turso; check_auth; cmd_backup "$@" ;;
        backup-all)          check_turso; check_auth; cmd_backup_all "$@" ;;
        restore)             check_turso; check_auth; cmd_restore "$@" ;;
        setup-cron)          cmd_setup_cron "$@" ;;
        help|-h|--help)      usage ;;
        *)                   fail "Unknown command: $cmd. Run with --help for usage." ;;
    esac
}

main "$@"
