---
name: system-inventory
description: >-
  Generate comprehensive system inventory reports — hardware, OS, packages,
  services, network, storage, and users in one command.
categories: [dev-tools, automation]
dependencies: [bash, coreutils]
---

# System Inventory Tool

## What This Does

Generates a detailed inventory of your entire system: hardware specs, OS info, installed packages, running services, network configuration, storage layout, open ports, and user accounts. Output as structured markdown or JSON for documentation, auditing, migration planning, or disaster recovery.

**Example:** "Scan this server, give me a full inventory report I can save for documentation."

## Quick Start (2 minutes)

### 1. Run Full Inventory

```bash
bash scripts/inventory.sh
```

This produces a comprehensive markdown report to stdout. Redirect to save:

```bash
bash scripts/inventory.sh > inventory-$(hostname)-$(date +%Y%m%d).md
```

### 2. Run Specific Sections

```bash
# Hardware only
bash scripts/inventory.sh --section hardware

# Network only
bash scripts/inventory.sh --section network

# Storage only
bash scripts/inventory.sh --section storage

# Services only
bash scripts/inventory.sh --section services

# Packages only
bash scripts/inventory.sh --section packages

# Users only
bash scripts/inventory.sh --section users
```

### 3. JSON Output

```bash
bash scripts/inventory.sh --format json > inventory.json
```

### 4. Compare Two Snapshots

```bash
# Take baseline
bash scripts/inventory.sh --format json > baseline.json

# Later, take another snapshot and diff
bash scripts/inventory.sh --format json > current.json
bash scripts/diff-inventory.sh baseline.json current.json
```

## Core Workflows

### Workflow 1: Full Server Documentation

**Use case:** Document a server for handoff or compliance

```bash
bash scripts/inventory.sh > /docs/server-$(hostname).md
```

**Output includes:**
- Hostname, OS, kernel, uptime, timezone
- CPU model, cores, RAM, swap
- All disks, partitions, mount points, usage
- Network interfaces, IPs, DNS, routes
- Running services (systemd)
- Installed packages (apt/dnf/pacman)
- User accounts and groups
- Open ports and listening services
- Cron jobs

### Workflow 2: Pre-Migration Snapshot

**Use case:** Capture system state before migrating to new server

```bash
bash scripts/inventory.sh --format json > pre-migration.json

# After migration, compare
bash scripts/inventory.sh --format json > post-migration.json
bash scripts/diff-inventory.sh pre-migration.json post-migration.json
```

**Diff output:**
```
+ ADDED: nginx 1.24.0 (package)
- REMOVED: apache2 2.4.57 (package)
~ CHANGED: disk /dev/sda1 usage 45% → 23%
= UNCHANGED: 847 items
```

### Workflow 3: Security Audit Snapshot

**Use case:** Periodic security inventory — who has access, what's running

```bash
bash scripts/inventory.sh --section users --section services --section network
```

### Workflow 4: Scheduled Inventory (Cron)

```bash
# Weekly inventory snapshot
0 0 * * 0 cd /path/to/skill && bash scripts/inventory.sh > /backups/inventory-$(date +\%Y\%m\%d).md
```

## Configuration

### Environment Variables

```bash
# Include sudo commands (for hardware details like dmidecode)
export INVENTORY_SUDO=true

# Custom sections to include (comma-separated)
export INVENTORY_SECTIONS="hardware,network,storage,services"

# Output format (markdown or json)
export INVENTORY_FORMAT=markdown
```

### Sections Available

| Section | What It Collects | Needs Sudo? |
|---------|-----------------|-------------|
| `system` | Hostname, OS, kernel, uptime, timezone | No |
| `hardware` | CPU, RAM, swap, DMI data | Partial (dmidecode) |
| `storage` | Disks, partitions, mounts, usage, inodes | No |
| `network` | Interfaces, IPs, DNS, routes, open ports | Partial (ss) |
| `services` | Systemd units, enabled/running status | No |
| `packages` | Installed packages with versions | No |
| `users` | User accounts, groups, sudo access, login shells | No |
| `cron` | Cron jobs for all users | Partial |
| `docker` | Containers, images, volumes (if Docker installed) | Partial |

## Advanced Usage

### Filter by Pattern

```bash
# Only show packages matching "nginx"
bash scripts/inventory.sh --section packages --filter nginx

# Only show services that are running
bash scripts/inventory.sh --section services --filter running
```

### Machine-Readable Sections

```bash
# Get just the package list as TSV
bash scripts/inventory.sh --section packages --format tsv
```

### Remote Inventory via SSH

```bash
ssh user@server 'bash -s' < scripts/inventory.sh > remote-inventory.md
```

## Troubleshooting

### Issue: "Permission denied" for hardware details

**Fix:** Run with sudo or set `INVENTORY_SUDO=true`:
```bash
sudo bash scripts/inventory.sh
```

### Issue: Missing package manager

The script auto-detects apt, dnf, yum, pacman, apk, zypper. If your package manager isn't detected, packages section will be skipped with a note.

### Issue: No Docker section

Docker section only appears if `docker` command is available and the user has permission to run it.

## Dependencies

- `bash` (4.0+)
- `coreutils` (uname, df, du, wc, sort, etc.)
- Optional: `lshw`, `dmidecode` (detailed hardware info)
- Optional: `jq` (for JSON output formatting)
- Optional: `docker` (for container inventory)

## Key Principles

1. **Non-destructive** — Read-only commands, never modifies system
2. **Portable** — Works on Debian, Ubuntu, RHEL, Fedora, Arch, Alpine
3. **Graceful degradation** — Skips unavailable tools, doesn't error
4. **Deterministic** — Same system = same output (minus timestamps)
