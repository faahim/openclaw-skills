---
name: data-processor
description: >-
  Transform, filter, join, and analyze CSV/JSON/TSV data files using powerful CLI tools (csvkit, miller, jq).
categories: [data, productivity]
dependencies: [csvkit, miller, jq, python3]
---

# Data Processor

## What This Does

Process structured data files (CSV, JSON, TSV, Excel) directly from the command line — filter rows, convert formats, join datasets, compute statistics, and generate reports. Powered by csvkit, miller (mlr), and jq.

**Example:** "Convert 50MB CSV to JSON, filter rows where revenue > 10000, group by region, compute averages — all in one pipeline."

## Quick Start (3 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

### 2. Try It

```bash
# Convert CSV to JSON
mlr --icsv --ojson cat data.csv

# Filter rows
csvgrep -c status -m "active" customers.csv

# Get column statistics
csvstat sales.csv

# Pretty-print JSON
cat data.json | jq '.'
```

## Core Workflows

### Workflow 1: Format Conversion

Convert between CSV, JSON, TSV, NDJSON, Markdown tables, and Excel.

```bash
# CSV → JSON
mlr --icsv --ojson cat input.csv > output.json

# JSON → CSV
mlr --ijson --ocsv cat input.json > output.csv

# CSV → Markdown table
mlr --icsv --omarkdown cat input.csv

# Excel → CSV
in2csv spreadsheet.xlsx > output.csv

# Excel → CSV (specific sheet)
in2csv --sheet "Sheet2" spreadsheet.xlsx > output.csv

# CSV → TSV
mlr --icsv --otsv cat input.csv > output.tsv

# JSON array → NDJSON (one object per line)
cat input.json | jq -c '.[]' > output.ndjson

# NDJSON → JSON array
cat input.ndjson | jq -s '.' > output.json
```

### Workflow 2: Filter & Search

Find specific rows matching conditions.

```bash
# Filter by exact value
csvgrep -c country -m "Bangladesh" sales.csv

# Filter by regex
csvgrep -c email -r "@gmail\.com$" users.csv

# Filter by numeric condition (miller)
mlr --csv filter '$revenue > 10000' sales.csv

# Multiple conditions
mlr --csv filter '$revenue > 10000 && $region == "Asia"' sales.csv

# Exclude rows
csvgrep -c status -m "cancelled" -i orders.csv

# Filter JSON arrays
cat data.json | jq '[.[] | select(.age > 25 and .country == "BD")]'

# Top N rows
head -n 11 data.csv  # header + 10 rows

# Random sample
mlr --csv sample -k 100 large_file.csv
```

### Workflow 3: Transform & Reshape

Add columns, rename fields, reshape data.

```bash
# Select specific columns
csvcut -c name,email,phone contacts.csv

# Reorder columns
csvcut -c 3,1,2 data.csv

# Rename columns
mlr --csv rename "old_name,new_name" data.csv

# Add computed column
mlr --csv put '$profit = $revenue - $cost' sales.csv

# Convert date formats
mlr --csv put '$date = strftime(strptime($date, "%m/%d/%Y"), "%Y-%m-%d")' data.csv

# Uppercase a field
mlr --csv put '$name = toupper($name)' data.csv

# Remove duplicates
mlr --csv uniq -f email contacts.csv

# Sort by column
csvsort -c revenue -r sales.csv  # -r for reverse (descending)

# Sort by multiple columns
mlr --csv sort-by region,revenue sales.csv
```

### Workflow 4: Aggregate & Statistics

Compute summaries, group-bys, and statistics.

```bash
# Column statistics (min, max, mean, median, stdev, etc.)
csvstat sales.csv

# Stats for specific column
csvstat -c revenue sales.csv

# Group by + aggregate
mlr --csv stats1 -a mean,sum,count -f revenue -g region sales.csv

# Group by + multiple aggregations
mlr --csv stats1 -a min,max,mean,p50,p90 -f response_time -g endpoint logs.csv

# Count by category
mlr --csv count-distinct -f category products.csv

# Histogram
mlr --csv decimate -g status -n 1 orders.csv

# Cross-tabulation
mlr --csv count-distinct -f region,status orders.csv

# Running totals
mlr --csv step -a rsum -f revenue sales.csv

# JSON aggregation
cat sales.json | jq 'group_by(.region) | map({region: .[0].region, total: (map(.revenue) | add), count: length})'
```

### Workflow 5: Join & Merge Datasets

Combine data from multiple files.

```bash
# Inner join on shared column
csvjoin -c id customers.csv orders.csv

# Left join
csvjoin --left -c id customers.csv orders.csv

# Join on differently-named columns
csvjoin -c customer_id,id orders.csv customers.csv

# Stack/concatenate files (same columns)
csvstack file1.csv file2.csv file3.csv > combined.csv

# Stack with source tracking
csvstack -g "jan,feb,mar" -n month jan.csv feb.csv mar.csv > quarterly.csv

# Miller join
mlr --csv join -j id -f customers.csv orders.csv
```

### Workflow 6: Data Quality & Cleanup

Validate, deduplicate, and fix data issues.

```bash
# Check for problems (encoding, row length mismatches)
csvclean data.csv

# Show column names and positions
csvcut -n data.csv

# Count rows
wc -l data.csv  # includes header, subtract 1

# Find empty/null values in a column
csvgrep -c email -r "^$" contacts.csv

# Remove rows with empty values
mlr --csv filter 'strlen($email) > 0' contacts.csv

# Trim whitespace
mlr --csv put 'for (k in $*) { $[k] = lstrip(rstrip($[k])) }' data.csv

# Deduplicate
mlr --csv uniq -a data.csv

# Validate JSON
cat data.json | jq empty && echo "Valid" || echo "Invalid"

# Fix common CSV issues (BOM, line endings)
sed '1s/^\xEF\xBB\xBF//' data.csv | tr -d '\r' > clean.csv
```

### Workflow 7: SQL-Style Queries

Use csvsql for full SQL power on CSV files.

```bash
# SQL query on CSV
csvsql --query "SELECT region, SUM(revenue) as total FROM sales GROUP BY region ORDER BY total DESC" sales.csv

# Join with SQL
csvsql --query "SELECT c.name, o.amount FROM customers c JOIN orders o ON c.id = o.customer_id WHERE o.amount > 100" customers.csv orders.csv

# Insert CSV into SQLite
csvsql --db sqlite:///analysis.db --insert sales.csv

# Query from SQLite
sql2csv --db sqlite:///analysis.db --query "SELECT * FROM sales WHERE revenue > 10000"
```

### Workflow 8: JSON Processing (jq)

Advanced JSON transformations.

```bash
# Extract nested fields
cat data.json | jq '.users[] | {name: .name, city: .address.city}'

# Flatten nested JSON
cat data.json | jq '[.[] | {id, name, street: .address.street, city: .address.city}]'

# Build new structure
cat data.json | jq '{total: length, active: [.[] | select(.active)] | length}'

# Update values
cat data.json | jq '.[].status = "processed"'

# Delete keys
cat data.json | jq 'del(.[].internal_id)'

# Merge JSON files
jq -s '.[0] * .[1]' base.json overrides.json

# Convert JSON to CSV manually
cat data.json | jq -r '(.[0] | keys_unsorted) as $keys | $keys, (.[] | [.[$keys[]]] ) | @csv'
```

## Pipeline Examples

Chain commands for complex transformations:

```bash
# Full pipeline: Excel → filter → aggregate → JSON
in2csv sales.xlsx | \
  csvgrep -c region -m "Asia" | \
  csvsort -c revenue -r | \
  mlr --csv stats1 -a sum,mean -f revenue -g country | \
  mlr --icsv --ojson cat

# Clean → dedupe → analyze
csvclean raw.csv && \
  mlr --csv uniq -a raw_err.csv | \
  mlr --csv sort-by -nr revenue | \
  csvstat -c revenue

# Multi-file merge and report
csvstack -g "Q1,Q2,Q3,Q4" -n quarter q*.csv | \
  mlr --csv stats1 -a sum,mean,count -f revenue -g quarter | \
  mlr --icsv --omarkdown cat
```

## Troubleshooting

### "csvkit not found"

```bash
pip3 install csvkit
```

### "mlr not found"

```bash
# Ubuntu/Debian
sudo apt-get install miller

# Mac
brew install miller

# Or download binary
curl -L -o /usr/local/bin/mlr https://github.com/johnkerl/miller/releases/latest/download/mlr-linux-amd64
chmod +x /usr/local/bin/mlr
```

### "UnicodeDecodeError" on CSV

```bash
# Detect encoding
file -bi data.csv

# Convert to UTF-8
iconv -f ISO-8859-1 -t UTF-8 data.csv > data_utf8.csv
```

### Large files (>1GB) running slow

```bash
# Use miller (faster than csvkit for large files)
mlr --csv filter '$amount > 100' huge.csv > filtered.csv

# Or use awk for simple filters (fastest)
awk -F',' 'NR==1 || $3 > 100' huge.csv > filtered.csv
```

### Excel file with multiple sheets

```bash
# List sheets
in2csv --names spreadsheet.xlsx

# Convert specific sheet
in2csv --sheet "Revenue" spreadsheet.xlsx > revenue.csv
```

## Dependencies

- `python3` (3.8+) — for csvkit
- `csvkit` — CSV Swiss Army knife (csvcut, csvgrep, csvsort, csvjoin, csvstat, csvsql, in2csv)
- `miller` (mlr) — high-performance data processor
- `jq` — JSON processor
- Optional: `sqlite3` (for csvsql database features)
