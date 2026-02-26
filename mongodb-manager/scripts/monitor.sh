#!/bin/bash
# MongoDB Monitoring Script
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
  mongosh $MONGOSH_OPTS --quiet --eval "$1" "${2:-}" 2>/dev/null
}

usage() {
  cat <<EOF
MongoDB Monitor

Usage: $0 <command> [options]

Commands:
  status          Quick server status overview
  live            Live monitoring (refreshes periodically)
  connections     Show connection details
  slow-queries    Show slow queries
  disk-usage      Show disk usage per database
  replica-status  Show replica set status

Options:
  --interval N      Refresh interval in seconds (for live, default: 5)
  --threshold N     Slow query threshold in ms (default: 100)
EOF
  exit 1
}

cmd_status() {
  # Check if MongoDB is running
  if ! mongosh $MONGOSH_OPTS --quiet --eval "db.runCommand({ping:1})" &>/dev/null; then
    echo "❌ MongoDB is not running or not reachable at $MONGO_HOST:$MONGO_PORT"
    exit 1
  fi

  local VERSION=$(run_mongosh "db.version()")
  local PID=$(run_mongosh "db.serverStatus().pid")
  local UPTIME=$(run_mongosh "
    var s = db.serverStatus().uptime;
    var d = Math.floor(s/86400);
    var h = Math.floor((s%86400)/3600);
    var m = Math.floor((s%3600)/60);
    print((d>0?d+'d ':'') + h+'h ' + m+'m');
  ")
  local CONNECTIONS=$(run_mongosh "
    var s = db.serverStatus().connections;
    print(s.current + '/' + s.available);
  ")
  local MEMORY=$(run_mongosh "
    var m = db.serverStatus().mem;
    print(m.resident + 'MB');
  ")
  local DBS=$(run_mongosh "db.adminCommand('listDatabases').databases.length")
  local DATA_SIZE=$(run_mongosh "
    var total = 0;
    db.adminCommand('listDatabases').databases.forEach(d => total += d.sizeOnDisk);
    print((total/1024/1024/1024).toFixed(2) + 'GB');
  ")

  echo "✅ MongoDB $VERSION running (PID $PID)"
  echo "📊 Connections: $CONNECTIONS | Memory: $MEMORY | Uptime: $UPTIME"
  echo "💾 Databases: $DBS | Data Size: $DATA_SIZE"
  echo ""

  # Per-database breakdown
  echo "📁 Databases:"
  run_mongosh "
    db.adminCommand('listDatabases').databases.forEach(d => {
      var size = (d.sizeOnDisk/1024/1024).toFixed(1);
      print('   ' + d.name.padEnd(25) + size.padStart(8) + ' MB');
    });
  "
}

cmd_live() {
  local INTERVAL=5
  while [[ $# -gt 0 ]]; do
    case $1 in
      --interval) INTERVAL="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  echo "🔴 Live monitoring (every ${INTERVAL}s, Ctrl+C to stop)"
  echo ""

  while true; do
    clear
    echo "═══════════════════════════════════════════════════"
    echo "  MongoDB Monitor — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "═══════════════════════════════════════════════════"
    run_mongosh "
      var ss = db.serverStatus();
      var conn = ss.connections;
      var mem = ss.mem;
      var ops = ss.opcounters;
      var up = ss.uptime;
      var d = Math.floor(up/86400);
      var h = Math.floor((up%86400)/3600);
      
      print('');
      print('  Connections:  ' + conn.current + ' active / ' + conn.available + ' available');
      print('  Memory:       ' + mem.resident + ' MB resident / ' + mem.virtual + ' MB virtual');
      print('  Uptime:       ' + d + 'd ' + h + 'h');
      print('');
      print('  Operations (total):');
      print('    Insert:  ' + ops.insert);
      print('    Query:   ' + ops.query);
      print('    Update:  ' + ops.update);
      print('    Delete:  ' + ops.delete);
      print('    Command: ' + ops.command);
      print('');
      
      var dbs = db.adminCommand('listDatabases').databases;
      var total = 0;
      print('  Databases:');
      dbs.forEach(d => {
        total += d.sizeOnDisk;
        print('    ' + d.name.padEnd(20) + (d.sizeOnDisk/1024/1024).toFixed(1).padStart(8) + ' MB');
      });
      print('    ' + '─'.repeat(30));
      print('    ' + 'TOTAL'.padEnd(20) + (total/1024/1024).toFixed(1).padStart(8) + ' MB');
    "
    sleep "$INTERVAL"
  done
}

cmd_connections() {
  echo "🔌 Connection Details:"
  run_mongosh "
    var ss = db.serverStatus().connections;
    print('  Current:    ' + ss.current);
    print('  Available:  ' + ss.available);
    print('  Total created: ' + ss.totalCreated);
    print('');
    
    // Current operations
    var ops = db.currentOp().inprog;
    print('  Active operations: ' + ops.length);
    ops.slice(0, 10).forEach(op => {
      if (op.op !== 'none') {
        print('    [' + op.op + '] ' + (op.ns || 'N/A') + ' — ' + (op.secs_running || 0) + 's');
      }
    });
  "
}

cmd_slow_queries() {
  local THRESHOLD=100
  while [[ $# -gt 0 ]]; do
    case $1 in
      --threshold) THRESHOLD="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  echo "🐌 Slow queries (>${THRESHOLD}ms):"
  run_mongosh "
    // Check if profiling is enabled
    var level = db.getProfilingLevel();
    if (level === 0) {
      print('  ⚠️ Profiling is OFF. Enable with: db.setProfilingLevel(1, {slowms: $THRESHOLD})');
      print('  Checking system.profile for any existing data...');
    }
    
    var queries = db.system.profile.find({millis: {\$gte: $THRESHOLD}}).sort({ts: -1}).limit(10).toArray();
    if (queries.length === 0) {
      print('  No slow queries found.');
    } else {
      queries.forEach(q => {
        print('  [' + q.ts.toISOString() + '] ' + q.op + ' ' + q.ns + ' — ' + q.millis + 'ms');
        if (q.command) print('    ' + JSON.stringify(q.command).substring(0, 120));
      });
    }
  "
}

cmd_disk_usage() {
  echo "💾 Disk Usage:"
  run_mongosh "
    var dbs = db.adminCommand('listDatabases').databases;
    dbs.sort((a,b) => b.sizeOnDisk - a.sizeOnDisk);
    
    var total = 0;
    dbs.forEach(d => {
      total += d.sizeOnDisk;
      var mb = (d.sizeOnDisk/1024/1024).toFixed(1);
      var bar = '█'.repeat(Math.min(40, Math.ceil(d.sizeOnDisk / (dbs[0].sizeOnDisk || 1) * 40)));
      print('  ' + d.name.padEnd(20) + mb.padStart(8) + ' MB  ' + bar);
    });
    print('  ' + '─'.repeat(50));
    print('  ' + 'TOTAL'.padEnd(20) + (total/1024/1024).toFixed(1).padStart(8) + ' MB');
  "
}

cmd_replica_status() {
  echo "🔗 Replica Set Status:"
  run_mongosh "
    try {
      var rs_status = rs.status();
      print('  Set: ' + rs_status.set);
      print('  Members:');
      rs_status.members.forEach(m => {
        var state = m.stateStr;
        var icon = state === 'PRIMARY' ? '👑' : state === 'SECONDARY' ? '📋' : '⚠️';
        print('    ' + icon + ' ' + m.name.padEnd(25) + state.padEnd(12) + ' health: ' + (m.health === 1 ? '✅' : '❌'));
      });
    } catch(e) {
      print('  ⚠️ Not a replica set member: ' + e.message);
    }
  "
}

# Route
COMMAND="${1:-}"
shift || true

case "$COMMAND" in
  status)         cmd_status ;;
  live)           cmd_live "$@" ;;
  connections)    cmd_connections ;;
  slow-queries)   cmd_slow_queries "$@" ;;
  disk-usage)     cmd_disk_usage ;;
  replica-status) cmd_replica_status ;;
  *) usage ;;
esac
