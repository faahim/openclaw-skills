# Listing Copy: Unbound DNS Resolver

## Metadata
- **Type:** Skill
- **Name:** unbound-dns
- **Display Name:** Unbound DNS Resolver
- **Categories:** [security, home]
- **Price:** $12
- **Icon:** 🛡️
- **Dependencies:** [bash, curl, unbound]

## Tagline

"Private recursive DNS resolver — Stop leaking every domain you visit"

## Description

Every DNS query you make tells someone what you're browsing. Google, Cloudflare, your ISP — they all see every domain you visit. Even "privacy-friendly" DNS providers still log your queries on their servers.

Unbound DNS Resolver sets up a local recursive DNS resolver that talks directly to authoritative nameservers. No middleman. Your DNS queries never leave your machine. Plus you get DNSSEC validation, aggressive caching (sub-millisecond repeat lookups), and optional ad-blocking that blocks 85,000+ ad/tracker domains at the DNS level.

**What you get:**
- 🛡️ Full DNS privacy — queries go direct to authoritative servers
- ⚡ Sub-millisecond cached lookups (vs 20-50ms to external DNS)
- 🔐 DNSSEC validation out of the box
- 🚫 DNS-level ad-blocking (85K+ domains, auto-updated daily)
- 🏠 Custom local zones for homelab services (nas.home, server.home)
- 📊 Built-in stats dashboard (cache hit rates, query counts, latency)
- 🔧 One-command install, works on Ubuntu/Debian/RHEL/Arch/macOS

## Quick Start Preview

```bash
bash scripts/install.sh       # Auto-detect OS, install Unbound
bash scripts/configure.sh     # Optimized config + DNSSEC + start
bash scripts/verify.sh        # Verify everything works
bash scripts/adblock.sh --enable  # Optional: block 85K ad domains
```

## Core Capabilities

1. Recursive DNS resolution — talk directly to authoritative nameservers
2. DNSSEC validation — reject spoofed/tampered DNS responses
3. Aggressive caching — sub-ms repeat lookups, prefetching for popular domains
4. DNS-level ad-blocking — 85K+ domains via Steven Black's unified list
5. DNS-over-TLS forwarding — encrypted queries to upstream resolvers
6. Custom local zones — map homelab domains to local IPs
7. Multi-OS support — Ubuntu, Debian, RHEL, Fedora, Arch, Alpine, macOS
8. Network-wide DNS — serve your entire LAN from one machine
9. Cache management — flush, dump, inspect cached records
10. Health monitoring — cron-ready health check script with alerting
11. Statistics dashboard — query counts, cache hit rates, memory usage
12. Clean uninstall — removes everything, restores original DNS

## Dependencies
- `bash` (4.0+)
- `curl`
- `unbound` (installed by install.sh)
- Root/sudo access

## Installation Time
**5 minutes**

## Pricing Justification

**Why $12:**
- Self-hosted alternative to Pi-hole DNS ($0 but hours of setup)
- No monthly fees (vs NextDNS $20/yr, custom DNS services)
- Includes ad-blocking, DNSSEC, local zones, monitoring
- One-time purchase, unlimited use
