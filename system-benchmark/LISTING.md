# Listing Copy: System Benchmark Tool

## Metadata
- **Type:** Skill
- **Name:** system-benchmark
- **Display Name:** System Benchmark Tool
- **Categories:** [dev-tools, analytics]
- **Price:** $10
- **Dependencies:** [sysbench, fio, iperf3, jq]
- **Icon:** 📊

## Tagline

Benchmark CPU, memory, disk & network — structured reports with star ratings

## Description

Manually testing server performance is tedious and inconsistent. You SSH in, run random commands, eyeball numbers, and forget the results. When comparing VPS providers or diagnosing bottlenecks, you need structured, repeatable benchmarks.

System Benchmark Tool runs industry-standard benchmarks (sysbench for CPU/memory, fio for disk I/O, iperf3 for network) and outputs structured JSON reports with human-readable star ratings. Compare machines side-by-side, track performance over time, and identify bottlenecks in seconds.

**What it does:**
- 🧠 CPU benchmark — events/sec, latency, multi-threaded
- 💾 Disk I/O — sequential read/write, random IOPS (4K blocks)
- 🧮 Memory — throughput in MiB/sec
- 🌐 Network — send/receive throughput via iperf3
- 📊 Star ratings — instant "is this good?" assessment
- 🔄 Machine comparison — side-by-side diff with percentage deltas
- 📄 JSON output — pipe to dashboards, log over time

Perfect for developers evaluating VPS providers, sysadmins diagnosing performance issues, and anyone who needs to answer "how fast is this machine?"

## Core Capabilities

1. CPU benchmarking — multi-threaded events/sec with configurable prime limits
2. Memory throughput — large block transfer speed measurement
3. Disk I/O profiling — sequential and random read/write with fio
4. Network testing — iperf3 throughput measurement
5. Star ratings — 5-star scale for instant assessment
6. Machine comparison — side-by-side percentage deltas
7. JSON reports — structured output for automation
8. Auto-installer — detects OS and installs dependencies
9. Configurable — thread count, disk size, runtime, fio profiles
10. Cron-ready — schedule daily benchmarks for trend analysis

## Installation Time
**5 minutes** — run install.sh, then benchmark
