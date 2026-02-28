#!/bin/bash
# Habit Tracker — Track daily habits with streaks, stats, and reports
# Requires: bash 4+, sqlite3
# Storage: ~/.habit-tracker/habits.db

set -euo pipefail

DB_DIR="${HABIT_TRACKER_DIR:-$HOME/.habit-tracker}"
DB_FILE="$DB_DIR/habits.db"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

init_db() {
  mkdir -p "$DB_DIR"
  sqlite3 "$DB_FILE" <<'SQL'
CREATE TABLE IF NOT EXISTS habits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE NOT NULL,
  description TEXT DEFAULT '',
  frequency TEXT DEFAULT 'daily',
  created_at TEXT DEFAULT (datetime('now')),
  archived INTEGER DEFAULT 0
);
CREATE TABLE IF NOT EXISTS completions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  habit_id INTEGER NOT NULL,
  completed_date TEXT NOT NULL,
  note TEXT DEFAULT '',
  created_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY (habit_id) REFERENCES habits(id),
  UNIQUE(habit_id, completed_date)
);
CREATE INDEX IF NOT EXISTS idx_completions_date ON completions(completed_date);
CREATE INDEX IF NOT EXISTS idx_completions_habit ON completions(habit_id);
SQL
}

cmd_add() {
  local name="$1"
  local desc="${2:-}"
  local freq="${3:-daily}"
  
  if sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM habits WHERE name='$name' AND archived=0;" | grep -q '^0$'; then
    sqlite3 "$DB_FILE" "INSERT INTO habits (name, description, frequency) VALUES ('$name', '$desc', '$freq');"
    echo -e "${GREEN}✅ Added habit:${NC} $name ($freq)"
  else
    echo -e "${YELLOW}⚠️  Habit '$name' already exists${NC}"
    return 1
  fi
}

cmd_done() {
  local name="$1"
  local date="${2:-$(date +%Y-%m-%d)}"
  local note="${3:-}"
  
  local habit_id
  habit_id=$(sqlite3 "$DB_FILE" "SELECT id FROM habits WHERE name='$name' AND archived=0;")
  
  if [ -z "$habit_id" ]; then
    echo -e "${RED}❌ Habit '$name' not found${NC}"
    return 1
  fi
  
  if sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM completions WHERE habit_id=$habit_id AND completed_date='$date';" | grep -q '^0$'; then
    sqlite3 "$DB_FILE" "INSERT INTO completions (habit_id, completed_date, note) VALUES ($habit_id, '$date', '$note');"
    local streak
    streak=$(get_streak "$habit_id")
    echo -e "${GREEN}✅ Done:${NC} $name ${DIM}($date)${NC} 🔥 Streak: $streak days"
  else
    echo -e "${YELLOW}⚠️  Already completed '$name' for $date${NC}"
  fi
}

cmd_undo() {
  local name="$1"
  local date="${2:-$(date +%Y-%m-%d)}"
  
  local habit_id
  habit_id=$(sqlite3 "$DB_FILE" "SELECT id FROM habits WHERE name='$name' AND archived=0;")
  
  if [ -z "$habit_id" ]; then
    echo -e "${RED}❌ Habit '$name' not found${NC}"
    return 1
  fi
  
  sqlite3 "$DB_FILE" "DELETE FROM completions WHERE habit_id=$habit_id AND completed_date='$date';"
  echo -e "${YELLOW}↩️  Undone:${NC} $name for $date"
}

get_streak() {
  local habit_id="$1"
  local today
  today=$(date +%Y-%m-%d)
  
  sqlite3 "$DB_FILE" <<SQL
WITH RECURSIVE dates AS (
  SELECT '$today' as d, 0 as n
  UNION ALL
  SELECT date(d, '-1 day'), n+1 FROM dates
  WHERE EXISTS (
    SELECT 1 FROM completions 
    WHERE habit_id=$habit_id AND completed_date=date(d, '-1 day')
  )
  AND n < 3650
)
SELECT CASE 
  WHEN EXISTS (SELECT 1 FROM completions WHERE habit_id=$habit_id AND completed_date='$today')
  THEN (SELECT MAX(n)+1 FROM dates)
  WHEN EXISTS (SELECT 1 FROM completions WHERE habit_id=$habit_id AND completed_date=date('$today', '-1 day'))
  THEN (SELECT MAX(n) FROM dates)
  ELSE 0
END;
SQL
}

cmd_list() {
  local today
  today=$(date +%Y-%m-%d)
  
  echo -e "${BOLD}📋 Habits — $today${NC}"
  echo ""
  
  local habits
  habits=$(sqlite3 -separator '|' "$DB_FILE" "SELECT id, name, frequency FROM habits WHERE archived=0 ORDER BY name;")
  
  if [ -z "$habits" ]; then
    echo -e "${DIM}No habits yet. Add one with: habit add <name>${NC}"
    return
  fi
  
  printf "  ${DIM}%-20s %-10s %-8s %-8s${NC}\n" "HABIT" "FREQ" "TODAY" "STREAK"
  echo -e "  ${DIM}────────────────────────────────────────────────${NC}"
  
  while IFS='|' read -r id name freq; do
    local done_today streak
    done_today=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM completions WHERE habit_id=$id AND completed_date='$today';")
    streak=$(get_streak "$id")
    
    local status
    if [ "$done_today" -gt 0 ]; then
      status="${GREEN}  ✅${NC}"
    else
      status="${RED}  ⬜${NC}"
    fi
    
    local streak_display
    if [ "$streak" -gt 0 ]; then
      streak_display="🔥 $streak"
    else
      streak_display="${DIM}0${NC}"
    fi
    
    printf "  %-20s %-10s %b  %-8b\n" "$name" "$freq" "$status" "$streak_display"
  done <<< "$habits"
}

cmd_stats() {
  local name="${1:-}"
  local days="${2:-30}"
  
  if [ -n "$name" ]; then
    # Stats for specific habit
    local habit_id
    habit_id=$(sqlite3 "$DB_FILE" "SELECT id FROM habits WHERE name='$name' AND archived=0;")
    
    if [ -z "$habit_id" ]; then
      echo -e "${RED}❌ Habit '$name' not found${NC}"
      return 1
    fi
    
    local streak total_completions rate created_at
    streak=$(get_streak "$habit_id")
    total_completions=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM completions WHERE habit_id=$habit_id;")
    created_at=$(sqlite3 "$DB_FILE" "SELECT created_at FROM habits WHERE id=$habit_id;")
    rate=$(sqlite3 "$DB_FILE" "SELECT ROUND(COUNT(*) * 100.0 / $days, 1) FROM completions WHERE habit_id=$habit_id AND completed_date >= date('now', '-${days} days');")
    
    local best_streak
    best_streak=$(sqlite3 "$DB_FILE" <<SQL
WITH ordered AS (
  SELECT completed_date,
    julianday(completed_date) - ROW_NUMBER() OVER (ORDER BY completed_date) as grp
  FROM completions WHERE habit_id=$habit_id
),
streaks AS (
  SELECT grp, COUNT(*) as len FROM ordered GROUP BY grp
)
SELECT COALESCE(MAX(len), 0) FROM streaks;
SQL
)
    
    echo -e "${BOLD}📊 Stats: $name${NC}"
    echo -e "  Created:          $created_at"
    echo -e "  Current streak:   🔥 $streak days"
    echo -e "  Best streak:      ⭐ $best_streak days"
    echo -e "  Total completions: $total_completions"
    echo -e "  Last ${days}d rate:    ${rate}%"
    echo ""
    
    # Last 7 days heatmap
    echo -e "  ${DIM}Last 7 days:${NC}"
    printf "  "
    for i in $(seq 6 -1 0); do
      local d
      d=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d)
      local done
      done=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM completions WHERE habit_id=$habit_id AND completed_date='$d';")
      if [ "$done" -gt 0 ]; then
        printf "${GREEN}█${NC} "
      else
        printf "${DIM}░${NC} "
      fi
    done
    echo ""
    printf "  "
    for i in $(seq 6 -1 0); do
      local d
      d=$(date -d "$i days ago" +%a 2>/dev/null || date -v-${i}d +%a)
      printf "${DIM}${d:0:1}${NC} "
    done
    echo ""
  else
    # Overview stats
    echo -e "${BOLD}📊 Overview (last ${days} days)${NC}"
    echo ""
    
    local habits
    habits=$(sqlite3 -separator '|' "$DB_FILE" "SELECT id, name FROM habits WHERE archived=0 ORDER BY name;")
    
    printf "  ${DIM}%-20s %-8s %-10s %-8s${NC}\n" "HABIT" "STREAK" "RATE" "BEST"
    echo -e "  ${DIM}────────────────────────────────────────────────${NC}"
    
    while IFS='|' read -r id name; do
      local streak rate best_streak
      streak=$(get_streak "$id")
      rate=$(sqlite3 "$DB_FILE" "SELECT ROUND(COUNT(*) * 100.0 / $days, 1) FROM completions WHERE habit_id=$id AND completed_date >= date('now', '-${days} days');")
      best_streak=$(sqlite3 "$DB_FILE" "WITH ordered AS (SELECT completed_date, julianday(completed_date) - ROW_NUMBER() OVER (ORDER BY completed_date) as grp FROM completions WHERE habit_id=$id), streaks AS (SELECT grp, COUNT(*) as len FROM ordered GROUP BY grp) SELECT COALESCE(MAX(len), 0) FROM streaks;")
      
      printf "  %-20s 🔥 %-6s %-10s ⭐ %-6s\n" "$name" "$streak" "${rate}%" "$best_streak"
    done <<< "$habits"
  fi
}

cmd_heatmap() {
  local name="$1"
  local weeks="${2:-12}"
  
  local habit_id
  habit_id=$(sqlite3 "$DB_FILE" "SELECT id FROM habits WHERE name='$name' AND archived=0;")
  
  if [ -z "$habit_id" ]; then
    echo -e "${RED}❌ Habit '$name' not found${NC}"
    return 1
  fi
  
  local total_days=$((weeks * 7))
  echo -e "${BOLD}🗓️  Heatmap: $name (${weeks} weeks)${NC}"
  echo ""
  
  local day_labels=("M" "T" "W" "T" "F" "S" "S")
  
  for dow in $(seq 0 6); do
    printf "  ${DIM}${day_labels[$dow]}${NC} "
    for w in $(seq $((weeks - 1)) -1 0); do
      local offset=$((w * 7 + (6 - dow)))
      local d
      d=$(date -d "$offset days ago" +%Y-%m-%d 2>/dev/null || date -v-${offset}d +%Y-%m-%d)
      local done
      done=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM completions WHERE habit_id=$habit_id AND completed_date='$d';")
      if [ "$done" -gt 0 ]; then
        printf "${GREEN}█${NC} "
      else
        printf "${DIM}░${NC} "
      fi
    done
    echo ""
  done
}

cmd_remove() {
  local name="$1"
  sqlite3 "$DB_FILE" "UPDATE habits SET archived=1 WHERE name='$name';"
  echo -e "${YELLOW}🗑️  Archived:${NC} $name"
}

cmd_export() {
  local format="${1:-csv}"
  
  case "$format" in
    csv)
      echo "habit,date,note"
      sqlite3 -csv "$DB_FILE" "SELECT h.name, c.completed_date, c.note FROM completions c JOIN habits h ON c.habit_id=h.id ORDER BY c.completed_date DESC;"
      ;;
    json)
      sqlite3 -json "$DB_FILE" "SELECT h.name as habit, c.completed_date as date, c.note FROM completions c JOIN habits h ON c.habit_id=h.id ORDER BY c.completed_date DESC;"
      ;;
    *)
      echo -e "${RED}❌ Unknown format: $format (use csv or json)${NC}"
      return 1
      ;;
  esac
}

cmd_report() {
  local days="${1:-7}"
  local today
  today=$(date +%Y-%m-%d)
  
  echo -e "${BOLD}📈 Weekly Report (last ${days} days)${NC}"
  echo -e "${DIM}Generated: $(date '+%Y-%m-%d %H:%M')${NC}"
  echo ""
  
  local total_habits total_completions possible
  total_habits=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM habits WHERE archived=0;")
  total_completions=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM completions c JOIN habits h ON c.habit_id=h.id WHERE h.archived=0 AND c.completed_date >= date('now', '-${days} days');")
  possible=$((total_habits * days))
  
  local overall_rate=0
  if [ "$possible" -gt 0 ]; then
    overall_rate=$(echo "scale=1; $total_completions * 100 / $possible" | bc)
  fi
  
  echo -e "  ${BOLD}Overall completion rate:${NC} ${overall_rate}% ($total_completions/$possible)"
  echo ""
  
  # Per-habit breakdown
  local habits
  habits=$(sqlite3 -separator '|' "$DB_FILE" "SELECT id, name FROM habits WHERE archived=0 ORDER BY name;")
  
  while IFS='|' read -r id name; do
    local count streak
    count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM completions WHERE habit_id=$id AND completed_date >= date('now', '-${days} days');")
    streak=$(get_streak "$id")
    local rate
    rate=$(echo "scale=0; $count * 100 / $days" | bc)
    
    # Progress bar
    local filled=$((rate / 5))
    local empty=$((20 - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    local color="$RED"
    [ "$rate" -ge 50 ] && color="$YELLOW"
    [ "$rate" -ge 80 ] && color="$GREEN"
    
    echo -e "  ${name}"
    echo -e "  ${color}${bar}${NC} ${rate}% (${count}/${days}) 🔥${streak}"
    echo ""
  done <<< "$habits"
}

# Main
init_db

case "${1:-help}" in
  add)
    [ -z "${2:-}" ] && { echo "Usage: habit add <name> [description] [daily|weekly]"; exit 1; }
    cmd_add "$2" "${3:-}" "${4:-daily}"
    ;;
  done|complete|check)
    [ -z "${2:-}" ] && { echo "Usage: habit done <name> [date] [note]"; exit 1; }
    cmd_done "$2" "${3:-$(date +%Y-%m-%d)}" "${4:-}"
    ;;
  undo)
    [ -z "${2:-}" ] && { echo "Usage: habit undo <name> [date]"; exit 1; }
    cmd_undo "$2" "${3:-$(date +%Y-%m-%d)}"
    ;;
  list|ls)
    cmd_list
    ;;
  stats)
    cmd_stats "${2:-}" "${3:-30}"
    ;;
  heatmap|heat)
    [ -z "${2:-}" ] && { echo "Usage: habit heatmap <name> [weeks]"; exit 1; }
    cmd_heatmap "$2" "${3:-12}"
    ;;
  remove|rm|archive)
    [ -z "${2:-}" ] && { echo "Usage: habit remove <name>"; exit 1; }
    cmd_remove "$2"
    ;;
  export)
    cmd_export "${2:-csv}"
    ;;
  report)
    cmd_report "${2:-7}"
    ;;
  help|--help|-h)
    echo -e "${BOLD}Habit Tracker${NC} — Track daily habits with streaks and stats"
    echo ""
    echo "Usage: habit <command> [args]"
    echo ""
    echo "Commands:"
    echo "  add <name> [desc] [freq]  Add a new habit (freq: daily|weekly)"
    echo "  done <name> [date] [note] Mark habit as done (default: today)"
    echo "  undo <name> [date]        Remove completion for a date"
    echo "  list                      Show all habits with today's status"
    echo "  stats [name] [days]       Show statistics (default: 30 days)"
    echo "  heatmap <name> [weeks]    Show GitHub-style heatmap (default: 12 weeks)"
    echo "  report [days]             Generate completion report"
    echo "  export [csv|json]         Export all data"
    echo "  remove <name>             Archive a habit"
    echo ""
    echo "Examples:"
    echo "  habit add exercise \"Morning workout\" daily"
    echo "  habit done exercise"
    echo "  habit done meditation 2026-02-25 \"10 min session\""
    echo "  habit stats exercise 90"
    echo "  habit heatmap exercise 8"
    echo "  habit report 7"
    ;;
  *)
    echo -e "${RED}Unknown command: $1${NC}"
    echo "Run 'habit help' for usage"
    exit 1
    ;;
esac
