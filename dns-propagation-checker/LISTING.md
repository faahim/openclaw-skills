# Listing Copy: DNS Propagation Checker

## Metadata
- **Type:** Skill
- **Name:** dns-propagation-checker
- **Display Name:** DNS Propagation Checker
- **Categories:** [dev-tools, automation]
- **Icon:** 🌐
- **Dependencies:** [bash, dig]

## Tagline

Check DNS record propagation across 20+ global resolvers instantly

## Description

Changed your DNS records and wondering if they've propagated? Manually querying resolvers one by one is tedious and error-prone. You need to know exactly which global DNS servers have your new records and which are still serving stale data.

DNS Propagation Checker queries 20+ public DNS resolvers worldwide — Google, Cloudflare, Quad9, OpenDNS, AdGuard, Yandex, Baidu, and more — in parallel. See instant results with match/mismatch indicators, response latency, and a propagation percentage bar. Supports A, AAAA, CNAME, MX, TXT, NS, and all standard record types.

**What it does:**
- 🌐 Check propagation across 20 global DNS resolvers simultaneously
- ✅ Compare results against expected values or authoritative answers
- ⏱️ Monitor mode — keep checking until full propagation is achieved
- 📊 Output as table, JSON, or CSV for scripting
- 🔧 Custom resolver lists for internal DNS testing
- ⚡ Parallel queries with configurable concurrency
- 🔑 Show authoritative nameserver answer for comparison
- 📋 Batch check multiple domains via piping

## Quick Start Preview

```bash
bash scripts/check.sh mysite.com A --expect 203.0.113.50
```

## Core Capabilities

1. Multi-resolver check — Query 20+ DNS servers in one command
2. Record type support — A, AAAA, CNAME, MX, TXT, NS, SOA, SRV, CAA, PTR
3. Expected value matching — Compare against your target record value
4. Propagation monitoring — Wait mode polls until 100% propagated
5. Parallel querying — Fast results with configurable concurrency
6. Multiple output formats — Human table, JSON, CSV
7. Custom resolvers — Test against internal or custom DNS servers
8. Authoritative comparison — Show what the authoritative NS returns
9. Latency tracking — See response time from each resolver
10. Zero external services — Uses dig locally, no API keys needed

## Dependencies
- `bash` (4.0+)
- `dig` (from dnsutils / bind-utils)
- Optional: `jq` (JSON formatting)

## Installation Time
**2 minutes** — dig is pre-installed on most systems
