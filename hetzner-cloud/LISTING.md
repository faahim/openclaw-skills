# Listing Copy: Hetzner Cloud Manager

## Metadata
- **Type:** Skill
- **Name:** hetzner-cloud
- **Display Name:** Hetzner Cloud Manager
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Icon:** ☁️
- **Dependencies:** [bash, curl, jq]

## Tagline

Manage Hetzner Cloud servers, snapshots, firewalls & volumes — all from your terminal

## Description

Manually clicking through the Hetzner Cloud console to create servers, configure firewalls, and manage snapshots gets old fast. When you're managing multiple servers, you need CLI automation.

Hetzner Cloud Manager wraps the entire Hetzner Cloud API into simple bash commands. Create servers, take snapshots, configure firewalls, attach volumes, and estimate costs — all without leaving your terminal or opening a browser.

**What it does:**
- 🖥️ Create, list, power on/off, reboot, and delete servers
- 📸 Create, list, and auto-cleanup snapshots on schedule
- 🔥 Create firewalls with custom rules and apply to servers
- 💾 Create, attach, detach, and resize block volumes
- 🔑 Manage SSH keys for server provisioning
- 💰 Estimate monthly infrastructure cost
- 📊 View server CPU/RAM/network metrics
- ⚡ Batch operations — snapshot all servers, power off staging fleet

Perfect for developers, indie hackers, and sysadmins who use Hetzner Cloud and want fast, scriptable infrastructure management.

## Quick Start Preview

```bash
export HETZNER_API_TOKEN="your-token"

# Create a server
bash scripts/hetzner.sh servers create --name web-prod --type cx22 --image ubuntu-24.04

# Snapshot it
bash scripts/hetzner.sh snapshots create --server 12345 --description "Pre-deploy"

# Check costs
bash scripts/hetzner.sh cost
```

## Core Capabilities

1. Server management — Create, list, power on/off, reboot, rebuild, delete
2. Snapshot automation — Create, list, cleanup old snapshots by age
3. Firewall rules — Create firewalls, add TCP/UDP rules, apply to servers
4. Volume management — Create, attach, detach, resize block storage
5. SSH key management — Upload, list, delete public keys
6. Server type browser — List all types with vCPU, RAM, disk, pricing
7. Datacenter listing — View all available locations (DE, FI, US)
8. Cost estimation — Calculate monthly spend across all resources
9. Server metrics — View CPU, network, and disk I/O stats
10. Batch operations — Script complex multi-server workflows
11. Config file support — Set defaults for location, type, image, SSH key
12. JSON output — Machine-readable output for pipeline integration
