# Listing Copy: DNS Benchmark Tool

## Metadata
- **Type:** Skill
- **Name:** dns-benchmark
- **Display Name:** DNS Benchmark Tool
- **Categories:** [dev-tools, analytics]
- **Price:** $8
- **Dependencies:** [bash, dig, bc]

## Tagline

"Benchmark DNS resolvers — Find the fastest one for your location"

## Description

Slow DNS resolution adds invisible latency to every web request, API call, and service your machine touches. Most people stick with their ISP's default DNS without knowing it might be 5-10x slower than alternatives like Cloudflare or Quad9.

DNS Benchmark Tool tests 12+ public DNS resolvers from your actual location, measuring real latency, packet loss, and DNSSEC support. It runs multiple queries against multiple domains to produce statistically reliable results — not just a single ping.

**What it does:**
- ⚡ Tests 12 popular DNS resolvers (Cloudflare, Google, Quad9, OpenDNS, etc.)
- 📊 Measures average, median, min, max latency and packet loss
- 🔐 Validates DNSSEC support per resolver
- 🏆 Ranks resolvers and recommends the fastest
- ⚙️ Optionally applies the winner to your system DNS
- 📋 JSON output for automation and logging
- 🔒 Privacy-only mode (test no-logging resolvers only)

Perfect for developers, sysadmins, and homelabbers who want to squeeze every millisecond of latency out of their DNS.

## Core Capabilities

1. Multi-resolver benchmark — Test 12+ resolvers simultaneously
2. Statistical accuracy — Multiple queries per resolver for reliable results
3. DNSSEC validation — Check which resolvers properly validate DNSSEC
4. Packet loss detection — Identify unreliable resolvers
5. Privacy-focused mode — Test only no-logging resolvers (Cloudflare, Quad9, Mullvad)
6. Custom resolvers — Add your own (Pi-hole, local router, corporate DNS)
7. System DNS apply — Automatically configure your system with the winner
8. JSON output — Pipe results into dashboards or monitoring tools
9. Current DNS comparison — Include your existing resolver in the benchmark
10. Cron-ready — Schedule weekly benchmarks to track DNS performance over time

## Dependencies
- `bash` (4.0+)
- `dig` (from dnsutils/bind-utils)
- `bc` (floating-point math)

## Installation Time
**2 minutes** — Install dig if missing, run script
