# Listing Copy: System Inventory Tool

## Metadata
- **Type:** Skill
- **Name:** system-inventory
- **Display Name:** System Inventory Tool
- **Categories:** [dev-tools, automation]
- **Icon:** 📋
- **Dependencies:** [bash, coreutils]

## Tagline

Generate complete system inventory reports — hardware, network, storage, services, and packages in one command.

## Description

Documenting servers is tedious. Tracking what's installed, what's running, and what changed between deployments takes hours of manual commands and copy-pasting. For migrations, audits, or disaster recovery, you need a reliable system snapshot — not scattered notes.

System Inventory Tool runs a single command and produces a comprehensive report of your entire system: CPU, RAM, storage layout, network interfaces, running services, installed packages, user accounts, cron jobs, and Docker containers. Output as structured markdown for documentation or JSON for programmatic comparison.

**What it does:**
- 📋 Full system snapshot in one command — hardware, OS, network, storage, services, packages, users
- 📊 Markdown or JSON output — save, version, or pipe into other tools
- 🔄 Snapshot diff — compare two inventories to see what changed (packages added, users removed, disk usage shifted)
- 🔍 Section filtering — grab just network, just packages, or just services
- 🐧 Cross-distro — works on Debian, Ubuntu, RHEL, Fedora, Arch, Alpine
- 🐳 Docker-aware — includes container, image, and volume inventory if Docker is present
- ⚡ Fast and read-only — never modifies your system

## Quick Start Preview

```bash
# Full inventory to markdown
bash scripts/inventory.sh > inventory-$(hostname).md

# Just network info
bash scripts/inventory.sh --section network

# JSON for programmatic use
bash scripts/inventory.sh --format json > snapshot.json

# Compare two snapshots
bash scripts/diff-inventory.sh baseline.json current.json
```

## Core Capabilities

1. System info — hostname, OS, kernel, uptime, timezone
2. Hardware specs — CPU model, cores, RAM, swap, manufacturer
3. Storage layout — disks, partitions, mount points, usage, inodes
4. Network config — interfaces, IPs, DNS, routes, listening ports
5. Service inventory — all systemd services with status
6. Package list — all installed packages with versions (apt/dnf/pacman/apk)
7. User accounts — UIDs, home dirs, shells, sudo access
8. Cron jobs — system and user crontabs
9. Docker inventory — containers, images, volumes
10. Snapshot diff — compare two JSON snapshots, see what changed
11. Section filtering — grab only what you need
12. Remote inventory — pipe over SSH to inventory remote servers

## Dependencies
- `bash` (4.0+)
- `coreutils` (standard Linux tools)
- Optional: `jq` (JSON formatting), `lshw`/`dmidecode` (hardware details), `docker`
