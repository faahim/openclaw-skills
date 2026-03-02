# Listing Copy: Unbound DNS Resolver

## Metadata
- **Type:** Skill
- **Name:** unbound-dns
- **Display Name:** Unbound DNS Resolver
- **Categories:** [security, home]
- **Icon:** 🛡️
- **Price:** $10
- **Dependencies:** [bash, curl, unbound]

## Tagline

Run your own recursive DNS resolver — full privacy, DNSSEC, and ad-blocking built in.

## Description

Every DNS query you make tells someone which websites you visit. Even "privacy-focused" DNS providers like Cloudflare and Google see every domain you resolve. The only way to truly own your DNS is to resolve it yourself.

Unbound DNS Resolver installs and configures Unbound as a local recursive DNS resolver. Your machine queries root servers directly — no middleman sees your traffic. It validates responses with DNSSEC, caches aggressively for speed, and optionally blocks 140,000+ ad/tracker domains using the StevenBlack hosts list.

**What it does:**
- 🔒 Full recursive DNS resolution — queries root servers directly, no third-party
- 🔐 DNSSEC validation — cryptographically verifies DNS responses
- 🚫 Optional ad/tracker blocking — 140K+ domains blocked (StevenBlack list)
- ⚡ Aggressive caching — sub-millisecond responses for cached domains
- 📊 Query logging & analysis — see what's being resolved, find suspicious patterns
- 🏠 Local DNS zones — add custom entries (homelab, dev servers)
- 🔄 Auto-updatable blocklists via cron
- 🖥️ Multi-OS support — Debian, Ubuntu, Fedora, Arch, Alpine, macOS

Perfect for privacy-conscious developers, homelab enthusiasts, and anyone who wants DNS they actually control.

## Quick Start Preview

```bash
bash scripts/install.sh
sudo bash scripts/configure.sh --mode recursive
sudo bash scripts/set-system-dns.sh
bash scripts/status.sh
# ✅ Unbound is running (PID 1234)
# ✅ DNSSEC validation: active
# ✅ Listening on: 127.0.0.1:53
```

## Core Capabilities

1. Recursive DNS resolution — query root servers directly, maximum privacy
2. Forwarding mode — cache + DNSSEC with Cloudflare/Quad9/Google upstream (TLS)
3. Ad-blocking mode — block 140K+ ad/tracker domains at DNS level
4. DNSSEC validation — reject forged DNS responses automatically
5. Query logging — analyze DNS traffic, detect suspicious patterns
6. Local DNS zones — custom domain-to-IP mappings for homelab
7. Cache management — stats, dump, flush per-domain or full
8. Multi-OS install — one script handles Debian, Ubuntu, Fedora, Arch, Alpine, macOS
9. Cron-ready blocklist updates — keep blocklists fresh automatically
10. Uninstall script — clean restore to original DNS config
