---
name: proxmox-manager
description: >-
  Manage Proxmox VE virtual machines and containers from the command line — create, start, stop, snapshot, migrate, and monitor resources via the Proxmox API.
categories: [dev-tools, automation]
dependencies: [curl, jq, bash]
---

# Proxmox VE Manager

## What This Does

Manage your Proxmox Virtual Environment cluster from the terminal. Start/stop VMs and containers, create snapshots, monitor resource usage, manage backups, and automate common operations — all through the Proxmox REST API.

**Example:** "List all VMs, start VM 101, take a snapshot, check cluster resource usage."

## Quick Start (5 minutes)

### 1. Configure Connection

```bash
# Copy config template
cp scripts/config-template.env ~/.proxmox-manager.env

# Edit with your Proxmox details
cat > ~/.proxmox-manager.env << 'EOF'
PROXMOX_HOST="https://your-proxmox-ip:8006"
PROXMOX_USER="root@pam"
PROXMOX_PASSWORD=""
PROXMOX_TOKEN_ID=""
PROXMOX_TOKEN_SECRET=""
PROXMOX_NODE="pve"
PROXMOX_VERIFY_SSL="false"
EOF

# Option A: Use API token (recommended)
# Create token in Proxmox UI: Datacenter → Permissions → API Tokens
# Then set PROXMOX_TOKEN_ID="root@pam!mytoken" and PROXMOX_TOKEN_SECRET="uuid-here"

# Option B: Use password (creates ticket per session)
# Set PROXMOX_PASSWORD="your-password"
```

### 2. Test Connection

```bash
bash scripts/pvm.sh status
# Output:
# ✅ Connected to Proxmox VE 8.x at https://192.168.1.100:8006
# Node: pve | CPU: 12% | RAM: 8.2/32 GB | Uptime: 14d 3h
```

### 3. List VMs & Containers

```bash
bash scripts/pvm.sh list
# Output:
# ID    TYPE  NAME            STATUS   CPU  RAM      DISK
# 100   qemu  ubuntu-server   running  2    4096 MB  32 GB
# 101   qemu  windows-11      stopped  0    8192 MB  128 GB
# 200   lxc   nginx-proxy     running  1    512 MB   8 GB
# 201   lxc   pihole          running  1    256 MB   4 GB
```

## Core Workflows

### Workflow 1: VM/Container Lifecycle

```bash
# Start a VM
bash scripts/pvm.sh start 100

# Stop gracefully (ACPI shutdown)
bash scripts/pvm.sh stop 100

# Force stop
bash scripts/pvm.sh stop 100 --force

# Restart
bash scripts/pvm.sh restart 100

# Suspend/Resume
bash scripts/pvm.sh suspend 100
bash scripts/pvm.sh resume 100
```

### Workflow 2: Snapshots

```bash
# Create snapshot
bash scripts/pvm.sh snapshot 100 --name "before-upgrade"

# List snapshots
bash scripts/pvm.sh snapshots 100
# Output:
# NAME              DATE                 DESCRIPTION
# before-upgrade    2026-02-28 12:00     Created by pvm.sh
# clean-install     2026-02-15 09:30     Created by pvm.sh

# Rollback to snapshot
bash scripts/pvm.sh rollback 100 --name "before-upgrade"

# Delete snapshot
bash scripts/pvm.sh snap-delete 100 --name "before-upgrade"
```

### Workflow 3: Resource Monitoring

```bash
# Cluster overview
bash scripts/pvm.sh status

# Detailed node stats
bash scripts/pvm.sh node-status
# Output:
# NODE: pve
# CPU:      12.3% (4/32 cores)
# RAM:      8.2 / 32.0 GB (25.6%)
# SWAP:     0.1 / 8.0 GB (1.2%)
# DISK:     120 / 500 GB (24.0%)
# UPTIME:   14d 3h 22m
# VMs:      4 running / 2 stopped
# CTs:      3 running / 0 stopped

# Per-VM resource usage
bash scripts/pvm.sh top
# Output:
# ID    NAME            CPU%   RAM%    DISK I/O   NET I/O
# 100   ubuntu-server   8.2    62.5    1.2 MB/s   540 KB/s
# 200   nginx-proxy     2.1    45.0    0.3 MB/s   12 MB/s
# 201   pihole          0.5    15.2    0.0 MB/s   0.1 MB/s
```

### Workflow 4: Backup Management

```bash
# Create backup (default: vzdump to local storage)
bash scripts/pvm.sh backup 100

# Backup with compression
bash scripts/pvm.sh backup 100 --compress zstd --storage local

# List backups
bash scripts/pvm.sh backups
# Output:
# VMID  DATE                 SIZE     STORAGE  FILE
# 100   2026-02-28 14:00     2.3 GB   local    vzdump-qemu-100-2026_02_28-14_00.vma.zst
# 100   2026-02-21 14:00     2.1 GB   local    vzdump-qemu-100-2026_02_21-14_00.vma.zst

# Restore backup
bash scripts/pvm.sh restore 100 --file vzdump-qemu-100-2026_02_28-14_00.vma.zst
```

### Workflow 5: Create New VM/Container

```bash
# Create LXC container from template
bash scripts/pvm.sh create-ct \
  --id 202 \
  --name "my-container" \
  --template "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst" \
  --memory 1024 \
  --cores 2 \
  --disk 16 \
  --net "bridge=vmbr0,ip=dhcp"

# Create QEMU VM
bash scripts/pvm.sh create-vm \
  --id 102 \
  --name "my-vm" \
  --memory 4096 \
  --cores 4 \
  --disk 64 \
  --iso "local:iso/ubuntu-22.04-live-server-amd64.iso" \
  --net "bridge=vmbr0"
```

### Workflow 6: Migration (Multi-Node Clusters)

```bash
# Live migrate VM to another node
bash scripts/pvm.sh migrate 100 --target pve2

# Offline migration
bash scripts/pvm.sh migrate 100 --target pve2 --offline
```

## Configuration

### Config File (~/.proxmox-manager.env)

```bash
# Proxmox connection
PROXMOX_HOST="https://192.168.1.100:8006"
PROXMOX_USER="root@pam"

# Auth: Token (recommended) or Password
PROXMOX_TOKEN_ID="root@pam!automation"
PROXMOX_TOKEN_SECRET="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
# PROXMOX_PASSWORD="fallback-password"

# Default node (for single-node setups)
PROXMOX_NODE="pve"

# SSL verification (set to true for production)
PROXMOX_VERIFY_SSL="false"
```

### Environment Variables

All config values can also be set as environment variables (they override the config file).

## Advanced Usage

### Run as Cron (Automated Snapshots)

```bash
# Daily snapshot of critical VMs at 2am
0 2 * * * bash /path/to/scripts/pvm.sh snapshot 100 --name "daily-$(date +\%Y\%m\%d)" 2>&1 >> /var/log/pvm-snapshots.log

# Weekly backup
0 3 * * 0 bash /path/to/scripts/pvm.sh backup 100 --compress zstd 2>&1 >> /var/log/pvm-backups.log

# Cleanup old snapshots (keep last 7)
0 4 * * * bash /path/to/scripts/pvm.sh snap-prune 100 --keep 7 2>&1 >> /var/log/pvm-prune.log
```

### Health Check with Alerts

```bash
# Check if critical VMs are running, alert if not
bash scripts/pvm.sh health --ids 100,200,201 --alert telegram

# Output (on failure):
# ❌ VM 101 (windows-11) is STOPPED — expected running
# 🔔 Alert sent to Telegram
```

### Batch Operations

```bash
# Start all VMs tagged "production"
bash scripts/pvm.sh list --tag production --status stopped | while read id; do
  bash scripts/pvm.sh start "$id"
done

# Snapshot all running VMs
bash scripts/pvm.sh list --status running | while read id; do
  bash scripts/pvm.sh snapshot "$id" --name "batch-$(date +%Y%m%d)"
done
```

### JSON Output (for scripting)

```bash
# All commands support --json flag
bash scripts/pvm.sh list --json | jq '.[] | select(.status == "running")'
bash scripts/pvm.sh status --json | jq '.cpu_usage'
```

## Troubleshooting

### Issue: "Connection refused" or timeout

**Fix:**
1. Check Proxmox host is reachable: `curl -k https://your-proxmox:8006/api2/json/version`
2. Verify firewall allows port 8006
3. Check `PROXMOX_HOST` includes `https://` and port `:8006`

### Issue: "401 Unauthorized"

**Fix:**
1. For tokens: Verify token ID format is `user@realm!tokenname`
2. For tokens: Check token has correct permissions in Proxmox UI
3. For passwords: Verify credentials work in Proxmox web UI
4. Check token/user has the required privilege (VM.Audit, VM.PowerMgmt, etc.)

### Issue: "SSL certificate problem"

**Fix:** Set `PROXMOX_VERIFY_SSL="false"` in config (ok for homelab). For production, import your Proxmox CA cert.

### Issue: Snapshot fails with "disk locked"

**Fix:** Another operation may be running. Check with `bash scripts/pvm.sh tasks` and wait for completion.

## Required Proxmox API Permissions

For full functionality, the API token needs:
- `VM.Audit` — List and monitor VMs/CTs
- `VM.PowerMgmt` — Start/stop/restart
- `VM.Snapshot` — Create/delete snapshots
- `VM.Backup` — Create backups
- `VM.Allocate` — Create new VMs
- `VM.Migrate` — Migrate between nodes
- `Datastore.Allocate` — Manage storage
- `Sys.Audit` — Node status

Create a role with these permissions, then assign to your API token.

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests to Proxmox API)
- `jq` (JSON parsing)
- Optional: Telegram bot token for health alerts
