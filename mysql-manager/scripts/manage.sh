#!/bin/bash
# MySQL/MariaDB Management Script
set -euo pipefail

MYSQL_CMD="mysql"
MYSQLDUMP_CMD="mysqldump"

# Use env vars or ~/.my.cnf
MYSQL_ARGS=""
[[ -n "${MYSQL_HOST:-}" ]] && MYSQL_ARGS+=" -h $MYSQL_HOST"
[[ -n "${MYSQL_PORT:-}" ]] && MYSQL_ARGS+=" -P $MYSQL_PORT"
[[ -n "${MYSQL_USER:-}" ]] && MYSQL_ARGS+=" -u $MYSQL_USER"
[[ -n "${MYSQL_PASSWORD:-}" ]] && MYSQL_ARGS+=" -p$MYSQL_PASSWORD"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
err() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1" >&2; exit 1; }

run_sql() { $MYSQL_CMD $MYSQL_ARGS -e "$1" 2>/dev/null; }
run_sql_db() { $MYSQL_CMD $MYSQL_ARGS "$1" -e "$2" 2>/dev/null; }

cmd_secure() {
  log "Securing MySQL installation..."
  run_sql "DELETE FROM mysql.user WHERE User='';" || true
  run_sql "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" || true
  run_sql "DROP DATABASE IF EXISTS test;" || true
  run_sql "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" || true
  run_sql "FLUSH PRIVILEGES;"
  log "✅ Secured: removed anonymous users, remote root, test database"
}

cmd_create_db() {
  local db="${1:?Usage: create-db <database>}"
  local charset="${2:-utf8mb4}"
  run_sql "CREATE DATABASE IF NOT EXISTS \`$db\` CHARACTER SET $charset COLLATE ${charset}_unicode_ci;"
  log "✅ Database '$db' created (charset: $charset)"
}

cmd_create_user() {
  local user="${1:?Usage: create-user <user> <password> <database> [--readonly|--full]}"
  local pass="${2:?Password required}"
  local db="${3:?Database required}"
  local mode="${4:---full}"

  run_sql "CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$pass';"

  case "$mode" in
    --readonly)
      run_sql "GRANT SELECT ON \`$db\`.* TO '$user'@'%';"
      log "✅ User '$user' created with READ-ONLY access to '$db'"
      ;;
    --full|*)
      run_sql "GRANT ALL PRIVILEGES ON \`$db\`.* TO '$user'@'%';"
      log "✅ User '$user' created with FULL access to '$db'"
      ;;
  esac
  run_sql "FLUSH PRIVILEGES;"
}

cmd_drop_user() {
  local user="${1:?Usage: drop-user <user>}"
  run_sql "DROP USER IF EXISTS '$user'@'%'; DROP USER IF EXISTS '$user'@'localhost';"
  run_sql "FLUSH PRIVILEGES;"
  log "✅ User '$user' dropped"
}

cmd_reset_password() {
  local user="${1:?Usage: reset-password <user> <new_password>}"
  local pass="${2:?New password required}"
  run_sql "ALTER USER '$user'@'%' IDENTIFIED BY '$pass';" 2>/dev/null || \
  run_sql "SET PASSWORD FOR '$user'@'%' = PASSWORD('$pass');" 2>/dev/null || \
  run_sql "ALTER USER '$user'@'localhost' IDENTIFIED BY '$pass';" 2>/dev/null || \
  run_sql "SET PASSWORD FOR '$user'@'localhost' = PASSWORD('$pass');"
  log "✅ Password reset for '$user'"
}

cmd_reset_root() {
  log "Resetting root password..."
  local new_pass=$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)

  # Stop MySQL, start in safe mode
  sudo systemctl stop mysql 2>/dev/null || sudo systemctl stop mariadb 2>/dev/null || true
  sudo mysqld_safe --skip-grant-tables --skip-networking &
  sleep 3

  mysql -u root -e "FLUSH PRIVILEGES; ALTER USER 'root'@'localhost' IDENTIFIED BY '$new_pass';" 2>/dev/null || \
  mysql -u root -e "FLUSH PRIVILEGES; SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$new_pass');" 2>/dev/null

  # Kill safe mode, restart normally
  sudo killall mysqld mysqld_safe 2>/dev/null || true
  sleep 2
  sudo systemctl start mysql 2>/dev/null || sudo systemctl start mariadb 2>/dev/null

  # Update credentials file
  cat > ~/.my.cnf << EOF
[client]
user=root
password=${new_pass}
EOF
  chmod 600 ~/.my.cnf

  log "✅ Root password reset. New password: $new_pass"
  log "Saved to ~/.my.cnf"
}

cmd_list_users() {
  log "MySQL Users:"
  run_sql "SELECT User, Host, IF(plugin='mysql_native_password' OR plugin='', 'password', plugin) AS auth FROM mysql.user ORDER BY User;" | column -t
}

cmd_list_dbs() {
  log "Databases with sizes:"
  run_sql "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)', COUNT(*) AS 'Tables' FROM information_schema.tables GROUP BY table_schema ORDER BY SUM(data_length + index_length) DESC;" | column -t
}

cmd_table_sizes() {
  local db="${1:?Usage: table-sizes <database>}"
  log "Table sizes in '$db':"
  run_sql "SELECT table_name AS 'Table', ROUND((data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)', table_rows AS 'Rows' FROM information_schema.tables WHERE table_schema='$db' ORDER BY (data_length + index_length) DESC;" | column -t
}

cmd_clone_db() {
  local src="${1:?Usage: clone-db <source> <target>}"
  local dst="${2:?Target database required}"
  log "Cloning '$src' → '$dst'..."
  cmd_create_db "$dst"
  $MYSQLDUMP_CMD $MYSQL_ARGS --single-transaction "$src" | $MYSQL_CMD $MYSQL_ARGS "$dst"
  log "✅ Cloned '$src' → '$dst'"
}

cmd_drop_db() {
  local db="${1:?Usage: drop-db <database>}"
  read -p "⚠️  Drop database '$db'? This is PERMANENT. Type 'yes' to confirm: " confirm
  [[ "$confirm" == "yes" ]] || { log "Cancelled."; exit 0; }
  run_sql "DROP DATABASE IF EXISTS \`$db\`;"
  log "✅ Database '$db' dropped"
}

cmd_run_sql() {
  local db="${1:?Usage: run-sql <database> <file.sql>}"
  local file="${2:?SQL file required}"
  [[ -f "$file" ]] || err "File not found: $file"
  $MYSQL_CMD $MYSQL_ARGS "$db" < "$file"
  log "✅ Executed $file on '$db'"
}

cmd_export_schema() {
  local db="${1:?Usage: export-schema <database>}"
  $MYSQLDUMP_CMD $MYSQL_ARGS --no-data --routines --triggers "$db" 2>/dev/null
}

cmd_import() {
  local db="${1:?Usage: import <database> <file> [--fast]}"
  local file="${2:?File required}"
  local fast="${3:-}"
  [[ -f "$file" ]] || err "File not found: $file"

  if [[ "$fast" == "--fast" ]]; then
    log "Fast import mode (disabled keys, autocommit off)..."
    {
      echo "SET autocommit=0; SET unique_checks=0; SET foreign_key_checks=0;"
      if [[ "$file" == *.gz ]]; then zcat "$file"; else cat "$file"; fi
      echo "SET foreign_key_checks=1; SET unique_checks=1; COMMIT;"
    } | $MYSQL_CMD $MYSQL_ARGS "$db"
  else
    if [[ "$file" == *.gz ]]; then
      if command -v pv &>/dev/null; then
        pv "$file" | zcat | $MYSQL_CMD $MYSQL_ARGS "$db"
      else
        zcat "$file" | $MYSQL_CMD $MYSQL_ARGS "$db"
      fi
    else
      if command -v pv &>/dev/null; then
        pv "$file" | $MYSQL_CMD $MYSQL_ARGS "$db"
      else
        $MYSQL_CMD $MYSQL_ARGS "$db" < "$file"
      fi
    fi
  fi
  log "✅ Imported '$file' → '$db'"
}

cmd_slow_log() {
  local action="${1:?Usage: slow-log enable|disable [--threshold N]}"
  local threshold="${3:-2}"

  case "$action" in
    enable)
      run_sql "SET GLOBAL slow_query_log = 'ON'; SET GLOBAL long_query_time = $threshold;"
      log "✅ Slow query log enabled (threshold: ${threshold}s)"
      ;;
    disable)
      run_sql "SET GLOBAL slow_query_log = 'OFF';"
      log "✅ Slow query log disabled"
      ;;
  esac
}

cmd_replication_primary() {
  local server_id="${2:?Usage: replication-primary --server-id N}"
  log "Configuring as replication primary (server-id: $server_id)..."

  sudo tee -a /etc/mysql/conf.d/replication.cnf > /dev/null << EOF
[mysqld]
server-id = $server_id
log_bin = /var/log/mysql/mysql-bin.log
binlog_do_db = include_database_name
EOF

  sudo systemctl restart mysql 2>/dev/null || sudo systemctl restart mariadb 2>/dev/null
  local repl_pass=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)
  run_sql "CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY '$repl_pass'; GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'; FLUSH PRIVILEGES;"

  log "✅ Primary configured. Replica user: repl / $repl_pass"
  run_sql "SHOW MASTER STATUS\G"
}

# Dispatch
ACTION="${1:-help}"
shift 2>/dev/null || true

case "$ACTION" in
  secure)              cmd_secure ;;
  create-db)           cmd_create_db "$@" ;;
  create-user)         cmd_create_user "$@" ;;
  drop-user)           cmd_drop_user "$@" ;;
  reset-password)      cmd_reset_password "$@" ;;
  reset-root)          cmd_reset_root ;;
  list-users)          cmd_list_users ;;
  list-dbs)            cmd_list_dbs ;;
  table-sizes)         cmd_table_sizes "$@" ;;
  clone-db)            cmd_clone_db "$@" ;;
  drop-db)             cmd_drop_db "$@" ;;
  run-sql)             cmd_run_sql "$@" ;;
  export-schema)       cmd_export_schema "$@" ;;
  import)              cmd_import "$@" ;;
  slow-log)            cmd_slow_log "$@" ;;
  replication-primary) cmd_replication_primary "$@" ;;
  *)
    echo "MySQL Manager — Database Administration Tool"
    echo ""
    echo "Usage: bash manage.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  secure                           Remove test data, anonymous users"
    echo "  create-db <name> [charset]       Create database"
    echo "  create-user <u> <p> <db> [mode]  Create user (--readonly or --full)"
    echo "  drop-user <user>                 Remove user"
    echo "  reset-password <user> <pass>     Change user password"
    echo "  reset-root                       Reset root password (emergency)"
    echo "  list-users                       Show all users"
    echo "  list-dbs                         Show databases with sizes"
    echo "  table-sizes <db>                 Show table sizes"
    echo "  clone-db <src> <dst>             Clone database"
    echo "  drop-db <name>                   Drop database"
    echo "  run-sql <db> <file.sql>          Execute SQL file"
    echo "  export-schema <db>               Export schema (no data)"
    echo "  import <db> <file> [--fast]      Import SQL/gz file"
    echo "  slow-log enable|disable          Manage slow query log"
    echo "  replication-primary --server-id N Configure as replication primary"
    ;;
esac
