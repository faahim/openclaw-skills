---
name: csv-toolkit
description: >-
  Parse, filter, sort, join, convert, and analyze CSV/TSV/JSON data files using fast CLI tools.
categories: [data, productivity]
dependencies: [miller, csvkit, xsv]
---

# CSV Toolkit

## What This Does

Process CSV, TSV, and JSON data files at speed using dedicated CLI tools (Miller, csvkit, xsv). Filter rows, sort columns, join files, convert formats, compute stats, and reshape data — all from the terminal.

**Example:** "Filter a 500MB CSV to rows where revenue > 10000, sort by date, convert to JSON, compute column averages — in seconds."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install all three tools (use whichever is available for your OS)
bash scripts/install.sh
```

### 2. Try It

```bash
# View CSV as a formatted table
mlr --icsv --opprint head -n 10 data.csv

# Filter rows
mlr --csv filter '$revenue > 10000' data.csv

# Convert CSV to JSON
mlr --icsv --ojson cat data.csv > data.json

# Get column statistics
csvstat data.csv

# Sort by column (blazing fast with xsv)
xsv sort -s date data.csv
```

## Core Workflows

### Workflow 1: Explore & Inspect Data

**Use case:** Understand a new CSV file quickly.

```bash
# Show headers
xsv headers data.csv

# Row count (instant, even for huge files)
xsv count data.csv

# Column statistics (min, max, mean, unique values)
csvstat data.csv

# Preview first 20 rows as table
mlr --icsv --opprint head -n 20 data.csv

# Frequency table for a column
xsv frequency -s category data.csv | head -20

# Find unique values in a column
mlr --csv uniq -g category data.csv
```

### Workflow 2: Filter & Search

**Use case:** Extract specific rows matching conditions.

```bash
# Filter by numeric condition
mlr --csv filter '$amount > 1000' transactions.csv

# Filter by string match
mlr --csv filter '$status == "active"' users.csv

# Regex search across all columns
xsv search -i "error|fail" logs.csv

# Search specific column
xsv search -s email "@gmail.com" contacts.csv

# Multiple conditions
mlr --csv filter '$age >= 18 && $country == "US"' users.csv

# Date range filter
mlr --csv filter '$date >= "2026-01-01" && $date <= "2026-01-31"' events.csv
```

### Workflow 3: Transform & Reshape

**Use case:** Clean, rename, reorder, or compute new columns.

```bash
# Select specific columns
xsv select name,email,phone contacts.csv

# Remove columns
mlr --csv cut -x -f internal_id,debug_flag data.csv

# Rename columns
mlr --csv rename old_name,new_name data.csv

# Add computed column
mlr --csv put '$total = $price * $quantity' orders.csv

# Reorder columns
xsv select id,name,email,phone,address contacts.csv

# Uppercase a column
mlr --csv put '$name = toupper($name)' data.csv

# Fill empty values
mlr --csv put 'if ($status == "") { $status = "unknown" }' data.csv
```

### Workflow 4: Sort & Deduplicate

**Use case:** Order data and remove duplicates.

```bash
# Sort by column (ascending)
xsv sort -s revenue data.csv

# Sort descending (numeric)
xsv sort -s revenue -N -R data.csv

# Sort by multiple columns
mlr --csv sort-within-groups -f category -nr revenue data.csv

# Remove duplicate rows
mlr --csv uniq -a data.csv

# Remove duplicates by specific columns
mlr --csv uniq -g email contacts.csv

# Top N rows by value
mlr --csv sort -nr revenue then head -n 10 data.csv
```

### Workflow 5: Aggregate & Summarize

**Use case:** Group data and compute statistics.

```bash
# Sum by group
mlr --csv stats1 -a sum -f revenue -g category sales.csv

# Multiple aggregations
mlr --csv stats1 -a sum,mean,count -f revenue -g category sales.csv

# Group by and count
mlr --csv group-by category then count-distinct -f product sales.csv

# Percentiles
mlr --csv stats1 -a p50,p90,p99 -f response_time metrics.csv

# Histogram
mlr --csv histogram -o value -w 40 -nbins 10 data.csv
```

### Workflow 6: Join & Merge Files

**Use case:** Combine data from multiple CSVs.

```bash
# Inner join on matching column
mlr --csv join -j id -f users.csv orders.csv

# Stack/concatenate CSVs (same columns)
xsv cat rows file1.csv file2.csv file3.csv > combined.csv

# Stack with different columns (fills missing with empty)
csvstack file1.csv file2.csv > combined.csv

# Paste CSVs side by side
paste -d, file1.csv file2.csv > merged.csv
```

### Workflow 7: Format Conversion

**Use case:** Convert between CSV, JSON, TSV, Markdown, SQL.

```bash
# CSV → JSON
mlr --icsv --ojson cat data.csv > data.json

# JSON → CSV
mlr --ijson --ocsv cat data.json > data.csv

# CSV → TSV
mlr --icsv --otsv cat data.csv > data.tsv

# CSV → Markdown table
mlr --icsv --omd cat data.csv

# CSV → Pretty table
mlr --icsv --opprint cat data.csv

# CSV → NDJSON (one JSON object per line)
mlr --icsv --ojsonl cat data.csv > data.jsonl

# JSON array → CSV
mlr --ijson --ocsv cat data.json > data.csv

# Generate SQL INSERT statements
csvsql --insert --tables my_table data.csv
```

### Workflow 8: Split Large Files

**Use case:** Break a huge CSV into manageable chunks.

```bash
# Split into files of N rows each
xsv split -s 10000 output_dir/ data.csv

# Split by column value (one file per category)
mlr --csv --from data.csv split-join-stitch-csv -o '{category}.csv'

# Sample random rows
xsv sample 1000 data.csv > sample.csv

# Take first/last N rows
xsv slice -l 100 data.csv > first100.csv
xsv slice -s 9900 data.csv > last100.csv
```

## Configuration

### Tool Selection Guide

| Tool | Best For | Speed | Features |
|------|----------|-------|----------|
| **xsv** | Large files, indexing, search | ⚡ Fastest | Search, sort, split, stats |
| **mlr (Miller)** | Transforms, aggregations, conversions | 🚀 Fast | Full DSL, format conversion |
| **csvkit** | SQL queries, statistics, DB import | 🏃 Good | SQL, stats, DB integration |

### Environment Variables

```bash
# Default delimiter (if not CSV)
export MLR_CSV_DEFAULT_FS=","

# Use with TSV files
mlr --itsv --ocsv cat data.tsv
```

## Advanced Usage

### SQL Queries on CSV

```bash
# Run SQL directly on CSV files
csvsql --query "SELECT category, SUM(revenue) as total FROM data GROUP BY category ORDER BY total DESC" data.csv

# Join CSVs with SQL
csvsql --query "SELECT u.name, o.amount FROM users u JOIN orders o ON u.id = o.user_id" users.csv orders.csv
```

### Pipeline Processing

```bash
# Complex pipeline: filter → transform → aggregate → sort → format
mlr --csv \
  filter '$status == "completed"' \
  then put '$profit = $revenue - $cost' \
  then stats1 -a sum,mean -f profit -g category \
  then sort -nr profit_sum \
  then head -n 10 \
  sales.csv
```

### Index Large Files

```bash
# Create index for instant random access
xsv index data.csv

# Now slicing is instant
xsv slice -s 1000000 -l 100 data.csv
```

### Import to SQLite

```bash
# Create SQLite database from CSV
csvsql --db sqlite:///data.db --insert data.csv

# Query it
sqlite3 data.db "SELECT * FROM data WHERE revenue > 10000"
```

## Troubleshooting

### Issue: "command not found: mlr"

**Fix:**
```bash
bash scripts/install.sh
```

### Issue: Encoding errors

**Fix:**
```bash
# Convert to UTF-8 first
iconv -f ISO-8859-1 -t UTF-8 data.csv > data_utf8.csv
```

### Issue: Inconsistent number of columns

**Fix:**
```bash
# Find bad rows
xsv fixlengths data.csv > fixed.csv
```

### Issue: CSV with different delimiters

**Fix:**
```bash
# Semicolon-separated
mlr --icsv --ifs ";" --ocsv cat data.csv

# Pipe-separated
mlr --icsv --ifs "|" --ocsv cat data.csv
```

## Dependencies

- **Miller (mlr)** — Swiss-army knife for CSV/JSON (v6+)
- **csvkit** — Python CSV utilities with SQL support
- **xsv** — Rust-based CSV processor (fastest for large files)
- Optional: `sqlite3` (for SQL import/export)
