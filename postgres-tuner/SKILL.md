---
name: postgres-tuner
description: >-
  Analyze system resources and generate optimized PostgreSQL configuration. Auto-tunes shared_buffers, work_mem, effective_cache_size, and 20+ parameters.
categories: [dev-tools, data]
dependencies: [bash, postgresql]
---

# PostgreSQL Tuner

## What This Does

Inspects your system's RAM, CPU cores, and disk type, then generates an optimized `postgresql.conf` tuned for your workload (web, OLTP, data warehouse, or mixed). Replaces guesswork with calculated settings based on PostgreSQL best practices and pgtune algorithms.

**Example:** "Analyze 8GB RAM / 4 cores server → generate optimized config for web workload → apply and restart PostgreSQL."

## Quick Start (2 minutes)

### 1. Analyze & Generate Config

```bash
bash scripts/tune.sh --workload web
```

**Output:**
```
🔍 System Analysis:
   RAM: 8192 MB | CPUs: 4 | Disk: SSD
   PostgreSQL: 16.2 | Data dir: /var/lib/postgresql/16/main

📊 Recommended Settings (web workload):
   shared_buffers = 2GB
   effective_cache_size = 6GB
   work_mem = 10MB
   maintenance_work_mem = 512MB
   max_connections = 200
   ... (20+ parameters)

💾 Config written to: /tmp/postgresql-tuned.conf
   Review with: diff /etc/postgresql/16/main/postgresql.conf /tmp/postgresql-tuned.conf
```

### 2. Review Changes

```bash
bash scripts/tune.sh --workload web --diff
```

Shows a side-by-side diff of current vs recommended settings.

### 3. Apply (with backup)

```bash
sudo bash scripts/tune.sh --workload web --apply
```

Backs up current config, applies tuned settings, and restarts PostgreSQL.

## Core Workflows

### Workflow 1: Web Application (Django, Rails, Node.js)

High connection count, short queries, read-heavy.

```bash
bash scripts/tune.sh --workload web
```

Optimizes for: many connections, small work_mem, large shared_buffers, aggressive caching.

### Workflow 2: OLTP (Transaction Processing)

Medium connections, write-heavy, data integrity critical.

```bash
bash scripts/tune.sh --workload oltp
```

Optimizes for: WAL performance, checkpoint tuning, fsync, synchronous_commit.

### Workflow 3: Data Warehouse / Analytics

Few connections, complex queries, large datasets.

```bash
bash scripts/tune.sh --workload dw
```

Optimizes for: huge work_mem, parallel query workers, large maintenance_work_mem.

### Workflow 4: Mixed Workload

General-purpose balanced config.

```bash
bash scripts/tune.sh --workload mixed
```

### Workflow 5: Custom RAM / CPU Override

For containers or VMs where detected values are wrong.

```bash
bash scripts/tune.sh --workload web --ram 4096 --cpus 2
```

### Workflow 6: Generate Config Only (no system detection)

```bash
bash scripts/tune.sh --workload web --ram 16384 --cpus 8 --disk ssd --connections 300 --pg-version 16
```

## Configuration

### Workload Types

| Type | Best For | Connections | Query Type |
|------|----------|-------------|------------|
| `web` | Web apps, APIs | High (100-500) | Short, read-heavy |
| `oltp` | Transaction systems | Medium (50-200) | Write-heavy, short |
| `dw` | Analytics, reporting | Low (10-50) | Complex, long-running |
| `mixed` | General purpose | Medium (50-200) | Balanced |

### Flags

| Flag | Description | Default |
|------|-------------|---------|
| `--workload` | Workload type (web/oltp/dw/mixed) | mixed |
| `--ram` | Override RAM in MB | auto-detect |
| `--cpus` | Override CPU count | auto-detect |
| `--disk` | Disk type (ssd/hdd) | auto-detect |
| `--connections` | Max connections | workload-dependent |
| `--pg-version` | PostgreSQL version | auto-detect |
| `--diff` | Show diff against current config | off |
| `--apply` | Apply config (requires sudo) | off |
| `--output` | Output file path | /tmp/postgresql-tuned.conf |

## Parameters Tuned

### Memory
- `shared_buffers` — Main shared memory (25% of RAM for most workloads)
- `effective_cache_size` — OS cache estimate (50-75% of RAM)
- `work_mem` — Per-sort/hash operation memory
- `maintenance_work_mem` — VACUUM, CREATE INDEX memory
- `huge_pages` — Enable for >8GB shared_buffers

### Connections
- `max_connections` — Based on workload type
- `superuser_reserved_connections` — Always 3

### WAL & Checkpoints
- `wal_buffers` — WAL write buffer
- `min_wal_size` — Minimum WAL retention
- `max_wal_size` — Maximum before checkpoint
- `checkpoint_completion_target` — Spread checkpoint I/O
- `wal_compression` — Compress WAL for I/O savings

### Query Planner
- `random_page_cost` — SSD: 1.1, HDD: 4.0
- `effective_io_concurrency` — SSD: 200, HDD: 2
- `default_statistics_target` — Sample size for planner stats

### Parallelism (PG 10+)
- `max_worker_processes` — Total background workers
- `max_parallel_workers_per_gather` — Per-query parallelism
- `max_parallel_workers` — Total parallel workers
- `max_parallel_maintenance_workers` — Parallel VACUUM/INDEX

### Logging
- `log_min_duration_statement` — Log slow queries (>1s)
- `log_checkpoints` — Log checkpoint activity
- `log_connections` / `log_disconnections` — Connection logging

## Troubleshooting

### Issue: "PostgreSQL not found"

**Fix:** Ensure PostgreSQL is installed and `pg_config` is in PATH.
```bash
which pg_config || sudo apt install postgresql
```

### Issue: "Permission denied" on apply

**Fix:** Run with sudo for apply mode.
```bash
sudo bash scripts/tune.sh --workload web --apply
```

### Issue: PostgreSQL won't start after tuning

**Fix:** The script always creates a backup. Restore it:
```bash
sudo cp /etc/postgresql/16/main/postgresql.conf.backup-* /etc/postgresql/16/main/postgresql.conf
sudo systemctl restart postgresql
```

### Issue: shared_buffers too high for available RAM

**Fix:** Use `--ram` to specify actual available memory (minus OS/app needs):
```bash
bash scripts/tune.sh --workload web --ram 2048  # Only 2GB available for PG
```

## Key Principles

1. **Conservative defaults** — Never allocate >25% RAM to shared_buffers
2. **Workload-aware** — Different workloads need different tuning
3. **Safe apply** — Always backs up before changing anything
4. **Detect everything** — RAM, CPUs, disk type, PG version auto-detected
5. **Idempotent** — Run multiple times safely

## Dependencies

- `bash` (4.0+)
- `postgresql` (any version 10-17)
- `grep`, `awk`, `sed` (standard Unix tools)
- Optional: `sudo` (for apply mode)
