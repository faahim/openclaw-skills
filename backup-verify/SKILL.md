---
name: backup-verify
description: >-
  Verify backup integrity — check recency, file sizes, checksums, and archive corruption. Get alerts when backups fail silently.
categories: [data, automation]
dependencies: [bash, sha256sum, tar, gzip]
---

# Backup Verify

## What This Does

Validates your backups actually work. Checks that backup files exist, aren't too old, aren't empty, pass checksum verification, and archives aren't corrupt. Alerts you when something fails silently — because the worst time to discover a bad backup is when you need to restore.

**Example:** "Check /var/backups every 6 hours, verify checksums, test-extract archives, alert via Telegram if anything fails."

## Quick Start (2 minutes)

### 1. Verify Backups Exist and Are Recent

```bash
bash scripts/verify.sh --path /var/backups --max-age 24
```

**Output:**
```
═══════════════════════════════════════════════════
  BACKUP VERIFICATION REPORT
  Path: /var/backups
  Time: 2026-02-28 10:00:00 UTC
═══════════════════════════════════════════════════

[2026-02-28 10:00:00] ✅ PASS Found 3 backup file(s)
[2026-02-28 10:00:00] ✅ PASS Newest backup is 6h old: db-2026-02-28.sql.gz
[2026-02-28 10:00:00] ✅ PASS All files have reasonable sizes
[2026-02-28 10:00:00] ✅ PASS Disk usage: 42% (28G available)

  ALL CHECKS PASSED (4/4)
```

### 2. Generate Checksum Manifest

```bash
bash scripts/verify.sh --path /var/backups --generate-checksums
# Creates /var/backups/checksums.sha256
```

### 3. Full Verification

```bash
bash scripts/verify.sh \
  --path /var/backups \
  --max-age 24 \
  --checksum /var/backups/checksums.sha256 \
  --test-restore \
  --verbose
```

## Core Workflows

### Workflow 1: Daily Backup Check via Cron

```bash
# Add to crontab — verify every 6 hours
0 */6 * * * bash /path/to/scripts/verify.sh \
  --path /var/backups \
  --max-age 24 \
  --test-restore \
  --report /var/backups/verify-report.md \
  --alert 'curl -s -d "🚨 Backup verification FAILED on $(hostname)" ntfy.sh/my-alerts'
```

### Workflow 2: Database Backup Verification

```bash
# Check SQL dumps are recent and not empty
bash scripts/verify.sh --path /var/backups/postgres --max-age 12

# With checksum verification
bash scripts/verify.sh \
  --path /var/backups/postgres \
  --checksum /var/backups/postgres/checksums.sha256 \
  --max-age 12
```

### Workflow 3: Archive Integrity Check

```bash
# Test all .tar.gz, .zip, .xz, .zst archives can be extracted
bash scripts/verify.sh --path /var/backups --test-restore --verbose
```

**On corrupt archive:**
```
[2026-02-28 10:00:00] ❌ FAIL Corrupt archive: site-backup-2026-02-27.tar.gz
  VERIFICATION FAILED (1 failed, 3 passed, 0 warnings)
```

### Workflow 4: Telegram Alert on Failure

```bash
export TELEGRAM_BOT_TOKEN="your-token"
export TELEGRAM_CHAT_ID="your-chat-id"

bash scripts/verify.sh \
  --path /var/backups \
  --max-age 24 \
  --test-restore \
  --alert "curl -s 'https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage?chat_id=${TELEGRAM_CHAT_ID}&text=🚨+Backup+verification+FAILED+on+$(hostname)'"
```

### Workflow 5: Multi-Directory Verification

```bash
#!/bin/bash
# verify-all.sh — Check multiple backup locations

DIRS=("/var/backups/postgres" "/var/backups/files" "/var/backups/configs")
FAILURES=0

for dir in "${DIRS[@]}"; do
  echo "Checking $dir..."
  if ! bash scripts/verify.sh --path "$dir" --max-age 24 --test-restore; then
    FAILURES=$((FAILURES + 1))
  fi
  echo ""
done

if [[ $FAILURES -gt 0 ]]; then
  echo "⚠️ $FAILURES location(s) failed verification"
  exit 1
fi
```

## Configuration

### Config File

```bash
cp scripts/config-template.yaml config.yaml
# Edit config.yaml, then:
bash scripts/verify.sh --config config.yaml
```

### Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--path DIR` | Backup directory to verify | Required |
| `--max-age HOURS` | Max backup age before alerting | 24 |
| `--checksum FILE` | SHA256 manifest to verify against | None |
| `--test-restore` | Test archive integrity | Off |
| `--alert CMD` | Command to run on failure | None |
| `--report FILE` | Write report to file | None |
| `--generate-checksums` | Create SHA256 manifest | — |
| `--verbose` | Detailed output | Off |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed |
| 1 | One or more checks failed |
| 2 | Passed with warnings |

### Supported Backup Formats

`.tar` `.tar.gz` `.tgz` `.zip` `.sql` `.sql.gz` `.bak` `.dump` `.7z` `.xz` `.bz2` `.zst` `.db` `.sqlite`

## Checks Performed

1. **Existence** — Are there backup files in the directory?
2. **Recency** — Is the newest backup within the max age?
3. **File size** — Are any backups empty or suspiciously small?
4. **Checksums** — Do files match their SHA256 manifest? (optional)
5. **Archive integrity** — Can archives be listed/extracted? (optional)
6. **Disk space** — Is the backup volume running out of space?

## Troubleshooting

### Issue: "No backup files found"

The script looks for common backup extensions. If your backups use a different extension, rename them or create symlinks.

### Issue: Checksum mismatch

Regenerate checksums after a successful backup:
```bash
bash scripts/verify.sh --path /var/backups --generate-checksums
```

### Issue: False age alerts after moving files

File modification time is used for recency checks. After copying/moving backups, timestamps may change. Use `touch` to update:
```bash
touch -r original-backup.tar.gz copied-backup.tar.gz
```

## Dependencies

- `bash` (4.0+)
- `sha256sum` (GNU coreutils)
- `tar`, `gzip` (for archive testing)
- `df` (disk space check)
- Optional: `unzip`, `xz`, `bzip2`, `zstd` (for respective formats)
- Optional: `curl` (for webhook alerts)
