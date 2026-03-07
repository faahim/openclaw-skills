# Listing Copy: Dnsmasq Manager

## Metadata
- **Type:** Skill
- **Name:** dnsmasq-manager
- **Display Name:** Dnsmasq Manager
- **Categories:** [home, automation]
- **Icon:** 🌐
- **Dependencies:** [bash, dnsmasq, curl]

## Tagline

Lightweight DNS forwarder, ad blocker, and DHCP server — managed in one command.

## Description

Running Pi-hole just for DNS-level ad blocking feels like using a sledgehammer to hang a picture. Dnsmasq does the same job in a fraction of the memory, with zero web UI overhead.

**Dnsmasq Manager** installs and configures dnsmasq as your local DNS forwarder, network-level ad blocker, and DHCP server. One script handles installation across Debian, Ubuntu, RHEL, Fedora, Arch, Alpine, and macOS. Another sets up DNS forwarding, caching, and ad blocking in under 5 minutes.

**What it does:**
- 🌐 Local DNS forwarding with configurable upstream servers (Cloudflare, Google, custom)
- 🚫 Network-level ad blocking using community-maintained blocklists (85,000+ domains)
- 📡 DHCP server with static leases for home labs and dev environments
- 🔀 Split DNS — route internal domains to internal servers
- 🌍 Wildcard domains — *.dev.local → your dev box
- 📊 Query logging and analytics — see what's being resolved
- 💾 Backup and restore config with one command

Perfect for home lab enthusiasts, developers running local services, and anyone who wants DNS-level ad blocking without Pi-hole's overhead.

## Core Capabilities

1. Auto-install — Detects OS, installs dnsmasq, handles systemd-resolved conflicts
2. DNS forwarding — Cache queries locally, use any upstream DNS provider
3. Ad blocking — Download and apply community blocklists, whitelist exceptions
4. DHCP server — Assign IPs, set static leases, advertise gateway and DNS
5. Custom domains — Map hostnames to IPs for local services
6. Wildcard domains — Route entire subdomains to one IP
7. Conditional forwarding — Send specific domains to specific DNS servers
8. Query logging — Track DNS queries, find top domains, spot blocked requests
9. Config backup/restore — Never lose your setup
10. Service management — Start, stop, restart, status with one command

## Installation Time

**5 minutes** — Install, configure upstream DNS, optional ad blocking
