---
name: sysctl-tuner
description: >-
  Profile your Linux system and apply optimized kernel parameters (sysctl) for web servers, databases, containers, or desktops.
categories: [dev-tools, automation]
dependencies: [bash, sysctl]
---

# Sysctl Tuner

## What This Does

Analyzes your Linux system's workload profile and applies optimized kernel parameters via `sysctl`. Covers network stack tuning, memory management, filesystem caching, and security hardening. Backs up current settings before any changes.

**Example:** "Tune a web server for 10k+ concurrent connections — adjust TCP buffers, connection tracking, file descriptors, and keepalive settings in one command."

## Quick Start (3 minutes)

### 1. Check Current Settings

```bash
# View current kernel parameters
bash scripts/sysctl-tuner.sh --profile current
```

### 2. Apply a Profile

```bash
# Apply web server optimizations (preview first)
bash scripts/sysctl-tuner.sh --profile webserver --dry-run

# Apply for real (creates backup first)
sudo bash scripts/sysctl-tuner.sh --profile webserver --apply
```

### 3. Verify Changes

```bash
bash scripts/sysctl-tuner.sh --verify
```

## Profiles

### `webserver` — High-traffic web/API servers
- Increases TCP buffer sizes and backlog queue
- Enables TCP Fast Open, BBR congestion control
- Raises file descriptor limits
- Optimizes keepalive timers
- Enables SYN flood protection

### `database` — PostgreSQL, MySQL, MongoDB
- Increases shared memory limits
- Optimizes dirty page writeback thresholds
- Reduces swappiness to 10
- Increases semaphore limits
- Tunes filesystem read-ahead

### `container` — Docker/K8s host nodes
- Enables IP forwarding
- Increases conntrack table size
- Raises inotify watches for many containers
- Optimizes bridge/netfilter settings
- Increases PID limits

### `desktop` — Developer workstations
- Reduces swappiness to 10
- Increases inotify watches (for IDEs)
- Optimizes writeback for responsiveness
- Enables Magic SysRq for recovery
- Tunes scheduler for interactive workloads

### `security` — Hardened settings (overlay on any profile)
- Disables IP source routing
- Enables reverse path filtering
- Ignores ICMP redirects
- Enables TCP SYN cookies
- Randomizes virtual address space
- Restricts dmesg access
- Limits core dumps

### `custom` — Your own YAML config

```bash
# Apply custom parameters from YAML
sudo bash scripts/sysctl-tuner.sh --config custom.yaml --apply
```

## Core Workflows

### Workflow 1: Tune a Web Server

```bash
# 1. Backup current settings
sudo bash scripts/sysctl-tuner.sh --backup

# 2. Preview changes
bash scripts/sysctl-tuner.sh --profile webserver --dry-run

# Output:
# [DRY RUN] Would set:
#   net.core.somaxconn = 65535 (current: 4096)
#   net.ipv4.tcp_max_syn_backlog = 65535 (current: 1024)
#   net.core.rmem_max = 16777216 (current: 212992)
#   ...
# Total: 18 parameters changed

# 3. Apply
sudo bash scripts/sysctl-tuner.sh --profile webserver --apply

# 4. Make persistent across reboots
sudo bash scripts/sysctl-tuner.sh --profile webserver --persist
```

### Workflow 2: Database + Security Hardening

```bash
# Stack profiles (database + security overlay)
sudo bash scripts/sysctl-tuner.sh --profile database --profile security --apply --persist
```

### Workflow 3: Rollback Changes

```bash
# List backups
bash scripts/sysctl-tuner.sh --list-backups

# Rollback to a specific backup
sudo bash scripts/sysctl-tuner.sh --rollback 2026-02-25T20-53-00

# Rollback to latest backup
sudo bash scripts/sysctl-tuner.sh --rollback latest
```

### Workflow 4: Custom Config

```yaml
# custom.yaml
parameters:
  net.core.somaxconn: 32768
  vm.swappiness: 5
  fs.file-max: 2097152
  net.ipv4.tcp_fin_timeout: 15
```

```bash
sudo bash scripts/sysctl-tuner.sh --config custom.yaml --apply --persist
```

### Workflow 5: System Audit

```bash
# Compare current settings vs recommended for your workload
bash scripts/sysctl-tuner.sh --audit --profile webserver

# Output:
# ⚠️  net.core.somaxconn = 4096 (recommended: 65535)
# ⚠️  net.ipv4.tcp_max_syn_backlog = 1024 (recommended: 65535)
# ✅  net.ipv4.tcp_syncookies = 1 (recommended: 1)
# ...
# Score: 6/18 parameters optimized (33%)
```

## Configuration

### Environment Variables

```bash
# Custom backup directory (default: /var/backups/sysctl-tuner)
export SYSCTL_BACKUP_DIR="/path/to/backups"

# Sysctl persist file (default: /etc/sysctl.d/99-tuner.conf)
export SYSCTL_PERSIST_FILE="/etc/sysctl.d/99-tuner.conf"
```

## Advanced Usage

### Run as Cron (Drift Detection)

```bash
# Alert if settings drift from profile
*/30 * * * * bash /path/to/scripts/sysctl-tuner.sh --audit --profile webserver --alert-drift
```

### Export Current Settings

```bash
# Export all current sysctl values to YAML
bash scripts/sysctl-tuner.sh --export > current-settings.yaml
```

### Compare Two Systems

```bash
# Export on system A, compare on system B
bash scripts/sysctl-tuner.sh --diff system-a.yaml
```

## Troubleshooting

### Issue: "Permission denied"

**Fix:** Run with `sudo` — sysctl changes require root.

### Issue: "sysctl: cannot stat /proc/sys/..."

**Fix:** The parameter doesn't exist on this kernel. The script skips unavailable parameters and logs a warning.

### Issue: Changes lost after reboot

**Fix:** Use `--persist` flag to write to `/etc/sysctl.d/99-tuner.conf`.

### Issue: System unstable after tuning

**Fix:** Rollback immediately:
```bash
sudo bash scripts/sysctl-tuner.sh --rollback latest
```

## Dependencies

- `bash` (4.0+)
- `sysctl` (part of `procps` — installed on all Linux)
- `awk`, `grep`, `sed` (standard Linux tools)
- Optional: `yq` for YAML config parsing (falls back to built-in parser)
- Root access for applying changes
