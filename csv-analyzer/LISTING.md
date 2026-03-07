# Listing Copy: CSV Analyzer

## Metadata
- **Type:** Skill
- **Name:** csv-analyzer
- **Display Name:** CSV Analyzer
- **Categories:** [data, analytics]
- **Price:** $10
- **Dependencies:** [miller, bash]

## Tagline

Analyze, filter, and transform CSV/JSON/TSV data — instant insights from any structured file

## Description

Working with CSV files shouldn't require loading a spreadsheet or spinning up a database. Yet every developer and data analyst has been there — a 500MB export, a quick question, and no fast way to answer it.

CSV Analyzer uses Miller (mlr), the Swiss Army knife for structured data, to give your OpenClaw agent instant analytical superpowers. Filter rows, compute statistics, group and aggregate, join files, convert formats, and find patterns — all streaming, so it handles files larger than your RAM.

**What it does:**
- 📊 Instant statistics on all numeric columns (min, max, mean, sum)
- 🔍 Filter rows with expressions (`revenue > 1000 && status == "shipped"`)
- 📈 Group-by with aggregations (sum, mean, count, min, max)
- 🏆 Top/bottom N by any column
- 🔄 Convert between CSV, JSON, TSV, and Markdown tables
- 🔗 Join two files on a shared column
- 🧹 Deduplicate rows by any column
- 📐 Add calculated columns, rename, select
- 🎲 Random sampling for large file inspection

Perfect for developers, data analysts, and anyone who regularly works with structured data files and wants answers in seconds, not minutes.

## Quick Start Preview

```bash
# Get stats on a CSV
bash scripts/analyze.sh stats sales.csv

# Top 10 customers by revenue
bash scripts/analyze.sh top sales.csv revenue 10

# Group by region, sum revenue
bash scripts/analyze.sh group sales.csv region 'sum:revenue,count'
```

## Installation Time
**2 minutes** — Install Miller, run commands
