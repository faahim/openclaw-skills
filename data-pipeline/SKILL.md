---
name: data-pipeline
description: >-
  Transform, filter, join, and aggregate CSV/JSON/TSV data files using Miller, csvkit, and jq.
categories: [data, automation]
dependencies: [miller, csvkit, jq]
---

# Data Pipeline Tool

## What This Does

Process large CSV, JSON, and TSV files directly from the command line — filter rows, transform columns, join datasets, aggregate stats, and convert between formats. Uses Miller (mlr), csvkit, and jq — tools purpose-built for data wrangling that handle millions of rows without loading everything into memory.

**Example:** "Filter a 500MB CSV to rows where revenue > 10000, join with a customer lookup table, group by region, and export as JSON."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

This installs:
- **Miller (mlr)** — Swiss army knife for CSV/JSON/TSV
- **csvkit** — CSV-specific tools (csvcut, csvgrep, csvsql, csvstat)
- **jq** — JSON processor (likely already installed)

### 2. Verify Installation

```bash
bash scripts/install.sh --check
```

### 3. Run Your First Transform

```bash
# Convert CSV to JSON
mlr --icsv --ojson cat data.csv

# Filter rows
mlr --csv filter '$revenue > 10000' sales.csv

# Get column stats
csvstat sales.csv
```

## Core Workflows

### Workflow 1: Filter & Transform CSV

**Use case:** Extract specific rows and columns from a large dataset

```bash
# Filter rows where status is "active" and revenue > 5000
mlr --csv filter '$status == "active" && $revenue > 5000' input.csv > filtered.csv

# Select only specific columns
mlr --csv cut -f name,email,revenue filtered.csv > output.csv

# Or combine in one pipeline
mlr --csv filter '$status == "active" && $revenue > 5000' then cut -f name,email,revenue input.csv > output.csv
```

### Workflow 2: Join Two Datasets

**Use case:** Merge customer info with order data

```bash
# Join orders.csv with customers.csv on customer_id
mlr --csv join -j customer_id -f customers.csv orders.csv > enriched.csv

# Left join (keep all orders even without customer match)
mlr --csv join -j customer_id -f customers.csv --lp "cust_" --np orders.csv > enriched.csv
```

### Workflow 3: Aggregate & Group By

**Use case:** Summarize sales by region/category

```bash
# Sum revenue by region
mlr --csv stats1 -a sum -f revenue -g region sales.csv

# Multiple aggregations
mlr --csv stats1 -a sum,mean,count -f revenue,quantity -g region,category sales.csv

# Top N by group
mlr --csv top -n 5 -f revenue -g category sales.csv
```

### Workflow 4: Format Conversion

**Use case:** Convert between CSV, JSON, TSV, and other formats

```bash
# CSV → JSON
mlr --icsv --ojson cat data.csv > data.json

# JSON → CSV
mlr --ijson --ocsv cat data.json > data.csv

# CSV → TSV
mlr --icsv --otsv cat data.csv > data.tsv

# JSON array → CSV (flatten nested)
mlr --ijson --ocsv cat nested.json > flat.csv

# Pretty-print JSON
cat data.json | jq '.'

# CSV → Markdown table
mlr --icsv --omarkdown cat data.csv
```

### Workflow 5: Data Cleaning

**Use case:** Fix messy data — dedup, trim, normalize

```bash
# Remove duplicate rows
mlr --csv uniq -a data.csv > deduped.csv

# Remove duplicates by specific field
mlr --csv uniq -f email data.csv > deduped.csv

# Trim whitespace from all fields
mlr --csv put 'for (k in $*) { $[k] = lstrip(rstrip($[k])) }' data.csv > cleaned.csv

# Rename columns
mlr --csv rename 'old_name,new_name,another_old,another_new' data.csv > renamed.csv

# Fill empty fields with default
mlr --csv put 'if ($country == "") { $country = "Unknown" }' data.csv > filled.csv

# Sort by column
mlr --csv sort-by -nr revenue data.csv > sorted.csv
```

### Workflow 6: SQL Queries on CSV

**Use case:** Run SQL against CSV files without a database

```bash
# Query with SQL syntax
csvsql --query "SELECT region, SUM(revenue) as total FROM sales GROUP BY region ORDER BY total DESC" sales.csv

# Join with SQL
csvsql --query "SELECT o.*, c.name FROM orders AS o JOIN customers AS c ON o.customer_id = c.id" orders.csv customers.csv

# Filter with complex conditions
csvsql --query "SELECT * FROM data WHERE date BETWEEN '2026-01-01' AND '2026-06-30' AND amount > 1000" data.csv
```

### Workflow 7: JSON Processing with jq

**Use case:** Extract and transform JSON API responses

```bash
# Extract specific fields from JSON array
cat api_response.json | jq '[.data[] | {name: .name, email: .email}]'

# Filter JSON objects
cat data.json | jq '[.[] | select(.status == "active")]'

# Aggregate in jq
cat sales.json | jq '[.[].revenue] | add'

# Flatten nested JSON
cat nested.json | jq '[.[] | {id, name, city: .address.city, zip: .address.zip}]'

# Group by field
cat data.json | jq 'group_by(.category) | map({category: .[0].category, count: length})'
```

### Workflow 8: Batch Pipeline Script

**Use case:** Automate a multi-step data pipeline

```bash
bash scripts/run-pipeline.sh \
  --input raw_data.csv \
  --output report.json \
  --steps "filter:revenue>1000,join:customers.csv:customer_id,group:region:sum:revenue,sort:-total,format:json"
```

## Configuration

### Environment Variables

```bash
# Default output format (csv, json, tsv, markdown)
export DATA_PIPELINE_FORMAT="csv"

# Default delimiter for input files
export DATA_PIPELINE_DELIMITER=","

# Max rows to preview (head command)
export DATA_PIPELINE_PREVIEW=20
```

## Advanced Usage

### Stream Processing (Large Files)

Miller processes data in streaming mode — it doesn't load the entire file:

```bash
# Process a 10GB file without running out of memory
mlr --csv filter '$amount > 100' huge_file.csv > filtered.csv

# Count rows without loading file
mlr --csv count-distinct -f category huge_file.csv
```

### Chaining Operations

```bash
# Complex pipeline: filter → transform → join → aggregate → sort → format
mlr --csv \
  filter '$date >= "2026-01-01"' \
  then put '$quarter = "Q" . string(int((int(splita($date, "-")[2]) - 1) / 3) + 1)' \
  then join -j customer_id -f customers.csv \
  then stats1 -a sum,count -f revenue -g quarter,region \
  then sort-by -nr revenue_sum \
  then head -n 20 \
  sales.csv
```

### Cron-Ready Reports

```bash
# Generate daily sales summary
0 8 * * * cd /data && mlr --csv stats1 -a sum,mean -f revenue -g category today.csv | mlr --icsv --ojson cat >> /reports/daily-$(date +\%Y-\%m-\%d).json
```

## Troubleshooting

### Issue: "mlr: command not found"

```bash
# Re-run installer
bash scripts/install.sh

# Or install manually
# Ubuntu/Debian
sudo apt-get install miller

# Mac
brew install miller

# From source
curl -L https://github.com/johnkerl/miller/releases/latest/download/mlr-linux-amd64 -o /usr/local/bin/mlr && chmod +x /usr/local/bin/mlr
```

### Issue: "csvkit not found"

```bash
pip3 install csvkit
```

### Issue: CSV encoding errors

```bash
# Convert encoding first
iconv -f latin1 -t utf-8 input.csv > input_utf8.csv

# Or tell miller to handle it
mlr --csv --ifs ";" cat european_data.csv
```

### Issue: CSV with different delimiters

```bash
# Semicolon-delimited
mlr --icsv --ifs ";" --ocsv cat european.csv > standard.csv

# Tab-delimited
mlr --itsv --ocsv cat data.tsv > data.csv

# Pipe-delimited
mlr --icsv --ifs "|" --ocsv cat data.txt > data.csv
```

## Quick Reference

| Task | Command |
|------|---------|
| Preview first 10 rows | `mlr --csv head -n 10 data.csv` |
| Count rows | `mlr --csv count-distinct -f id data.csv` |
| Column stats | `csvstat data.csv` |
| Unique values | `mlr --csv uniq -f column data.csv` |
| Find duplicates | `mlr --csv count-distinct -f email data.csv \| mlr --csv filter '$count > 1'` |
| Search rows | `csvgrep -c name -m "John" data.csv` |
| Add column | `mlr --csv put '$total = $price * $qty' data.csv` |
| Delete column | `mlr --csv cut -x -f unwanted_col data.csv` |
| Frequency table | `mlr --csv count-distinct -f category data.csv` |
| Sample rows | `mlr --csv sample -k 100 data.csv` |

## Dependencies

- **Miller (mlr)** 6.0+ — CSV/JSON/TSV processor
- **csvkit** 1.1+ — CSV toolkit (csvcut, csvgrep, csvsql, csvstat)
- **jq** 1.6+ — JSON processor
- **Python 3** — Required by csvkit
- Optional: `iconv` (encoding conversion)
