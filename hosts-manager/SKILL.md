---
name: hosts-manager
description: >-
  Manage /etc/hosts entries, block ads/trackers with curated blocklists, whitelist domains, and maintain custom DNS mappings — all from the command line.
categories: [security, home]
dependencies: [bash, curl, grep, awk]
---

# Hosts File Manager

## What This Does

Manage your system's `/etc/hosts` file to block ads, trackers, malware domains, and add custom DNS mappings. Downloads and merges curated blocklists (Steven Black, Energized), lets you whitelist domains, and backs up before every change.

**Example:** "Block 50,000+ ad/tracker domains, whitelist `analytics.mysite.com`, add `192.168.1.50 homelab.local`."

## Quick Start (2 minutes)

### 1. Install

```bash
# Copy the script
chmod +x scripts/hosts-manager.sh

# Verify (no changes yet)
bash scripts/hosts-manager.sh status
```

### 2. Block Ads & Trackers

```bash
# Download Steven Black's unified hosts (ads + malware)
sudo bash scripts/hosts-manager.sh block --list steven-black

# Or use Energized Basic (lighter)
sudo bash scripts/hosts-manager.sh block --list energized-basic
```

### 3. Add Custom Entry

```bash
# Map a local hostname
sudo bash scripts/hosts-manager.sh add 192.168.1.50 homelab.local

# Block a specific domain
sudo bash scripts/hosts-manager.sh add 0.0.0.0 facebook.com
```

### 4. Whitelist a Domain

```bash
# Ensure a domain is never blocked
sudo bash scripts/hosts-manager.sh whitelist analytics.mysite.com
```

## Core Workflows

### Workflow 1: Full Ad/Tracker Blocking

**Use case:** Block ads, trackers, and malware domains system-wide

```bash
# Apply comprehensive blocklist
sudo bash scripts/hosts-manager.sh block --list steven-black

# Output:
# ✅ Backed up /etc/hosts to /etc/hosts.bak.2026-02-26
# 📥 Downloaded Steven Black unified hosts (58,432 domains)
# 🔒 Applied blocklist — 58,432 domains now blocked
# ℹ️  Whitelist: 0 domains preserved
```

### Workflow 2: Custom DNS Mappings

**Use case:** Map hostnames to IPs for local development or homelab

```bash
# Add multiple entries
sudo bash scripts/hosts-manager.sh add 192.168.1.10 nas.local
sudo bash scripts/hosts-manager.sh add 192.168.1.20 pi.local
sudo bash scripts/hosts-manager.sh add 127.0.0.1 myapp.test

# List custom entries
bash scripts/hosts-manager.sh list --custom
```

### Workflow 3: Selective Blocking

**Use case:** Block specific distracting sites

```bash
# Block social media during work hours
sudo bash scripts/hosts-manager.sh add 0.0.0.0 facebook.com
sudo bash scripts/hosts-manager.sh add 0.0.0.0 www.facebook.com
sudo bash scripts/hosts-manager.sh add 0.0.0.0 twitter.com
sudo bash scripts/hosts-manager.sh add 0.0.0.0 www.twitter.com
sudo bash scripts/hosts-manager.sh add 0.0.0.0 reddit.com
sudo bash scripts/hosts-manager.sh add 0.0.0.0 www.reddit.com

# Unblock when done
sudo bash scripts/hosts-manager.sh remove facebook.com
sudo bash scripts/hosts-manager.sh remove www.facebook.com
```

### Workflow 4: Restore from Backup

**Use case:** Something went wrong, restore original hosts

```bash
# List backups
bash scripts/hosts-manager.sh backups

# Restore latest
sudo bash scripts/hosts-manager.sh restore

# Restore specific backup
sudo bash scripts/hosts-manager.sh restore /etc/hosts.bak.2026-02-26
```

### Workflow 5: Update Blocklists

**Use case:** Refresh blocklist with latest domains

```bash
# Update to latest version
sudo bash scripts/hosts-manager.sh update

# Output:
# 📥 Downloading latest Steven Black unified hosts...
# ✅ Updated: 58,432 → 59,108 domains blocked (+676 new)
# ℹ️  Whitelist preserved: 3 domains
```

## Available Blocklists

| List | Domains | Focus | Size |
|------|---------|-------|------|
| `steven-black` | ~58K | Ads + Malware (recommended) | ~1.7MB |
| `steven-black-fakenews` | ~75K | + Fake news | ~2.2MB |
| `steven-black-social` | ~80K | + Social media | ~2.3MB |
| `energized-basic` | ~45K | Lightweight blocking | ~1.3MB |
| `energized-ultimate` | ~500K | Maximum blocking | ~15MB |

## Configuration

### Whitelist File

Create `~/.config/hosts-manager/whitelist.txt`:

```
# Domains that should never be blocked
analytics.mysite.com
ads.google.com
# One domain per line
```

### Custom Entries File

Create `~/.config/hosts-manager/custom-hosts.txt`:

```
# Custom DNS mappings (preserved across blocklist updates)
192.168.1.10 nas.local
192.168.1.20 pi.local
127.0.0.1 myapp.test
```

## Command Reference

```bash
# Status — show current hosts stats
bash scripts/hosts-manager.sh status

# Block — apply a blocklist
sudo bash scripts/hosts-manager.sh block --list <list-name>

# Update — refresh current blocklist
sudo bash scripts/hosts-manager.sh update

# Add — add a single entry
sudo bash scripts/hosts-manager.sh add <ip> <hostname>

# Remove — remove a hostname
sudo bash scripts/hosts-manager.sh remove <hostname>

# Whitelist — add domain to whitelist
sudo bash scripts/hosts-manager.sh whitelist <domain>

# List — show entries
bash scripts/hosts-manager.sh list [--custom|--blocked|--all]

# Search — find a domain
bash scripts/hosts-manager.sh search <pattern>

# Backups — list available backups
bash scripts/hosts-manager.sh backups

# Restore — restore from backup
sudo bash scripts/hosts-manager.sh restore [backup-path]

# Flush — flush DNS cache
sudo bash scripts/hosts-manager.sh flush

# Reset — remove all blocklist entries, keep custom
sudo bash scripts/hosts-manager.sh reset
```

## Troubleshooting

### Issue: "Permission denied"

**Fix:** Use `sudo` — hosts file requires root access:
```bash
sudo bash scripts/hosts-manager.sh block --list steven-black
```

### Issue: Websites still loading after blocking

**Fix:** Flush DNS cache:
```bash
sudo bash scripts/hosts-manager.sh flush
```

### Issue: Legitimate site blocked by blocklist

**Fix:** Add to whitelist:
```bash
sudo bash scripts/hosts-manager.sh whitelist example.com
sudo bash scripts/hosts-manager.sh update  # Re-apply without whitelisted domain
```

### Issue: Slow DNS resolution after large blocklist

**Fix:** Use a lighter blocklist:
```bash
sudo bash scripts/hosts-manager.sh block --list energized-basic  # 45K vs 500K domains
```

## Key Principles

1. **Always backs up** — Never modifies `/etc/hosts` without creating a backup
2. **Preserves custom entries** — Your manual entries survive blocklist updates
3. **Whitelist-aware** — Whitelisted domains are never blocked
4. **Atomic writes** — Uses temp file + mv to prevent corruption
5. **Idempotent** — Running the same command twice is safe

## Dependencies

- `bash` (4.0+)
- `curl` (downloading blocklists)
- `grep`, `awk`, `sort` (text processing)
- `sudo` (modifying /etc/hosts)
