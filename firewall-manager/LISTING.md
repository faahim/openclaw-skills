# Listing Copy: Firewall Manager

## Metadata
- **Type:** Skill
- **Name:** firewall-manager
- **Display Name:** Firewall Manager
- **Categories:** [security, automation]
- **Price:** $12
- **Dependencies:** [bash, ufw]

## Tagline

"Manage UFW firewall rules — Harden servers, open ports, audit security in seconds"

## Description

Manually configuring firewall rules is tedious and error-prone. One wrong iptables command can lock you out of your own server. You need a reliable way to manage firewall rules without memorizing cryptic syntax.

Firewall Manager wraps UFW (and firewalld) into a clean, scriptable interface your OpenClaw agent can use. Install UFW, set secure defaults, manage port rules, apply server presets, and run automated security audits — all with simple commands. No external services, no monthly fees.

**What it does:**
- 🔒 Install & configure UFW with secure defaults (deny incoming, allow outgoing)
- 🚪 Open/close ports with one command (`allow 80`, `block 203.0.113.50`)
- ⚡ Rate-limit ports to prevent brute force attacks
- 🖥️ Server presets: web-server, db-server, docker-host, minimal
- 🔍 Security audit with scoring (0-10) and actionable warnings
- 🐳 Fix Docker/UFW conflicts automatically
- 📋 Export/import rules across servers
- 📊 Log monitoring for blocked connections

**Perfect for developers, sysadmins, and anyone managing Linux servers who wants reliable firewall management without the complexity.**

## Core Capabilities

1. UFW installation — Auto-install with safe defaults (SSH always allowed first)
2. Port management — Allow, block, rate-limit any port/protocol
3. IP blocking — Block individual IPs or entire subnets
4. Source-based rules — Allow specific ports from trusted IPs only
5. Server presets — One-command setup for web, database, Docker, minimal configs
6. Security audit — Scored assessment with actionable recommendations
7. Rate limiting — Protect against brute force (6 connections per 30s)
8. Docker fix — Resolve Docker/UFW iptables conflict automatically
9. Rule export/import — Move firewall configs between servers
10. Application profiles — Use UFW app profiles (Nginx, OpenSSH, etc.)
11. Logging — Configure and monitor firewall logs
12. Firewalld fallback — Works on CentOS/RHEL with firewalld

## Dependencies
- `bash` (4.0+)
- `ufw` (auto-installed) or `firewalld`
- `sudo` access

## Installation Time
**2 minutes** — Run install, get secure defaults immediately
