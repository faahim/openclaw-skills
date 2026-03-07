---
name: system-inventory
description: >-
  Generate comprehensive hardware and software inventory reports for any Linux system.
categories: [automation, analytics]
dependencies: [bash, lscpu, lsblk, ip, dpkg/rpm]
---

# System Inventory Reporter

## What This Does

Generate a complete hardware and software inventory of any Linux system in seconds. Outputs CPU, RAM, storage, network, installed packages, running services, open ports, and system info as JSON, Markdown, or HTML reports.

**Example:** "Scan this server, output a full inventory report I can share with my team or use for documentation."

## Quick Start (2 minutes)

### 1. Run Basic Inventory

```bash
bash scripts/inventory.sh
```

This prints a Markdown summary to stdout.

### 2. Export to File

```bash
# JSON (machine-readable)
bash scripts/inventory.sh --format json --output inventory.json

# Markdown (human-readable)
bash scripts/inventory.sh --format md --output inventory.md

# HTML (shareable report)
bash scripts/inventory.sh --format html --output inventory.html
```

### 3. Specific Sections Only

```bash
# Just hardware info
bash scripts/inventory.sh --sections cpu,memory,storage

# Just software info
bash scripts/inventory.sh --sections packages,services

# Just network info
bash scripts/inventory.sh --sections network,ports
```

## Core Workflows

### Workflow 1: Full System Audit

**Use case:** Document everything about a server for handoff or compliance.

```bash
bash scripts/inventory.sh --format json --output /tmp/audit-$(hostname)-$(date +%Y%m%d).json
```

**Output includes:**
- Hostname, OS, kernel, uptime, timezone
- CPU model, cores, architecture, frequency
- RAM total/used/available, swap
- All block devices with sizes and mount points
- Network interfaces with IPs and MAC addresses
- Listening ports and associated processes
- Installed packages (deb or rpm)
- Running systemd services
- Environment summary (locale, shell, users)

### Workflow 2: Compare Two Systems

**Use case:** Verify staging matches production.

```bash
# On server A
bash scripts/inventory.sh --format json --output server-a.json

# On server B
bash scripts/inventory.sh --format json --output server-b.json

# Compare (using jq)
diff <(jq -S . server-a.json) <(jq -S . server-b.json)
```

### Workflow 3: Track Changes Over Time

**Use case:** Detect drift — new packages, changed services, new ports.

```bash
# Save baseline
bash scripts/inventory.sh --format json --output baseline.json

# Later, compare
bash scripts/inventory.sh --format json --output current.json
bash scripts/diff.sh baseline.json current.json
```

**Diff output:**
```
=== Package Changes ===
+ nginx 1.24.0 (newly installed)
- apache2 2.4.58 (removed)

=== Service Changes ===
~ nginx.service: inactive → active

=== Port Changes ===
+ 0.0.0.0:443 (nginx)
```

### Workflow 4: Security Quick Check

**Use case:** Spot open ports and unknown services.

```bash
bash scripts/inventory.sh --sections ports,services --format md
```

### Workflow 5: Asset Documentation

**Use case:** Generate a report for your fleet/wiki.

```bash
bash scripts/inventory.sh --format html --output "$(hostname)-inventory.html"
# Open in browser or upload to wiki
```

## Configuration

### Environment Variables

```bash
# Skip slow operations (package listing on large systems)
export INVENTORY_SKIP_PACKAGES=1

# Include detailed disk SMART data (requires smartctl)
export INVENTORY_SMART=1

# Custom output directory
export INVENTORY_OUTPUT_DIR=/var/log/inventory
```

### Sections Available

| Section | What It Collects | Tools Used |
|---------|-----------------|------------|
| `system` | Hostname, OS, kernel, uptime | `uname`, `/etc/os-release` |
| `cpu` | Model, cores, freq, arch | `lscpu` |
| `memory` | RAM, swap, usage | `free` |
| `storage` | Block devices, mounts, usage | `lsblk`, `df` |
| `network` | Interfaces, IPs, MACs, routes | `ip`, `ss` |
| `ports` | Listening ports + processes | `ss` |
| `packages` | All installed packages | `dpkg`/`rpm` |
| `services` | Systemd services + status | `systemctl` |
| `users` | System users, logged in, sudoers | `who`, `getent` |
| `docker` | Containers, images (if Docker present) | `docker` |

Default: all sections.

## Advanced Usage

### Run on Remote Systems via SSH

```bash
# Copy script and run remotely
scp scripts/inventory.sh user@remote:/tmp/
ssh user@remote 'bash /tmp/inventory.sh --format json' > remote-inventory.json
```

### Cron-Based Drift Detection

```bash
# Daily inventory snapshot
0 2 * * * cd /path/to/skill && bash scripts/inventory.sh --format json --output /var/log/inventory/$(date +\%Y-\%m-\%d).json

# Weekly diff report
0 3 * * 1 cd /path/to/skill && bash scripts/diff.sh /var/log/inventory/$(date -d '7 days ago' +\%Y-\%m-\%d).json /var/log/inventory/$(date +\%Y-\%m-\%d).json > /var/log/inventory/weekly-diff.md
```

### Pipe to Other Tools

```bash
# Count packages
bash scripts/inventory.sh --format json | jq '.packages | length'

# List all open ports
bash scripts/inventory.sh --format json | jq -r '.ports[] | "\(.port) \(.process)"'

# Get total storage
bash scripts/inventory.sh --format json | jq '[.storage.devices[].size_bytes] | add'
```

## Troubleshooting

### Issue: "Permission denied" for some sections

**Fix:** Run with sudo for full hardware details:
```bash
sudo bash scripts/inventory.sh --format json --output full-inventory.json
```

Without sudo, the script gracefully skips privileged info (SMART data, some hardware details) and notes what was skipped.

### Issue: Package listing is slow

**Fix:** Skip packages section:
```bash
bash scripts/inventory.sh --sections system,cpu,memory,storage,network
```

Or set `INVENTORY_SKIP_PACKAGES=1`.

### Issue: "command not found: lscpu"

**Fix:** Install util-linux:
```bash
# Ubuntu/Debian
sudo apt-get install util-linux procps

# RHEL/CentOS
sudo yum install util-linux procps-ng
```

## Dependencies

- `bash` (4.0+)
- `coreutils` (standard Linux)
- `util-linux` (`lscpu`, `lsblk`)
- `procps` (`free`, `ps`)
- `iproute2` (`ip`, `ss`)
- `jq` (for JSON output — optional, falls back to raw)
- Optional: `smartmontools` (disk SMART data)
- Optional: `docker` (container inventory)
