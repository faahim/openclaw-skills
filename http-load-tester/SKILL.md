---
name: http-load-tester
description: >-
  Load test HTTP endpoints with configurable concurrency, duration, and reporting.
  Installs and uses industry-standard tools (hey, ab, wrk) to stress test APIs and websites.
categories: [dev-tools, automation]
dependencies: [bash, curl]
---

# HTTP Load Tester

## What This Does

Run HTTP load tests against any URL or API endpoint — measure requests/sec, latency percentiles, error rates, and throughput. Automatically installs the best available load testing tool (`hey`, `ab`, or `wrk`) and generates clean reports.

**Example:** "Hit https://api.example.com/health with 200 concurrent connections for 30 seconds, show me p50/p95/p99 latency."

## Quick Start (2 minutes)

### 1. Install Load Testing Tools

```bash
bash scripts/install.sh
```

This auto-detects your OS and installs `hey` (preferred), falls back to `ab` (Apache Bench).

### 2. Run Your First Load Test

```bash
bash scripts/run.sh --url https://httpbin.org/get --concurrency 10 --duration 10
```

**Output:**
```
═══════════════════════════════════════════════════
  HTTP Load Test Report
  Target: https://httpbin.org/get
  Duration: 10s | Concurrency: 10
═══════════════════════════════════════════════════

  Total Requests:    1,247
  Requests/sec:      124.7
  Success Rate:      100.0%

  Latency:
    p50:   72ms
    p95:   145ms
    p99:   210ms
    max:   312ms

  Throughput:        2.4 MB/s
  Status Codes:      [200: 1247]
═══════════════════════════════════════════════════
```

## Core Workflows

### Workflow 1: Quick Benchmark

**Use case:** How fast is my endpoint?

```bash
bash scripts/run.sh \
  --url https://yourapi.com/endpoint \
  --concurrency 50 \
  --requests 1000
```

### Workflow 2: Duration-Based Stress Test

**Use case:** Can my server handle sustained load?

```bash
bash scripts/run.sh \
  --url https://yourapi.com/endpoint \
  --concurrency 100 \
  --duration 60 \
  --report /tmp/loadtest-report.txt
```

### Workflow 3: POST Request Load Test

**Use case:** Test API writes under load

```bash
bash scripts/run.sh \
  --url https://yourapi.com/data \
  --method POST \
  --body '{"name":"test","value":42}' \
  --content-type "application/json" \
  --concurrency 20 \
  --duration 30
```

### Workflow 4: Auth-Protected Endpoints

**Use case:** Load test behind authentication

```bash
bash scripts/run.sh \
  --url https://yourapi.com/protected \
  --header "Authorization: Bearer $TOKEN" \
  --concurrency 30 \
  --duration 20
```

### Workflow 5: Compare Before/After

**Use case:** Did my optimization help?

```bash
# Before optimization
bash scripts/run.sh --url https://api.example.com/slow --concurrency 50 --duration 30 --report /tmp/before.txt

# After optimization
bash scripts/run.sh --url https://api.example.com/slow --concurrency 50 --duration 30 --report /tmp/after.txt

# Compare
bash scripts/compare.sh /tmp/before.txt /tmp/after.txt
```

### Workflow 6: Gradual Ramp-Up

**Use case:** Find the breaking point

```bash
bash scripts/ramp.sh \
  --url https://yourapi.com/endpoint \
  --start 10 \
  --end 200 \
  --step 10 \
  --step-duration 10
```

**Output:**
```
Concurrency  RPS      p95     Errors
─────────────────────────────────────
10           98       45ms    0%
20           195      48ms    0%
50           480      62ms    0%
100          890      95ms    0%
150          1100     210ms   0.2%
200          950      850ms   5.1%  ← DEGRADATION
─────────────────────────────────────
Recommended max concurrency: ~150
```

## Configuration

### Environment Variables

```bash
# Default tool preference (hey > ab > wrk)
export LOADTEST_TOOL="hey"

# Default timeout per request (seconds)
export LOADTEST_TIMEOUT=10

# Default output directory for reports
export LOADTEST_REPORT_DIR="/tmp/loadtests"
```

### All CLI Options

| Flag | Description | Default |
|------|-------------|---------|
| `--url` | Target URL (required) | - |
| `--concurrency` / `-c` | Concurrent connections | 10 |
| `--requests` / `-n` | Total requests (mutually exclusive with --duration) | - |
| `--duration` / `-d` | Test duration in seconds | 10 |
| `--method` / `-m` | HTTP method (GET, POST, PUT, DELETE) | GET |
| `--body` / `-b` | Request body (for POST/PUT) | - |
| `--content-type` | Content-Type header | application/json |
| `--header` / `-H` | Custom header (repeatable) | - |
| `--timeout` | Per-request timeout (seconds) | 10 |
| `--report` / `-r` | Save report to file | stdout |
| `--json` | Output as JSON | false |
| `--tool` | Force tool (hey/ab/wrk) | auto-detect |

## Advanced Usage

### JSON Output for Scripting

```bash
bash scripts/run.sh --url https://example.com --concurrency 50 --duration 10 --json
```

```json
{
  "url": "https://example.com",
  "concurrency": 50,
  "duration_sec": 10,
  "total_requests": 5230,
  "rps": 523.0,
  "success_rate": 100.0,
  "latency": {
    "p50_ms": 85,
    "p95_ms": 152,
    "p99_ms": 245,
    "max_ms": 410
  },
  "throughput_mbps": 12.4,
  "status_codes": {"200": 5230}
}
```

### OpenClaw Cron Integration

```bash
# Run daily load test at 6am, alert if p95 > 500ms
# In OpenClaw cron:
bash scripts/run.sh --url https://yourapi.com/health -c 20 -d 30 --json | \
  jq -e '.latency.p95_ms < 500' || echo "⚠️ p95 latency exceeded 500ms!"
```

## Troubleshooting

### Issue: "hey: command not found"

**Fix:** Run `bash scripts/install.sh` — it installs hey automatically.

### Issue: "Connection refused" errors

**Check:**
1. Is the target URL accessible? `curl -I <url>`
2. Is your firewall blocking outbound connections?
3. Is the server rate-limiting you? Reduce `--concurrency`

### Issue: All requests timing out

**Fix:** Increase `--timeout` or check if the server is overwhelmed:
```bash
bash scripts/run.sh --url https://example.com -c 5 -d 5 --timeout 30
```

### Issue: "Too many open files"

**Fix:** Increase ulimit before testing:
```bash
ulimit -n 10000
bash scripts/run.sh --url https://example.com -c 500 -d 30
```

## Dependencies

- `bash` (4.0+)
- `curl` (for fallback + connectivity check)
- One of: `hey` (preferred), `ab` (Apache Bench), `wrk`
- `jq` (for JSON output)
- `bc` (for calculations)
