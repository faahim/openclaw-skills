# Listing Copy: CSV Toolkit

## Metadata
- **Type:** Skill
- **Name:** csv-toolkit
- **Display Name:** CSV Toolkit
- **Categories:** [data, productivity]
- **Icon:** 📊
- **Dependencies:** [miller, csvkit, xsv]

## Tagline

Parse, filter, sort, join, and convert CSV data files with fast CLI tools

## Description

Working with CSV files shouldn't mean opening Excel or writing one-off Python scripts. When you need to filter 500MB of transaction data, join two CSVs by a common column, or convert formats between CSV, JSON, and SQL — you need real tools.

CSV Toolkit installs and configures three best-in-class CLI data processors: **Miller (mlr)** for transformations and format conversion, **xsv** for blazing-fast search and sorting, and **csvkit** for SQL queries directly on CSV files. Your OpenClaw agent can then process data files in seconds.

**What it does:**
- 📊 Inspect — headers, row counts, column statistics, frequency tables
- 🔍 Filter — numeric conditions, regex search, date ranges
- 🔄 Transform — rename columns, compute new fields, reshape data
- ⚡ Sort & deduplicate — by any column, ascending/descending
- 📈 Aggregate — group-by, sum, mean, percentiles, histograms
- 🔗 Join — merge CSVs by matching columns, stack files
- 🔄 Convert — CSV ↔ JSON ↔ TSV ↔ Markdown ↔ SQL
- ✂️ Split — break large files into chunks, sample random rows

Perfect for developers, data analysts, and anyone who regularly works with structured data files.

## Core Capabilities

1. Data inspection — instant headers, row counts, and column stats
2. Row filtering — numeric, string, regex, and date-based conditions
3. Column transforms — select, rename, reorder, compute new fields
4. Multi-format conversion — CSV, JSON, NDJSON, TSV, Markdown, SQL
5. Aggregation — group-by with sum, mean, count, percentiles
6. File joining — inner joins, concatenation, side-by-side merge
7. SQL on CSV — run SELECT/JOIN/GROUP BY queries directly on files
8. Large file handling — index files for instant random access
9. Deduplication — remove duplicates by all or specific columns
10. Sorting — by any column, numeric or alphabetic, multi-key
11. Splitting — chunk large files or split by column value
12. SQLite import — load CSVs into SQLite for complex queries

## Dependencies
- Miller (mlr) — v6+
- csvkit — Python-based CSV utilities
- xsv — Rust-based CSV processor

## Installation Time
**5 minutes** — automated install script handles all three tools
