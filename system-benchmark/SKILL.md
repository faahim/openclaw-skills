---
name: system-benchmark
description: >-
  Run comprehensive CPU, memory, disk, and network benchmarks with structured reports.
categories: [dev-tools, analytics]
dependencies: [sysbench, fio, iperf3, jq]
---

# System Benchmark Tool

## What This Does

Benchmark your system's CPU, memory, disk I/O, and network throughput using industry-standard tools. Get structured JSON reports, compare results across machines, and identify bottlenecks. Uses sysbench, fio, and iperf3 — real benchmarking tools, not toy scripts.

**Example:** "Benchmark this VPS, compare CPU vs my home server, find the disk I/O bottleneck."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

### 2. Run Full Benchmark

```bash
bash scripts/run.sh --all
```

### 3. Run Specific Benchmark

```bash
# CPU only
bash scripts/run.sh --cpu

# Disk I/O only
bash scripts/run.sh --disk

# Memory only
bash scripts/run.sh --memory

# Network (requires iperf3 server)
bash scripts/run.sh --network --server <iperf3-server-ip>
```

## Core Workflows

### Workflow 1: Quick System Assessment

**Use case:** Evaluate a new VPS or server

```bash
bash scripts/run.sh --all --output results/$(hostname)-$(date +%Y%m%d).json
```

**Output:**
```
════════════════════════════════════════════
  SYSTEM BENCHMARK REPORT
  Host: vps-01  |  Date: 2026-02-26
════════════════════════════════════════════

CPU Benchmark (sysbench)
  Threads: 4
  Events/sec: 4,521.32
  Avg latency: 0.88ms
  Rating: ★★★★☆ Good

Memory Benchmark (sysbench)
  Block size: 1MB
  Throughput: 8,234.56 MiB/sec
  Rating: ★★★★★ Excellent

Disk I/O Benchmark (fio)
  Sequential Read:  512.3 MB/s
  Sequential Write: 478.1 MB/s
  Random Read IOPS: 45,230
  Random Write IOPS: 38,120
  Rating: ★★★★☆ Good

Network (iperf3)
  Skipped (no --server specified)

Overall: ★★★★☆ Good
Full report: results/vps-01-20260226.json
════════════════════════════════════════════
```

### Workflow 2: Compare Two Machines

```bash
# Run on machine A
bash scripts/run.sh --all --output results/machine-a.json

# Run on machine B
bash scripts/run.sh --all --output results/machine-b.json

# Compare
bash scripts/compare.sh results/machine-a.json results/machine-b.json
```

**Output:**
```
COMPARISON: machine-a vs machine-b

                    machine-a    machine-b    Winner
CPU events/sec      4,521        12,340       machine-b (+173%)
Memory MiB/sec      8,234        16,102       machine-b (+96%)
Seq Read MB/s       512          3,200        machine-b (+525%)
Seq Write MB/s      478          2,800        machine-b (+486%)
Random Read IOPS    45,230       210,000      machine-b (+364%)
Random Write IOPS   38,120       185,000      machine-b (+385%)
```

### Workflow 3: Disk-Only Deep Dive

**Use case:** Evaluate storage performance for database workloads

```bash
bash scripts/run.sh --disk --disk-size 4G --disk-runtime 120
```

### Workflow 4: Continuous Monitoring

**Use case:** Track performance over time

```bash
# Add to crontab — benchmark daily at 3am
echo "0 3 * * * cd /path/to/skill && bash scripts/run.sh --all --output results/\$(date +\%Y\%m\%d).json --quiet" | crontab -
```

## Configuration

### Command-Line Options

```
--all               Run all benchmarks (CPU + memory + disk)
--cpu               Run CPU benchmark
--memory            Run memory benchmark
--disk              Run disk I/O benchmark
--network           Run network benchmark (requires --server)
--server <ip>       iperf3 server address for network test
--threads <n>       CPU threads to test (default: auto-detect)
--disk-size <size>  Fio test file size (default: 1G)
--disk-runtime <s>  Fio test duration in seconds (default: 60)
--output <path>     Save JSON report to file
--quiet             Suppress terminal output (JSON only)
--json              Output raw JSON to stdout
```

### Environment Variables

```bash
# Override default test parameters
export BENCH_CPU_THREADS=8
export BENCH_CPU_MAX_PRIME=20000
export BENCH_DISK_SIZE="4G"
export BENCH_DISK_RUNTIME=120
export BENCH_IPERF_SERVER="10.0.0.1"
```

## Advanced Usage

### Custom fio Profiles

```bash
# Database workload (random 4K reads)
bash scripts/run.sh --disk --fio-profile database

# Streaming workload (sequential large reads)
bash scripts/run.sh --disk --fio-profile streaming

# Available profiles: database, streaming, mixed, archive
```

### Network Benchmark

```bash
# Start iperf3 server on remote machine
iperf3 -s -D

# Run from this machine
bash scripts/run.sh --network --server 192.168.1.100
```

### Export for Comparison

```bash
# All results as CSV
bash scripts/export-csv.sh results/ > benchmarks.csv
```

## Troubleshooting

### Issue: "sysbench: command not found"

```bash
bash scripts/install.sh
# Or manually:
# Ubuntu/Debian: sudo apt-get install -y sysbench fio iperf3
# RHEL/CentOS: sudo yum install -y sysbench fio iperf3
# Mac: brew install sysbench fio iperf3
```

### Issue: Disk benchmark shows very high numbers

The OS may be caching. Use `--disk-size` larger than your RAM for accurate results:
```bash
bash scripts/run.sh --disk --disk-size 8G
```

### Issue: fio requires root for direct I/O

```bash
sudo bash scripts/run.sh --disk
```

## Dependencies

- `sysbench` — CPU and memory benchmarks
- `fio` — Flexible I/O tester for disk benchmarks
- `iperf3` — Network throughput testing (optional)
- `jq` — JSON processing
- `bash` (4.0+)
