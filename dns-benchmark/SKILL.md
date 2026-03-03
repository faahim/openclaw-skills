---
name: dns-benchmark
description: >-
  Benchmark DNS resolvers to find the fastest, most reliable one for your location.
categories: [dev-tools, analytics]
dependencies: [bash, dig, bc]
---

# DNS Benchmark Tool

## What This Does

Tests multiple DNS resolvers (Cloudflare, Google, Quad9, OpenDNS, etc.) for latency, reliability, and DNSSEC support from YOUR location. Produces a ranked report so you can pick the fastest resolver and configure your system to use it.

**Example:** "Test 15 DNS resolvers, run 50 queries each, rank by median latency, and optionally apply the winner to your system."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
# dig is required (part of dnsutils/bind-utils)
which dig || sudo apt-get install -y dnsutils  # Debian/Ubuntu
# or: sudo dnf install bind-utils              # Fedora/RHEL
# or: brew install bind                        # macOS
```

### 2. Run Benchmark

```bash
bash scripts/dns-benchmark.sh
```

**Sample output:**
```
DNS Benchmark — Testing 12 resolvers × 20 queries each
═══════════════════════════════════════════════════════

 #  Resolver              IP               Avg(ms)  Med(ms)  Min(ms)  Max(ms)  Loss%  DNSSEC
 1  Cloudflare            1.1.1.1             4.2      3.8      2.1      9.7    0.0%   ✅
 2  Google                8.8.8.8             5.1      4.9      3.2     11.3    0.0%   ✅
 3  Quad9                 9.9.9.9             6.3      5.7      3.0     14.2    0.0%   ✅
 4  NextDNS               45.90.28.0          7.8      7.1      4.5     18.6    0.0%   ✅
 5  OpenDNS               208.67.222.222      8.2      7.4      5.1     19.1    0.0%   ❌
 ...

🏆 Winner: Cloudflare (1.1.1.1) — 3.8ms median

Apply winner to system? [y/N]
```

## Core Workflows

### Workflow 1: Quick Benchmark (Default Resolvers)

```bash
bash scripts/dns-benchmark.sh
```

Tests 12 popular public DNS resolvers with 20 queries each.

### Workflow 2: Extended Benchmark (More Accuracy)

```bash
bash scripts/dns-benchmark.sh --queries 50 --domains 10
```

Runs 50 queries against 10 different domains for more accurate results.

### Workflow 3: Custom Resolvers

```bash
bash scripts/dns-benchmark.sh --resolvers "1.1.1.1,8.8.8.8,192.168.1.1"
```

Test specific resolvers (e.g., include your local router or Pi-hole).

### Workflow 4: Compare Current vs Best

```bash
bash scripts/dns-benchmark.sh --include-current
```

Includes your currently configured DNS resolver in the comparison.

### Workflow 5: Apply Winner to System

```bash
bash scripts/dns-benchmark.sh --apply
```

After benchmarking, automatically updates `/etc/resolv.conf` or `systemd-resolved` with the fastest resolver.

### Workflow 6: JSON Output (for automation)

```bash
bash scripts/dns-benchmark.sh --json > dns-results.json
```

Outputs structured JSON for piping into other tools or dashboards.

### Workflow 7: Scheduled Monitoring

```bash
# Add to crontab — benchmark weekly, log results
0 3 * * 0 bash /path/to/scripts/dns-benchmark.sh --json >> /var/log/dns-benchmark.log
```

## Configuration

### Environment Variables

```bash
# Override default query count
export DNS_BENCH_QUERIES=30

# Override test domains
export DNS_BENCH_DOMAINS="google.com,github.com,cloudflare.com,amazon.com"

# Timeout per query (seconds)
export DNS_BENCH_TIMEOUT=3
```

### Custom Resolver List

Edit `scripts/resolvers.txt` to add/remove resolvers:

```
# Format: NAME IP [SECONDARY_IP]
Cloudflare 1.1.1.1 1.0.0.1
Google 8.8.8.8 8.8.4.4
Quad9 9.9.9.9 149.112.112.112
OpenDNS 208.67.222.222 208.67.220.220
NextDNS 45.90.28.0 45.90.30.0
Comodo 8.26.56.26 8.20.247.20
CleanBrowsing 185.228.168.9 185.228.169.9
AdGuard 94.140.14.14 94.140.15.15
Mullvad 194.242.2.2
Control-D 76.76.2.0 76.76.10.0
LibreDNS 116.202.176.26
DNS.SB 185.222.222.222 45.11.45.11
```

## Advanced Usage

### DNSSEC Validation Check

```bash
bash scripts/dns-benchmark.sh --check-dnssec
```

Tests whether each resolver properly validates DNSSEC signatures.

### Latency Histogram

```bash
bash scripts/dns-benchmark.sh --histogram
```

Shows latency distribution per resolver:

```
Cloudflare (1.1.1.1):
  0-5ms   ████████████████████ 85%
  5-10ms  ████ 12%
  10-20ms █ 3%
  >20ms   0%
```

### Privacy-Focused Only

```bash
bash scripts/dns-benchmark.sh --privacy-only
```

Tests only resolvers with no-logging policies: Cloudflare, Quad9, Mullvad, NextDNS, LibreDNS.

## Troubleshooting

### Issue: "dig: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install -y dnsutils

# RHEL/Fedora
sudo dnf install -y bind-utils

# macOS
brew install bind

# Alpine
apk add bind-tools
```

### Issue: All resolvers show high latency

Your network might be throttling DNS. Try:
1. Check if a firewall is blocking UDP port 53
2. Test with `--timeout 10` for slower connections
3. Run from a different network to compare

### Issue: "Permission denied" when applying

Applying DNS changes requires root:
```bash
sudo bash scripts/dns-benchmark.sh --apply
```

## Dependencies

- `bash` (4.0+)
- `dig` (from dnsutils/bind-utils)
- `bc` (for floating-point math)
- `sort`, `awk` (standard Unix tools)
- Optional: `sudo` (for applying DNS changes)
