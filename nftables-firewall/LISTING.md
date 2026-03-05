# Listing Copy: nftables Firewall Manager

## Metadata
- **Type:** Skill
- **Name:** nftables-firewall
- **Display Name:** nftables Firewall Manager
- **Categories:** [security, automation]
- **Icon:** 🛡️
- **Dependencies:** [nftables, bash, jq]

## Tagline

Manage Linux firewalls with nftables — presets, rate-limiting, GeoIP blocking, and more

## Description

Setting up a Linux firewall shouldn't require memorizing iptables syntax or copy-pasting Stack Overflow answers. With nftables replacing iptables as the modern Linux firewall framework, there's a better way.

nftables Firewall Manager gives your OpenClaw agent full control over your server's firewall. Apply battle-tested presets (web server, Docker host, lockdown), add rules on the fly, block IPs from threat feeds, rate-limit brute-force attempts, and set up port forwarding — all through simple commands.

**What it does:**
- 🛡️ Five ready-made presets (server-basic, server-full, desktop, lockdown, docker-host)
- 🚫 IP blocklists — block individual IPs, CIDR ranges, or import from files
- ⏱️ Rate limiting — stop brute-force attacks with per-port rate limits
- 🌍 GeoIP blocking — block entire countries with one command
- 🔄 NAT & port forwarding — redirect traffic between ports/services
- 📊 Threat feed updates — auto-pull Spamhaus DROP + Emerging Threats lists
- 💾 Backup & restore — export/import full rulesets
- 🔒 SSH safety — never accidentally lock yourself out
- ☁️ Docker-friendly — preset that coexists with Docker networking

Perfect for sysadmins, developers, and self-hosters who want a secure, manageable firewall without the complexity of raw nftables syntax.

## Quick Start Preview

```bash
# Install nftables
sudo bash scripts/install.sh

# Apply a secure preset
sudo bash scripts/nft-manage.sh apply-preset server-basic

# Block an IP
sudo bash scripts/nft-manage.sh block --ip 1.2.3.4

# Rate-limit SSH
sudo bash scripts/nft-manage.sh rate-limit --port 22 --rate "5/minute"
```

## Core Capabilities

1. Preset rulesets — One-command secure setup for common server types
2. IP blocking — Single IPs, CIDR ranges, or bulk import from files
3. Rate limiting — Per-port rate limits with configurable burst
4. GeoIP blocking — Block traffic by country code
5. Port forwarding — NAT/DNAT with automatic IP forwarding setup
6. Threat feeds — Auto-update from Spamhaus + Emerging Threats
7. Fail2Ban integration — Create dedicated nftables sets
8. Backup/restore — Export and import complete rulesets
9. SSH safety — Built-in protection against lockout
10. Docker compatibility — Preset that works alongside Docker networking
11. Persistent rules — Auto-save to survive reboots
12. Dry-run mode — Preview changes before applying

## Dependencies
- `nftables` (1.0+)
- `bash` (4.0+)
- `jq`
- `curl` (for GeoIP/threat feeds)
- Root/sudo access

## Installation Time
**5 minutes**
