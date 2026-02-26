#!/bin/bash
# Time Tracker — Install Script
set -e

DB_DIR="${TT_DB_DIR:-$HOME/.timetracker}"
DB_FILE="${TT_DB:-$DB_DIR/tt.db}"

echo "🕐 Installing Time Tracker..."

# Check deps
for cmd in sqlite3 bc; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Required: $cmd — install it first"
    exit 1
  fi
done

# Create DB directory
mkdir -p "$DB_DIR"

# Create database
sqlite3 "$DB_FILE" <<'SQL'
CREATE TABLE IF NOT EXISTS entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  description TEXT NOT NULL,
  project TEXT DEFAULT '',
  client TEXT DEFAULT '',
  tags TEXT DEFAULT '',
  rate REAL DEFAULT 0,
  started_at TEXT NOT NULL,
  stopped_at TEXT DEFAULT NULL,
  duration_seconds INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS active_timer (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  entry_id INTEGER NOT NULL,
  FOREIGN KEY (entry_id) REFERENCES entries(id)
);

CREATE INDEX IF NOT EXISTS idx_entries_started ON entries(started_at);
CREATE INDEX IF NOT EXISTS idx_entries_project ON entries(project);
CREATE INDEX IF NOT EXISTS idx_entries_client ON entries(client);
SQL

echo "✅ Database created at $DB_FILE"
echo ""
echo "Usage:"
echo "  bash scripts/tt.sh start \"Task description\" --project myapp"
echo "  bash scripts/tt.sh stop"
echo "  bash scripts/tt.sh report today"
echo ""
echo "Done! 🎉"
