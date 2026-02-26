#!/bin/bash
# Time Tracker — Main CLI
# Usage: bash tt.sh <command> [args]
set -e

DB_FILE="${TT_DB:-$HOME/.timetracker/tt.db}"

if [ ! -f "$DB_FILE" ]; then
  echo "❌ Database not found. Run: bash scripts/install.sh"
  exit 1
fi

CURRENCY="${TT_CURRENCY:-\$}"
DEFAULT_RATE="${TT_DEFAULT_RATE:-0}"

# ─── Helpers ──────────────────────────────────────────

format_duration() {
  local secs=$1
  local hours=$((secs / 3600))
  local mins=$(( (secs % 3600) / 60 ))
  printf "%dh %02dm" "$hours" "$mins"
}

parse_duration() {
  # Parse formats: 1h30m, 45m, 2h, 90 (minutes)
  local input="$1"
  local total=0
  if [[ "$input" =~ ([0-9]+)h ]]; then
    total=$(( total + ${BASH_REMATCH[1]} * 3600 ))
  fi
  if [[ "$input" =~ ([0-9]+)m ]]; then
    total=$(( total + ${BASH_REMATCH[1]} * 60 ))
  fi
  if [[ "$total" -eq 0 && "$input" =~ ^[0-9]+$ ]]; then
    total=$(( input * 60 ))
  fi
  echo "$total"
}

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

today_start() {
  date -u +"%Y-%m-%dT00:00:00Z"
}

yesterday_start() {
  date -u -d "yesterday" +"%Y-%m-%dT00:00:00Z" 2>/dev/null || date -u -v-1d +"%Y-%m-%dT00:00:00Z"
}

week_start() {
  # Monday of current week
  local dow=$(date -u +%u)
  local offset=$(( dow - 1 ))
  date -u -d "$offset days ago" +"%Y-%m-%dT00:00:00Z" 2>/dev/null || date -u -v-${offset}d +"%Y-%m-%dT00:00:00Z"
}

month_start() {
  date -u +"%Y-%m-01T00:00:00Z"
}

# ─── Commands ─────────────────────────────────────────

cmd_start() {
  local desc=""
  local project=""
  local client=""
  local tags=""
  local rate="$DEFAULT_RATE"

  # Check if timer already running
  local active=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM active_timer;")
  if [ "$active" -gt 0 ]; then
    local running=$(sqlite3 "$DB_FILE" "SELECT e.description FROM active_timer a JOIN entries e ON a.entry_id = e.id;")
    echo "⚠️  Timer already running: \"$running\""
    echo "   Stop it first: tt.sh stop"
    exit 1
  fi

  # Parse args
  desc="$1"; shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project|-p) project="$2"; shift 2 ;;
      --client|-c) client="$2"; shift 2 ;;
      --tag|-t) tags="${tags:+$tags,}$2"; shift 2 ;;
      --rate|-r) rate="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$desc" ]; then
    echo "❌ Usage: tt.sh start \"description\" [--project NAME] [--client NAME] [--rate N]"
    exit 1
  fi

  local started=$(now_iso)
  sqlite3 "$DB_FILE" <<EOSQL
INSERT INTO entries (description, project, client, tags, rate, started_at) VALUES ('$(echo "$desc" | sed "s/'/''/g")', '$(echo "$project" | sed "s/'/''/g")', '$(echo "$client" | sed "s/'/''/g")', '$tags', $rate, '$started');
INSERT OR REPLACE INTO active_timer (id, entry_id) VALUES (1, last_insert_rowid());
EOSQL

  echo "⏱️  Started: \"$desc\""
  [ -n "$project" ] && echo "   Project: $project"
  [ -n "$client" ] && echo "   Client: $client"
  [ "$rate" != "0" ] && echo "   Rate: ${CURRENCY}${rate}/hr"
}

cmd_stop() {
  local active=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM active_timer;")
  if [ "$active" -eq 0 ]; then
    echo "❌ No active timer. Start one: tt.sh start \"description\""
    exit 1
  fi

  local entry_id=$(sqlite3 "$DB_FILE" "SELECT entry_id FROM active_timer WHERE id = 1;")
  local stopped=$(now_iso)
  local started=$(sqlite3 "$DB_FILE" "SELECT started_at FROM entries WHERE id = $entry_id;")

  # Calculate duration
  local start_epoch=$(date -d "$started" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started" +%s)
  local stop_epoch=$(date -d "$stopped" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$stopped" +%s)
  local duration=$(( stop_epoch - start_epoch ))

  sqlite3 "$DB_FILE" "UPDATE entries SET stopped_at = '$stopped', duration_seconds = $duration WHERE id = $entry_id;"
  sqlite3 "$DB_FILE" "DELETE FROM active_timer WHERE id = 1;"

  local desc=$(sqlite3 "$DB_FILE" "SELECT description FROM entries WHERE id = $entry_id;")
  local project=$(sqlite3 "$DB_FILE" "SELECT project FROM entries WHERE id = $entry_id;")
  local client=$(sqlite3 "$DB_FILE" "SELECT client FROM entries WHERE id = $entry_id;")

  local fmt=$(format_duration $duration)
  echo "✅ Stopped: \"$desc\" — $fmt"
  [ -n "$project" ] && echo "   Project: $project"
  [ -n "$client" ] && echo "   Client: $client"
}

cmd_status() {
  local active=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM active_timer;")
  if [ "$active" -eq 0 ]; then
    echo "💤 No active timer"
    return
  fi

  local entry_id=$(sqlite3 "$DB_FILE" "SELECT entry_id FROM active_timer WHERE id = 1;")
  local info=$(sqlite3 -separator '|' "$DB_FILE" "SELECT description, project, client, started_at FROM entries WHERE id = $entry_id;")

  IFS='|' read -r desc project client started <<< "$info"
  local start_epoch=$(date -d "$started" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started" +%s)
  local now_epoch=$(date +%s)
  local elapsed=$(( now_epoch - start_epoch ))
  local fmt=$(format_duration $elapsed)

  echo "⏱️  Running: \"$desc\" — $fmt"
  [ -n "$project" ] && echo "   Project: $project"
  [ -n "$client" ] && echo "   Client: $client"
  echo "   Started: $started"
}

cmd_add() {
  local desc=""
  local project=""
  local client=""
  local tags=""
  local rate="$DEFAULT_RATE"
  local duration_str=""

  desc="$1"; shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project|-p) project="$2"; shift 2 ;;
      --client|-c) client="$2"; shift 2 ;;
      --tag|-t) tags="${tags:+$tags,}$2"; shift 2 ;;
      --rate|-r) rate="$2"; shift 2 ;;
      --duration|-d) duration_str="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$desc" ] || [ -z "$duration_str" ]; then
    echo "❌ Usage: tt.sh add \"description\" --duration 1h30m [--project NAME]"
    exit 1
  fi

  local duration_secs=$(parse_duration "$duration_str")
  local stopped=$(now_iso)
  local start_epoch=$(( $(date +%s) - duration_secs ))
  local started=$(date -u -d "@$start_epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -r "$start_epoch" +"%Y-%m-%dT%H:%M:%SZ")

  sqlite3 "$DB_FILE" "INSERT INTO entries (description, project, client, tags, rate, started_at, stopped_at, duration_seconds) VALUES ('$(echo "$desc" | sed "s/'/''/g")', '$(echo "$project" | sed "s/'/''/g")', '$(echo "$client" | sed "s/'/''/g")', '$tags', $rate, '$started', '$stopped', $duration_secs);"

  local fmt=$(format_duration $duration_secs)
  echo "✅ Added: \"$desc\" — $fmt"
  [ -n "$project" ] && echo "   Project: $project"
}

cmd_report() {
  local period="${1:-today}"
  local from_date=""
  local to_date=$(now_iso)
  local project_filter=""
  local client_filter=""

  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) from_date="${2}T00:00:00Z"; shift 2 ;;
      --to) to_date="${2}T23:59:59Z"; shift 2 ;;
      --project|-p) project_filter="$2"; shift 2 ;;
      --client|-c) client_filter="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  # Set date range from period
  case "$period" in
    today) from_date=$(today_start) ;;
    yesterday) from_date=$(yesterday_start); to_date=$(today_start) ;;
    week) from_date=$(week_start) ;;
    month) from_date=$(month_start) ;;
    custom) ;; # from/to already set
  esac

  local where="WHERE started_at >= '$from_date' AND started_at <= '$to_date' AND stopped_at IS NOT NULL"
  [ -n "$project_filter" ] && where="$where AND project = '$project_filter'"
  [ -n "$client_filter" ] && where="$where AND client = '$client_filter'"

  local title=""
  case "$period" in
    today) title="Today — $(date -u +%b\ %d,\ %Y)" ;;
    yesterday) title="Yesterday" ;;
    week) title="This Week" ;;
    month) title="This Month" ;;
    *) title="Report" ;;
  esac

  echo "📊 $title"
  [ -n "$project_filter" ] && echo "   Project: $project_filter"
  [ -n "$client_filter" ] && echo "   Client: $client_filter"
  echo "─────────────────────────────────────────"

  sqlite3 -separator '|' "$DB_FILE" "SELECT description, project, tags, duration_seconds FROM entries $where ORDER BY started_at;" | while IFS='|' read -r desc proj tgs dur; do
    local fmt=$(format_duration "$dur")
    local extra=""
    [ -n "$proj" ] && extra="  $proj"
    [ -n "$tgs" ] && extra="$extra  [$tgs]"
    printf "  %-30s %8s%s\n" "$desc" "$fmt" "$extra"
  done

  local total=$(sqlite3 "$DB_FILE" "SELECT COALESCE(SUM(duration_seconds), 0) FROM entries $where;")
  echo "─────────────────────────────────────────"
  echo "  Total: $(format_duration $total)"
}

cmd_invoice() {
  local client=""
  local from_date=$(month_start)
  local to_date=$(now_iso)

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --client|-c) client="$2"; shift 2 ;;
      --from) from_date="${2}T00:00:00Z"; shift 2 ;;
      --to) to_date="${2}T23:59:59Z"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$client" ]; then
    echo "❌ Usage: tt.sh invoice --client \"Client Name\" [--from DATE] [--to DATE]"
    exit 1
  fi

  local where="WHERE client = '$client' AND started_at >= '$from_date' AND started_at <= '$to_date' AND stopped_at IS NOT NULL"

  local from_display=$(echo "$from_date" | cut -c1-10)
  local to_display=$(echo "$to_date" | cut -c1-10)

  echo "┌─────────────────────────────────────────────────┐"
  printf "│  INVOICE — %-37s│\n" "$client"
  printf "│  Period: %-39s│\n" "$from_display to $to_display"
  echo "├─────────────────────────────────────────────────┤"

  local grand_total_secs=0
  local grand_total_amount="0"

  sqlite3 -separator '|' "$DB_FILE" "SELECT description, SUM(duration_seconds), rate FROM entries $where GROUP BY description, rate ORDER BY SUM(duration_seconds) DESC;" | while IFS='|' read -r desc dur rate; do
    local fmt=$(format_duration "$dur")
    local amount="0.00"
    if [ "$(echo "$rate > 0" | bc)" -eq 1 ]; then
      local hours=$(echo "scale=2; $dur / 3600" | bc)
      amount=$(echo "scale=2; $hours * $rate" | bc)
    fi
    printf "│  %-26s %8s  %s%8s│\n" "$desc" "$fmt" "$CURRENCY" "$amount"
  done

  local total_secs=$(sqlite3 "$DB_FILE" "SELECT COALESCE(SUM(duration_seconds), 0) FROM entries $where;")
  local total_amount=$(sqlite3 "$DB_FILE" "SELECT COALESCE(SUM(CAST(duration_seconds AS REAL) / 3600.0 * rate), 0) FROM entries $where;")
  total_amount=$(printf "%.2f" "$total_amount")

  echo "├─────────────────────────────────────────────────┤"
  printf "│  TOTAL %27s  %s%8s│\n" "$(format_duration $total_secs)" "$CURRENCY" "$total_amount"
  echo "└─────────────────────────────────────────────────┘"
}

cmd_list() {
  local limit="${1:-20}"
  echo "📋 Recent entries (last $limit):"
  echo "─────────────────────────────────────────"
  sqlite3 -separator '|' "$DB_FILE" "SELECT id, description, project, duration_seconds, date(started_at) FROM entries WHERE stopped_at IS NOT NULL ORDER BY started_at DESC LIMIT $limit;" | while IFS='|' read -r id desc proj dur dt; do
    local fmt=$(format_duration "$dur")
    printf "  #%-4d %-25s %8s  %s  %s\n" "$id" "$desc" "$fmt" "${proj:-—}" "$dt"
  done
}

cmd_delete() {
  local id="$1"
  if [ -z "$id" ]; then
    echo "❌ Usage: tt.sh delete <ID>"
    exit 1
  fi
  sqlite3 "$DB_FILE" "DELETE FROM entries WHERE id = $id;"
  echo "🗑️  Deleted entry #$id"
}

cmd_projects() {
  echo "📁 Projects:"
  sqlite3 -separator '|' "$DB_FILE" "SELECT project, COUNT(*), SUM(duration_seconds) FROM entries WHERE project != '' AND stopped_at IS NOT NULL GROUP BY project ORDER BY SUM(duration_seconds) DESC;" | while IFS='|' read -r proj count dur; do
    printf "  %-20s %3d entries  %s\n" "$proj" "$count" "$(format_duration $dur)"
  done
}

cmd_clients() {
  echo "👥 Clients:"
  sqlite3 -separator '|' "$DB_FILE" "SELECT client, COUNT(*), SUM(duration_seconds), rate FROM entries WHERE client != '' AND stopped_at IS NOT NULL GROUP BY client ORDER BY SUM(duration_seconds) DESC;" | while IFS='|' read -r cl count dur rate; do
    printf "  %-20s %3d entries  %s" "$cl" "$count" "$(format_duration $dur)"
    [ "$(echo "$rate > 0" | bc)" -eq 1 ] && printf "  @${CURRENCY}%s/hr" "$rate"
    echo
  done
}

cmd_export() {
  local format="${1:-csv}"
  shift || true
  local from_date=""
  local to_date=""
  local client_filter=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) from_date="${2}T00:00:00Z"; shift 2 ;;
      --to) to_date="${2}T23:59:59Z"; shift 2 ;;
      --client|-c) client_filter="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local where="WHERE stopped_at IS NOT NULL"
  [ -n "$from_date" ] && where="$where AND started_at >= '$from_date'"
  [ -n "$to_date" ] && where="$where AND started_at <= '$to_date'"
  [ -n "$client_filter" ] && where="$where AND client = '$client_filter'"

  case "$format" in
    csv)
      echo "id,description,project,client,tags,rate,started_at,stopped_at,duration_seconds,duration_hours"
      sqlite3 -separator ',' "$DB_FILE" "SELECT id, description, project, client, tags, rate, started_at, stopped_at, duration_seconds, ROUND(CAST(duration_seconds AS REAL)/3600, 2) FROM entries $where ORDER BY started_at;"
      ;;
    json)
      sqlite3 -json "$DB_FILE" "SELECT id, description, project, client, tags, rate, started_at, stopped_at, duration_seconds, ROUND(CAST(duration_seconds AS REAL)/3600, 2) as duration_hours FROM entries $where ORDER BY started_at;"
      ;;
    *)
      echo "❌ Unknown format: $format (use csv or json)"
      exit 1
      ;;
  esac
}

# ─── Router ───────────────────────────────────────────

CMD="${1:-help}"
shift || true

case "$CMD" in
  start)    cmd_start "$@" ;;
  stop)     cmd_stop "$@" ;;
  status)   cmd_status "$@" ;;
  add)      cmd_add "$@" ;;
  report)   cmd_report "$@" ;;
  invoice)  cmd_invoice "$@" ;;
  list)     cmd_list "$@" ;;
  delete)   cmd_delete "$@" ;;
  projects) cmd_projects "$@" ;;
  clients)  cmd_clients "$@" ;;
  export)   cmd_export "$@" ;;
  help|--help|-h)
    echo "🕐 Time Tracker"
    echo ""
    echo "Commands:"
    echo "  start \"desc\"    Start a timer"
    echo "  stop            Stop running timer"
    echo "  status          Show active timer"
    echo "  add \"desc\"      Add completed entry (--duration required)"
    echo "  report [period] Show report (today/yesterday/week/month)"
    echo "  invoice         Generate invoice (--client required)"
    echo "  list [N]        List recent entries"
    echo "  delete ID       Delete an entry"
    echo "  projects        List projects"
    echo "  clients         List clients"
    echo "  export csv|json Export data"
    echo ""
    echo "Options:"
    echo "  --project, -p   Project name"
    echo "  --client, -c    Client name"
    echo "  --tag, -t       Tag (repeatable)"
    echo "  --rate, -r      Hourly rate"
    echo "  --duration, -d  Duration (1h30m, 45m, 2h)"
    echo "  --from DATE     Start date (YYYY-MM-DD)"
    echo "  --to DATE       End date (YYYY-MM-DD)"
    ;;
  *)
    echo "❌ Unknown command: $CMD"
    echo "   Run: tt.sh help"
    exit 1
    ;;
esac
