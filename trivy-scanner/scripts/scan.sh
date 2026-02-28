#!/bin/bash
# Trivy scan wrapper — simplified interface with formatted output
set -euo pipefail

# Defaults
SCAN_TYPE=""
TARGET=""
SEVERITY="${TRIVY_SEVERITY:-CRITICAL,HIGH,MEDIUM,LOW}"
SCANNERS="vuln,secret,misconfig"
FORMAT="table"
OUTPUT=""
EXIT_CODE=0
ALERT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --image)    SCAN_TYPE="image"; TARGET="$2"; shift 2 ;;
    --fs)       SCAN_TYPE="fs"; TARGET="$2"; shift 2 ;;
    --repo)     SCAN_TYPE="repo"; TARGET="$2"; shift 2 ;;
    --severity) SEVERITY="$2"; shift 2 ;;
    --scanners) SCANNERS="$2"; shift 2 ;;
    --format)   FORMAT="$2"; shift 2 ;;
    --output|-o) OUTPUT="$2"; shift 2 ;;
    --exit-code) EXIT_CODE="$2"; shift 2 ;;
    --alert)    ALERT="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: scan.sh --image|--fs|--repo <target> [options]"
      echo ""
      echo "Scan types:"
      echo "  --image <name>    Scan Docker/OCI image"
      echo "  --fs <path>       Scan local filesystem"
      echo "  --repo <url>      Scan remote Git repository"
      echo ""
      echo "Options:"
      echo "  --severity <list>   Filter by severity (default: CRITICAL,HIGH,MEDIUM,LOW)"
      echo "  --scanners <list>   Scan types: vuln,secret,misconfig (default: all)"
      echo "  --format <fmt>      Output format: table, json, sarif (default: table)"
      echo "  --output <file>     Write report to file"
      echo "  --exit-code <n>     Exit code when vulnerabilities found (default: 0)"
      echo "  --alert <type>      Send alert on findings: telegram"
      exit 0
      ;;
    *) echo "❌ Unknown option: $1. Use --help for usage."; exit 1 ;;
  esac
done

# Validate
if [ -z "$SCAN_TYPE" ] || [ -z "$TARGET" ]; then
  echo "❌ Must specify scan type and target. Use --help for usage."
  exit 1
fi

# Find trivy
TRIVY=$(command -v trivy 2>/dev/null || echo "$HOME/.local/bin/trivy")
if [ ! -x "$TRIVY" ]; then
  echo "❌ Trivy not found. Run: bash scripts/install.sh"
  exit 1
fi

# Build command
CMD=("$TRIVY" "$SCAN_TYPE" "$TARGET")
CMD+=(--severity "$SEVERITY")
CMD+=(--scanners "$SCANNERS")

if [ "$FORMAT" = "json" ]; then
  CMD+=(--format json)
elif [ "$FORMAT" = "sarif" ]; then
  CMD+=(--format sarif)
fi

if [ -n "$OUTPUT" ]; then
  CMD+=(--output "$OUTPUT")
fi

CMD+=(--exit-code "$EXIT_CODE")

# Header
echo "🔍 Scanning $SCAN_TYPE: $TARGET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Scanners: $SCANNERS"
echo "   Severity: $SEVERITY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Run scan
SCAN_EXIT=0
"${CMD[@]}" || SCAN_EXIT=$?

# JSON summary (if format is table, also generate a hidden JSON for parsing)
if [ "$FORMAT" = "table" ] && [ -z "$OUTPUT" ]; then
  SUMMARY_FILE="/tmp/trivy-summary-$(echo "$TARGET" | tr '/:' '-').json"
  "$TRIVY" "$SCAN_TYPE" "$TARGET" \
    --severity "$SEVERITY" \
    --scanners "$SCANNERS" \
    --format json \
    --output "$SUMMARY_FILE" \
    --exit-code 0 2>/dev/null || true
  
  if [ -f "$SUMMARY_FILE" ] && command -v jq &>/dev/null; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Count by severity
    CRITICAL=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "$SUMMARY_FILE" 2>/dev/null || echo 0)
    HIGH=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "$SUMMARY_FILE" 2>/dev/null || echo 0)
    MEDIUM=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' "$SUMMARY_FILE" 2>/dev/null || echo 0)
    LOW=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="LOW")] | length' "$SUMMARY_FILE" 2>/dev/null || echo 0)
    SECRETS=$(jq '[.Results[]?.Secrets[]?] | length' "$SUMMARY_FILE" 2>/dev/null || echo 0)
    MISCONFIGS=$(jq '[.Results[]?.Misconfigurations[]?] | length' "$SUMMARY_FILE" 2>/dev/null || echo 0)
    
    echo "CRITICAL: $CRITICAL | HIGH: $HIGH | MEDIUM: $MEDIUM | LOW: $LOW"
    [ "$SECRETS" -gt 0 ] 2>/dev/null && echo "Secrets: $SECRETS"
    [ "$MISCONFIGS" -gt 0 ] 2>/dev/null && echo "Misconfigurations: $MISCONFIGS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Full JSON: $SUMMARY_FILE"
    
    # Telegram alert
    if [ "$ALERT" = "telegram" ] && [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
      TOTAL=$((CRITICAL + HIGH))
      if [ "$TOTAL" -gt 0 ]; then
        MSG="🚨 Trivy Scan Alert%0A%0ATarget: $TARGET%0ACRITICAL: $CRITICAL | HIGH: $HIGH%0A%0ARun full scan for details."
        curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage?chat_id=${TELEGRAM_CHAT_ID}&text=${MSG}" > /dev/null 2>&1
        echo "📨 Alert sent to Telegram"
      fi
    fi
  fi
fi

exit $SCAN_EXIT
