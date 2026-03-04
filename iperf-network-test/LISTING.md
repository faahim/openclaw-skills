# Listing Copy: iperf Network Test

## Metadata
- **Type:** Skill
- **Name:** iperf-network-test
- **Display Name:** iperf Network Test
- **Categories:** [dev-tools, analytics]
- **Price:** $8
- **Dependencies:** [iperf3, jq]

## Tagline

Test network throughput between hosts — Diagnose bandwidth bottlenecks with real data

## Description

### The Problem

"My connection feels slow" isn't a diagnosis. Speed test websites measure ISP speed, not server-to-server throughput. When your app is laggy, your VPN is slow, or your backup is crawling, you need real numbers between the actual hosts involved.

### The Solution

iperf Network Test installs iperf3 and wraps it with workflows for common scenarios: quick bandwidth checks, sustained load tests, UDP jitter analysis for VoIP/gaming, multi-server comparisons, and scheduled monitoring with CSV logging. Run it between any two machines to get hard throughput numbers.

### What It Does

- 🚀 **Quick bandwidth test** — One command against public or private servers
- 📊 **TCP & UDP testing** — Throughput, jitter, and packet loss
- ↔️ **Bidirectional tests** — Upload and download simultaneously
- 🔄 **Sustained load tests** — 5-minute+ runs to catch instability
- 📈 **Scheduled monitoring** — Hourly/daily bandwidth logging to CSV
- 🏆 **Multi-server comparison** — Side-by-side formatted table
- 🖥️ **Server mode** — Run your own iperf3 server with systemd
- ⚡ **3-minute setup** — Install, test, done

### Who It's For

Sysadmins, network engineers, and developers who need to diagnose network bottlenecks, verify ISP performance, or benchmark server-to-server links.

## Dependencies
- `iperf3` (3.1+)
- `jq`
- `bash` (4.0+)

## Installation Time
**3 minutes**
