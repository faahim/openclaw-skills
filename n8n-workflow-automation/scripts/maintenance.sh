#!/bin/bash
# n8n maintenance tasks
set -euo pipefail

N8N_DIR="${N8N_DIR:-$HOME/.n8n}"
N8N_PORT="${N8N_PORT:-5678}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --prune-executions)
      HOURS="${3:-72}"
      echo "🧹 Pruning executions older than ${HOURS}h..."
      docker compose -f "$N8N_DIR/docker-compose.yml" exec -T n8n \
        n8n prune --delete-data-older-than "$HOURS" 2>/dev/null || \
        echo "   Manual prune: set EXECUTIONS_DATA_PRUNE=true and EXECUTIONS_DATA_MAX_AGE=$HOURS"
      shift ;;
    --older-than)
      shift 2 ;;  # consumed by --prune-executions
    --vacuum)
      echo "🔧 Vacuuming SQLite database..."
      docker compose -f "$N8N_DIR/docker-compose.yml" exec -T n8n \
        sqlite3 /home/node/.n8n/database.sqlite "VACUUM;" 2>/dev/null && \
        echo "✅ Database vacuumed" || echo "⚠️  Vacuum failed (may be using PostgreSQL)"
      shift ;;
    --check-disk)
      echo "💾 Disk usage:"
      du -sh "$N8N_DIR" 2>/dev/null
      docker system df 2>/dev/null
      shift ;;
    *)
      echo "Usage: maintenance.sh [--prune-executions --older-than Nh] [--vacuum] [--check-disk]"
      exit 1 ;;
  esac
done
