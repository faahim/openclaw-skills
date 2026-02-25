---
name: duckdb-analytics
description: >-
  Install DuckDB and run SQL queries on CSV, JSON, and Parquet files — no database server needed.
categories: [data, analytics]
dependencies: [bash, curl, unzip]
---

# DuckDB Analytics Tool

## What This Does

Query CSV, JSON, and Parquet files using SQL — directly from the command line. DuckDB is an embedded analytical database (like SQLite for analytics). No server, no setup, no imports — just point it at your files and run SQL.

**Example:** "Query a 500MB CSV with `SELECT country, SUM(revenue) FROM 'sales.csv' GROUP BY country ORDER BY 2 DESC LIMIT 10` — instant results."

## Quick Start (2 minutes)

### 1. Install DuckDB

```bash
bash scripts/install.sh
```

This auto-detects your OS/architecture and installs the latest DuckDB CLI to `~/.local/bin/duckdb`.

### 2. Query a CSV File

```bash
duckdb -c "SELECT * FROM 'data.csv' LIMIT 10"
```

### 3. Query with Aggregation

```bash
duckdb -c "SELECT category, COUNT(*) as cnt, AVG(price) as avg_price FROM 'products.csv' GROUP BY category ORDER BY cnt DESC"
```

## Core Workflows

### Workflow 1: Explore Any Data File

**Use case:** Quickly understand a CSV/JSON/Parquet file's structure and contents.

```bash
# See schema (column names + types)
duckdb -c "DESCRIBE SELECT * FROM 'data.csv'"

# Row count
duckdb -c "SELECT COUNT(*) FROM 'data.csv'"

# First 10 rows
duckdb -c "SELECT * FROM 'data.csv' LIMIT 10"

# Column statistics
duckdb -c "SUMMARIZE SELECT * FROM 'data.csv'"
```

### Workflow 2: Filter & Aggregate Large Files

**Use case:** Run analytical queries on files too large for text processing.

```bash
# Filter rows
duckdb -c "SELECT * FROM 'logs.csv' WHERE status_code >= 400 AND timestamp > '2026-01-01'"

# Group & aggregate
duckdb -c "
  SELECT 
    date_trunc('month', timestamp::DATE) as month,
    COUNT(*) as requests,
    COUNT(*) FILTER (WHERE status_code >= 500) as errors
  FROM 'access_log.csv'
  GROUP BY 1 ORDER BY 1
"

# Window functions
duckdb -c "
  SELECT *, 
    LAG(revenue) OVER (ORDER BY month) as prev_month,
    revenue - LAG(revenue) OVER (ORDER BY month) as growth
  FROM 'monthly_revenue.csv'
"
```

### Workflow 3: Join Multiple Files

**Use case:** Combine data from different CSV files.

```bash
duckdb -c "
  SELECT o.order_id, c.name, o.total
  FROM 'orders.csv' o
  JOIN 'customers.csv' c ON o.customer_id = c.id
  WHERE o.total > 100
  ORDER BY o.total DESC
"
```

### Workflow 4: Export Results

**Use case:** Transform data and save to a new file.

```bash
# CSV → CSV (filtered/transformed)
duckdb -c "COPY (SELECT * FROM 'raw.csv' WHERE status='active') TO 'filtered.csv' (HEADER, DELIMITER ',')"

# CSV → JSON
duckdb -c "COPY (SELECT * FROM 'data.csv') TO 'data.json' (FORMAT JSON, ARRAY true)"

# CSV → Parquet (compressed, fast for re-querying)
duckdb -c "COPY (SELECT * FROM 'data.csv') TO 'data.parquet' (FORMAT PARQUET, COMPRESSION ZSTD)"

# JSON → CSV
duckdb -c "COPY (SELECT * FROM 'data.json') TO 'data.csv' (HEADER)"
```

### Workflow 5: Query Remote Files

**Use case:** Query files from URLs without downloading.

```bash
# Query a CSV from the web
duckdb -c "SELECT * FROM 'https://example.com/data.csv' LIMIT 10"

# Query S3 (if AWS credentials configured)
duckdb -c "SELECT * FROM 's3://bucket/path/data.parquet' LIMIT 10"
```

### Workflow 6: Generate Reports

**Use case:** Create summary reports from raw data.

```bash
bash scripts/report.sh sales.csv
```

This generates a markdown summary with row count, column stats, top values, and distribution.

## Advanced Usage

### Multiple Statements / Persistent DB

```bash
# Create a persistent database for repeated queries
duckdb analytics.db <<'SQL'
CREATE TABLE sales AS SELECT * FROM 'sales_2025.csv';
CREATE TABLE sales_2026 AS SELECT * FROM 'sales_2026.csv';

-- Combined analysis
SELECT year, SUM(revenue) 
FROM (
  SELECT 2025 as year, revenue FROM sales
  UNION ALL
  SELECT 2026, revenue FROM sales_2026
) GROUP BY year;
SQL
```

### Glob Patterns (Query Multiple Files)

```bash
# All CSVs in a directory
duckdb -c "SELECT * FROM 'logs/*.csv' LIMIT 10"

# All Parquet files with filename column
duckdb -c "SELECT filename, COUNT(*) FROM read_parquet('data/**/*.parquet', filename=true) GROUP BY filename"
```

### JSON Handling

```bash
# Query nested JSON
duckdb -c "SELECT json_extract(data, '$.user.name') as name FROM 'events.json'"

# Flatten JSON arrays
duckdb -c "SELECT unnest(items) as item FROM 'orders.json'"
```

### Performance Tips

```bash
# For large files, use Parquet format (10-100x faster than CSV for repeated queries)
duckdb -c "COPY (SELECT * FROM 'huge.csv') TO 'huge.parquet' (FORMAT PARQUET)"
duckdb -c "SELECT * FROM 'huge.parquet' WHERE ..."

# Set memory limit
duckdb -c "SET memory_limit='2GB'; SELECT * FROM 'huge.csv'"

# Parallel processing (automatic, but configurable)
duckdb -c "SET threads=4; SELECT * FROM 'huge.parquet'"
```

## Troubleshooting

### Issue: "duckdb: command not found"

**Fix:** Run the install script or add to PATH:
```bash
bash scripts/install.sh
# OR
export PATH="$HOME/.local/bin:$PATH"
```

### Issue: CSV parsing errors

**Fix:** Specify delimiter or quote character:
```bash
duckdb -c "SELECT * FROM read_csv('data.tsv', delim='\t', header=true)"
duckdb -c "SELECT * FROM read_csv('data.csv', quote='\"', escape='\"')"
```

### Issue: Out of memory on large files

**Fix:** Use streaming or limit memory:
```bash
duckdb -c "SET memory_limit='1GB'; SELECT COUNT(*) FROM 'huge.csv'"
# Or convert to Parquet first (more memory-efficient)
```

### Issue: Date/time parsing

**Fix:** Cast explicitly:
```bash
duckdb -c "SELECT strptime(date_col, '%m/%d/%Y')::DATE as parsed FROM 'data.csv'"
```

## Dependencies

- `bash` (4.0+)
- `curl` (for install script)
- `unzip` (for install script)
- DuckDB CLI (installed by `scripts/install.sh`)
