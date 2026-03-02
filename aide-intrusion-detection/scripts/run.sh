#!/bin/bash
# AIDE Intrusion Detection — Main Runner
# Usage: bash run.sh <command> [options]
#   Commands: init, check, update, schedule, unschedule
set -euo pipefail

AIDE_CONFIG="${AIDE_CONFIG:-/etc/aide/aide.conf}"
AIDE_DB="${AIDE_DB:-/var/lib/aide/aide.db}"
AIDE_DB_NEW="${AIDE_DB}.new"
AIDE_LOG_DIR="${AIDE_LOG_DIR:-/var/log/aide}"
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S')
DATE_TAG=$(date -u '+%Y%m%d_%H%M%S')

# Alert config (from env)
TELEGRAM_TOKEN="${AIDE_ALERT_TELEGRAM_TOKEN:-}"
TELEGRAM_CHAT="${AIDE_ALERT_TELEGRAM_CHAT:-}"
WEBHOOK_URL="${AIDE_ALERT_WEBHOOK:-}"
ALERT_EMAIL="${AIDE_ALERT_EMAIL:-}"

# Defaults
REPORT_FILE=""
FORMAT="text"
RULES=""
ALERT=false
EXCLUDE_PATTERNS=""
CUSTOM_PATHS=""
INTERVAL=""
CRON_EXPR=""

# ---- Helpers ----

log() { echo "[$TIMESTAMP] $*"; }

send_alert() {
  local message="$1"
  local hostname
  hostname=$(hostname 2>/dev/null || echo "unknown")

  if [[ -n "$TELEGRAM_TOKEN" && -n "$TELEGRAM_CHAT" ]]; then
    curl -sf -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
      -d chat_id="$TELEGRAM_CHAT" \
      -d text="🚨 AIDE Alert on ${hostname}:
${message}" \
      -d parse_mode="Markdown" >/dev/null 2>&1 || true
    log "📱 Telegram alert sent"
  fi

  if [[ -n "$WEBHOOK_URL" ]]; then
    curl -sf -X POST "$WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{\"text\":\"AIDE Alert on ${hostname}: ${message}\"}" >/dev/null 2>&1 || true
    log "🔗 Webhook alert sent"
  fi

  if [[ -n "$ALERT_EMAIL" ]] && command -v mail &>/dev/null; then
    echo "$message" | mail -s "AIDE Alert on ${hostname}" "$ALERT_EMAIL" 2>/dev/null || true
    log "📧 Email alert sent"
  fi
}

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "[!] AIDE requires root. Re-running with sudo..."
    exec sudo bash "$0" "$@"
  fi
}

ensure_config() {
  if [[ ! -f "$AIDE_CONFIG" ]]; then
    echo "[!] AIDE config not found at $AIDE_CONFIG"
    echo "    Run: bash scripts/install.sh"
    exit 1
  fi
}

ensure_db() {
  if [[ ! -f "$AIDE_DB" ]]; then
    echo "[!] AIDE database not found at $AIDE_DB"
    echo "    Run: bash scripts/run.sh init"
    exit 1
  fi
}

# ---- Commands ----

cmd_init() {
  check_root
  ensure_config
  
  log "Initializing AIDE database..."
  
  # Use custom paths if specified
  local config_to_use="$AIDE_CONFIG"
  if [[ -n "$CUSTOM_PATHS" ]]; then
    local tmp_conf="/tmp/aide-custom-$$.conf"
    # Start with base config (db locations + rules only)
    grep -E '^(database|NORMAL|PERMS|LOG|DIR|!)' "$AIDE_CONFIG" > "$tmp_conf" || true
    # Add custom paths
    IFS=',' read -ra PATHS <<< "$CUSTOM_PATHS"
    for p in "${PATHS[@]}"; do
      p=$(echo "$p" | xargs)  # trim
      echo "$p NORMAL" >> "$tmp_conf"
    done
    config_to_use="$tmp_conf"
  fi
  
  sudo mkdir -p "$(dirname "$AIDE_DB")" "$AIDE_LOG_DIR" 2>/dev/null || true
  
  if aide --init --config="$config_to_use" 2>&1; then
    # AIDE outputs to aide.db.new, move to aide.db
    if [[ -f "$AIDE_DB_NEW" ]]; then
      sudo mv "$AIDE_DB_NEW" "$AIDE_DB"
    fi
    
    local file_count
    file_count=$(aide --config="$config_to_use" --check 2>&1 | grep -oP 'Total number of entries:\s*\K\d+' || echo "unknown")
    log "✅ Baseline created: $AIDE_DB"
    log "Monitored: $file_count files"
  else
    log "❌ Initialization failed. Check config: $config_to_use"
    exit 1
  fi
  
  [[ -n "$CUSTOM_PATHS" ]] && rm -f "/tmp/aide-custom-$$.conf"
}

cmd_check() {
  check_root
  ensure_config
  ensure_db
  
  log "Running AIDE integrity check..."
  
  local aide_output
  local exit_code=0
  aide_output=$(aide --check --config="$AIDE_CONFIG" 2>&1) || exit_code=$?
  
  # AIDE exit codes:
  #  0 = no changes
  #  1-7 = changes detected (bitmask: 1=added, 2=removed, 4=modified)
  # 14+ = error
  
  if [[ $exit_code -eq 0 ]]; then
    local file_count
    file_count=$(echo "$aide_output" | grep -oP 'Total number of entries:\s*\K\d+' || echo "unknown")
    log "✅ No unauthorized changes detected ($file_count files checked)"
    
    if [[ "$FORMAT" == "json" ]]; then
      echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"status\":\"clean\",\"summary\":{\"added\":0,\"modified\":0,\"removed\":0},\"changes\":[]}"
    fi
  elif [[ $exit_code -ge 1 && $exit_code -le 7 ]]; then
    # Parse changes
    local added modified removed
    added=$(echo "$aide_output" | grep -cP '^\s*Added:' || echo "0")  
    modified=$(echo "$aide_output" | grep -cP '^\s*(Changed|Modified):' || echo "0")
    removed=$(echo "$aide_output" | grep -cP '^\s*Removed:' || echo "0")
    
    # Better parsing from summary line
    added=$(echo "$aide_output" | grep -oP 'Added entries:\s*\K\d+' || echo "?")
    removed=$(echo "$aide_output" | grep -oP 'Removed entries:\s*\K\d+' || echo "?")
    modified=$(echo "$aide_output" | grep -oP 'Changed entries:\s*\K\d+' || echo "?")
    
    log "⚠️ Changes detected: +$added added, ~$modified modified, -$removed removed"
    
    if [[ "$FORMAT" == "json" ]]; then
      echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"status\":\"changes_detected\",\"summary\":{\"added\":$added,\"modified\":$modified,\"removed\":$removed}}"
    else
      echo ""
      echo "$aide_output" | grep -E '(^f|^d|^l|Added|Changed|Removed|Entry)' | head -50
    fi
    
    # Save report
    if [[ -n "$REPORT_FILE" ]]; then
      echo "$aide_output" > "$REPORT_FILE"
      log "📄 Full report saved to $REPORT_FILE"
    fi
    
    # Save to log dir
    sudo mkdir -p "$AIDE_LOG_DIR" 2>/dev/null || true
    echo "$aide_output" | sudo tee "$AIDE_LOG_DIR/check-${DATE_TAG}.log" >/dev/null
    
    # Send alerts
    if $ALERT; then
      send_alert "Changes detected: +$added added, ~$modified modified, -$removed removed"
    fi
  else
    log "❌ AIDE check failed (exit code: $exit_code)"
    echo "$aide_output"
    exit 1
  fi
}

cmd_update() {
  check_root
  ensure_config
  ensure_db
  
  log "Updating AIDE baseline..."
  
  # Backup current DB
  local backup="${AIDE_DB}.bak.${DATE_TAG}"
  sudo cp "$AIDE_DB" "$backup"
  log "Previous baseline backed up to $backup"
  
  if aide --update --config="$AIDE_CONFIG" 2>&1; then
    if [[ -f "$AIDE_DB_NEW" ]]; then
      sudo mv "$AIDE_DB_NEW" "$AIDE_DB"
    fi
    log "✅ Baseline updated successfully"
  else
    log "❌ Update failed"
    sudo mv "$backup" "$AIDE_DB"
    exit 1
  fi
}

cmd_schedule() {
  check_root
  
  local cron_line=""
  local script_path
  script_path="$(cd "$(dirname "$0")" && pwd)/run.sh"
  local cron_cmd="bash $script_path check --alert >> $AIDE_LOG_DIR/cron.log 2>&1"
  
  if [[ -n "$CRON_EXPR" ]]; then
    cron_line="$CRON_EXPR $cron_cmd"
  elif [[ -n "$INTERVAL" ]]; then
    case "$INTERVAL" in
      1h)  cron_line="0 * * * * $cron_cmd" ;;
      2h)  cron_line="0 */2 * * * $cron_cmd" ;;
      4h)  cron_line="0 */4 * * * $cron_cmd" ;;
      6h)  cron_line="0 */6 * * * $cron_cmd" ;;
      8h)  cron_line="0 */8 * * * $cron_cmd" ;;
      12h) cron_line="0 */12 * * * $cron_cmd" ;;
      24h) cron_line="0 3 * * * $cron_cmd" ;;
      *)   echo "[!] Unsupported interval: $INTERVAL (use 1h,2h,4h,6h,8h,12h,24h)"; exit 1 ;;
    esac
  else
    cron_line="0 */6 * * * $cron_cmd"
  fi
  
  # Remove existing AIDE cron entries, add new one
  (crontab -l 2>/dev/null | grep -v "aide.*run.sh" || true; echo "$cron_line") | crontab -
  
  sudo mkdir -p "$AIDE_LOG_DIR" 2>/dev/null || true
  log "✅ Scheduled: $cron_line"
}

cmd_unschedule() {
  check_root
  (crontab -l 2>/dev/null | grep -v "aide.*run.sh" || true) | crontab -
  log "✅ AIDE cron jobs removed"
}

# ---- Argument Parsing ----

COMMAND="${1:-help}"
shift || true

while [[ $# -gt 0 ]]; do
  case $1 in
    --report)     REPORT_FILE="$2"; shift 2 ;;
    --format)     FORMAT="$2"; shift 2 ;;
    --rules)      RULES="$2"; shift 2 ;;
    --alert)      ALERT=true; shift ;;
    --exclude)    EXCLUDE_PATTERNS="$2"; shift 2 ;;
    --paths)      CUSTOM_PATHS="$2"; shift 2 ;;
    --interval)   INTERVAL="$2"; shift 2 ;;
    --cron)       CRON_EXPR="$2"; shift 2 ;;
    *)            echo "[!] Unknown option: $1"; exit 1 ;;
  esac
done

case "$COMMAND" in
  init)       cmd_init ;;
  check)      cmd_check ;;
  update)     cmd_update ;;
  schedule)   cmd_schedule ;;
  unschedule) cmd_unschedule ;;
  help|--help|-h)
    echo "AIDE Intrusion Detection"
    echo ""
    echo "Usage: bash run.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init         Initialize baseline database"
    echo "  check        Check for changes against baseline"
    echo "  update       Update baseline (accept current changes)"
    echo "  schedule     Set up cron for automated checks"
    echo "  unschedule   Remove automated checks"
    echo ""
    echo "Options:"
    echo "  --paths <p1,p2>    Custom paths to monitor (init only)"
    echo "  --report <file>    Save report to file (check only)"
    echo "  --format <fmt>     Output format: text|json (check only)"
    echo "  --alert            Send alerts on changes (check only)"
    echo "  --interval <Nh>    Check interval: 1h,2h,4h,6h,8h,12h,24h"
    echo "  --cron <expr>      Custom cron expression"
    echo ""
    echo "Environment:"
    echo "  AIDE_ALERT_TELEGRAM_TOKEN  Telegram bot token"
    echo "  AIDE_ALERT_TELEGRAM_CHAT   Telegram chat ID"
    echo "  AIDE_ALERT_WEBHOOK         Webhook URL (POST JSON)"
    echo "  AIDE_ALERT_EMAIL           Email address"
    echo "  AIDE_CONFIG                Config path (default: /etc/aide/aide.conf)"
    echo "  AIDE_DB                    Database path (default: /var/lib/aide/aide.db)"
    ;;
  *)
    echo "[!] Unknown command: $COMMAND"
    echo "    Run: bash run.sh help"
    exit 1
    ;;
esac
