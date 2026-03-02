---
name: latency-monitor
description: >-
  Monitor network latency, jitter, and packet loss to any host. Get alerts when network quality degrades.
categories: [automation, analytics]
dependencies: [bash, fping, mtr, bc, curl]
---

# Latency Monitor

## What This Does

Continuously monitors network latency, jitter, and packet loss to one or more hosts. Logs results to CSV for trend analysis and sends alerts (Telegram, webhook, or custom command) when thresholds are exceeded. Unlike uptime monitors (HTTP status checks) or bandwidth monitors (throughput), this focuses on **network quality** — the metrics that matter for VoIP, gaming, video calls, and real-time applications.

**Example:** "Ping 5 hosts every 30 seconds, alert me on Telegram if latency exceeds 100ms or packet loss exceeds 2%."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y fping mtr-tiny bc curl

# Alpine
sudo apk add fping mtr bc curl

# macOS
brew install fping mtr bc curl

# RHEL/CentOS/Fedora
sudo dnf install -y fping mtr bc curl
```

### 2. Monitor a Single Host

```bash
bash scripts/latency-monitor.sh --host 1.1.1.1 --interval 30
```

**Output:**
```
[2026-03-02 15:00:00] 1.1.1.1 | latency=12.4ms jitter=1.2ms loss=0.0% | ✅ OK
[2026-03-02 15:00:30] 1.1.1.1 | latency=13.1ms jitter=0.8ms loss=0.0% | ✅ OK
[2026-03-02 15:01:00] 1.1.1.1 | latency=45.2ms jitter=18.3ms loss=0.0% | ⚠️ HIGH JITTER
```

### 3. Monitor Multiple Hosts with Alerts

```bash
bash scripts/latency-monitor.sh \
  --hosts "1.1.1.1,8.8.8.8,your-server.com" \
  --interval 60 \
  --latency-warn 50 \
  --latency-crit 100 \
  --loss-warn 1 \
  --loss-crit 5 \
  --jitter-warn 10 \
  --alert-telegram "$TELEGRAM_BOT_TOKEN:$TELEGRAM_CHAT_ID" \
  --log /var/log/latency-monitor.csv
```

## Core Workflows

### Workflow 1: Basic Latency Monitoring

**Use case:** Track latency to critical infrastructure

```bash
bash scripts/latency-monitor.sh \
  --hosts "1.1.1.1,8.8.8.8,your-db-server.internal" \
  --interval 30 \
  --count 5
```

Each check sends 5 ICMP pings (`--count`), calculates avg latency, jitter (stddev), and packet loss percentage.

### Workflow 2: Network Quality Report

**Use case:** Generate a one-time report using mtr

```bash
bash scripts/latency-report.sh --host your-server.com --cycles 100
```

**Output:**
```
=== Network Quality Report ===
Target: your-server.com (203.0.113.10)
Date: 2026-03-02 15:00:00 UTC
Cycles: 100

Hop  Host                    Loss%  Avg(ms)  Best(ms) Worst(ms) StDev
1    gateway.local           0.0    1.2      0.8      2.1       0.3
2    isp-router.net          0.0    5.4      4.1      8.2       1.1
3    core-router.carrier.net 0.5    12.3     10.1     18.4      2.3
4    your-server.com         0.0    15.6     14.2     22.1      1.8

Summary:
  End-to-end latency: 15.6ms avg (14.2 - 22.1ms)
  Jitter: 1.8ms
  Packet loss: 0.0%
  Grade: ★★★★★ Excellent
```

### Workflow 3: VoIP/Gaming Quality Check

**Use case:** Check if network is good enough for real-time applications

```bash
bash scripts/latency-monitor.sh \
  --hosts "your-voip-server.com" \
  --interval 10 \
  --count 10 \
  --latency-warn 30 \
  --latency-crit 80 \
  --jitter-warn 5 \
  --jitter-crit 15 \
  --loss-warn 0.5 \
  --loss-crit 1
```

### Workflow 4: Multi-ISP Comparison

**Use case:** Compare latency across different DNS/CDN providers

```bash
bash scripts/latency-monitor.sh \
  --hosts "1.1.1.1,8.8.8.8,9.9.9.9,208.67.222.222" \
  --interval 60 \
  --log /tmp/isp-comparison.csv \
  --duration 3600
```

Then analyze:
```bash
bash scripts/latency-analyze.sh /tmp/isp-comparison.csv
```

**Output:**
```
=== Latency Analysis ===
Period: 2026-03-02 15:00 - 16:00 (60 samples each)

Host              Avg(ms)  P50(ms)  P95(ms)  P99(ms)  Jitter  Loss%
1.1.1.1           12.3     11.8     15.2     22.1     1.4     0.0
8.8.8.8           18.7     17.2     25.4     38.6     3.2     0.0
9.9.9.9           14.1     13.5     18.8     26.3     2.1     0.0
208.67.222.222    22.4     20.1     32.6     45.8     4.8     0.2

Winner: 1.1.1.1 (Cloudflare) — lowest latency, lowest jitter, zero loss
```

## Configuration

### Command-Line Options

```
--host HOST           Single host to monitor
--hosts HOST1,HOST2   Comma-separated list of hosts
--interval SECS       Seconds between checks (default: 30)
--count N             Pings per check (default: 5)
--duration SECS       Stop after N seconds (default: unlimited)
--log FILE            Log results to CSV file
--latency-warn MS     Warn threshold for latency (default: 50)
--latency-crit MS     Critical threshold for latency (default: 100)
--jitter-warn MS      Warn threshold for jitter (default: 10)
--jitter-crit MS      Critical threshold for jitter (default: 20)
--loss-warn PCT       Warn threshold for packet loss % (default: 1)
--loss-crit PCT       Critical threshold for packet loss % (default: 5)
--alert-telegram TOKEN:CHAT_ID   Send alerts via Telegram
--alert-webhook URL              Send alerts via webhook POST
--alert-cmd "COMMAND"            Run custom command on alert
--quiet               Only output alerts (no OK lines)
--no-color            Disable colored output
```

### Environment Variables

```bash
# Telegram alerts
export LATMON_TELEGRAM_TOKEN="<bot-token>"
export LATMON_TELEGRAM_CHAT="<chat-id>"

# Default thresholds
export LATMON_LATENCY_WARN=50
export LATMON_LATENCY_CRIT=100
export LATMON_LOSS_WARN=1
export LATMON_LOSS_CRIT=5
```

## Advanced Usage

### Run as systemd Service

```bash
# Install as service
sudo bash scripts/install-service.sh \
  --hosts "1.1.1.1,8.8.8.8,your-server.com" \
  --interval 60 \
  --log /var/log/latency-monitor.csv \
  --alert-telegram "$LATMON_TELEGRAM_TOKEN:$LATMON_TELEGRAM_CHAT"

# Manage
sudo systemctl status latency-monitor
sudo systemctl stop latency-monitor
sudo journalctl -u latency-monitor -f
```

### Run via Cron (Periodic Snapshots)

```bash
# Check every 5 minutes, append to daily log
*/5 * * * * bash /path/to/scripts/latency-monitor.sh \
  --hosts "1.1.1.1,your-server.com" \
  --count 10 \
  --duration 1 \
  --log /var/log/latency/$(date +\%Y-\%m-\%d).csv \
  --quiet 2>&1
```

### CSV Log Format

```csv
timestamp,host,latency_avg,latency_min,latency_max,jitter,loss_pct,status
2026-03-02T15:00:00Z,1.1.1.1,12.4,10.1,15.8,1.2,0.0,ok
2026-03-02T15:00:00Z,8.8.8.8,18.7,15.2,24.3,3.2,0.0,ok
2026-03-02T15:00:30Z,1.1.1.1,45.2,12.1,120.4,18.3,0.0,warn
```

## Troubleshooting

### Issue: "fping: command not found"

```bash
# Install fping
sudo apt-get install -y fping    # Debian/Ubuntu
sudo dnf install -y fping        # RHEL/Fedora
brew install fping                # macOS
```

### Issue: "Operation not permitted" with fping

```bash
# fping needs raw socket access
sudo chmod u+s $(which fping)
# OR run with sudo
sudo bash scripts/latency-monitor.sh --host 1.1.1.1
```

### Issue: Host blocks ICMP (0% response)

Some hosts block ping. Use TCP-based check instead:
```bash
bash scripts/latency-monitor.sh --host example.com --tcp --port 443
```

### Issue: Telegram alerts not arriving

Test manually:
```bash
curl -s "https://api.telegram.org/bot${LATMON_TELEGRAM_TOKEN}/sendMessage" \
  -d "chat_id=${LATMON_TELEGRAM_CHAT}" \
  -d "text=Test alert from Latency Monitor"
```

## Network Quality Grading

| Grade | Latency | Jitter | Loss | Good For |
|-------|---------|--------|------|----------|
| ★★★★★ Excellent | <20ms | <2ms | 0% | Gaming, VoIP, video |
| ★★★★ Good | <50ms | <5ms | <0.5% | Video calls, streaming |
| ★★★ Fair | <100ms | <15ms | <1% | Web browsing, email |
| ★★ Poor | <200ms | <30ms | <3% | Basic connectivity |
| ★ Bad | >200ms | >30ms | >3% | Barely usable |

## Dependencies

- `bash` (4.0+)
- `fping` (ICMP ping with statistics)
- `mtr` (traceroute + ping combined, for reports)
- `bc` (floating-point math)
- `curl` (alert delivery)
- Optional: `systemd` (for service installation)
