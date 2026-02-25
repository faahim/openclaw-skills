# Listing Copy: DuckDB Analytics Tool

## Metadata
- **Type:** Skill
- **Name:** duckdb-analytics
- **Display Name:** DuckDB Analytics Tool
- **Categories:** [data, analytics]
- **Price:** $12
- **Dependencies:** [bash, curl, unzip]

## Tagline (50-80 chars)

"Query CSV, JSON & Parquet files with SQL — no database server needed"

## Description

Working with data files shouldn't require spinning up a database server, writing import scripts, or wrestling with pandas. But when your CSV hits 100MB+, grep and awk stop cutting it.

DuckDB Analytics Tool installs the DuckDB CLI and gives your OpenClaw agent the power to run full SQL queries directly on CSV, JSON, and Parquet files. No server process, no imports, no schema definitions — just point at a file and query. It handles joins across multiple files, window functions, aggregations, and can export results to any format.

**What it does:**
- 🦆 One-command install (auto-detects OS + architecture)
- 📊 SQL queries on CSV, JSON, Parquet — no import step
- 🔗 JOIN multiple files, glob patterns (`logs/*.csv`)
- 📈 Built-in SUMMARIZE for instant column statistics
- 💾 Export to CSV, JSON, Parquet, or persistent database
- 🌐 Query remote files (HTTP URLs, S3 buckets)
- 📋 Auto-generate markdown data reports
- ⚡ Columnar engine — handles GB-scale files on a laptop

Perfect for developers, data analysts, and anyone who needs to quickly explore, transform, or report on data files without the overhead of a full database.

## Core Capabilities

1. Install DuckDB CLI — Auto-detect platform, single command setup
2. Query any data file — CSV, JSON, Parquet with standard SQL
3. Schema detection — Auto-infer column names and types
4. Aggregation & analytics — GROUP BY, window functions, CTEs
5. Multi-file joins — JOIN across different CSV/JSON files
6. Glob queries — Query all files matching a pattern
7. Format conversion — CSV↔JSON↔Parquet with COPY
8. Data reports — Generate markdown summaries automatically
9. Remote files — Query URLs and S3 paths directly
10. Persistent databases — Save results for repeated analysis

## Installation Time
**2 minutes** — Run install script, start querying
