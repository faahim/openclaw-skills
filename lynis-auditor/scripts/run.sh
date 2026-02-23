#!/bin/bash
# Lynis Security Auditor — Main Runner
# Usage: sudo bash scripts/run.sh --audit [--category <cat>] [--fix-script] [--cron]
#        bash scripts/run.sh --compare [--last N]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
REPORT_DIR="${LYNIS_REPORT_DIR:-$BASE_DIR/reports}"
LOG_DIR="$BASE_DIR/logs"

mkdir -p "$REPORT_DIR" "$LOG_DIR"

# Parse arguments
ACTION=""
CATEGORY=""
FIX_SCRIPT=false
CRON_MODE=false
COMPARE_LAST=10
PROFILE=""
COMPLIANCE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --audit) ACTION="audit"; shift ;;
    --compare) ACTION="compare"; shift ;;
    --category) CATEGORY="$2"; shift 2 ;;
    --fix-script) FIX_SCRIPT=true; shift ;;
    --cron) CRON_MODE=true; shift ;;
    --last) COMPARE_LAST="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --compliance) COMPLIANCE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$ACTION" ]]; then
  echo "Usage:"
  echo "  sudo bash scripts/run.sh --audit [--category <cat>] [--fix-script] [--cron]"
  echo "  bash scripts/run.sh --compare [--last N]"
  echo ""
  echo "Categories: authentication, boot, crypto, dns, firewall, kernel, logging,"
  echo "  mail, networking, php, scheduler, shell, snmp, ssh, storage, time, webserver"
  exit 1
fi

# ──────────────────────────────────────
# AUDIT
# ──────────────────────────────────────
run_audit() {
  if [[ $EUID -ne 0 ]]; then
    echo "❌ Audit requires root. Run with: sudo bash scripts/run.sh --audit"
    exit 1
  fi

  if ! command -v lynis &>/dev/null; then
    echo "❌ Lynis not found. Run: bash scripts/install.sh"
    exit 1
  fi

  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  DATE_SLUG=$(date -u +%Y-%m-%d_%H%M%S)
  REPORT_FILE="$REPORT_DIR/$DATE_SLUG.json"
  RAW_LOG="$LOG_DIR/lynis-$DATE_SLUG.log"

  echo "🔍 Running Lynis security audit..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Build Lynis command
  LYNIS_CMD="lynis audit system --no-colors --quick"
  
  if [[ -n "$CATEGORY" ]]; then
    LYNIS_CMD="$LYNIS_CMD --tests-from-group $CATEGORY"
    echo "📂 Category filter: $CATEGORY"
  fi

  if [[ -n "$PROFILE" ]]; then
    LYNIS_CMD="$LYNIS_CMD --profile $PROFILE"
  fi

  if [[ -f "$SCRIPT_DIR/custom.prf" ]]; then
    LYNIS_CMD="$LYNIS_CMD --profile $SCRIPT_DIR/custom.prf"
  fi

  # Run Lynis
  $LYNIS_CMD > "$RAW_LOG" 2>&1 || true

  # Parse results from Lynis report
  LYNIS_REPORT="/var/log/lynis-report.dat"
  
  if [[ ! -f "$LYNIS_REPORT" ]]; then
    echo "❌ Lynis report not found at $LYNIS_REPORT"
    exit 1
  fi

  # Extract hardening index
  HARDENING=$(grep "hardening_index=" "$LYNIS_REPORT" | cut -d= -f2 | head -1)
  HARDENING=${HARDENING:-0}

  # Extract warnings
  WARNINGS=()
  while IFS= read -r line; do
    WARNINGS+=("$line")
  done < <(grep "^warning\[\]=" "$LYNIS_REPORT" | sed 's/^warning\[\]=//' || true)

  # Extract suggestions
  SUGGESTIONS=()
  while IFS= read -r line; do
    SUGGESTIONS+=("$line")
  done < <(grep "^suggestion\[\]=" "$LYNIS_REPORT" | sed 's/^suggestion\[\]=//' || true)

  # Build JSON report
  WARNINGS_JSON="[]"
  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    WARNINGS_JSON=$(printf '%s\n' "${WARNINGS[@]}" | jq -R -s 'split("\n") | map(select(length > 0)) | map(split("|") | {id: .[0], description: .[1], severity: (.[2] // "warning")})')
  fi

  SUGGESTIONS_JSON="[]"
  if [[ ${#SUGGESTIONS[@]} -gt 0 ]]; then
    SUGGESTIONS_JSON=$(printf '%s\n' "${SUGGESTIONS[@]}" | jq -R -s 'split("\n") | map(select(length > 0)) | map(split("|") | {id: .[0], description: .[1], details: (.[2] // ""), severity: "suggestion"})')
  fi

  # Write JSON report
  jq -n \
    --arg ts "$TIMESTAMP" \
    --arg hi "$HARDENING" \
    --argjson warnings "$WARNINGS_JSON" \
    --argjson suggestions "$SUGGESTIONS_JSON" \
    '{
      timestamp: $ts,
      hardening_index: ($hi | tonumber),
      warning_count: ($warnings | length),
      suggestion_count: ($suggestions | length),
      warnings: $warnings,
      suggestions: $suggestions
    }' > "$REPORT_FILE"

  # Display results
  echo ""
  echo "📊 Hardening Index: $HARDENING/100"
  echo "⚠️  Warnings: ${#WARNINGS[@]}"
  echo "💡 Suggestions: ${#SUGGESTIONS[@]}"
  echo ""

  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo "🔴 CRITICAL (fix these first):"
    COUNT=1
    for w in "${WARNINGS[@]}"; do
      ID=$(echo "$w" | cut -d'|' -f1)
      DESC=$(echo "$w" | cut -d'|' -f2)
      echo "  $COUNT. [$ID] $DESC"
      COUNT=$((COUNT + 1))
      [[ $COUNT -gt 5 ]] && break
    done
    echo ""
  fi

  if [[ ${#SUGGESTIONS[@]} -gt 0 ]]; then
    echo "🟡 TOP SUGGESTIONS:"
    COUNT=1
    for s in "${SUGGESTIONS[@]}"; do
      ID=$(echo "$s" | cut -d'|' -f1)
      DESC=$(echo "$s" | cut -d'|' -f2)
      echo "  $COUNT. [$ID] $DESC"
      COUNT=$((COUNT + 1))
      [[ $COUNT -gt 10 ]] && break
    done
    echo ""
  fi

  echo "📁 Full report: $REPORT_FILE"
  echo "📁 Raw log: $RAW_LOG"

  # Generate fix script if requested
  if [[ "$FIX_SCRIPT" == true ]]; then
    generate_fix_script "$REPORT_FILE"
  fi

  # Send alerts if in cron mode and critical findings
  if [[ "$CRON_MODE" == true ]] && [[ ${#WARNINGS[@]} -gt 0 ]]; then
    send_alerts "$HARDENING" "${#WARNINGS[@]}" "${#SUGGESTIONS[@]}"
  fi
}

# ──────────────────────────────────────
# COMPARE
# ──────────────────────────────────────
run_compare() {
  echo "📈 Hardening Progress:"
  echo ""

  REPORTS=$(ls -1 "$REPORT_DIR"/*.json 2>/dev/null | sort | tail -n "$COMPARE_LAST")

  if [[ -z "$REPORTS" ]]; then
    echo "❌ No reports found. Run an audit first:"
    echo "   sudo bash scripts/run.sh --audit"
    exit 1
  fi

  PREV_SCORE=0
  while IFS= read -r report; do
    DATE=$(basename "$report" .json | sed 's/_/ /')
    SCORE=$(jq -r '.hardening_index' "$report")
    WARNS=$(jq -r '.warning_count' "$report")
    SUGS=$(jq -r '.suggestion_count' "$report")

    if [[ $PREV_SCORE -gt 0 ]]; then
      DIFF=$((SCORE - PREV_SCORE))
      if [[ $DIFF -gt 0 ]]; then
        echo "  $DATE: $SCORE/100 (+$DIFF) — $WARNS warnings, $SUGS suggestions"
      elif [[ $DIFF -lt 0 ]]; then
        echo "  $DATE: $SCORE/100 ($DIFF) — $WARNS warnings, $SUGS suggestions"
      else
        echo "  $DATE: $SCORE/100 (=) — $WARNS warnings, $SUGS suggestions"
      fi
    else
      echo "  $DATE: $SCORE/100 (baseline) — $WARNS warnings, $SUGS suggestions"
    fi
    PREV_SCORE=$SCORE
  done <<< "$REPORTS"

  # Calculate next milestone
  LATEST_SCORE=$(echo "$REPORTS" | tail -1 | xargs jq -r '.hardening_index')
  NEXT_MILESTONE=$(( ((LATEST_SCORE / 10) + 1) * 10 ))
  NEEDED=$((NEXT_MILESTONE - LATEST_SCORE))
  echo ""
  echo "🎯 Next milestone: $NEXT_MILESTONE/100 — improve by $NEEDED points"
}

# ──────────────────────────────────────
# FIX SCRIPT GENERATOR
# ──────────────────────────────────────
generate_fix_script() {
  local REPORT_FILE="$1"
  local FIX_FILE="$REPORT_DIR/remediation.sh"

  echo "🔧 Generating remediation script..."

  cat > "$FIX_FILE" << 'HEADER'
#!/bin/bash
# Auto-generated remediation script
# Review each section before running!
# Generated by Lynis Security Auditor

set -euo pipefail
echo "⚠️  Review this script before running. Press Ctrl+C to cancel."
read -p "Press Enter to continue..."

HEADER

  # Parse warnings and generate fixes
  jq -r '.warnings[] | "\(.id)|\(.description)"' "$REPORT_FILE" 2>/dev/null | while IFS='|' read -r id desc; do
    echo "" >> "$FIX_FILE"
    echo "# [$id] $desc" >> "$FIX_FILE"
    
    case "$id" in
      SSH-7408*)
        echo 'sed -i "s/^#*PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config' >> "$FIX_FILE"
        echo 'systemctl restart sshd' >> "$FIX_FILE"
        ;;
      AUTH-9262*)
        echo 'echo "SHA_CRYPT_MIN_ROUNDS 5000" >> /etc/login.defs' >> "$FIX_FILE"
        echo 'echo "SHA_CRYPT_MAX_ROUNDS 10000" >> /etc/login.defs' >> "$FIX_FILE"
        ;;
      FIRE-4590*)
        echo 'iptables -A INPUT -i lo -j ACCEPT' >> "$FIX_FILE"
        echo 'iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT' >> "$FIX_FILE"
        echo 'iptables -A INPUT -p tcp --dport 22 -j ACCEPT' >> "$FIX_FILE"
        echo 'iptables -A INPUT -j DROP' >> "$FIX_FILE"
        ;;
      KRNL-5820*)
        echo 'echo "fs.suid_dumpable = 0" >> /etc/sysctl.d/99-security.conf' >> "$FIX_FILE"
        echo 'sysctl -p /etc/sysctl.d/99-security.conf' >> "$FIX_FILE"
        ;;
      *)
        echo "# TODO: Manual fix required for $id" >> "$FIX_FILE"
        echo "echo 'Manual fix needed: [$id] $desc'" >> "$FIX_FILE"
        ;;
    esac
  done

  chmod +x "$FIX_FILE"
  echo "📁 Remediation script: $FIX_FILE"
  echo "   Review, then run: sudo bash $FIX_FILE"
}

# ──────────────────────────────────────
# ALERTS
# ──────────────────────────────────────
send_alerts() {
  local SCORE="$1"
  local WARNS="$2"
  local SUGS="$3"

  MSG="🔒 Lynis Audit Report\nScore: $SCORE/100\nWarnings: $WARNS\nSuggestions: $SUGS"

  # Telegram
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]] && [[ -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
      -d "chat_id=$TELEGRAM_CHAT_ID" \
      -d "text=$MSG" \
      -d "parse_mode=HTML" > /dev/null 2>&1 || true
    echo "📨 Telegram alert sent"
  fi

  # Email
  if [[ -n "${ALERT_EMAIL:-}" ]] && command -v mail &>/dev/null; then
    echo -e "$MSG" | mail -s "Lynis Audit: Score $SCORE/100" "$ALERT_EMAIL" || true
    echo "📨 Email alert sent to $ALERT_EMAIL"
  fi
}

# ──────────────────────────────────────
# MAIN
# ──────────────────────────────────────
case "$ACTION" in
  audit) run_audit ;;
  compare) run_compare ;;
  *) echo "Unknown action: $ACTION"; exit 1 ;;
esac
