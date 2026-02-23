# Listing Copy: Data Pipeline Tool

## Metadata
- **Type:** Skill
- **Name:** data-pipeline
- **Display Name:** Data Pipeline Tool
- **Categories:** [data, automation]
- **Price:** $10
- **Dependencies:** [miller, csvkit, jq, python3]

## Tagline

"Transform, filter, join & aggregate CSV/JSON data — no database needed"

## Description

Working with data files shouldn't require spinning up a database or writing throwaway Python scripts. Whether it's a 500MB export from your CRM, API response logs, or messy CSVs from a client — you need to filter, transform, and analyze it fast.

Data Pipeline Tool installs and configures three battle-tested CLI tools — Miller (mlr), csvkit, and jq — and gives your OpenClaw agent ready-made workflows for every common data task. Filter rows, join datasets, aggregate by groups, convert between formats, clean duplicates, and run SQL queries directly on CSV files.

**What it does:**
- 🔄 Convert between CSV, JSON, TSV, and Markdown instantly
- 🔍 Filter and search across millions of rows (streaming, low memory)
- 🔗 Join datasets on shared keys (like SQL JOINs on flat files)
- 📊 Aggregate stats: sum, mean, count, min, max — grouped by any column
- 🧹 Clean data: dedup, trim whitespace, fill blanks, normalize
- 💾 Run SQL queries directly on CSV files (no database needed)
- ⚡ Multi-step pipeline script for chaining operations
- 📦 One-command installer for all dependencies

Perfect for developers, data analysts, and anyone who regularly wrangles CSV/JSON data and wants their agent to handle it properly.

## Core Capabilities

1. Format conversion — CSV ↔ JSON ↔ TSV ↔ Markdown in one command
2. Row filtering — Complex conditions on any column, streaming mode
3. Column operations — Select, rename, add computed columns, delete
4. Dataset joins — Inner/left/right joins on shared keys
5. Aggregation — Group-by with sum/mean/count/min/max
6. SQL on CSV — Full SQL queries without a database (via csvsql)
7. Data cleaning — Dedup, trim, fill blanks, normalize values
8. Batch pipelines — Chain multiple steps in a single command
9. Large file support — Streaming processing, handles GB-scale files
10. Cross-platform — Works on Linux, macOS, ARM/x86

## Dependencies
- Miller (mlr) 6.0+
- csvkit 1.1+
- jq 1.6+
- Python 3

## Installation Time
**5 minutes** — Run install script, start processing
