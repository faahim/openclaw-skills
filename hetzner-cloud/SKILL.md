---
name: hetzner-cloud
description: >-
  Manage Hetzner Cloud servers, snapshots, firewalls, volumes, and SSH keys from the command line.
categories: [dev-tools, automation]
dependencies: [bash, curl, jq]
---

# Hetzner Cloud Manager

## What This Does

Manage your Hetzner Cloud infrastructure without leaving the terminal. Create/destroy servers, take snapshots, configure firewalls, attach volumes, and manage SSH keys — all through simple bash commands with the Hetzner Cloud API.

**Example:** "Spin up an Ubuntu server in Falkenstein, attach a 50GB volume, configure a firewall to allow SSH + HTTP/HTTPS, and snapshot it nightly."

## Quick Start (5 minutes)

### 1. Get Your API Token

1. Go to https://console.hetzner.cloud → Select project → Security → API Tokens
2. Generate a Read & Write token

```bash
export HETZNER_API_TOKEN="your-token-here"

# Optional: persist in shell config
echo 'export HETZNER_API_TOKEN="your-token-here"' >> ~/.bashrc
```

### 2. Verify Connection

```bash
bash scripts/hetzner.sh status
# Output:
# ✅ Connected to Hetzner Cloud
# Project: my-project
# Servers: 3 | Volumes: 2 | Snapshots: 5 | Firewalls: 2
```

### 3. List Your Servers

```bash
bash scripts/hetzner.sh servers list
# ID       NAME           STATUS   TYPE      IP              LOCATION   CREATED
# 12345    web-prod       running  cx22      116.203.x.x     fsn1       2026-01-15
# 12346    staging        off      cx11      95.216.x.x      nbg1       2026-02-01
```

## Core Workflows

### Workflow 1: Create a Server

```bash
bash scripts/hetzner.sh servers create \
  --name my-server \
  --type cx22 \
  --image ubuntu-24.04 \
  --location fsn1 \
  --ssh-key my-key

# Output:
# ✅ Server 'my-server' created
# ID: 12347
# IPv4: 116.203.x.x
# IPv6: 2a01:4f8:x::1
# Type: cx22 (2 vCPU, 4GB RAM, 40GB disk)
# Location: Falkenstein (fsn1)
# Image: Ubuntu 24.04
```

**Available server types:**
```bash
bash scripts/hetzner.sh types
# TYPE     vCPU  RAM     DISK    PRICE/mo
# cx11     1     2GB     20GB    €3.29
# cx22     2     4GB     40GB    €5.39
# cx32     4     8GB     80GB    €9.59
# cx42     8     16GB    160GB   €17.99
# cx52     16    32GB    320GB   €35.99
# cax11    2     4GB     40GB    €3.29    (ARM)
# cax21    4     8GB     80GB    €5.49    (ARM)
# cax31    8     16GB    160GB   €9.49    (ARM)
# cax41    16    32GB    320GB   €17.49   (ARM)
```

**Available locations:**
```bash
bash scripts/hetzner.sh locations
# ID    NAME           CITY           COUNTRY
# fsn1  Falkenstein    Falkenstein    DE
# nbg1  Nuremberg      Nuremberg      DE
# hel1  Helsinki       Helsinki       FI
# ash   Ashburn        Ashburn        US
# hil   Hillsboro      Hillsboro      US
```

### Workflow 2: Manage Server Power

```bash
# Power off
bash scripts/hetzner.sh servers power-off --id 12345

# Power on
bash scripts/hetzner.sh servers power-on --id 12345

# Reboot
bash scripts/hetzner.sh servers reboot --id 12345

# Rebuild (reinstall OS — DESTRUCTIVE)
bash scripts/hetzner.sh servers rebuild --id 12345 --image ubuntu-24.04
```

### Workflow 3: Snapshots

```bash
# Create snapshot
bash scripts/hetzner.sh snapshots create --server 12345 --description "Before upgrade"
# ✅ Snapshot created: snap-12345-20260307 (ID: 98765)

# List snapshots
bash scripts/hetzner.sh snapshots list
# ID      SERVER   DESCRIPTION        SIZE    CREATED
# 98765   12345    Before upgrade     4.2GB   2026-03-07

# Restore from snapshot
bash scripts/hetzner.sh servers rebuild --id 12345 --image 98765

# Delete snapshot
bash scripts/hetzner.sh snapshots delete --id 98765
```

### Workflow 4: Firewalls

```bash
# Create firewall
bash scripts/hetzner.sh firewalls create --name web-firewall

# Add rules
bash scripts/hetzner.sh firewalls add-rule --id 1234 \
  --direction in --protocol tcp --port 22 --source "0.0.0.0/0" --description "SSH"

bash scripts/hetzner.sh firewalls add-rule --id 1234 \
  --direction in --protocol tcp --port "80,443" --source "0.0.0.0/0" --description "HTTP/HTTPS"

# Apply to server
bash scripts/hetzner.sh firewalls apply --id 1234 --server 12345

# List firewalls
bash scripts/hetzner.sh firewalls list
```

### Workflow 5: Volumes

```bash
# Create volume
bash scripts/hetzner.sh volumes create \
  --name data-vol \
  --size 50 \
  --location fsn1 \
  --format ext4
# ✅ Volume 'data-vol' created (50GB, ext4)
# Linux device: /dev/disk/by-id/scsi-0HC_Volume_12345

# Attach to server
bash scripts/hetzner.sh volumes attach --id 12345 --server 12345

# Detach
bash scripts/hetzner.sh volumes detach --id 12345

# Resize
bash scripts/hetzner.sh volumes resize --id 12345 --size 100

# List volumes
bash scripts/hetzner.sh volumes list
```

### Workflow 6: SSH Keys

```bash
# Upload SSH key
bash scripts/hetzner.sh ssh-keys create --name my-laptop --key "$(cat ~/.ssh/id_ed25519.pub)"

# List keys
bash scripts/hetzner.sh ssh-keys list

# Delete key
bash scripts/hetzner.sh ssh-keys delete --id 12345
```

### Workflow 7: Server Metrics

```bash
# Get CPU/RAM/disk/network metrics (last hour)
bash scripts/hetzner.sh servers metrics --id 12345 --type cpu --period 1h

# Output:
# CPU Usage (last 1h):
# 12:00  ██░░░░░░░░  18%
# 12:15  ███░░░░░░░  27%
# 12:30  ██░░░░░░░░  15%
# 12:45  █░░░░░░░░░   8%
```

## Configuration

### Environment Variables

```bash
# Required
export HETZNER_API_TOKEN="your-token-here"

# Optional: default values
export HETZNER_DEFAULT_LOCATION="fsn1"
export HETZNER_DEFAULT_TYPE="cx22"
export HETZNER_DEFAULT_IMAGE="ubuntu-24.04"
export HETZNER_DEFAULT_SSH_KEY="my-key"
```

### Config File (Optional)

```bash
# ~/.config/hetzner-cloud/config
HETZNER_DEFAULT_LOCATION=fsn1
HETZNER_DEFAULT_TYPE=cx22
HETZNER_DEFAULT_IMAGE=ubuntu-24.04
HETZNER_DEFAULT_SSH_KEY=my-key
```

## Advanced Usage

### Batch Operations

```bash
# Power off all servers with a name pattern
bash scripts/hetzner.sh servers list --format json | \
  jq -r '.[] | select(.name | startswith("staging-")) | .id' | \
  xargs -I{} bash scripts/hetzner.sh servers power-off --id {}

# Snapshot all running servers
bash scripts/hetzner.sh servers list --format json | \
  jq -r '.[] | select(.status == "running") | .id' | \
  xargs -I{} bash scripts/hetzner.sh snapshots create --server {} --description "Nightly $(date +%Y-%m-%d)"
```

### Scheduled Snapshots (Cron)

```bash
# Nightly snapshots at 3 AM
echo '0 3 * * * HETZNER_API_TOKEN="your-token" bash /path/to/scripts/hetzner.sh snapshots create --server 12345 --description "Nightly $(date +\%Y-\%m-\%d)"' | crontab -

# Weekly cleanup: delete snapshots older than 7 days
echo '0 4 * * 0 HETZNER_API_TOKEN="your-token" bash /path/to/scripts/hetzner.sh snapshots cleanup --older-than 7d' | crontab -
```

### Cost Estimation

```bash
bash scripts/hetzner.sh cost
# Monthly Cost Estimate:
# RESOURCE         TYPE     COUNT   COST/mo
# Servers          cx22     2       €10.78
# Servers          cax11    1       €3.29
# Volumes          50GB     2       €4.40
# Snapshots        12GB     5       €0.24
# Floating IPs     IPv4     1       €3.57
# ─────────────────────────────────────────
# TOTAL                             €22.28
```

## Troubleshooting

### Issue: "401 Unauthorized"

**Fix:** Check your API token
```bash
echo $HETZNER_API_TOKEN | head -c 10
# Should show first 10 chars of your token

# Test directly
curl -s -H "Authorization: Bearer $HETZNER_API_TOKEN" \
  https://api.hetzner.cloud/v1/servers | jq '.servers | length'
```

### Issue: "Server creation failed — insufficient resources"

**Fix:** Try a different location or server type
```bash
# Check available types per location
bash scripts/hetzner.sh types --location fsn1
```

### Issue: "Rate limit exceeded"

**Fix:** Hetzner allows 3600 requests/hour. The script auto-retries with backoff.

### Issue: Volume not showing on server

**Fix:** After attaching, mount it on the server:
```bash
ssh root@<server-ip> 'mount /dev/disk/by-id/scsi-0HC_Volume_<id> /mnt/data'
```

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests to Hetzner API)
- `jq` (JSON parsing)
- Hetzner Cloud API token (free to create)
