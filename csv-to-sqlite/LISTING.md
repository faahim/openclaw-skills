# Listing Copy: CSV to SQLite

## Metadata
- **Type:** Skill
- **Name:** csv-to-sqlite
- **Display Name:** CSV to SQLite
- **Categories:** [data, productivity]
- **Price:** $8
- **Dependencies:** [sqlite3, bash]

## Tagline

Import CSV files into SQLite databases — Query any data with SQL instantly

## Description

Tired of staring at massive CSV files in a text editor? Need to join data from multiple exports? CSV to SQLite turns any CSV or TSV file into a queryable SQLite database in seconds.

Auto-detects delimiters and column types. Supports bulk imports of entire directories. Run SQL queries immediately — joins, aggregations, filters, everything SQLite supports. Export results back to CSV when you're done.

**What it does:**
- 📥 Import CSV/TSV files with auto-detection (delimiter, types, headers)
- 🔍 Query with full SQL — SELECT, JOIN, GROUP BY, window functions
- 📂 Bulk import directories of CSVs into one database
- 📊 Schema explorer and column statistics
- 📤 Export query results as CSV, JSON, or Markdown
- ⚡ Handles large files (1GB+) efficiently
- 🔧 Pipe from stdin — `curl ... | csv-to-sqlite import -`

Perfect for developers, data analysts, and anyone who works with CSV exports and needs quick answers without firing up Python or Excel.

## Quick Start Preview

```bash
# Import a CSV
bash scripts/csv-to-sqlite.sh import sales.csv analytics.sqlite
# ✅ Imported sales.csv → analytics.sqlite (table: sales)
# 📊 12,847 rows, 8 columns detected

# Query it
bash scripts/csv-to-sqlite.sh query analytics.sqlite \
  "SELECT region, SUM(revenue) FROM sales GROUP BY region ORDER BY 2 DESC"
```

## Core Capabilities

1. CSV/TSV import — Auto-detect delimiters, headers, and column types
2. Bulk directory import — Import all CSVs from a folder into one database
3. SQL queries — Full SQLite SQL support with formatted output
4. Multiple output formats — Table, CSV, JSON, Markdown
5. Schema explorer — View all tables, columns, and types at a glance
6. Column statistics — Min/max/avg for numbers, unique counts for text
7. Stdin piping — Import from curl, cat, or any command
8. Append mode — Merge multiple CSVs into one table
9. Export — Dump any table back to CSV
10. Large file support — SQLite handles GB-scale data efficiently

## Dependencies
- `sqlite3` (3.31+)
- `bash` (4.0+)

## Installation Time
**2 minutes** — sqlite3 is pre-installed on most systems
