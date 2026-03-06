---
name: incus-manager
description: >-
  Install, configure, and manage Incus system containers and virtual machines from the terminal.
categories: [dev-tools, automation]
dependencies: [bash, curl, incus]
---

# Incus Container Manager

## What This Does

Manage lightweight system containers and virtual machines with [Incus](https://linuxcontainers.org/incus/) — the community-driven successor to LXD. Create isolated environments in seconds, snapshot and restore them, set up networking and storage pools, and manage container lifecycles — all from your OpenClaw agent.

**Example:** "Spin up 3 Ubuntu containers, configure a bridge network, set CPU/memory limits, snapshot before testing, restore if something breaks."

## Quick Start (10 minutes)

### 1. Install Incus

```bash
bash scripts/install.sh
```

This handles:
- Adding the Zabbly repository (official Incus packages)
- Installing Incus
- Running initial setup with sane defaults
- Adding current user to the `incus-admin` group

### 2. Launch Your First Container

```bash
# Launch an Ubuntu 24.04 container
incus launch images:ubuntu/24.04 my-first-container

# Check it's running
incus list

# Get a shell inside
incus exec my-first-container -- bash
```

### 3. Launch a VM (instead of container)

```bash
# Launch a virtual machine
incus launch images:ubuntu/24.04 my-vm --vm

# Access it
incus exec my-vm -- bash
```

## Core Workflows

### Workflow 1: Create and Manage Containers

```bash
# Launch containers from various images
incus launch images:ubuntu/24.04 web-server
incus launch images:debian/12 db-server
incus launch images:alpine/3.19 cache-server

# List all instances
incus list

# Stop, start, restart
incus stop web-server
incus start web-server
incus restart web-server

# Delete (must be stopped first, or use --force)
incus delete cache-server --force
```

### Workflow 2: Resource Limits

```bash
# Set CPU limit (2 cores)
incus config set web-server limits.cpu 2

# Set memory limit (512MB)
incus config set web-server limits.memory 512MiB

# Set disk limit (requires btrfs/zfs storage pool)
incus config device set web-server root size=10GiB

# View current config
incus config show web-server
```

### Workflow 3: Snapshots & Restore

```bash
# Create a snapshot before making changes
incus snapshot create web-server pre-deploy

# List snapshots
incus snapshot list web-server

# Restore to snapshot
incus snapshot restore web-server pre-deploy

# Delete old snapshot
incus snapshot delete web-server pre-deploy
```

### Workflow 4: File Transfer

```bash
# Push file into container
incus file push ./app.tar.gz web-server/tmp/app.tar.gz

# Pull file from container
incus file pull web-server/var/log/syslog ./container-syslog.log

# Push a directory
incus file push -r ./deploy/ web-server/opt/deploy/
```

### Workflow 5: Networking

```bash
# Create a bridge network
incus network create my-bridge

# Attach container to network
incus network attach my-bridge web-server eth1

# Forward a port (host:8080 → container:80)
incus config device add web-server proxy80 proxy \
  listen=tcp:0.0.0.0:8080 connect=tcp:127.0.0.1:80

# List network info
incus network list
incus network show my-bridge
```

### Workflow 6: Profiles (Reusable Configs)

```bash
# Create a profile for web servers
incus profile create web-profile
incus profile set web-profile limits.cpu 2
incus profile set web-profile limits.memory 1GiB

# Launch with profile
incus launch images:ubuntu/24.04 web2 --profile web-profile

# List profiles
incus profile list
incus profile show web-profile
```

### Workflow 7: Image Management

```bash
# List available remote images
incus image list images: ubuntu/24 architecture=amd64

# List local (cached) images
incus image list

# Create image from container
incus publish web-server --alias my-web-image

# Export image to file
incus image export my-web-image ./my-web-image

# Import image
incus image import ./my-web-image.tar.gz --alias imported-image
```

### Workflow 8: Batch Operations

```bash
# Run a command on all running containers
bash scripts/run.sh batch-exec "apt update && apt upgrade -y"

# Snapshot all containers
bash scripts/run.sh batch-snapshot "daily-$(date +%Y%m%d)"

# List resource usage
bash scripts/run.sh status
```

## Configuration

### Storage Pools

```bash
# Create a directory-based pool (works everywhere)
incus storage create my-pool dir source=/var/lib/incus/storage-pools/my-pool

# Create a btrfs pool (recommended, supports quotas)
incus storage create fast-pool btrfs source=/dev/sdb

# Create a ZFS pool
incus storage create zfs-pool zfs source=/dev/sdc

# List pools
incus storage list
```

### Remote Servers

```bash
# Add a remote Incus server
incus remote add production https://incus.example.com:8443

# List instances on remote
incus list production:

# Launch on remote
incus launch images:ubuntu/24.04 production:web-prod

# Copy container to remote
incus copy web-server production:web-server-backup
```

### Cloud-Init

```bash
# Launch with cloud-init configuration
incus launch images:ubuntu/24.04 configured-server \
  --config=user.user-data="$(cat scripts/cloud-init.yaml)"
```

## Advanced Usage

### Run as Development Environment

```bash
# Create a dev container with shared directory
incus launch images:ubuntu/24.04 dev-env
incus config device add dev-env workspace disk \
  source=/home/user/projects path=/workspace

# Forward dev ports
incus config device add dev-env port3000 proxy \
  listen=tcp:0.0.0.0:3000 connect=tcp:127.0.0.1:3000
incus config device add dev-env port5432 proxy \
  listen=tcp:0.0.0.0:5432 connect=tcp:127.0.0.1:5432
```

### Automated Backups

```bash
# Backup all containers to directory
bash scripts/run.sh backup /backups/incus/

# Restore from backup
incus import /backups/incus/web-server.tar.gz
```

### Cluster Management

```bash
# Initialize cluster on first node
incus admin init --cluster

# Join additional nodes
incus admin init --cluster-join

# List cluster members
incus cluster list
```

## Troubleshooting

### Issue: "Permission denied" or socket errors

**Fix:** Ensure your user is in the `incus-admin` group:
```bash
sudo usermod -aG incus-admin $USER
newgrp incus-admin
```

### Issue: "Failed to create network" on cloud VPS

**Fix:** Many VPS providers don't support bridged networking. Use NAT mode:
```bash
incus network create my-net \
  ipv4.address=10.10.10.1/24 \
  ipv4.nat=true
```

### Issue: Container can't access internet

**Fix:** Check NAT and firewall:
```bash
# Verify NAT is enabled on the bridge
incus network show incusbr0

# Check iptables
sudo iptables -t nat -L -n | grep incus
```

### Issue: "No storage pool found"

**Fix:** Create a default pool:
```bash
incus storage create default dir
incus profile device add default root disk pool=default path=/
```

### Issue: VM won't start

**Fix:** Ensure KVM is available:
```bash
# Check virtualization support
grep -cE 'vmx|svm' /proc/cpuinfo

# Load KVM module
sudo modprobe kvm
sudo modprobe kvm_intel  # or kvm_amd
```

## Key Principles

1. **Containers over VMs** — Use containers for most workloads (faster, lighter). Use VMs only when you need a different kernel or full isolation.
2. **Snapshot before changes** — Always snapshot before upgrades or config changes.
3. **Use profiles** — Don't repeat config. Define profiles for common patterns.
4. **Resource limits** — Always set CPU/memory limits in production to prevent noisy neighbors.
5. **Storage pools** — Use btrfs or ZFS for production (supports snapshots, quotas).

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- `incus` (installed by scripts/install.sh)
- Linux kernel 5.4+ (for full feature support)
- Optional: `btrfs-progs` or `zfsutils-linux` (for advanced storage)
