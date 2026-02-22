#!/usr/bin/env bash
# Disk Space Monitor — Monitor usage, find large files, auto-clean, alert
# Usage: bash disk-monitor.sh --check [--find-large] [--clean] [--alert telegram]

set -uo pipefail

# ── Defaults ──────────────────────────────────────────────
WARN_THRESHOLD="${DISK_WARN_THRESHOLD:-80}"
CRITICAL_THRESHOLD="${DISK_CRITICAL_THRESHOLD:-95}"
TOP_N=20
SCAN_PATH="/"
SCAN_DEPTH=4
EXCLUDE_PATHS="/proc,/sys,/dev,/run,/snap"
OUTPUT_FMT="text"
ALERT_TYPE=""
CLEAN_TARGETS=""
DRY_RUN=false
HISTORY_FILE=""
CONFIG_FILE=""
TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT="${TELEGRAM_CHAT_ID:-}"

# ── Modes ─────────────────────────────────────────────────
DO_CHECK=false
DO_FIND_LARGE=false
DO_FIND_DIRS=false
DO_CLEAN=false
DO_TREND=false

# ── Parse Args ────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)             DO_CHECK=true; shift ;;
    --find-large)        DO_FIND_LARGE=true; shift ;;
    --find-large-dirs)   DO_FIND_DIRS=true; shift ;;
    --clean)             DO_CLEAN=true; shift ;;
    --trend)             DO_TREND=true; shift ;;
    --dry-run)           DRY_RUN=true; shift ;;
    --path)              SCAN_PATH="$2"; shift 2 ;;
    --top)               TOP_N="$2"; shift 2 ;;
    --depth)             SCAN_DEPTH="$2"; shift 2 ;;
    --warn-threshold)    WARN_THRESHOLD="$2"; shift 2 ;;
    --critical-threshold) CRITICAL_THRESHOLD="$2"; shift 2 ;;
    --alert)             ALERT_TYPE="$2"; shift 2 ;;
    --targets)           CLEAN_TARGETS="$2"; shift 2 ;;
    --output)            OUTPUT_FMT="$2"; shift 2 ;;
    --log-history)       HISTORY_FILE="$2"; shift 2 ;;
    --history-file)      HISTORY_FILE="$2"; shift 2 ;;
    --exclude)           EXCLUDE_PATHS="$2"; shift 2 ;;
    --telegram-token)    TELEGRAM_TOKEN="$2"; shift 2 ;;
    --telegram-chat)     TELEGRAM_CHAT="$2"; shift 2 ;;
    --config)            CONFIG_FILE="$2"; shift 2 ;;
    --partition)         TREND_PARTITION="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: disk-monitor.sh [--check] [--find-large] [--clean] [--alert telegram]"
      echo "Run with --help for full options. See SKILL.md for documentation."
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Default to --check if nothing specified
if ! $DO_CHECK && ! $DO_FIND_LARGE && ! $DO_FIND_DIRS && ! $DO_CLEAN && ! $DO_TREND; then
  DO_CHECK=true
fi

NOW=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

# ── Helpers ───────────────────────────────────────────────

human_size() {
  local bytes=$1
  if command -v numfmt &>/dev/null; then
    numfmt --to=iec --suffix=B "$bytes" 2>/dev/null || echo "${bytes}B"
  else
    echo "${bytes}B"
  fi
}

send_telegram() {
  local msg="$1"
  if [[ -n "$TELEGRAM_TOKEN" && -n "$TELEGRAM_CHAT" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
      -d chat_id="$TELEGRAM_CHAT" \
      -d text="$msg" \
      -d parse_mode="Markdown" >/dev/null 2>&1 || true
  fi
}

send_alert() {
  local msg="$1"
  case "$ALERT_TYPE" in
    telegram) send_telegram "$msg" ;;
    webhook)
      [[ -n "${WEBHOOK_URL:-}" ]] && curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"$msg\"}" >/dev/null 2>&1 || true ;;
    *) ;; # no alert
  esac
}

# ── Check Disk Usage ──────────────────────────────────────

if $DO_CHECK; then
  warnings=0
  criticals=0
  alert_msg=""

  if [[ "$OUTPUT_FMT" == "text" ]]; then
    echo "=== Disk Space Report ($NOW) ==="
    echo ""
    printf "%-22s %6s %8s %8s %5s  %s\n" "PARTITION" "SIZE" "USED" "AVAIL" "USE%" "STATUS"
  fi

  json_parts=()

  while IFS= read -r line; do
    fs=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    used=$(echo "$line" | awk '{print $3}')
    avail=$(echo "$line" | awk '{print $4}')
    pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
    mount=$(echo "$line" | awk '{print $6}')

    # Skip pseudo-filesystems
    case "$fs" in
      tmpfs|devtmpfs|efivarfs|overlay|shm) continue ;;
    esac
    [[ "$mount" == "/snap/"* ]] && continue

    # Determine status
    status="✅ OK"
    if [[ "$pct" -ge "$CRITICAL_THRESHOLD" ]]; then
      status="🔴 CRITICAL"
      ((criticals++)) || true
      alert_msg+="🔴 *$mount* is ${pct}% full ($avail free)\n"
    elif [[ "$pct" -ge "$WARN_THRESHOLD" ]]; then
      status="⚠️  WARNING"
      ((warnings++)) || true
      alert_msg+="⚠️ *$mount* is ${pct}% full ($avail free)\n"
    fi

    if [[ "$OUTPUT_FMT" == "text" ]]; then
      printf "%-22s %6s %8s %8s %4s%%  %s\n" "$fs" "$size" "$used" "$avail" "$pct" "$status"
    elif [[ "$OUTPUT_FMT" == "json" ]]; then
      json_parts+=("{\"filesystem\":\"$fs\",\"size\":\"$size\",\"used\":\"$used\",\"available\":\"$avail\",\"percent\":$pct,\"mount\":\"$mount\",\"status\":\"$(echo $status | sed 's/[^a-zA-Z]//g')\"}")
    elif [[ "$OUTPUT_FMT" == "csv" ]]; then
      echo "$NOW,$fs,$mount,$size,$used,$avail,$pct"
    fi
  done < <(df -h --output=source,size,used,avail,pcent,target 2>/dev/null | tail -n +2 || df -h | tail -n +2)

  if [[ "$OUTPUT_FMT" == "text" ]]; then
    echo ""
    if [[ $criticals -gt 0 ]]; then
      echo "🔴 $criticals partition(s) at CRITICAL level (>=${CRITICAL_THRESHOLD}%)"
    fi
    if [[ $warnings -gt 0 ]]; then
      echo "⚠️  $warnings partition(s) above warning threshold (${WARN_THRESHOLD}%)"
    fi
    if [[ $criticals -eq 0 && $warnings -eq 0 ]]; then
      echo "✅ All partitions healthy"
    fi
  elif [[ "$OUTPUT_FMT" == "json" ]]; then
    IFS=','
    echo "{\"timestamp\":\"$NOW\",\"partitions\":[${json_parts[*]}],\"warnings\":$warnings,\"criticals\":$criticals}"
  fi

  # Log history
  if [[ -n "$HISTORY_FILE" ]]; then
    if [[ ! -f "$HISTORY_FILE" ]]; then
      echo "timestamp,filesystem,mount,size,used,available,percent" > "$HISTORY_FILE"
    fi
    while IFS= read -r line; do
      fs=$(echo "$line" | awk '{print $1}')
      case "$fs" in tmpfs|devtmpfs|efivarfs|overlay|shm) continue ;; esac
      size=$(echo "$line" | awk '{print $2}')
      used=$(echo "$line" | awk '{print $3}')
      avail=$(echo "$line" | awk '{print $4}')
      pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
      mount=$(echo "$line" | awk '{print $6}')
      [[ "$mount" == "/snap/"* ]] && continue
      echo "$NOW,$fs,$mount,$size,$used,$avail,$pct" >> "$HISTORY_FILE"
    done < <(df -h --output=source,size,used,avail,pcent,target 2>/dev/null | tail -n +2 || df -h | tail -n +2)
  fi

  # Send alert if needed
  if [[ -n "$ALERT_TYPE" && ($criticals -gt 0 || $warnings -gt 0) ]]; then
    send_alert "🖥️ *Disk Space Alert*\n${alert_msg}\nChecked at: $NOW"
  fi
fi

# ── Find Large Files ──────────────────────────────────────

if $DO_FIND_LARGE; then
  echo ""
  echo "=== Top $TOP_N Largest Files in $SCAN_PATH ==="

  # Build exclude args
  FIND_EXCLUDES=""
  IFS=',' read -ra EXCL <<< "$EXCLUDE_PATHS"
  for p in "${EXCL[@]}"; do
    FIND_EXCLUDES+=" -not -path '${p}/*'"
  done

  eval "find '$SCAN_PATH' -xdev -type f $FIND_EXCLUDES -printf '%s %p\n' 2>/dev/null" | \
    sort -rn | head -n "$TOP_N" | while read -r size path; do
      hr=$(human_size "$size")
      printf "  %-8s %s\n" "$hr" "$path"
    done
fi

# ── Find Large Directories ───────────────────────────────

if $DO_FIND_DIRS; then
  echo ""
  echo "=== Top $TOP_N Largest Directories in $SCAN_PATH (depth $SCAN_DEPTH) ==="

  du -h --max-depth="$SCAN_DEPTH" "$SCAN_PATH" 2>/dev/null | \
    sort -rh | head -n "$TOP_N" | while read -r size path; do
      printf "  %-8s %s\n" "$size" "$path"
    done
fi

# ── Auto-Clean ────────────────────────────────────────────

if $DO_CLEAN; then
  [[ -z "$CLEAN_TARGETS" ]] && CLEAN_TARGETS="logs,tmp"

  echo ""
  echo "=== Auto-Clean ($NOW) ==="
  $DRY_RUN && echo "[DRY RUN — no files will be deleted]"
  echo ""

  IFS=',' read -ra TARGETS <<< "$CLEAN_TARGETS"
  total_freed=0

  for target in "${TARGETS[@]}"; do
    case "$target" in
      apt)
        echo "→ Package cache (apt/yum)..."
        if command -v apt-get &>/dev/null; then
          if $DRY_RUN; then
            size=$(du -sh /var/cache/apt/archives/ 2>/dev/null | awk '{print $1}')
            echo "  Would clean apt cache (~$size)"
          else
            apt-get clean 2>/dev/null && echo "  ✅ apt cache cleaned" || echo "  ⚠️  Need sudo for apt clean"
          fi
        elif command -v yum &>/dev/null; then
          if $DRY_RUN; then
            echo "  Would run: yum clean all"
          else
            yum clean all 2>/dev/null && echo "  ✅ yum cache cleaned" || echo "  ⚠️  Need sudo for yum clean"
          fi
        else
          echo "  ⏭️  No apt/yum found, skipping"
        fi
        ;;

      logs)
        echo "→ Rotated logs older than 7 days..."
        count=$(find /var/log -type f \( -name "*.gz" -o -name "*.1" -o -name "*.old" -o -name "*.xz" \) -mtime +7 2>/dev/null | wc -l)
        if $DRY_RUN; then
          echo "  Would delete $count rotated log file(s)"
        else
          find /var/log -type f \( -name "*.gz" -o -name "*.1" -o -name "*.old" -o -name "*.xz" \) -mtime +7 -delete 2>/dev/null || true
          echo "  ✅ Cleaned $count rotated log(s)"
        fi
        ;;

      tmp)
        echo "→ Temp files older than 7 days..."
        count=$(find /tmp -type f -mtime +7 2>/dev/null | wc -l)
        if $DRY_RUN; then
          echo "  Would delete $count temp file(s)"
        else
          find /tmp -type f -mtime +7 -delete 2>/dev/null || true
          echo "  ✅ Cleaned $count temp file(s)"
        fi
        ;;

      docker)
        echo "→ Docker unused resources..."
        if command -v docker &>/dev/null; then
          if $DRY_RUN; then
            docker system df 2>/dev/null || echo "  Docker not accessible"
            echo "  Would run: docker system prune -af"
          else
            docker system prune -af 2>/dev/null && echo "  ✅ Docker pruned" || echo "  ⚠️  Docker prune failed"
          fi
        else
          echo "  ⏭️  Docker not installed, skipping"
        fi
        ;;

      journal)
        echo "→ Systemd journal logs older than 7 days..."
        if command -v journalctl &>/dev/null; then
          if $DRY_RUN; then
            journalctl --disk-usage 2>/dev/null
            echo "  Would vacuum to 7 days"
          else
            journalctl --vacuum-time=7d 2>/dev/null && echo "  ✅ Journal vacuumed" || echo "  ⚠️  Need sudo for journal vacuum"
          fi
        else
          echo "  ⏭️  journalctl not found, skipping"
        fi
        ;;

      npm)
        echo "→ npm cache..."
        if command -v npm &>/dev/null; then
          if $DRY_RUN; then
            echo "  Would run: npm cache clean --force"
          else
            npm cache clean --force 2>/dev/null && echo "  ✅ npm cache cleaned" || true
          fi
        fi
        ;;

      pip)
        echo "→ pip cache..."
        if command -v pip3 &>/dev/null; then
          if $DRY_RUN; then
            echo "  Would run: pip3 cache purge"
          else
            pip3 cache purge 2>/dev/null && echo "  ✅ pip cache purged" || true
          fi
        fi
        ;;

      *)
        echo "→ Unknown target: $target (skipping)"
        ;;
    esac
    echo ""
  done
fi

# ── Trend Analysis ────────────────────────────────────────

if $DO_TREND; then
  if [[ -z "$HISTORY_FILE" || ! -f "$HISTORY_FILE" ]]; then
    echo "Error: No history file. Use --check --log-history <file> to build history first."
    exit 1
  fi

  TARGET_PART="${TREND_PARTITION:-}"
  if [[ -z "$TARGET_PART" ]]; then
    # Pick the largest non-tmpfs partition
    TARGET_PART=$(df --output=source,size | tail -n +2 | sort -k2 -rn | head -1 | awk '{print $1}')
  fi

  echo "=== Usage Trend for $TARGET_PART ==="
  echo ""

  prev_pct=0
  while IFS=',' read -r ts fs mount size used avail pct; do
    [[ "$fs" != "$TARGET_PART" ]] && continue
    # Simple bar
    bar_len=$((pct / 5))
    bar=$(printf '█%.0s' $(seq 1 $bar_len 2>/dev/null) 2>/dev/null || echo "")
    empty=$((20 - bar_len))
    empty_bar=$(printf '░%.0s' $(seq 1 $empty 2>/dev/null) 2>/dev/null || echo "")
    date_short=$(echo "$ts" | cut -d' ' -f1)
    printf "%s: %s%s %d%%\n" "$date_short" "$bar" "$empty_bar" "$pct"
    prev_pct=$pct
  done < <(tail -n +2 "$HISTORY_FILE")
fi
