# Listing Copy: PostgreSQL Tuner

## Metadata
- **Type:** Skill
- **Name:** postgres-tuner
- **Display Name:** PostgreSQL Tuner
- **Categories:** [dev-tools, data]
- **Icon:** 🐘
- **Dependencies:** [bash, postgresql]

## Tagline

Optimize PostgreSQL config in seconds — auto-tune 20+ parameters for your hardware and workload.

## Description

Most PostgreSQL installations run on default settings designed for a laptop with 512MB of RAM. That means your production server with 16GB is using ~2% of its potential. Manually tuning shared_buffers, work_mem, and WAL settings requires deep knowledge of both PostgreSQL internals and your system hardware.

PostgreSQL Tuner analyzes your system's RAM, CPU cores, and disk type, then generates a fully optimized `postgresql.conf` tailored to your specific workload — web application, OLTP, data warehouse, or mixed. It tunes 20+ parameters including memory allocation, WAL checkpoints, parallel query workers, and query planner costs. No guesswork, no memorizing formulas.

**What it does:**
- 🔍 Auto-detects RAM, CPUs, disk type, and PG version
- ⚡ Generates optimized config for web/OLTP/DW/mixed workloads
- 📋 Side-by-side diff of current vs recommended settings
- 🔄 Safe apply with automatic backup and rollback support
- 🐘 Tunes shared_buffers, work_mem, WAL, parallelism, autovacuum
- 🖥️ Works on bare metal, VMs, and containers (with manual overrides)

Perfect for developers, DBAs, and DevOps engineers who want PostgreSQL running at peak performance without becoming a tuning expert.

## Quick Start Preview

```bash
bash scripts/tune.sh --workload web

# Output:
# 🔍 System: 8192 MB RAM | 4 CPUs | SSD
# 📊 shared_buffers = 2GB | work_mem = 10MB | effective_cache_size = 6GB
# 💾 Config written to: /tmp/postgresql-tuned.conf
```

## Core Capabilities

1. System resource detection — Auto-detects RAM, CPUs, disk type, PG version
2. Workload-specific tuning — Web, OLTP, Data Warehouse, or Mixed profiles
3. Memory optimization — Calculates shared_buffers, work_mem, effective_cache_size
4. WAL tuning — Optimizes checkpoints, wal_buffers, compression
5. Parallel query config — Sets max_parallel_workers based on CPU count
6. Query planner costs — Adjusts random_page_cost for SSD vs HDD
7. Autovacuum tuning — Optimizes vacuum frequency and thresholds
8. Safe apply mode — Backup before apply, easy rollback
9. Config diff — Compare current settings vs recommended
10. Container support — Override detected values for Docker/Kubernetes
