# Listing Copy: Backup Verify

## Metadata
- **Type:** Skill
- **Name:** backup-verify
- **Display Name:** Backup Verify
- **Categories:** [data, automation]
- **Icon:** 🔍
- **Dependencies:** [bash, sha256sum, tar, gzip]

## Tagline

Verify backup integrity — catch silent failures before you need to restore

## Description

Backups fail silently. Your cron job runs, the script exits 0, but the archive is corrupt, the dump is empty, or the disk is full. You won't know until you desperately need that data — and by then it's too late.

Backup Verify validates that your backups actually work. It checks file existence, recency, sizes, SHA256 checksums, and archive integrity. Run it on a schedule, get instant alerts via Telegram, ntfy, email, or any webhook when something goes wrong.

**What it does:**
- ✅ Check backup files exist and aren't empty
- ⏱️ Alert when backups are older than expected
- 🔐 Verify SHA256 checksums against manifest
- 📦 Test archive integrity (tar.gz, zip, xz, zst, bz2)
- 💾 Monitor disk space on backup volume
- 🔔 Alert via Telegram, ntfy, email, or custom webhook
- 📊 Generate verification reports

Perfect for sysadmins, developers, and anyone who runs backups but doesn't verify them (which is almost everyone).

## Quick Start Preview

```bash
# Check backups exist and are recent
bash scripts/verify.sh --path /var/backups --max-age 24

# Full verification with checksums + archive testing
bash scripts/verify.sh --path /var/backups \
  --checksum /var/backups/checksums.sha256 \
  --test-restore --verbose

# Run via cron every 6 hours with alerting
0 */6 * * * bash scripts/verify.sh --path /var/backups \
  --max-age 24 --test-restore \
  --alert 'curl -s -d "Backup FAILED" ntfy.sh/my-alerts'
```

## Installation Time
**2 minutes** — No dependencies to install (uses standard Linux tools)
