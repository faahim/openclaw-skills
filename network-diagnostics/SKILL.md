---
name: network-diagnostics
description: >-
  Scan ports, resolve DNS, trace routes, test bandwidth, and diagnose network issues — all from your OpenClaw agent.
categories: [security, dev-tools]
dependencies: [nmap, dig, mtr, iperf3, curl, ss]
---

# Network Diagnostics Toolkit

## What This Does

A comprehensive network diagnostics toolkit that lets your OpenClaw agent scan ports, resolve DNS records, trace routes, test bandwidth, check SSL certificates, and diagnose connectivity issues. Uses real networking tools (nmap, dig, mtr, iperf3) that agents cannot replicate with text generation alone.

**Example:** "Scan my server's open ports, check DNS propagation for my domain, and test download speed — all in one command."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

This installs: `nmap`, `dnsutils` (dig/nslookup), `mtr`, `iperf3`, `netcat`, `whois`, `traceroute`.

### 2. Run a Quick Scan

```bash
# Port scan a host
bash scripts/netdiag.sh portscan example.com

# DNS lookup
bash scripts/netdiag.sh dns example.com

# Full diagnostic report
bash scripts/netdiag.sh report example.com
```

## Core Workflows

### Workflow 1: Port Scanning

**Use case:** Check which ports are open on a server.

```bash
# Quick scan (top 100 ports)
bash scripts/netdiag.sh portscan example.com

# Full scan (all 65535 ports) — takes longer
bash scripts/netdiag.sh portscan example.com --full

# Scan specific ports
bash scripts/netdiag.sh portscan example.com --ports 22,80,443,3306,5432,6379,8080

# Service version detection
bash scripts/netdiag.sh portscan example.com --version
```

**Output:**
```
=== Port Scan: example.com ===
[2026-02-22 03:55:00] Scanning top 100 ports...

PORT     STATE  SERVICE
22/tcp   open   ssh
80/tcp   open   http
443/tcp  open   https
3306/tcp closed mysql
5432/tcp closed postgresql

Open: 3 | Closed: 2 | Filtered: 95
Scan completed in 4.2s
```

### Workflow 2: DNS Diagnostics

**Use case:** Check DNS records, propagation, and resolution.

```bash
# All DNS records
bash scripts/netdiag.sh dns example.com

# Specific record type
bash scripts/netdiag.sh dns example.com --type MX
bash scripts/netdiag.sh dns example.com --type TXT
bash scripts/netdiag.sh dns example.com --type CNAME

# Check propagation across multiple DNS servers
bash scripts/netdiag.sh dns-propagation example.com

# Reverse DNS
bash scripts/netdiag.sh rdns 93.184.216.34
```

**Output:**
```
=== DNS Lookup: example.com ===

A Records:
  93.184.216.34 (TTL: 3600)

AAAA Records:
  2606:2800:220:1:248:1893:25c8:1946 (TTL: 3600)

MX Records:
  10 mail.example.com (TTL: 3600)

NS Records:
  a.iana-servers.net (TTL: 86400)
  b.iana-servers.net (TTL: 86400)

TXT Records:
  "v=spf1 include:_spf.google.com ~all" (TTL: 3600)
```

### Workflow 3: Route Tracing

**Use case:** Diagnose network path and latency issues.

```bash
# Trace route with latency
bash scripts/netdiag.sh trace example.com

# MTR (continuous trace with packet loss stats)
bash scripts/netdiag.sh mtr example.com --count 10
```

**Output:**
```
=== Route Trace: example.com ===

Hop  Host                    Avg(ms)  Loss%
 1   gateway (192.168.1.1)   1.2      0.0%
 2   isp-router.net          8.4      0.0%
 3   core-router.isp.net     12.1     0.0%
 4   peer-link.cdn.net       24.8     0.0%
 5   example.com             28.3     0.0%

Total hops: 5 | Avg latency: 28.3ms | Packet loss: 0.0%
```

### Workflow 4: Bandwidth Testing

**Use case:** Test download/upload speeds.

```bash
# Download speed test (uses curl to a known CDN)
bash scripts/netdiag.sh speedtest

# Test against specific endpoint
bash scripts/netdiag.sh speedtest --url https://speed.cloudflare.com/__down?bytes=100000000

# Latency test (ping)
bash scripts/netdiag.sh ping example.com --count 10
```

**Output:**
```
=== Speed Test ===
[2026-02-22 03:55:00]

Download: 245.8 Mbps
  File: 100MB test file
  Time: 3.26s
  Server: Cloudflare CDN

Ping (example.com):
  Min: 24.1ms | Avg: 28.3ms | Max: 35.7ms | Loss: 0.0%
```

### Workflow 5: SSL/TLS Certificate Check

**Use case:** Inspect SSL certificates, check expiry, verify chain.

```bash
# Check SSL certificate
bash scripts/netdiag.sh ssl example.com

# Check multiple domains
bash scripts/netdiag.sh ssl example.com api.example.com staging.example.com
```

**Output:**
```
=== SSL Certificate: example.com ===

Subject:    CN=example.com
Issuer:     Let's Encrypt Authority X3
Valid From: 2026-01-15
Valid Until: 2026-04-15
Days Left:  52 ✅

Chain:
  1. example.com (RSA 2048)
  2. Let's Encrypt Authority X3
  3. ISRG Root X1 (trusted)

Protocol:   TLSv1.3
Cipher:     TLS_AES_256_GCM_SHA384
```

### Workflow 6: Full Diagnostic Report

**Use case:** Comprehensive network health check for a host.

```bash
# Generate full report
bash scripts/netdiag.sh report example.com

# Save to file
bash scripts/netdiag.sh report example.com --output report.txt
```

This runs: port scan + DNS lookup + SSL check + traceroute + ping test, all in one report.

### Workflow 7: Local Network Info

**Use case:** Check local network interfaces, connections, listening ports.

```bash
# Show network interfaces
bash scripts/netdiag.sh interfaces

# Show listening ports
bash scripts/netdiag.sh listening

# Show active connections
bash scripts/netdiag.sh connections

# Show public IP
bash scripts/netdiag.sh myip
```

### Workflow 8: WHOIS Lookup

**Use case:** Check domain registration details.

```bash
bash scripts/netdiag.sh whois example.com
```

## Configuration

### Environment Variables

```bash
# Default scan timeout (seconds)
export NETDIAG_TIMEOUT=10

# Default ping count
export NETDIAG_PING_COUNT=5

# MTR report count
export NETDIAG_MTR_COUNT=10

# Speed test file size (bytes)
export NETDIAG_SPEEDTEST_BYTES=100000000
```

## Troubleshooting

### Issue: "nmap: command not found"

```bash
# Run the installer
bash scripts/install.sh

# Or install manually
sudo apt-get install -y nmap        # Debian/Ubuntu
sudo yum install -y nmap            # RHEL/CentOS
brew install nmap                   # macOS
```

### Issue: "Permission denied" on port scan

Nmap needs root for SYN scans. Use:
```bash
# TCP connect scan (no root needed)
bash scripts/netdiag.sh portscan example.com --tcp-connect
```

### Issue: MTR not showing hostnames

```bash
# Use numeric mode (faster, no DNS resolution)
bash scripts/netdiag.sh mtr example.com --no-dns
```

## Dependencies

- `nmap` — Port scanning and service detection
- `dnsutils` / `bind-utils` — DNS queries (dig, nslookup)
- `mtr` — Network route analysis
- `curl` — HTTP requests, speed testing
- `openssl` — SSL certificate inspection
- `whois` — Domain registration lookup
- `netcat` (`nc`) — TCP/UDP connectivity testing
- `ss` / `netstat` — Local connection info
- `traceroute` — Route tracing (fallback for mtr)
