#!/bin/bash
# Semgrep Code Scanner — main scan script
set -e

# Defaults
SCAN_PATH=""
RULESET="security"
OUTPUT=""
FORMAT="text"
SEVERITY=""
FAIL_ON_FINDINGS=false
GIT_DIFF=false
BASELINE=""
RULES_FILE=""

usage() {
  cat <<EOF
Usage: bash scripts/scan.sh --path <dir> [options]

Options:
  --path <dir>          Directory to scan (required)
  --ruleset <name>      Rule set: security|owasp|secrets|python|javascript|go|java|ruby|docker|terraform|supply-chain|all (default: security)
  --rules-file <path>   Custom rules YAML file
  --output <file>       Save results to file
  --format <fmt>        Output format: text|json|sarif|markdown (default: text)
  --severity <levels>   Filter: HIGH|MEDIUM|LOW (comma-separated)
  --fail-on-findings    Exit code 1 if findings found
  --git-diff            Scan only git-changed files
  --baseline <file>     Show only new findings vs baseline JSON
  -h, --help            Show this help

Examples:
  bash scripts/scan.sh --path ./myapp
  bash scripts/scan.sh --path ./myapp --ruleset owasp --severity HIGH,MEDIUM
  bash scripts/scan.sh --path ./myapp --ruleset secrets --output report.json --format json
  bash scripts/scan.sh --path . --git-diff
EOF
  exit 0
}

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --path) SCAN_PATH="$2"; shift 2 ;;
    --ruleset) RULESET="$2"; shift 2 ;;
    --rules-file) RULES_FILE="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --severity) SEVERITY="$2"; shift 2 ;;
    --fail-on-findings) FAIL_ON_FINDINGS=true; shift ;;
    --git-diff) GIT_DIFF=true; shift ;;
    --baseline) BASELINE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$SCAN_PATH" ]]; then
  echo "❌ --path is required"
  usage
fi

if ! command -v semgrep &>/dev/null; then
  echo "❌ semgrep not found. Run: bash scripts/install.sh"
  exit 1
fi

# Map ruleset to semgrep config
map_ruleset() {
  case "$1" in
    security)     echo "p/security-audit" ;;
    owasp)        echo "p/owasp-top-ten" ;;
    secrets)      echo "p/secrets" ;;
    python)       echo "p/python" ;;
    javascript)   echo "p/javascript" ;;
    go)           echo "p/golang" ;;
    java)         echo "p/java" ;;
    ruby)         echo "p/ruby" ;;
    docker)       echo "p/docker" ;;
    terraform)    echo "p/terraform" ;;
    supply-chain) echo "p/supply-chain" ;;
    all)          echo "p/default" ;;
    *)            echo "p/$1" ;;
  esac
}

# Build semgrep command
CMD="semgrep"

if [[ -n "$RULES_FILE" ]]; then
  CMD="$CMD --config $RULES_FILE"
else
  CONFIG=$(map_ruleset "$RULESET")
  CMD="$CMD --config $CONFIG"
fi

# Format
case "$FORMAT" in
  json)     CMD="$CMD --json" ;;
  sarif)    CMD="$CMD --sarif" ;;
  markdown) CMD="$CMD --json" ;;  # We'll convert later
  text)     ;;  # Default
esac

# Severity filter
if [[ -n "$SEVERITY" ]]; then
  IFS=',' read -ra SEVS <<< "$SEVERITY"
  for s in "${SEVS[@]}"; do
    CMD="$CMD --severity $(echo "$s" | tr '[:lower:]' '[:upper:]')"
  done
fi

# Baseline
if [[ -n "$BASELINE" ]]; then
  CMD="$CMD --baseline-commit HEAD~1"
fi

# Git diff mode
if [[ "$GIT_DIFF" == true ]]; then
  cd "$SCAN_PATH"
  CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || git diff --name-only HEAD 2>/dev/null || echo "")
  if [[ -z "$CHANGED_FILES" ]]; then
    echo "ℹ️  No changed files detected."
    exit 0
  fi
  TMPFILE=$(mktemp)
  echo "$CHANGED_FILES" > "$TMPFILE"
  CMD="$CMD --include-pattern-file $TMPFILE"
fi

CMD="$CMD $SCAN_PATH"

echo "🔍 Scanning $SCAN_PATH with ruleset: $RULESET..."
echo ""

# Run scan
if [[ -n "$OUTPUT" ]]; then
  if [[ "$FORMAT" == "markdown" ]]; then
    # Capture JSON, convert to markdown
    TMPJSON=$(mktemp)
    eval "$CMD --json" > "$TMPJSON" 2>/dev/null || true
    
    # Generate markdown report
    python3 -c "
import json, sys
from datetime import datetime

with open('$TMPJSON') as f:
    data = json.load(f)

results = data.get('results', [])
errors = data.get('errors', [])

high = sum(1 for r in results if r.get('extra', {}).get('severity', '').upper() == 'ERROR')
med = sum(1 for r in results if r.get('extra', {}).get('severity', '').upper() == 'WARNING')
low = sum(1 for r in results if r.get('extra', {}).get('severity', '').upper() == 'INFO')

print('# Security Scan Report')
print(f'**Date:** {datetime.utcnow().strftime(\"%Y-%m-%d %H:%M UTC\")}')
print(f'**Path:** \`$SCAN_PATH\`')
print(f'**Ruleset:** $RULESET')
print()
print('## Summary')
print(f'- **Total findings:** {len(results)}')
print(f'- 🔴 High: {high}')
print(f'- 🟡 Medium: {med}')
print(f'- 🔵 Low: {low}')
print()

if results:
    print('## Findings')
    print()
    for r in results:
        sev = r.get('extra', {}).get('severity', 'UNKNOWN').upper()
        icon = {'ERROR': '🔴', 'WARNING': '🟡', 'INFO': '🔵'}.get(sev, '⚪')
        print(f'### {icon} {r.get(\"check_id\", \"unknown\")}')
        print(f'**File:** \`{r.get(\"path\", \"?\")}:{r.get(\"start\", {}).get(\"line\", \"?\")}\`')
        print(f'**Message:** {r.get(\"extra\", {}).get(\"message\", \"No message\")}')
        if r.get('extra', {}).get('fix'):
            print(f'**Fix:** {r[\"extra\"][\"fix\"]}')
        print()
else:
    print('## ✅ No findings! Your code looks clean.')
" > "$OUTPUT" 2>/dev/null
    
    rm -f "$TMPJSON"
    echo "📄 Markdown report saved to: $OUTPUT"
  else
    eval "$CMD" > "$OUTPUT" 2>/dev/null || true
    echo "📄 Results saved to: $OUTPUT"
  fi
  
  # Also print summary to stdout
  if [[ "$FORMAT" == "json" || "$FORMAT" == "sarif" ]]; then
    echo "📊 Results written to $OUTPUT"
  fi
else
  # Print to stdout
  eval "$CMD" 2>/dev/null
  SCAN_EXIT=$?
fi

# Clean up git diff temp file
if [[ "$GIT_DIFF" == true && -n "${TMPFILE:-}" ]]; then
  rm -f "$TMPFILE"
fi

# Fail on findings
if [[ "$FAIL_ON_FINDINGS" == true ]]; then
  if [[ -n "$OUTPUT" ]]; then
    # Check if findings exist in output
    if [[ "$FORMAT" == "json" ]] && command -v jq &>/dev/null; then
      COUNT=$(jq '.results | length' "$OUTPUT" 2>/dev/null || echo "0")
      if [[ "$COUNT" -gt 0 ]]; then
        echo "❌ $COUNT finding(s) detected. Failing build."
        exit 1
      fi
    fi
  elif [[ "${SCAN_EXIT:-0}" -ne 0 ]]; then
    echo "❌ Findings detected. Failing build."
    exit 1
  fi
fi

echo ""
echo "✅ Scan complete."
