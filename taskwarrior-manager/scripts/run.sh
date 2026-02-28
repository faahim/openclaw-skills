#!/bin/bash
# Taskwarrior Manager — wrapper with extended commands
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check taskwarrior is installed
if ! command -v task &>/dev/null; then
  echo "❌ Taskwarrior not installed. Run: bash scripts/install.sh"
  exit 1
fi

ACTION="${1:-help}"
shift 2>/dev/null || true

case "$ACTION" in
  # === Standard task commands (pass-through) ===
  add|list|next|done|modify|delete|projects|tags|info|undo|sync|export|import|config)
    task rc.confirmation=off "$ACTION" "$@"
    ;;

  # === Extended commands ===

  daily-review)
    echo ""
    echo "📋 Daily Review — $(date +%Y-%m-%d)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Overdue
    OVERDUE=$(task rc.verbose=nothing status:pending "due.before:today" count 2>/dev/null || echo "0")
    if [[ "$OVERDUE" -gt 0 ]]; then
      echo ""
      echo "🔴 OVERDUE ($OVERDUE):"
      task rc.verbose=nothing rc.report.list.sort=urgency- status:pending "due.before:today" list 2>/dev/null || true
    fi

    # Due today
    TODAY=$(task rc.verbose=nothing status:pending "due:today" count 2>/dev/null || echo "0")
    if [[ "$TODAY" -gt 0 ]]; then
      echo ""
      echo "📅 DUE TODAY ($TODAY):"
      task rc.verbose=nothing status:pending "due:today" list 2>/dev/null || true
    fi

    # High priority
    HIGH=$(task rc.verbose=nothing status:pending priority:H count 2>/dev/null || echo "0")
    if [[ "$HIGH" -gt 0 ]]; then
      echo ""
      echo "⚡ HIGH PRIORITY ($HIGH):"
      task rc.verbose=nothing status:pending priority:H list 2>/dev/null || true
    fi

    # Stats
    PENDING=$(task rc.verbose=nothing status:pending count 2>/dev/null || echo "0")
    WEEK=$(task rc.verbose=nothing status:pending "due.before:eow" count 2>/dev/null || echo "0")
    COMPLETED=$(task rc.verbose=nothing status:completed count 2>/dev/null || echo "0")
    echo ""
    echo "📊 Stats: $PENDING pending | $WEEK due this week | $COMPLETED completed total"
    echo ""
    ;;

  overdue)
    echo "🔴 Overdue Tasks:"
    task rc.verbose=nothing status:pending "due.before:today" list 2>/dev/null || echo "  None! 🎉"
    ;;

  completed-today)
    echo "✅ Completed Today:"
    task rc.verbose=nothing status:completed "end:today" list 2>/dev/null || echo "  Nothing yet."
    ;;

  summary)
    echo "📊 Productivity Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Pending:   $(task rc.verbose=nothing status:pending count 2>/dev/null || echo 0)"
    echo "Completed: $(task rc.verbose=nothing status:completed count 2>/dev/null || echo 0)"
    echo "Deleted:   $(task rc.verbose=nothing status:deleted count 2>/dev/null || echo 0)"
    echo ""
    echo "By Priority:"
    echo "  H: $(task rc.verbose=nothing status:pending priority:H count 2>/dev/null || echo 0)"
    echo "  M: $(task rc.verbose=nothing status:pending priority:M count 2>/dev/null || echo 0)"
    echo "  L: $(task rc.verbose=nothing status:pending priority:L count 2>/dev/null || echo 0)"
    echo "  -: $(task rc.verbose=nothing status:pending priority: count 2>/dev/null || echo 0)"
    echo ""
    echo "Projects:"
    task rc.verbose=nothing summary 2>/dev/null || echo "  No projects yet."
    ;;

  burndown)
    PERIOD="${1:-daily}"
    task burndown."$PERIOD" 2>/dev/null || echo "No data for burndown chart yet."
    ;;

  project-summary)
    task rc.verbose=nothing summary 2>/dev/null || echo "No projects yet."
    ;;

  bulk-add)
    PROJECT="$1"
    shift
    if [[ -z "$PROJECT" ]]; then
      echo "Usage: run.sh bulk-add <project> \"task1\" \"task2\" ..."
      exit 1
    fi
    COUNT=0
    for TASK_DESC in "$@"; do
      task rc.confirmation=off add "$TASK_DESC" project:"$PROJECT"
      ((COUNT++))
    done
    echo "✅ Added $COUNT tasks to project:$PROJECT"
    ;;

  export-json)
    OUTPUT="${1:-tasks-export.json}"
    task rc.verbose=nothing export > "$OUTPUT"
    echo "✅ Exported to $OUTPUT ($(wc -l < "$OUTPUT") tasks)"
    ;;

  import-csv)
    CSV_FILE="$1"
    PROJECT="${3:-inbox}"
    if [[ -z "$CSV_FILE" || ! -f "$CSV_FILE" ]]; then
      echo "Usage: run.sh import-csv <file.csv> --project <name>"
      exit 1
    fi
    # Parse --project flag
    while [[ $# -gt 0 ]]; do
      case $1 in
        --project) PROJECT="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    COUNT=0
    while IFS=, read -r desc priority due; do
      # Skip header
      [[ "$desc" == "description" ]] && continue
      CMD="task rc.confirmation=off add \"$desc\" project:$PROJECT"
      [[ -n "$priority" ]] && CMD="$CMD priority:$priority"
      [[ -n "$due" ]] && CMD="$CMD due:$due"
      eval "$CMD"
      ((COUNT++))
    done < "$CSV_FILE"
    echo "✅ Imported $COUNT tasks from $CSV_FILE"
    ;;

  setup-cron)
    while [[ $# -gt 0 ]]; do
      case $1 in
        --daily-review)
          HOUR="$2"
          CRON_LINE="0 $HOUR * * * cd $(pwd) && bash scripts/run.sh daily-review >> /tmp/task-review.log 2>&1"
          (crontab -l 2>/dev/null | grep -v "task-review"; echo "$CRON_LINE") | crontab -
          echo "✅ Daily review scheduled at ${HOUR}:00"
          shift 2
          ;;
        --overdue-alert)
          INTERVAL="$2"
          CRON_LINE="0 */$INTERVAL * * * cd $(pwd) && bash scripts/run.sh overdue >> /tmp/task-overdue.log 2>&1"
          (crontab -l 2>/dev/null | grep -v "task-overdue"; echo "$CRON_LINE") | crontab -
          echo "✅ Overdue alerts every ${INTERVAL} hours"
          shift 2
          ;;
        *) shift ;;
      esac
    done
    ;;

  sync-status)
    if grep -q "taskd.server" "$HOME/.taskrc" 2>/dev/null; then
      echo "✅ Sync configured"
      grep "taskd\." "$HOME/.taskrc" | sed 's/=/ = /'
    else
      echo "❌ Sync not configured. Run: bash scripts/setup-sync.sh --server <host>"
    fi
    ;;

  help|*)
    echo "Taskwarrior Manager — Extended CLI"
    echo ""
    echo "Standard commands (pass-through to task):"
    echo "  add <desc> [opts]     Add a task"
    echo "  list [filter]         List tasks"
    echo "  next                  Most urgent tasks"
    echo "  done <id>             Complete a task"
    echo "  modify <id> [opts]    Modify a task"
    echo "  delete <id>           Delete a task"
    echo "  projects              List projects"
    echo "  tags                  List tags"
    echo "  sync                  Sync with Taskserver"
    echo "  config <key> <val>    Set configuration"
    echo ""
    echo "Extended commands:"
    echo "  daily-review          Morning review (overdue + today + high priority)"
    echo "  overdue               List overdue tasks"
    echo "  completed-today       Tasks completed today"
    echo "  summary               Productivity stats"
    echo "  burndown [period]     Burndown chart (daily/weekly/monthly)"
    echo "  project-summary       Project progress"
    echo "  bulk-add <proj> ...   Add multiple tasks to a project"
    echo "  export-json [file]    Export all tasks as JSON"
    echo "  import-csv <file>     Import tasks from CSV"
    echo "  setup-cron [opts]     Schedule daily review / alerts"
    echo "  sync-status           Check sync configuration"
    echo ""
    ;;
esac
