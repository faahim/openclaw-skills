---
name: csv-analyzer
description: >-
  Analyze, filter, transform, and summarize CSV/JSON/TSV data files using Miller (mlr) — the Swiss Army knife for structured data.
categories: [data, analytics]
dependencies: [miller, bash]
---

# CSV Analyzer

## What This Does

Analyze CSV, JSON, and TSV files directly from the command line using Miller (`mlr`). Filter rows, compute statistics, group and aggregate data, join files, convert formats, and generate reports — all without loading data into a database or spreadsheet.

**Example:** "Show me the top 10 customers by revenue from a 500MB sales CSV, grouped by region."

## Quick Start (2 minutes)

### 1. Install Miller

```bash
bash scripts/install.sh
```

### 2. Analyze a CSV

```bash
# Basic stats on all numeric columns
bash scripts/analyze.sh stats sales.csv

# Filter rows
bash scripts/analyze.sh filter sales.csv 'revenue > 1000'

# Top N by column
bash scripts/analyze.sh top sales.csv revenue 10

# Group and summarize
bash scripts/analyze.sh group sales.csv region 'sum:revenue,count'
```

## Core Workflows

### Workflow 1: Quick Statistics

**Use case:** Get instant stats on any CSV file

```bash
bash scripts/analyze.sh stats data.csv
```

**Output:**
```
=== File: data.csv ===
Rows: 15,234
Columns: name, email, revenue, region, date

=== Numeric Column Stats ===
field    count   min     max      mean      sum
revenue  15234   0.50    9999.00  487.32    7,422,100.88
```

### Workflow 2: Filter & Search

**Use case:** Find specific rows matching criteria

```bash
# Simple filter
bash scripts/analyze.sh filter orders.csv 'status == "shipped" && total > 500'

# Search text in any column
bash scripts/analyze.sh search customers.csv "john"

# Date range filter
bash scripts/analyze.sh filter logs.csv 'date >= "2026-01-01" && date <= "2026-01-31"'
```

### Workflow 3: Group & Aggregate

**Use case:** Summarize data by categories

```bash
# Sum revenue by region
bash scripts/analyze.sh group sales.csv region 'sum:revenue'

# Count orders by status
bash scripts/analyze.sh group orders.csv status 'count'

# Multiple aggregations
bash scripts/analyze.sh group sales.csv region 'sum:revenue,mean:revenue,count,max:revenue'
```

**Output:**
```
region    revenue_sum    revenue_mean  count  revenue_max
North     2,345,678.00   523.45       4482   9,999.00
South     1,876,543.00   412.33       4551   8,765.00
East      1,654,321.00   498.90       3316   9,234.00
West      1,545,558.88   534.12       2885   9,100.00
```

### Workflow 4: Sort & Top/Bottom N

**Use case:** Find highest/lowest values

```bash
# Top 10 by revenue
bash scripts/analyze.sh top sales.csv revenue 10

# Bottom 5 by score
bash scripts/analyze.sh bottom results.csv score 5

# Sort by multiple columns
bash scripts/analyze.sh sort data.csv "region,revenue" "desc"
```

### Workflow 5: Format Conversion

**Use case:** Convert between CSV, JSON, TSV, Markdown table

```bash
# CSV to JSON
bash scripts/analyze.sh convert data.csv json

# JSON to CSV
bash scripts/analyze.sh convert data.json csv

# CSV to Markdown table
bash scripts/analyze.sh convert data.csv markdown

# CSV to TSV
bash scripts/analyze.sh convert data.csv tsv
```

### Workflow 6: Join Two Files

**Use case:** Merge data from multiple files

```bash
# Join orders with customers on customer_id
bash scripts/analyze.sh join orders.csv customers.csv customer_id
```

### Workflow 7: Deduplicate

**Use case:** Remove duplicate rows

```bash
# Deduplicate by email column
bash scripts/analyze.sh dedup contacts.csv email

# Full row deduplication
bash scripts/analyze.sh dedup data.csv
```

### Workflow 8: Column Operations

**Use case:** Select, rename, or add columns

```bash
# Select specific columns
bash scripts/analyze.sh select data.csv "name,email,revenue"

# Add a calculated column
bash scripts/analyze.sh calc data.csv 'margin = revenue - cost'

# Rename columns
bash scripts/analyze.sh rename data.csv 'old_name=new_name,amt=amount'
```

### Workflow 9: Frequency Count

**Use case:** Count occurrences of values

```bash
# How many orders per status?
bash scripts/analyze.sh freq orders.csv status

# Top 20 most common cities
bash scripts/analyze.sh freq customers.csv city 20
```

**Output:**
```
status      count  percent
shipped     8234   54.1%
pending     4521   29.7%
cancelled   1456   9.6%
returned    1023   6.7%
```

### Workflow 10: Sample & Preview

**Use case:** Inspect large files without loading everything

```bash
# Preview first 5 rows (pretty-printed)
bash scripts/analyze.sh head data.csv 5

# Random sample of 100 rows
bash scripts/analyze.sh sample data.csv 100

# Tail (last N rows)
bash scripts/analyze.sh tail data.csv 10
```

## Advanced Usage

### Chain Operations with Miller Directly

```bash
# Complex pipeline: filter → group → sort → top 5
mlr --csv \
  filter '$region == "North"' \
  then group-by category \
  then stats1 -a sum,count -f revenue \
  then sort-nr revenue_sum \
  then head -n 5 \
  sales.csv
```

### Process Large Files (streaming)

Miller processes data line-by-line, so it handles files larger than RAM:

```bash
# Works on multi-GB files
bash scripts/analyze.sh stats huge_file.csv
bash scripts/analyze.sh filter huge_file.csv 'amount > 10000' > filtered.csv
```

### Pipe from Other Commands

```bash
# Analyze API response
curl -s 'https://api.example.com/data' | mlr --json stats1 -a mean,sum -f value

# Process command output
ps aux | mlr --nidx --ifs space stats1 -a max -f 4
```

## Troubleshooting

### Issue: "mlr: command not found"

**Fix:** Run `bash scripts/install.sh` or install manually:
```bash
# Ubuntu/Debian
sudo apt-get install miller

# Mac
brew install miller

# From binary
curl -L -o mlr https://github.com/johnkerl/miller/releases/latest/download/mlr-linux-amd64
chmod +x mlr && sudo mv mlr /usr/local/bin/
```

### Issue: "CSV header not found"

**Fix:** Your file might not have headers. Use `--implicit-csv-header`:
```bash
mlr --csv --implicit-csv-header label name,age,score data.csv
```

### Issue: Wrong delimiter

**Fix:** Specify the delimiter:
```bash
# Semicolon-separated
mlr --csvlite --ifs ';' stats1 -a mean -f value data.csv

# Pipe-separated
mlr --csvlite --ifs '|' head -n 5 data.csv
```

## Dependencies

- `miller` (mlr) — 6.0+ recommended
- `bash` (4.0+)
- `awk` (fallback for basic ops)
- `column` (for pretty output formatting)
