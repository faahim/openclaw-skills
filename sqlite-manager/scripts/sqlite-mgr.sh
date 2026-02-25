#!/bin/bash
# SQLite Manager — Manage SQLite databases from the command line
# Usage: bash sqlite-mgr.sh <command> <database> [args...]

set -euo pipefail

VERSION="1.0.0"
HISTORY_DIR="${SQLITE_MGR_HISTORY:-$HOME/.sqlite-mgr}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_ok() { echo -e "${GREEN}✅${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠️${NC} $*"; }
log_err() { echo -e "${RED}❌${NC} $*"; }
log_info() { echo -e "${BLUE}📊${NC} $*"; }

check_sqlite() {
  if ! command -v sqlite3 &>/dev/null; then
    log_err "sqlite3 not found. Install: sudo apt-get install -y sqlite3"
    exit 1
  fi
}

check_db() {
  local db="$1"
  if [[ ! -f "$db" ]]; then
    log_err "Database not found: $db"
    exit 1
  fi
}

cmd_info() {
  local db="$1"
  check_db "$db"
  
  local size=$(du -h "$db" | cut -f1)
  local tables=$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
  local indexes=$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%';")
  local journal=$(sqlite3 "$db" "PRAGMA journal_mode;")
  
  echo -e "${BLUE}📊${NC} Database: $(basename "$db")"
  echo "   Size: $size"
  echo "   Tables: $tables"
  echo "   Indexes: $indexes"
  echo "   Journal mode: $journal"
  echo ""
  echo "Tables:"
  
  sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;" | while read -r table; do
    local rows=$(sqlite3 "$db" "SELECT COUNT(*) FROM \"$table\";")
    local idx_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND tbl_name='$table' AND name NOT LIKE 'sqlite_%';")
    printf "  %-20s — %s rows (%s indexes)\n" "$table" "$rows" "$idx_count"
  done
}

cmd_schema() {
  local db="$1"
  local table="${2:-}"
  check_db "$db"
  
  if [[ -n "$table" ]]; then
    echo -e "${BLUE}📋${NC} Table: $table"
    sqlite3 "$db" ".schema $table"
    echo ""
    echo "Indexes:"
    sqlite3 "$db" "SELECT '  ' || name || ' — ' || sql FROM sqlite_master WHERE type='index' AND tbl_name='$table' AND name NOT LIKE 'sqlite_%';" 2>/dev/null || echo "  (none)"
    echo ""
    local rows=$(sqlite3 "$db" "SELECT COUNT(*) FROM \"$table\";")
    echo "Row count: $rows"
  else
    sqlite3 "$db" ".schema"
  fi
}

cmd_indexes() {
  local db="$1"
  check_db "$db"
  
  echo -e "${BLUE}📋${NC} Indexes in $(basename "$db"):"
  sqlite3 "$db" "SELECT name || ' ON ' || tbl_name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%' ORDER BY tbl_name, name;"
}

cmd_query() {
  local db="$1"
  shift
  local sql="$*"
  check_db "$db"
  
  sqlite3 -header -column "$db" "$sql"
}

cmd_export() {
  local db="$1"
  local source="$2"
  local format="${3:-csv}"
  check_db "$db"
  
  # Determine if source is a table name or SQL query
  local sql
  if [[ "$source" == SELECT* ]] || [[ "$source" == select* ]]; then
    sql="$source"
  else
    sql="SELECT * FROM \"$source\""
  fi
  
  case "$format" in
    csv)
      sqlite3 -header -csv "$db" "$sql"
      ;;
    json)
      sqlite3 -json "$db" "$sql"
      ;;
    sql)
      sqlite3 "$db" ".dump $source"
      ;;
    *)
      log_err "Unknown format: $format (use csv, json, or sql)"
      exit 1
      ;;
  esac
}

cmd_dump_schema() {
  local db="$1"
  check_db "$db"
  sqlite3 "$db" ".schema"
}

cmd_backup() {
  local db="$1"
  local dest="$2"
  local compress="${3:-}"
  check_db "$db"
  
  mkdir -p "$(dirname "$dest")"
  
  if [[ "$compress" == "--compress" ]]; then
    sqlite3 "$db" ".backup '/tmp/sqlite-mgr-backup-$$.db'"
    gzip -c "/tmp/sqlite-mgr-backup-$$.db" > "$dest"
    rm -f "/tmp/sqlite-mgr-backup-$$.db"
    local size=$(du -h "$dest" | cut -f1)
    log_ok "Backup saved: $dest ($size, compressed)"
  else
    sqlite3 "$db" ".backup '$dest'"
    local size=$(du -h "$dest" | cut -f1)
    log_ok "Backup saved: $dest ($size)"
  fi
  
  # Record size history
  mkdir -p "$HISTORY_DIR"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) backup $(du -b "$db" | cut -f1) $dest" >> "$HISTORY_DIR/$(basename "$db").log"
}

cmd_restore() {
  local src="$1"
  local dest="$2"
  local decompress="${3:-}"
  
  if [[ ! -f "$src" ]]; then
    log_err "Backup not found: $src"
    exit 1
  fi
  
  if [[ "$decompress" == "--decompress" ]]; then
    gzip -dc "$src" > "$dest"
  else
    cp "$src" "$dest"
  fi
  
  # Verify restored db
  local check=$(sqlite3 "$dest" "PRAGMA integrity_check;" 2>/dev/null)
  if [[ "$check" == "ok" ]]; then
    log_ok "Restored: $dest (integrity: OK)"
  else
    log_warn "Restored: $dest (integrity check returned: $check)"
  fi
}

cmd_vacuum() {
  local db="$1"
  check_db "$db"
  
  local before=$(du -b "$db" | cut -f1)
  sqlite3 "$db" "VACUUM;"
  local after=$(du -b "$db" | cut -f1)
  local saved=$(( before - after ))
  
  local before_h=$(du -h "$db" | cut -f1)
  if [[ $saved -gt 0 ]]; then
    log_ok "VACUUM: $before_h → $(du -h "$db" | cut -f1) (saved $(numfmt --to=iec $saved 2>/dev/null || echo "${saved}B"))"
  else
    log_ok "VACUUM: $before_h (no space to reclaim)"
  fi
}

cmd_analyze() {
  local db="$1"
  check_db "$db"
  sqlite3 "$db" "ANALYZE;"
  local tables=$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
  log_ok "ANALYZE: Statistics updated for $tables tables"
}

cmd_check() {
  local db="$1"
  check_db "$db"
  
  local result=$(sqlite3 "$db" "PRAGMA integrity_check;")
  if [[ "$result" == "ok" ]]; then
    log_ok "Integrity check: OK"
  else
    log_err "Integrity check FAILED:"
    echo "$result"
    return 1
  fi
}

cmd_optimize() {
  local db="$1"
  check_db "$db"
  
  echo -e "🔧 Optimizing $(basename "$db")..."
  
  # Integrity check
  local check=$(sqlite3 "$db" "PRAGMA integrity_check;")
  if [[ "$check" == "ok" ]]; then
    echo "  $(log_ok "Integrity check: OK")"
  else
    echo "  $(log_err "Integrity check FAILED")"
    echo "  $check"
    return 1
  fi
  
  # Vacuum
  local before=$(du -h "$db" | cut -f1)
  sqlite3 "$db" "VACUUM;"
  local after=$(du -h "$db" | cut -f1)
  echo "  $(log_ok "VACUUM: $before → $after")"
  
  # Analyze
  local tables=$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
  sqlite3 "$db" "ANALYZE;"
  echo "  $(log_ok "ANALYZE: Statistics updated for $tables tables")"
  
  # WAL check
  local journal=$(sqlite3 "$db" "PRAGMA journal_mode;")
  if [[ "$journal" == "wal" ]]; then
    echo "  $(log_ok "WAL mode: already enabled")"
  else
    echo "  $(log_warn "Journal mode: $journal (consider WAL for better concurrency)")"
  fi
  
  echo "Done."
}

cmd_wal() {
  local db="$1"
  local mode="${2:-on}"
  check_db "$db"
  
  if [[ "$mode" == "on" ]]; then
    local result=$(sqlite3 "$db" "PRAGMA journal_mode=WAL;")
    log_ok "Journal mode set to: $result"
  elif [[ "$mode" == "off" ]]; then
    local result=$(sqlite3 "$db" "PRAGMA journal_mode=DELETE;")
    log_ok "Journal mode set to: $result"
  else
    local current=$(sqlite3 "$db" "PRAGMA journal_mode;")
    echo "Current journal mode: $current"
  fi
}

cmd_health() {
  local db="$1"
  check_db "$db"
  
  echo -e "🏥 Health Report: $(basename "$db")"
  echo ""
  
  # Storage
  local size=$(du -h "$db" | cut -f1)
  local page_size=$(sqlite3 "$db" "PRAGMA page_size;")
  local page_count=$(sqlite3 "$db" "PRAGMA page_count;")
  local freelist=$(sqlite3 "$db" "PRAGMA freelist_count;")
  
  echo "Storage:"
  echo "  File size: $size"
  echo "  Freelist pages: $freelist"
  echo "  Page size: $page_size bytes"
  echo "  Total pages: $page_count"
  echo ""
  
  # Performance
  local journal=$(sqlite3 "$db" "PRAGMA journal_mode;")
  local auto_vacuum=$(sqlite3 "$db" "PRAGMA auto_vacuum;")
  local cache_size=$(sqlite3 "$db" "PRAGMA cache_size;")
  
  echo "Performance:"
  if [[ "$journal" == "wal" ]]; then
    echo "  Journal mode: WAL ✅"
  else
    echo "  Journal mode: $journal ⚠️ (consider WAL)"
  fi
  
  case "$auto_vacuum" in
    0) echo "  Auto-vacuum: NONE ⚠️ (consider enabling)" ;;
    1) echo "  Auto-vacuum: FULL ✅" ;;
    2) echo "  Auto-vacuum: INCREMENTAL ✅" ;;
  esac
  
  echo "  Cache size: $cache_size pages"
  echo ""
  
  # Tables
  local table_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
  echo "Tables ($table_count):"
  
  sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;" | while read -r table; do
    local rows=$(sqlite3 "$db" "SELECT COUNT(*) FROM \"$table\";")
    local idx_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND tbl_name='$table' AND name NOT LIKE 'sqlite_%';")
    
    local status="✅"
    if [[ $rows -gt 1000 && $idx_count -eq 0 ]]; then
      status="⚠️ (no indexes, $rows rows)"
    fi
    
    printf "  %-20s — %s rows, %s idx %s\n" "$table" "$rows" "$idx_count" "$status"
  done
  
  echo ""
  
  # Integrity
  local check=$(sqlite3 "$db" "PRAGMA integrity_check;" | head -1)
  if [[ "$check" == "ok" ]]; then
    echo "Integrity: ✅ OK"
  else
    echo "Integrity: ❌ ISSUES FOUND"
    sqlite3 "$db" "PRAGMA integrity_check;" | head -5
  fi
}

cmd_exec() {
  local db="$1"
  local sql_file="$2"
  check_db "$db"
  
  if [[ ! -f "$sql_file" ]]; then
    log_err "SQL file not found: $sql_file"
    exit 1
  fi
  
  sqlite3 "$db" < "$sql_file"
  log_ok "Executed: $sql_file"
}

cmd_diff() {
  local db1="$1"
  local db2="$2"
  check_db "$db1"
  check_db "$db2"
  
  echo -e "${BLUE}📊${NC} Comparing $(basename "$db1") vs $(basename "$db2")"
  echo ""
  
  local tables1=$(sqlite3 "$db1" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;" | sort)
  local tables2=$(sqlite3 "$db2" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;" | sort)
  
  # Tables only in db1
  comm -23 <(echo "$tables1") <(echo "$tables2") | while read -r t; do
    echo "  ➕ Only in $(basename "$db1"): $t"
  done
  
  # Tables only in db2
  comm -13 <(echo "$tables1") <(echo "$tables2") | while read -r t; do
    echo "  ➕ Only in $(basename "$db2"): $t"
  done
  
  # Common tables — compare row counts
  comm -12 <(echo "$tables1") <(echo "$tables2") | while read -r t; do
    local r1=$(sqlite3 "$db1" "SELECT COUNT(*) FROM \"$t\";")
    local r2=$(sqlite3 "$db2" "SELECT COUNT(*) FROM \"$t\";")
    if [[ "$r1" != "$r2" ]]; then
      echo "  📊 $t: $r1 rows vs $r2 rows"
    fi
  done
}

cmd_size_history() {
  local db="$1"
  local logfile="$HISTORY_DIR/$(basename "$db").log"
  
  if [[ ! -f "$logfile" ]]; then
    log_warn "No history found. Run backups to start tracking."
    return
  fi
  
  echo -e "${BLUE}📈${NC} Size history: $(basename "$db")"
  cat "$logfile" | while read -r ts action size rest; do
    echo "  $ts — $(numfmt --to=iec "$size" 2>/dev/null || echo "${size}B")"
  done
}

# --- Main ---

check_sqlite

CMD="${1:-help}"
shift || true

case "$CMD" in
  info)        cmd_info "$@" ;;
  schema)      cmd_schema "$@" ;;
  indexes)     cmd_indexes "$@" ;;
  query)       cmd_query "$@" ;;
  export)      cmd_export "$@" ;;
  dump-schema) cmd_dump_schema "$@" ;;
  backup)      cmd_backup "$@" ;;
  restore)     cmd_restore "$@" ;;
  vacuum)      cmd_vacuum "$@" ;;
  analyze)     cmd_analyze "$@" ;;
  check)       cmd_check "$@" ;;
  optimize)    cmd_optimize "$@" ;;
  wal)         cmd_wal "$@" ;;
  health)      cmd_health "$@" ;;
  exec)        cmd_exec "$@" ;;
  diff)        cmd_diff "$@" ;;
  size-history) cmd_size_history "$@" ;;
  version)     echo "sqlite-mgr $VERSION" ;;
  help|*)
    echo "SQLite Manager v$VERSION"
    echo ""
    echo "Usage: sqlite-mgr.sh <command> <database> [args...]"
    echo ""
    echo "Commands:"
    echo "  info <db>                    Database overview (tables, sizes, indexes)"
    echo "  schema <db> [table]          Show schema (all or specific table)"
    echo "  indexes <db>                 List all indexes"
    echo "  query <db> <sql>             Run SQL query (results in columns)"
    echo "  export <db> <table|sql> <fmt> Export to csv/json/sql"
    echo "  dump-schema <db>             Export full schema as SQL"
    echo "  backup <db> <dest> [--compress]  Hot backup (safe while db in use)"
    echo "  restore <src> <dest> [--decompress]  Restore from backup"
    echo "  vacuum <db>                  Reclaim unused space"
    echo "  analyze <db>                 Update query planner statistics"
    echo "  check <db>                   Run integrity check"
    echo "  optimize <db>                Full optimization (check+vacuum+analyze)"
    echo "  wal <db> [on|off]            Enable/disable WAL mode"
    echo "  health <db>                  Generate health report with recommendations"
    echo "  exec <db> <file.sql>         Execute SQL file"
    echo "  diff <db1> <db2>             Compare two databases"
    echo "  size-history <db>            Show size trends over time"
    echo "  version                      Show version"
    ;;
esac
