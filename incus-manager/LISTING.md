# Listing Copy: Incus Container Manager

## Metadata
- **Type:** Skill
- **Name:** incus-manager
- **Display Name:** Incus Container Manager
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Dependencies:** [bash, curl, incus]

## Tagline

Manage system containers & VMs with Incus — launch, snapshot, and orchestrate in seconds

## Description

Running Docker for everything gets old fast. Sometimes you need a full Linux environment — not just an isolated process. Incus (the community successor to LXD) gives you lightweight system containers and VMs that boot in seconds, use minimal resources, and feel like real machines.

**Incus Container Manager** installs, configures, and automates Incus for your OpenClaw agent. Launch Ubuntu, Debian, or Alpine containers with one command. Set CPU/memory limits, create snapshots before risky changes, forward ports, share directories, and batch-manage dozens of instances at once.

**What it does:**
- 🚀 One-command installation via Zabbly packages (Ubuntu/Debian)
- 📦 Launch containers and VMs from 100+ Linux images
- 📸 Snapshot and restore — never lose work to a bad deploy
- 🔧 Set CPU, memory, and disk limits per instance
- 🌐 Port forwarding, bridge networks, and remote server management
- 📊 Batch operations — run commands, snapshot, or backup all instances at once
- 💾 Export/import containers for backup and migration
- ☁️ Cloud-init support for automated container provisioning
- 🏗️ Cluster mode for multi-node setups

Perfect for developers who need isolated environments, sysadmins managing infrastructure, and anyone who wants lightweight VMs without the overhead of full virtualization.

## Quick Start Preview

```bash
# Install Incus
sudo bash scripts/install.sh

# Launch a container
incus launch images:ubuntu/24.04 dev-env

# Get a shell
incus exec dev-env -- bash

# Snapshot before changes
incus snapshot create dev-env pre-deploy
```

## Core Capabilities

1. Container lifecycle — Launch, stop, start, restart, delete instances
2. VM support — Full virtual machines when you need kernel isolation
3. Snapshot management — Create, restore, and clean up snapshots automatically
4. Resource limits — CPU, memory, and disk quotas per instance
5. Port forwarding — Expose container services on host ports
6. File transfer — Push/pull files and directories between host and container
7. Batch operations — Execute commands across all running instances
8. Automated backups — Export all instances to compressed archives
9. Network management — Create bridge networks, configure NAT
10. Profile system — Reusable configuration templates for consistent environments
11. Cloud-init — Automated provisioning with user-data scripts
12. Remote management — Control Incus servers across your infrastructure
