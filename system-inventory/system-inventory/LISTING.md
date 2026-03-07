# Listing Copy: System Inventory Reporter

## Metadata
- **Type:** Skill
- **Name:** system-inventory
- **Display Name:** System Inventory Reporter
- **Categories:** [automation, analytics]
- **Price:** $8
- **Dependencies:** [bash, coreutils, util-linux, iproute2]

## Tagline

Generate complete hardware & software inventory reports for any Linux system

## Description

Manually checking system specs means running a dozen different commands and piecing together the output. When you manage multiple servers or need to document your infrastructure, this gets tedious fast.

System Inventory Reporter scans your entire Linux system in seconds and generates a structured report covering CPU, RAM, storage, network interfaces, listening ports, installed packages, running services, Docker containers, and more. Export as JSON (machine-readable), Markdown (documentation), or HTML (shareable reports).

**What it does:**
- 🖥️ Full hardware inventory — CPU, memory, storage, network
- 📦 Software audit — installed packages, running services, open ports
- 🐳 Docker awareness — containers, images, status
- 📊 Three output formats — JSON, Markdown, HTML
- 🔄 Drift detection — compare snapshots over time to spot changes
- ⚡ Runs in seconds — no agents, no daemons, just a bash script
- 🔒 Graceful without root — collects what it can, notes what it skipped

Perfect for sysadmins documenting infrastructure, developers auditing servers, teams doing compliance checks, or anyone who needs a quick system overview.

## Quick Start Preview

```bash
# Full inventory to terminal
bash scripts/inventory.sh

# Export as JSON
bash scripts/inventory.sh --format json --output server-audit.json

# Just network + ports
bash scripts/inventory.sh --sections network,ports --format md
```

## Core Capabilities

1. System info — hostname, OS, kernel, uptime, architecture
2. CPU details — model, cores, threads, frequency
3. Memory stats — total/used/available RAM and swap
4. Storage audit — block devices, filesystems, usage percentages
5. Network map — interfaces, IPs, MACs, gateway, DNS
6. Port scan — all listening ports with associated processes
7. Package inventory — count + top 20 largest packages
8. Service listing — all systemd services with status
9. Docker inventory — containers, images, running status
10. Snapshot diffing — compare two reports to detect drift
11. Multi-format export — JSON, Markdown, HTML
12. Section filtering — scan only what you need

## Dependencies
- `bash` (4.0+)
- `coreutils`, `util-linux`, `procps`, `iproute2` (standard on most Linux)
- `jq` (optional, for pretty JSON)
- `smartmontools` (optional, for disk SMART data)

## Installation Time
**2 minutes** — no dependencies to install on most systems
