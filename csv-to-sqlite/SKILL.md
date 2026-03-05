---
name: csv-to-sqlite
description: >-
  Import CSV/TSV files into SQLite databases and query them with SQL. Bulk import, schema detection, and interactive queries.
categories: [data, productivity]
dependencies: [sqlite3, bash]
---

# CSV to SQLite

## What This Does

Turn any CSV or TSV file into a queryable SQLite database in seconds. Auto-detects column types, handles headers, supports bulk imports of multiple files, and lets you run SQL queries immediately. Perfect for analyzing data exports, log files, or any tabular data without setting up a database server.

**Example:** "Import 5 CSV exports from different sources, join them with SQL, export results as a new CSV."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
which sqlite3 || echo "Install sqlite3: sudo apt install sqlite3"
```

### 2. Import a CSV

```bash
bash scripts/csv-to-sqlite.sh import data.csv mydb.sqlite
# Output:
# ✅ Imported data.csv → mydb.sqlite (table: data)
# 📊 1,247 rows, 8 columns detected
# Columns: id (INTEGER), name (TEXT), email (TEXT), amount (REAL), created_at (TEXT)
```

### 3. Query It

```bash
bash scripts/csv-to-sqlite.sh query mydb.sqlite "SELECT name, SUM(amount) as total FROM data GROUP BY name ORDER BY total DESC LIMIT 10"
```

## Core Workflows

### Workflow 1: Import Single CSV

```bash
bash scripts/csv-to-sqlite.sh import sales.csv analytics.sqlite
# Auto-detects: delimiter, headers, column types
# Creates table named after file (sans extension)
```

### Workflow 2: Import Multiple CSVs

```bash
bash scripts/csv-to-sqlite.sh import-dir ./exports/ combined.sqlite
# Output:
# ✅ Imported customers.csv → table: customers (5,231 rows)
# ✅ Imported orders.csv → table: orders (12,847 rows)
# ✅ Imported products.csv → table: products (342 rows)
# 📊 3 tables created in combined.sqlite
```

### Workflow 3: Import with Custom Options

```bash
bash scripts/csv-to-sqlite.sh import data.tsv mydb.sqlite \
  --delimiter $'\t' \
  --table custom_name \
  --drop-existing \
  --skip-lines 2
```

### Workflow 4: Query and Export Results

```bash
# Run query, output as CSV
bash scripts/csv-to-sqlite.sh query mydb.sqlite \
  "SELECT c.name, COUNT(o.id) as order_count, SUM(o.total) as revenue
   FROM customers c
   JOIN orders o ON c.id = o.customer_id
   GROUP BY c.name
   HAVING revenue > 1000
   ORDER BY revenue DESC" \
  --csv > top_customers.csv
```

### Workflow 5: Explore Database Schema

```bash
bash scripts/csv-to-sqlite.sh schema mydb.sqlite
# Output:
# 📋 Database: mydb.sqlite (2.3 MB)
#
# Table: customers (5,231 rows)
#   id       INTEGER
#   name     TEXT
#   email    TEXT
#   signup   TEXT
#
# Table: orders (12,847 rows)
#   id          INTEGER
#   customer_id INTEGER
#   total       REAL
#   status      TEXT
#   created_at  TEXT
```

### Workflow 6: Quick Stats

```bash
bash scripts/csv-to-sqlite.sh stats mydb.sqlite orders
# Output:
# 📊 Table: orders
# Rows: 12,847
# Columns: 5
#
# Column Stats:
#   total: min=0.99, max=4,299.00, avg=87.42, nulls=0
#   status: unique=4 (pending: 2,341, shipped: 8,102, delivered: 2,201, cancelled: 203)
#   created_at: range 2024-01-01 to 2026-03-05
```

## Configuration

### Environment Variables

```bash
# Default database path (optional)
export CSV_SQLITE_DB="$HOME/.local/share/csv-sqlite/default.db"

# Default output format for queries
export CSV_SQLITE_FORMAT="table"  # table, csv, json, markdown
```

### Supported Delimiters

- `,` — CSV (default, auto-detected)
- `\t` — TSV (auto-detected from .tsv extension)
- `|` — Pipe-delimited
- `;` — Semicolon-delimited (common in European CSVs)

## Advanced Usage

### Merge Multiple CSVs into One Table

```bash
# All CSVs have same schema — append to single table
bash scripts/csv-to-sqlite.sh import file1.csv mydb.sqlite --table transactions
bash scripts/csv-to-sqlite.sh import file2.csv mydb.sqlite --table transactions --append
bash scripts/csv-to-sqlite.sh import file3.csv mydb.sqlite --table transactions --append
```

### Create Indexes for Fast Queries

```bash
bash scripts/csv-to-sqlite.sh query mydb.sqlite \
  "CREATE INDEX idx_customer_id ON orders(customer_id)"
```

### Export Entire Table Back to CSV

```bash
bash scripts/csv-to-sqlite.sh export mydb.sqlite customers > customers_clean.csv
```

### Pipe from stdin

```bash
# Pipe CSV data directly
cat data.csv | bash scripts/csv-to-sqlite.sh import - mydb.sqlite --table piped_data

# Download and import in one step
curl -s https://example.com/data.csv | bash scripts/csv-to-sqlite.sh import - mydb.sqlite --table remote_data
```

## Troubleshooting

### Issue: "column count mismatch"

**Cause:** Some rows have different numbers of columns (common in messy CSVs).

**Fix:**
```bash
bash scripts/csv-to-sqlite.sh import data.csv mydb.sqlite --flexible
# Pads short rows with NULLs, truncates long rows
```

### Issue: Wrong column types detected

**Fix:** Force all columns to TEXT, then cast in queries:
```bash
bash scripts/csv-to-sqlite.sh import data.csv mydb.sqlite --all-text
# Then cast in SQL: SELECT CAST(amount AS REAL) FROM data
```

### Issue: Encoding errors

**Fix:**
```bash
# Convert to UTF-8 first
iconv -f ISO-8859-1 -t UTF-8 data.csv > data_utf8.csv
bash scripts/csv-to-sqlite.sh import data_utf8.csv mydb.sqlite
```

### Issue: Very large files (>1GB)

**Tip:** SQLite handles large files well. Import may take a few minutes.
```bash
# Use --batch for faster import (less progress output)
bash scripts/csv-to-sqlite.sh import huge.csv mydb.sqlite --batch
```

## Dependencies

- `sqlite3` (3.31+) — Usually pre-installed on Linux/Mac
- `bash` (4.0+)
- `awk` — For CSV parsing (pre-installed)
- Optional: `iconv` — For encoding conversion
