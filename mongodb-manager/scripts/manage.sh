#!/bin/bash
# MongoDB Management Script — databases, users, indexes, exports
set -euo pipefail

MONGO_HOST="${MONGO_HOST:-localhost}"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_USER="${MONGO_USER:-}"
MONGO_PASS="${MONGO_PASS:-}"
MONGO_AUTH_DB="${MONGO_AUTH_DB:-admin}"

MONGOSH_OPTS=""
if [[ -n "$MONGO_USER" && -n "$MONGO_PASS" ]]; then
  MONGOSH_OPTS="--host $MONGO_HOST --port $MONGO_PORT -u $MONGO_USER -p $MONGO_PASS --authenticationDatabase $MONGO_AUTH_DB"
else
  MONGOSH_OPTS="--host $MONGO_HOST --port $MONGO_PORT"
fi

run_mongosh() {
  mongosh $MONGOSH_OPTS --quiet --eval "$1" "${2:-}"
}

usage() {
  cat <<EOF
MongoDB Manager — Database & User Management

Usage: $0 <command> [options]

Commands:
  create-db        Create a new database
  drop-db          Drop a database
  list-dbs         List all databases
  create-user      Create a database user
  drop-user        Drop a user
  list-users       List users in a database
  enable-auth      Enable authentication in mongod.conf
  export           Export collection to JSON/CSV
  import           Import data into collection
  indexes          List indexes for a collection
  create-index     Create an index
  drop-index       Drop an index
  init-replica     Initialize replica set
  step-down        Step down primary in replica set

Run '$0 <command> --help' for command-specific options.
EOF
  exit 1
}

cmd_create_db() {
  local DB=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) DB="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$DB" ]] && { echo "❌ --name required"; exit 1; }

  run_mongosh "db.createCollection('_init')" "$DB"
  run_mongosh "db._init.drop()" "$DB"
  echo "✅ Database '$DB' created"
}

cmd_drop_db() {
  local DB=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) DB="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$DB" ]] && { echo "❌ --name required"; exit 1; }

  run_mongosh "db.dropDatabase()" "$DB"
  echo "✅ Database '$DB' dropped"
}

cmd_list_dbs() {
  echo "📊 Databases:"
  run_mongosh "db.adminCommand('listDatabases').databases.forEach(d => print('  ' + d.name.padEnd(20) + ' ' + (d.sizeOnDisk/1024/1024).toFixed(1) + ' MB'))"
}

cmd_create_user() {
  local DB="" USER="" PASS="" ROLE="readWrite"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --db) DB="$2"; shift 2 ;;
      --user) USER="$2"; shift 2 ;;
      --pass) PASS="$2"; shift 2 ;;
      --role) ROLE="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$DB" || -z "$USER" || -z "$PASS" ]] && { echo "❌ --db, --user, --pass required"; exit 1; }

  run_mongosh "db.createUser({user:'$USER',pwd:'$PASS',roles:[{role:'$ROLE',db:'$DB'}]})" "$DB"
  echo "✅ User '$USER' created on '$DB' with role '$ROLE'"
}

cmd_drop_user() {
  local DB="" USER=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --db) DB="$2"; shift 2 ;;
      --user) USER="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$DB" || -z "$USER" ]] && { echo "❌ --db, --user required"; exit 1; }

  run_mongosh "db.dropUser('$USER')" "$DB"
  echo "✅ User '$USER' dropped from '$DB'"
}

cmd_list_users() {
  local DB="${1:-admin}"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --db) DB="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  echo "👥 Users in '$DB':"
  run_mongosh "db.getUsers().users.forEach(u => print('  ' + u.user.padEnd(20) + u.roles.map(r=>r.role).join(', ')))" "$DB"
}

cmd_enable_auth() {
  if grep -q "authorization: enabled" /etc/mongod.conf 2>/dev/null; then
    echo "✅ Authentication already enabled"
  else
    sudo sed -i '/^#security:/c\security:' /etc/mongod.conf
    if ! grep -q "authorization:" /etc/mongod.conf; then
      sudo sed -i '/^security:/a\  authorization: enabled' /etc/mongod.conf
    fi
    echo "✅ Authentication enabled. Restart MongoDB: sudo systemctl restart mongod"
  fi
}

cmd_export() {
  local DB="" COLLECTION="" OUTPUT="" CSV=false FIELDS=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --db) DB="$2"; shift 2 ;;
      --collection) COLLECTION="$2"; shift 2 ;;
      --output) OUTPUT="$2"; shift 2 ;;
      --csv) CSV=true; shift ;;
      --fields) FIELDS="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$DB" || -z "$COLLECTION" || -z "$OUTPUT" ]] && { echo "❌ --db, --collection, --output required"; exit 1; }

  EXPORT_OPTS="--host=$MONGO_HOST --port=$MONGO_PORT --db=$DB --collection=$COLLECTION --out=$OUTPUT"
  [[ -n "$MONGO_USER" ]] && EXPORT_OPTS="$EXPORT_OPTS -u=$MONGO_USER -p=$MONGO_PASS --authenticationDatabase=$MONGO_AUTH_DB"
  [[ "$CSV" == true ]] && EXPORT_OPTS="$EXPORT_OPTS --type=csv --fields=$FIELDS"

  mongoexport $EXPORT_OPTS
  echo "✅ Exported $DB.$COLLECTION → $OUTPUT"
}

cmd_import() {
  local DB="" COLLECTION="" INPUT="" CSV=false HEADERLINE=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --db) DB="$2"; shift 2 ;;
      --collection) COLLECTION="$2"; shift 2 ;;
      --input) INPUT="$2"; shift 2 ;;
      --csv) CSV=true; shift ;;
      --headerline) HEADERLINE=true; shift ;;
      *) shift ;;
    esac
  done
  [[ -z "$DB" || -z "$COLLECTION" || -z "$INPUT" ]] && { echo "❌ --db, --collection, --input required"; exit 1; }

  IMPORT_OPTS="--host=$MONGO_HOST --port=$MONGO_PORT --db=$DB --collection=$COLLECTION --file=$INPUT"
  [[ -n "$MONGO_USER" ]] && IMPORT_OPTS="$IMPORT_OPTS -u=$MONGO_USER -p=$MONGO_PASS --authenticationDatabase=$MONGO_AUTH_DB"
  [[ "$CSV" == true ]] && IMPORT_OPTS="$IMPORT_OPTS --type=csv"
  [[ "$HEADERLINE" == true ]] && IMPORT_OPTS="$IMPORT_OPTS --headerline"

  mongoimport $IMPORT_OPTS
  echo "✅ Imported $INPUT → $DB.$COLLECTION"
}

cmd_indexes() {
  local DB="" COLLECTION=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --db) DB="$2"; shift 2 ;;
      --collection) COLLECTION="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$DB" || -z "$COLLECTION" ]] && { echo "❌ --db, --collection required"; exit 1; }

  echo "📇 Indexes on $DB.$COLLECTION:"
  run_mongosh "db.$COLLECTION.getIndexes().forEach(i => print('  ' + i.name.padEnd(30) + JSON.stringify(i.key)))" "$DB"
}

cmd_create_index() {
  local DB="" COLLECTION="" FIELD="" FIELDS="" UNIQUE=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --db) DB="$2"; shift 2 ;;
      --collection) COLLECTION="$2"; shift 2 ;;
      --field) FIELD="$2"; shift 2 ;;
      --fields) FIELDS="$2"; shift 2 ;;
      --unique) UNIQUE=true; shift ;;
      *) shift ;;
    esac
  done
  [[ -z "$DB" || -z "$COLLECTION" ]] && { echo "❌ --db, --collection required"; exit 1; }

  local KEY_SPEC
  if [[ -n "$FIELD" ]]; then
    KEY_SPEC="{\"$FIELD\":1}"
  elif [[ -n "$FIELDS" ]]; then
    KEY_SPEC="$FIELDS"
  else
    echo "❌ --field or --fields required"; exit 1
  fi

  local OPTS="{}"
  [[ "$UNIQUE" == true ]] && OPTS="{unique:true}"

  run_mongosh "db.$COLLECTION.createIndex($KEY_SPEC, $OPTS)" "$DB"
  echo "✅ Index created on $DB.$COLLECTION: $KEY_SPEC"
}

cmd_drop_index() {
  local DB="" COLLECTION="" INDEX=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --db) DB="$2"; shift 2 ;;
      --collection) COLLECTION="$2"; shift 2 ;;
      --index) INDEX="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$DB" || -z "$COLLECTION" || -z "$INDEX" ]] && { echo "❌ --db, --collection, --index required"; exit 1; }

  run_mongosh "db.$COLLECTION.dropIndex('$INDEX')" "$DB"
  echo "✅ Index '$INDEX' dropped from $DB.$COLLECTION"
}

cmd_init_replica() {
  local NAME="" MEMBERS=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) NAME="$2"; shift 2 ;;
      --members) MEMBERS="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$NAME" || -z "$MEMBERS" ]] && { echo "❌ --name, --members required"; exit 1; }

  # Build members array
  IFS=',' read -ra HOSTS <<< "$MEMBERS"
  local MEMBER_JS="["
  for i in "${!HOSTS[@]}"; do
    [[ $i -gt 0 ]] && MEMBER_JS+=","
    MEMBER_JS+="{_id:$i,host:\"${HOSTS[$i]}\"}"
  done
  MEMBER_JS+="]"

  run_mongosh "rs.initiate({_id:'$NAME',members:$MEMBER_JS})"
  echo "✅ Replica set '$NAME' initialized with ${#HOSTS[@]} members"
}

cmd_step_down() {
  run_mongosh "rs.stepDown()"
  echo "✅ Primary stepped down"
}

# Route command
COMMAND="${1:-}"
shift || true

case "$COMMAND" in
  create-db)    cmd_create_db "$@" ;;
  drop-db)      cmd_drop_db "$@" ;;
  list-dbs)     cmd_list_dbs "$@" ;;
  create-user)  cmd_create_user "$@" ;;
  drop-user)    cmd_drop_user "$@" ;;
  list-users)   cmd_list_users "$@" ;;
  enable-auth)  cmd_enable_auth ;;
  export)       cmd_export "$@" ;;
  import)       cmd_import "$@" ;;
  indexes)      cmd_indexes "$@" ;;
  create-index) cmd_create_index "$@" ;;
  drop-index)   cmd_drop_index "$@" ;;
  init-replica) cmd_init_replica "$@" ;;
  step-down)    cmd_step_down ;;
  *) usage ;;
esac
