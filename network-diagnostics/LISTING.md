# Listing Copy: Network Diagnostics Toolkit

## Metadata
- **Type:** Skill
- **Name:** network-diagnostics
- **Display Name:** Network Diagnostics Toolkit
- **Categories:** [security, dev-tools]
- **Price:** $12
- **Dependencies:** [nmap, dig, mtr, curl, openssl, whois]

## Tagline
Scan ports, trace routes, check DNS & SSL — complete network diagnostics from your agent.

## Description

Diagnosing network issues usually means SSH-ing into a server, remembering obscure flag combinations for nmap/dig/mtr, and piecing together results from 6 different tools. Your agent should handle this.

Network Diagnostics Toolkit wraps nmap, dig, mtr, openssl, whois, and more into a single unified script. Port scan a server, check DNS propagation, inspect SSL certificates, trace routes, test bandwidth — all with one command. No external services, no monthly fees.

**What it does:**
- 🔍 Port scanning with service detection (nmap)
- 🌐 DNS lookups across all record types + propagation check
- 🔐 SSL certificate inspection with expiry alerts
- 📡 Route tracing with latency and packet loss stats (mtr)
- ⚡ Download speed testing via Cloudflare CDN
- 🏠 Local network info: interfaces, listening ports, connections
- 📋 Full diagnostic reports combining all checks
- 🔎 WHOIS domain registration lookups

Perfect for developers, sysadmins, and DevOps engineers who want their agent to handle network troubleshooting without memorizing CLI flags.

## Core Capabilities

1. Port scanning — Quick (top 100), full (65535), or targeted port scans
2. Service detection — Identify what's running on open ports
3. DNS diagnostics — All record types + multi-server propagation check
4. SSL inspection — Certificate chain, expiry countdown, protocol/cipher info
5. Route tracing — MTR with packet loss statistics per hop
6. Speed testing — Download bandwidth via Cloudflare CDN
7. Ping monitoring — Latency and packet loss measurement
8. Local network — Interfaces, listening ports, active connections
9. Public IP — IP address with geolocation info
10. WHOIS — Domain registration and expiry details
11. Full reports — One-command comprehensive diagnostics
12. Auto-installer — Detects OS and installs all dependencies

## Installation Time
**5 minutes** — Run install.sh, start diagnosing
