---
name: iperf-network-test
description: >-
  Test network throughput, latency, and bandwidth between hosts using iperf3. Diagnose bottlenecks with automated reports.
categories: [dev-tools, analytics]
dependencies: [iperf3]
---

# iperf Network Test

## What This Does

Measure real network throughput between any two hosts using [iperf3](https://iperf.fr/). Run quick bandwidth tests, sustained load tests, UDP jitter analysis, and generate formatted reports. Essential for diagnosing network bottlenecks, verifying ISP speeds, and benchmarking server-to-server links.

**Example:** "Test bandwidth between my VPS and home server, check for packet loss, log results over time."

## Quick Start (3 minutes)

### 1. Install iperf3

```bash
bash scripts/install.sh
```

### 2. Run a Quick Bandwidth Test

```bash
# Test against a public iperf3 server
bash scripts/quicktest.sh

# Or test against a specific host
bash scripts/test.sh --server your-server.com
```

### 3. Start Your Own Server

```bash
# Run iperf3 server on this machine
bash scripts/server.sh start

# Test from another machine
iperf3 -c this-machine-ip
```

## Core Workflows

### Workflow 1: Quick Internet Bandwidth Test

**Use case:** Check your actual network throughput

```bash
bash scripts/quicktest.sh
# Output:
# 🌐 iperf3 Quick Network Test
# ==============================
# Server: bouygues.iperf.fr (public)
#
# ⬇️  Download: 487 Mbits/sec
# ⬆️  Upload:   234 Mbits/sec
# 📊 Jitter:   0.42 ms
# 📦 Lost:     0/1247 (0%)
```

### Workflow 2: Server-to-Server Throughput

**Use case:** Measure bandwidth between two of your servers

```bash
# On server A (receiver):
bash scripts/server.sh start

# On server B (sender):
bash scripts/test.sh --server server-a-ip --duration 30 --parallel 4

# Output:
# 🔗 Testing: server-b → 10.0.1.5:5201
# ⏱️  Duration: 30s | Streams: 4
#
# [SUM]  0.00-30.00 sec  2.74 GBytes   785 Mbits/sec   sender
# [SUM]  0.00-30.00 sec  2.74 GBytes   784 Mbits/sec   receiver
```

### Workflow 3: UDP Jitter & Packet Loss Test

**Use case:** Test real-time application readiness (VoIP, gaming, streaming)

```bash
bash scripts/test.sh --server your-server.com --udp --bandwidth 100M

# Output:
# 🔗 UDP Test: → your-server.com:5201
# 📊 Bandwidth: 100 Mbits/sec target
#
# [  5]  0.00-10.00 sec  119 MBytes   100 Mbits/sec  0.031 ms  0/85549 (0%)
#
# ✅ Jitter: 0.031 ms (excellent for VoIP)
# ✅ Packet loss: 0% (no issues)
```

### Workflow 4: Sustained Load Test

**Use case:** Test network stability under sustained load

```bash
bash scripts/test.sh --server your-server.com --duration 300 --interval 10 --report

# Runs 5-minute test, reports every 10 seconds
# Saves results to reports/test-YYYY-MM-DD-HHMMSS.json
```

### Workflow 5: Bidirectional Test

**Use case:** Test upload AND download simultaneously

```bash
bash scripts/test.sh --server your-server.com --bidir

# Output:
# ⬇️  Download: 487 Mbits/sec
# ⬆️  Upload:   234 Mbits/sec (simultaneous)
```

### Workflow 6: Scheduled Monitoring

**Use case:** Log bandwidth over time to detect degradation

```bash
bash scripts/monitor.sh --server your-server.com --interval 3600 --logfile reports/hourly.csv

# Runs test every hour, appends to CSV:
# timestamp,server,download_mbps,upload_mbps,jitter_ms,loss_pct
# 2026-03-04T14:00:00Z,10.0.1.5,785.2,780.1,0.03,0.0
# 2026-03-04T15:00:00Z,10.0.1.5,781.8,779.5,0.04,0.0
```

## Configuration

### Environment Variables

```bash
# Default iperf3 server for quick tests
export IPERF_DEFAULT_SERVER="your-server.com"

# Default test duration (seconds)
export IPERF_DURATION=10

# Default port
export IPERF_PORT=5201

# Reports directory
export IPERF_REPORTS_DIR="./reports"
```

### Server Options

```bash
# Start server on custom port
bash scripts/server.sh start --port 5202

# Start server with authentication
bash scripts/server.sh start --auth --user admin --pass secret

# Start as systemd service (persistent)
bash scripts/server.sh install-service
```

## Advanced Usage

### Multiple Stream Test (Saturate Link)

```bash
# Use 8 parallel streams to saturate bandwidth
bash scripts/test.sh --server your-server.com --parallel 8
```

### Reverse Mode (Server Sends to Client)

```bash
# Test download speed (server pushes to you)
bash scripts/test.sh --server your-server.com --reverse
```

### Window Size Tuning

```bash
# Set TCP window size for long-distance links
bash scripts/test.sh --server remote-server.com --window 256K
```

### JSON Output for Automation

```bash
# Get raw JSON for scripting
iperf3 -c your-server.com -J > result.json

# Parse with jq
cat result.json | jq '.end.sum_sent.bits_per_second / 1000000'
```

### Compare Multiple Servers

```bash
bash scripts/compare.sh server1.com server2.com server3.com
# Output:
# 📊 Network Comparison
# ┌─────────────────┬──────────┬──────────┬──────────┐
# │ Server          │ Download │ Upload   │ Jitter   │
# ├─────────────────┼──────────┼──────────┼──────────┤
# │ server1.com     │ 487 Mbps │ 234 Mbps │ 0.42 ms  │
# │ server2.com     │ 312 Mbps │ 198 Mbps │ 1.23 ms  │
# │ server3.com     │ 891 Mbps │ 445 Mbps │ 0.08 ms  │
# └─────────────────┴──────────┴──────────┴──────────┘
```

## Troubleshooting

### Issue: "iperf3: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
# Ubuntu/Debian: sudo apt install iperf3
# RHEL/Fedora: sudo dnf install iperf3
# Mac: brew install iperf3
```

### Issue: "unable to connect to server"

**Check:**
1. Server is running: `bash scripts/server.sh status`
2. Port is open: `nc -zv server-ip 5201`
3. Firewall allows port: `sudo ufw allow 5201/tcp`

### Issue: "warning: did not receive ack"

**Fix:** The server may be busy with another test (iperf3 handles one client at a time by default).
```bash
# Start server in daemon mode with multiple clients
iperf3 -s -D --server-bitrate-limit 0
```

### Issue: Results seem low

**Check:**
1. Test with parallel streams: `--parallel 4`
2. Increase TCP window: `--window 256K`
3. Check for CPU bottleneck: `htop` during test
4. Test from different network path

## Dependencies

- `iperf3` (3.1+)
- `bash` (4.0+)
- `jq` (for JSON parsing in reports)
- Optional: `systemd` (for persistent server service)
- Optional: `bc` (for calculations in compare script)

## Key Principles

1. **Always test bidirectionally** — Upload and download often differ
2. **Use multiple streams** — Single stream may not saturate the link
3. **Test at different times** — Network congestion varies
4. **UDP for real-time apps** — TCP tests don't show jitter/loss
5. **Log over time** — Single tests miss intermittent issues
