# Listing Copy: Data Processor

## Metadata
- **Type:** Skill
- **Name:** data-processor
- **Display Name:** Data Processor
- **Categories:** [data, productivity]
- **Price:** $10
- **Dependencies:** [csvkit, miller, jq, python3]
- **Icon:** 📊

## Tagline

Transform, filter, and analyze CSV/JSON data — SQL-like power from the command line

## Description

Working with data files shouldn't mean opening a spreadsheet or writing a script from scratch. Whether you're cleaning a messy CSV export, converting formats, joining datasets, or computing aggregates — you need tools that just work.

Data Processor gives your OpenClaw agent instant access to three of the most powerful CLI data tools: **csvkit** (the CSV Swiss Army knife), **miller** (high-performance structured data processor), and **jq** (the JSON processor). One install script, 8 ready-to-use workflows.

**What it does:**
- 🔄 Convert between CSV, JSON, TSV, Excel, NDJSON, and Markdown tables
- 🔍 Filter and search with regex, numeric conditions, and multi-field queries
- 📊 Compute statistics: mean, median, sum, percentiles, group-by aggregates
- 🔗 Join and merge datasets (inner, left, stack/concatenate)
- 🧹 Clean data: deduplicate, trim whitespace, fix encoding, validate
- 🗄️ Run SQL queries directly on CSV files (no database needed)
- ⚡ Handle large files (1GB+) efficiently with miller's streaming processor
- 🔧 Full jq integration for nested JSON transformations

Perfect for developers, data analysts, and anyone who regularly works with structured data files.

## Core Capabilities

1. Format conversion — CSV ↔ JSON ↔ TSV ↔ Excel ↔ Markdown in one command
2. Row filtering — Exact match, regex, numeric conditions, multi-field AND/OR
3. Column operations — Select, reorder, rename, add computed columns
4. Aggregation — Group-by with sum/mean/count/min/max/percentiles
5. Dataset joins — Inner join, left join, concatenation with source tracking
6. SQL queries — Full SQL on CSV files via csvsql + SQLite
7. JSON processing — Flatten, reshape, filter, merge nested structures
8. Data validation — Detect encoding issues, find nulls, check row consistency
9. Large file support — Miller streams data (no memory limits)
10. One-command install — Single script installs all dependencies

## Dependencies
- python3 (3.8+)
- csvkit
- miller (mlr)
- jq

## Installation Time
**3 minutes** — run install.sh, start processing
