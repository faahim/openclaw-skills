# Listing Copy: ZFS Snapshot Manager

## Metadata
- **Type:** Skill
- **Name:** zfs-snapshot-manager
- **Display Name:** ZFS Snapshot Manager
- **Categories:** [data, automation]
- **Price:** $14
- **Dependencies:** [zfs]

## Tagline
Automate ZFS snapshots and retention — no more manual prune pain

## Description
Managing ZFS snapshots manually is fine until you forget a cleanup cycle and realize you’ve hoarded months of stale snapshots.

ZFS Snapshot Manager automates the full loop: create hourly/daily/weekly snapshots, enforce retention policies, and prune old snapshots safely. It uses plain shell scripts, works with cron, and includes dry-run support before destructive operations.

### What it does
- 📸 Create class-based snapshots (`hourly`, `daily`, `weekly`)
- 🧹 Prune old snapshots by retention policy
- 🧪 Dry-run mode to preview destructive actions
- 🕒 Cron-ready commands for fully automated operation
- 🧾 Snapshot status view per dataset

Perfect for homelab operators, self-hosters, and sysadmins running ZFS who want reliable backup hygiene with minimal setup.
