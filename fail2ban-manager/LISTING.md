# Listing Copy: Fail2ban Manager

## Metadata
- **Type:** Skill
- **Name:** fail2ban-manager
- **Display Name:** Fail2ban Manager
- **Categories:** [security, automation]
- **Icon:** 🛡️
- **Dependencies:** [fail2ban, bash, iptables]

## Tagline

Intrusion prevention made simple — install, configure, and manage Fail2ban with one-command setup and Telegram alerts.

## Description

Every server connected to the internet gets hit with brute-force attacks. SSH bots try thousands of passwords per hour. Without protection, it's only a matter of time before one gets through.

Fail2ban Manager automates intrusion prevention from install to monitoring. One command installs fail2ban, configures jails for SSH/Nginx/Apache, whitelists your trusted IPs, and sends real-time Telegram alerts when attackers get banned. No manual config file editing required.

**What it does:**
- 🛡️ Install fail2ban on any Linux distro (Ubuntu, CentOS, Fedora, Arch)
- 🔒 Configure jails: SSH, Nginx, Apache, or custom services
- 📱 Telegram alerts on every ban with IP + country + timestamp
- 🏳️ Whitelist trusted IPs and CIDR ranges
- 📊 Ban history, top offenders, country breakdown
- ☁️ Optional Cloudflare integration (ban at CDN level)
- 🔧 Custom jails with regex filters for any log file
- 📋 CSV export for ban analytics

Perfect for developers, sysadmins, and anyone running a VPS who needs server security without the complexity.

## Core Capabilities

1. One-command install — Auto-detects OS, installs fail2ban, enables on boot
2. SSH protection — Ban brute-force attackers after N failed attempts
3. Web server protection — Nginx and Apache jail configurations
4. Telegram alerts — Real-time notifications with IP, country, and failure count
5. IP whitelisting — Never accidentally lock yourself or your team out
6. Manual ban/unban — Instantly block or release specific IPs
7. Ban history — View recent bans, top offenders, stats by country
8. Custom jails — Protect any service with regex-based log filters
9. Cloudflare integration — Ban IPs at the CDN edge, not just iptables
10. Recidive jail — Permanently ban repeat offenders automatically
11. Multi-server — Check status across multiple servers via SSH
12. CSV export — Export ban data for analysis or reporting
