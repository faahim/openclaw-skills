#!/bin/bash
# Backup Verify — Validate backup integrity, recency, and restorability
# Usage: bash verify.sh [--config config.yaml | --path /path/to/backups --max-age 24]

set -euo pipefail

# Defaults
CONFIG=""
BACKUP_PATH=""
MAX_AGE_HOURS=24
CHECKSUM_FILE=""
TEST_RESTORE=false
ALERT_CMD=""
REPORT_FILE=""
VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  cat <<EOF
Backup Verify — Validate backup integrity

USAGE:
  bash verify.sh [OPTIONS]

OPTIONS:
  --config FILE        YAML config file (see config-template.yaml)
  --path DIR           Path to backup directory
  --max-age HOURS      Max age in hours before alerting (default: 24)
  --checksum FILE      Checksum manifest file (SHA256)
  --test-restore       Test extracting archives to temp dir
  --alert CMD          Command to run on failure (e.g., curl webhook)
  --report FILE        Write report to file
  --verbose            Show detailed output
  -h, --help           Show this help

EXAMPLES:
  # Check backups exist and are recent
  bash verify.sh --path /var/backups --max-age 24

  # Full verification with checksums and test restore
  bash verify.sh --path /var/backups --checksum /var/backups/checksums.sha256 --test-restore

  # With alerting
  bash verify.sh --path /var/backups --max-age 24 \
    --alert 'curl -s -d "Backup verification FAILED" ntfy.sh/my-backups'

  # Generate checksum manifest for existing backups
  bash verify.sh --path /var/backups --generate-checksums
EOF
  exit 0
}

GENERATE_CHECKSUMS=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --config) CONFIG="$2"; shift 2 ;;
    --path) BACKUP_PATH="$2"; shift 2 ;;
    --max-age) MAX_AGE_HOURS="$2"; shift 2 ;;
    --checksum) CHECKSUM_FILE="$2"; shift 2 ;;
    --test-restore) TEST_RESTORE=true; shift ;;
    --alert) ALERT_CMD="$2"; shift 2 ;;
    --report) REPORT_FILE="$2"; shift 2 ;;
    --verbose) VERBOSE=true; shift ;;
    --generate-checksums) GENERATE_CHECKSUMS=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Parse YAML config (simple key: value parser)
if [[ -n "$CONFIG" && -f "$CONFIG" ]]; then
  BACKUP_PATH=$(grep '^backup_path:' "$CONFIG" | awk '{print $2}' | tr -d '"' || echo "")
  MAX_AGE_HOURS=$(grep '^max_age_hours:' "$CONFIG" | awk '{print $2}' || echo "24")
  CHECKSUM_FILE=$(grep '^checksum_file:' "$CONFIG" | awk '{print $2}' | tr -d '"' || echo "")
  tr=$(grep '^test_restore:' "$CONFIG" | awk '{print $2}' || echo "false")
  [[ "$tr" == "true" ]] && TEST_RESTORE=true
  ALERT_CMD=$(grep '^alert_command:' "$CONFIG" | sed 's/^alert_command: *//' | tr -d '"' || echo "")
  REPORT_FILE=$(grep '^report_file:' "$CONFIG" | awk '{print $2}' | tr -d '"' || echo "")
fi

if [[ -z "$BACKUP_PATH" ]]; then
  echo -e "${RED}Error: --path or config with backup_path required${NC}"
  echo "Run with --help for usage"
  exit 1
fi

if [[ ! -d "$BACKUP_PATH" ]]; then
  echo -e "${RED}Error: Backup path does not exist: $BACKUP_PATH${NC}"
  exit 1
fi

# Counters
TOTAL_CHECKS=0
PASSED=0
FAILED=0
WARNINGS=0
RESULTS=""

log() {
  local level="$1"
  shift
  local msg="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  case $level in
    PASS) echo -e "[$timestamp] ${GREEN}✅ PASS${NC} $msg"; RESULTS+="PASS: $msg\n" ;;
    FAIL) echo -e "[$timestamp] ${RED}❌ FAIL${NC} $msg"; RESULTS+="FAIL: $msg\n" ;;
    WARN) echo -e "[$timestamp] ${YELLOW}⚠️  WARN${NC} $msg"; RESULTS+="WARN: $msg\n" ;;
    INFO) echo -e "[$timestamp] ℹ️  $msg" ;;
  esac
}

# Generate checksums mode
if [[ "$GENERATE_CHECKSUMS" == true ]]; then
  OUTFILE="$BACKUP_PATH/checksums.sha256"
  log INFO "Generating SHA256 checksums for files in $BACKUP_PATH..."
  find "$BACKUP_PATH" -maxdepth 1 -type f ! -name "checksums.sha256" -exec sha256sum {} \; > "$OUTFILE"
  count=$(wc -l < "$OUTFILE")
  log INFO "Generated checksums for $count files → $OUTFILE"
  exit 0
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "  BACKUP VERIFICATION REPORT"
echo "  Path: $BACKUP_PATH"
echo "  Time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "═══════════════════════════════════════════════════"
echo ""

# ─── CHECK 1: Backup files exist ───
log INFO "Check 1: Backup files exist"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

file_count=$(find "$BACKUP_PATH" -maxdepth 1 -type f \( -name "*.tar" -o -name "*.tar.gz" -o -name "*.tgz" -o -name "*.zip" -o -name "*.sql" -o -name "*.sql.gz" -o -name "*.bak" -o -name "*.dump" -o -name "*.7z" -o -name "*.xz" -o -name "*.bz2" -o -name "*.zst" -o -name "*.db" -o -name "*.sqlite" \) 2>/dev/null | wc -l)

if [[ $file_count -gt 0 ]]; then
  log PASS "Found $file_count backup file(s)"
  PASSED=$((PASSED + 1))
  
  if [[ "$VERBOSE" == true ]]; then
    find "$BACKUP_PATH" -maxdepth 1 -type f \( -name "*.tar" -o -name "*.tar.gz" -o -name "*.tgz" -o -name "*.zip" -o -name "*.sql" -o -name "*.sql.gz" -o -name "*.bak" -o -name "*.dump" -o -name "*.7z" -o -name "*.xz" -o -name "*.bz2" -o -name "*.zst" -o -name "*.db" -o -name "*.sqlite" \) -exec ls -lh {} \; 2>/dev/null | while read -r line; do
      echo "       $line"
    done
  fi
else
  log FAIL "No backup files found in $BACKUP_PATH"
  FAILED=$((FAILED + 1))
fi

echo ""

# ─── CHECK 2: Recency (max age) ───
log INFO "Check 2: Backup recency (max age: ${MAX_AGE_HOURS}h)"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

if [[ $file_count -gt 0 ]]; then
  newest_file=$(find "$BACKUP_PATH" -maxdepth 1 -type f \( -name "*.tar" -o -name "*.tar.gz" -o -name "*.tgz" -o -name "*.zip" -o -name "*.sql" -o -name "*.sql.gz" -o -name "*.bak" -o -name "*.dump" -o -name "*.7z" -o -name "*.xz" -o -name "*.bz2" -o -name "*.zst" -o -name "*.db" -o -name "*.sqlite" \) -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -1)
  
  if [[ -n "$newest_file" ]]; then
    newest_ts=$(echo "$newest_file" | cut -f1 | cut -d. -f1)
    newest_path=$(echo "$newest_file" | cut -f2-)
    now_ts=$(date +%s)
    age_hours=$(( (now_ts - newest_ts) / 3600 ))
    age_days=$(( age_hours / 24 ))
    
    if [[ $age_hours -le $MAX_AGE_HOURS ]]; then
      log PASS "Newest backup is ${age_hours}h old: $(basename "$newest_path")"
      PASSED=$((PASSED + 1))
    else
      log FAIL "Newest backup is ${age_hours}h old (${age_days}d) — exceeds ${MAX_AGE_HOURS}h limit"
      FAILED=$((FAILED + 1))
    fi
  fi
else
  log FAIL "No files to check recency"
  FAILED=$((FAILED + 1))
fi

echo ""

# ─── CHECK 3: File size (not empty/corrupt) ───
log INFO "Check 3: File sizes (detecting empty/tiny backups)"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

empty_count=0
suspicious_count=0

while IFS= read -r file; do
  size=$(stat --format=%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
  name=$(basename "$file")
  
  if [[ $size -eq 0 ]]; then
    log FAIL "Empty file: $name (0 bytes)"
    empty_count=$((empty_count + 1))
  elif [[ $size -lt 100 ]]; then
    log WARN "Suspiciously small: $name ($size bytes)"
    suspicious_count=$((suspicious_count + 1))
  elif [[ "$VERBOSE" == true ]]; then
    human_size=$(numfmt --to=iec "$size" 2>/dev/null || echo "${size}B")
    echo "       ✓ $name ($human_size)"
  fi
done < <(find "$BACKUP_PATH" -maxdepth 1 -type f \( -name "*.tar" -o -name "*.tar.gz" -o -name "*.tgz" -o -name "*.zip" -o -name "*.sql" -o -name "*.sql.gz" -o -name "*.bak" -o -name "*.dump" -o -name "*.7z" -o -name "*.xz" -o -name "*.bz2" -o -name "*.zst" -o -name "*.db" -o -name "*.sqlite" \) 2>/dev/null)

if [[ $empty_count -eq 0 && $suspicious_count -eq 0 ]]; then
  log PASS "All files have reasonable sizes"
  PASSED=$((PASSED + 1))
elif [[ $empty_count -gt 0 ]]; then
  FAILED=$((FAILED + 1))
else
  log WARN "$suspicious_count file(s) are suspiciously small"
  WARNINGS=$((WARNINGS + 1))
fi

echo ""

# ─── CHECK 4: Checksum verification ───
if [[ -n "$CHECKSUM_FILE" ]]; then
  log INFO "Check 4: Checksum verification ($CHECKSUM_FILE)"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  if [[ -f "$CHECKSUM_FILE" ]]; then
    cd "$BACKUP_PATH"
    if sha256sum --check --quiet "$CHECKSUM_FILE" 2>/dev/null; then
      checksum_count=$(wc -l < "$CHECKSUM_FILE")
      log PASS "All $checksum_count checksums verified"
      PASSED=$((PASSED + 1))
    else
      log FAIL "Checksum verification failed!"
      sha256sum --check "$CHECKSUM_FILE" 2>&1 | grep -i "FAILED" | while read -r line; do
        echo "       ❌ $line"
      done
      FAILED=$((FAILED + 1))
    fi
    cd - > /dev/null
  else
    log FAIL "Checksum file not found: $CHECKSUM_FILE"
    FAILED=$((FAILED + 1))
  fi
  echo ""
fi

# ─── CHECK 5: Archive integrity (test extraction) ───
if [[ "$TEST_RESTORE" == true ]]; then
  log INFO "Check 5: Test restore (archive integrity)"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  TEMP_DIR=$(mktemp -d)
  restore_failures=0
  
  while IFS= read -r file; do
    name=$(basename "$file")
    
    case "$name" in
      *.tar.gz|*.tgz)
        if tar tzf "$file" > /dev/null 2>&1; then
          [[ "$VERBOSE" == true ]] && echo "       ✓ $name — tar.gz valid"
        else
          log FAIL "Corrupt archive: $name"
          restore_failures=$((restore_failures + 1))
        fi
        ;;
      *.tar)
        if tar tf "$file" > /dev/null 2>&1; then
          [[ "$VERBOSE" == true ]] && echo "       ✓ $name — tar valid"
        else
          log FAIL "Corrupt archive: $name"
          restore_failures=$((restore_failures + 1))
        fi
        ;;
      *.zip)
        if unzip -t "$file" > /dev/null 2>&1; then
          [[ "$VERBOSE" == true ]] && echo "       ✓ $name — zip valid"
        else
          log FAIL "Corrupt archive: $name"
          restore_failures=$((restore_failures + 1))
        fi
        ;;
      *.gz)
        if gzip -t "$file" 2>/dev/null; then
          [[ "$VERBOSE" == true ]] && echo "       ✓ $name — gzip valid"
        else
          log FAIL "Corrupt gzip: $name"
          restore_failures=$((restore_failures + 1))
        fi
        ;;
      *.xz)
        if xz -t "$file" 2>/dev/null; then
          [[ "$VERBOSE" == true ]] && echo "       ✓ $name — xz valid"
        else
          log FAIL "Corrupt xz: $name"
          restore_failures=$((restore_failures + 1))
        fi
        ;;
      *.bz2)
        if bzip2 -t "$file" 2>/dev/null; then
          [[ "$VERBOSE" == true ]] && echo "       ✓ $name — bz2 valid"
        else
          log FAIL "Corrupt bz2: $name"
          restore_failures=$((restore_failures + 1))
        fi
        ;;
      *.zst)
        if zstd -t "$file" 2>/dev/null; then
          [[ "$VERBOSE" == true ]] && echo "       ✓ $name — zstd valid"
        else
          log FAIL "Corrupt zstd: $name"
          restore_failures=$((restore_failures + 1))
        fi
        ;;
      *)
        [[ "$VERBOSE" == true ]] && echo "       ⏭ $name — skipped (not an archive)"
        ;;
    esac
  done < <(find "$BACKUP_PATH" -maxdepth 1 -type f 2>/dev/null)
  
  rm -rf "$TEMP_DIR"
  
  if [[ $restore_failures -eq 0 ]]; then
    log PASS "All archives pass integrity check"
    PASSED=$((PASSED + 1))
  else
    log FAIL "$restore_failures archive(s) are corrupt"
    FAILED=$((FAILED + 1))
  fi
  echo ""
fi

# ─── CHECK 6: Disk space ───
log INFO "Check 6: Disk space on backup volume"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

disk_usage=$(df "$BACKUP_PATH" | tail -1 | awk '{print $5}' | tr -d '%')
disk_avail=$(df -h "$BACKUP_PATH" | tail -1 | awk '{print $4}')

if [[ $disk_usage -lt 80 ]]; then
  log PASS "Disk usage: ${disk_usage}% (${disk_avail} available)"
  PASSED=$((PASSED + 1))
elif [[ $disk_usage -lt 95 ]]; then
  log WARN "Disk usage: ${disk_usage}% — getting full (${disk_avail} available)"
  WARNINGS=$((WARNINGS + 1))
else
  log FAIL "Disk usage: ${disk_usage}% — critically low space (${disk_avail} available)"
  FAILED=$((FAILED + 1))
fi

echo ""

# ─── SUMMARY ───
echo "═══════════════════════════════════════════════════"
echo "  SUMMARY"
echo "═══════════════════════════════════════════════════"
echo ""

if [[ $FAILED -eq 0 && $WARNINGS -eq 0 ]]; then
  echo -e "  ${GREEN}ALL CHECKS PASSED${NC} ($PASSED/$TOTAL_CHECKS)"
  STATUS="PASS"
elif [[ $FAILED -eq 0 ]]; then
  echo -e "  ${YELLOW}PASSED WITH WARNINGS${NC} ($PASSED passed, $WARNINGS warnings)"
  STATUS="WARN"
else
  echo -e "  ${RED}VERIFICATION FAILED${NC} ($FAILED failed, $PASSED passed, $WARNINGS warnings)"
  STATUS="FAIL"
fi

echo ""
echo "  Checks run:  $TOTAL_CHECKS"
echo "  Passed:      $PASSED"
echo "  Failed:      $FAILED"
echo "  Warnings:    $WARNINGS"
echo ""

# Write report
if [[ -n "$REPORT_FILE" ]]; then
  {
    echo "# Backup Verification Report"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "Path: $BACKUP_PATH"
    echo "Status: $STATUS"
    echo "Checks: $TOTAL_CHECKS | Passed: $PASSED | Failed: $FAILED | Warnings: $WARNINGS"
    echo ""
    echo "## Details"
    echo -e "$RESULTS"
  } > "$REPORT_FILE"
  echo "  Report saved: $REPORT_FILE"
  echo ""
fi

# Alert on failure
if [[ $FAILED -gt 0 && -n "$ALERT_CMD" ]]; then
  log INFO "Sending failure alert..."
  eval "$ALERT_CMD" 2>/dev/null || log WARN "Alert command failed"
fi

# Exit code
if [[ $FAILED -gt 0 ]]; then
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  exit 2
else
  exit 0
fi
