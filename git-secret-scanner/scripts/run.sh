#!/bin/bash
# Git Secret Scanner — Main Runner
# Wraps gitleaks with friendly output and additional features

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
SCAN_PATH=""
SCAN_ALL_PATH=""
HISTORY=false
FORMAT="text"
OUTPUT=""
CONFIG=""
BASELINE=""
USE_BASELINE=""
INSTALL_HOOK=false
HOOK_PATH=""
SINCE=""

usage() {
  cat <<EOF
Git Secret Scanner — Find leaked secrets in git repos

USAGE:
  bash run.sh --scan <path>              Scan a repository
  bash run.sh --scan <path> --history    Scan full git history
  bash run.sh --scan-all <path>          Scan all repos in directory
  bash run.sh --hook <path>              Install pre-commit hook

OPTIONS:
  --scan <path>          Path to git repository to scan
  --scan-all <path>      Scan all git repos under this directory
  --history              Scan full git history (not just working tree)
  --format <fmt>         Output format: text, json, csv, sarif (default: text)
  --output <file>        Save results to file
  --config <file>        Custom gitleaks config (TOML)
  --baseline <file>      Create baseline file from current findings
  --use-baseline <file>  Compare against baseline (only show new findings)
  --since <date>         Only scan commits after date (YYYY-MM-DD)
  --hook <path>          Install pre-commit hook in repo
  -h, --help             Show this help

EXAMPLES:
  bash run.sh --scan .
  bash run.sh --scan . --history --format json --output report.json
  bash run.sh --scan-all ~/projects
  bash run.sh --hook .
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --scan) SCAN_PATH="$2"; shift 2 ;;
    --scan-all) SCAN_ALL_PATH="$2"; shift 2 ;;
    --history) HISTORY=true; shift ;;
    --format) FORMAT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    --baseline) BASELINE="$2"; shift 2 ;;
    --use-baseline) USE_BASELINE="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --hook) INSTALL_HOOK=true; HOOK_PATH="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Check gitleaks is installed
if ! command -v gitleaks &>/dev/null; then
  echo -e "${RED}❌ gitleaks not found.${NC}"
  echo "Run: bash $SCRIPT_DIR/install.sh"
  exit 1
fi

# Install pre-commit hook
if $INSTALL_HOOK; then
  if [ -z "$HOOK_PATH" ]; then
    echo -e "${RED}❌ Specify repo path: --hook /path/to/repo${NC}"
    exit 1
  fi

  HOOK_FILE="$HOOK_PATH/.git/hooks/pre-commit"
  if [ ! -d "$HOOK_PATH/.git" ]; then
    echo -e "${RED}❌ Not a git repository: $HOOK_PATH${NC}"
    exit 1
  fi

  cat > "$HOOK_FILE" <<'HOOKEOF'
#!/bin/bash
# Git Secret Scanner pre-commit hook
# Prevents committing secrets

echo "🔍 Scanning for secrets..."

if ! command -v gitleaks &>/dev/null; then
  echo "⚠️  gitleaks not installed — skipping secret scan"
  exit 0
fi

gitleaks protect --staged --no-banner -v 2>/dev/null
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "❌ SECRETS DETECTED — Commit blocked!"
  echo ""
  echo "To fix:"
  echo "  1. Remove the secret from your code"
  echo "  2. Use environment variables instead"
  echo "  3. Add to .gitleaks.toml allowlist if it's a false positive"
  echo ""
  echo "To bypass (NOT recommended):"
  echo "  git commit --no-verify"
  exit 1
fi

echo "✅ No secrets found"
HOOKEOF

  chmod +x "$HOOK_FILE"
  echo -e "${GREEN}✅ Pre-commit hook installed at $HOOK_FILE${NC}"
  echo "Future commits will be scanned for secrets automatically."
  exit 0
fi

# Scan all repos
if [ -n "$SCAN_ALL_PATH" ]; then
  if [ ! -d "$SCAN_ALL_PATH" ]; then
    echo -e "${RED}❌ Directory not found: $SCAN_ALL_PATH${NC}"
    exit 1
  fi

  echo -e "${BLUE}🔍 Scanning all repositories in $SCAN_ALL_PATH...${NC}"
  echo ""

  TOTAL=0
  CLEAN=0
  DIRTY=0
  TOTAL_SECRETS=0

  while IFS= read -r -d '' gitdir; do
    REPO_PATH=$(dirname "$gitdir")
    REPO_NAME=$(basename "$REPO_PATH")
    TOTAL=$((TOTAL + 1))

    # Build gitleaks command
    CMD="gitleaks detect --source $REPO_PATH --no-banner"
    if $HISTORY; then
      CMD="$CMD"
    else
      CMD="$CMD --no-git"
    fi
    CMD="$CMD --report-format json --report-path /tmp/gitleaks-scan-$$.json"

    if eval "$CMD" 2>/dev/null; then
      echo -e "  ${GREEN}✅ $REPO_NAME: Clean${NC}"
      CLEAN=$((CLEAN + 1))
    else
      COUNT=$(jq 'length' /tmp/gitleaks-scan-$$.json 2>/dev/null || echo "?")
      echo -e "  ${RED}❌ $REPO_NAME: $COUNT secrets found${NC}"
      DIRTY=$((DIRTY + 1))
      TOTAL_SECRETS=$((TOTAL_SECRETS + COUNT))
    fi
    rm -f /tmp/gitleaks-scan-$$.json
  done < <(find "$SCAN_ALL_PATH" -maxdepth 2 -name ".git" -type d -print0 2>/dev/null)

  echo ""
  echo -e "${BLUE}📊 Summary: $TOTAL_SECRETS secrets across $DIRTY of $TOTAL repos${NC}"
  exit $( [ $DIRTY -gt 0 ] && echo 1 || echo 0 )
fi

# Single repo scan
if [ -z "$SCAN_PATH" ]; then
  echo -e "${RED}❌ No scan target specified.${NC}"
  usage
fi

if [ ! -d "$SCAN_PATH" ]; then
  echo -e "${RED}❌ Directory not found: $SCAN_PATH${NC}"
  exit 1
fi

echo -e "${BLUE}🔍 Scanning $SCAN_PATH...${NC}"

# Build gitleaks command
GITLEAKS_CMD="gitleaks detect --source $SCAN_PATH --no-banner"

if ! $HISTORY; then
  GITLEAKS_CMD="$GITLEAKS_CMD --no-git"
fi

if [ -n "$CONFIG" ]; then
  GITLEAKS_CMD="$GITLEAKS_CMD --config $CONFIG"
fi

if [ -n "$SINCE" ]; then
  GITLEAKS_CMD="$GITLEAKS_CMD --log-opts='--since=$SINCE'"
fi

if [ -n "$USE_BASELINE" ]; then
  GITLEAKS_CMD="$GITLEAKS_CMD --baseline-path $USE_BASELINE"
fi

# Determine output format and path
REPORT_FILE="${OUTPUT:-/tmp/gitleaks-report-$$.json}"
case "$FORMAT" in
  json) GITLEAKS_CMD="$GITLEAKS_CMD --report-format json --report-path $REPORT_FILE" ;;
  csv) GITLEAKS_CMD="$GITLEAKS_CMD --report-format csv --report-path $REPORT_FILE" ;;
  sarif) GITLEAKS_CMD="$GITLEAKS_CMD --report-format sarif --report-path $REPORT_FILE" ;;
  text) GITLEAKS_CMD="$GITLEAKS_CMD --report-format json --report-path /tmp/gitleaks-report-$$.json" ;;
esac

# Run scan
set +e
eval "$GITLEAKS_CMD" 2>/dev/null
EXIT_CODE=$?
set -e

# Handle results
if [ $EXIT_CODE -eq 0 ]; then
  echo ""
  echo -e "${GREEN}✅ No secrets found!${NC}"
  
  if [ -n "$BASELINE" ]; then
    echo "[]" > "$BASELINE"
    echo -e "${BLUE}📋 Empty baseline created at $BASELINE${NC}"
  fi
  
  rm -f /tmp/gitleaks-report-$$.json
  exit 0
fi

# Secrets found
if [ "$FORMAT" = "text" ]; then
  REPORT="/tmp/gitleaks-report-$$.json"
  if [ -f "$REPORT" ]; then
    COUNT=$(jq 'length' "$REPORT")
    echo ""
    echo -e "${RED}❌ SECRETS FOUND: $COUNT${NC}"
    echo ""

    jq -r 'to_entries[] | "\u001b[1;31m[\(.key + 1)] \(.value.Description)\u001b[0m\n    File: \(.value.File):\(.value.StartLine)\n    Commit: \(.value.Commit[0:7]) (\(.value.Date[0:10]))\n    Match: \(.value.Secret[0:20])***\n    Rule: \(.value.RuleID)\n"' "$REPORT" 2>/dev/null || \
    jq -r '.[] | "[\(.RuleID)] \(.Description)\n  File: \(.File):\(.StartLine)\n  Match: \(.Secret[0:20])***\n"' "$REPORT"

    FILES=$(jq -r '[.[].File] | unique | length' "$REPORT")
    COMMITS=$(jq -r '[.[].Commit] | unique | length' "$REPORT")
    echo -e "${BLUE}📊 Summary: $COUNT secrets in $FILES files across $COMMITS commits${NC}"
    
    rm -f "$REPORT"
  fi
else
  COUNT=$(jq 'length' "$REPORT_FILE" 2>/dev/null || echo "?")
  echo ""
  echo -e "${RED}❌ SECRETS FOUND: $COUNT${NC}"
  echo -e "${BLUE}📄 Report saved to: $REPORT_FILE${NC}"
fi

# Create baseline if requested
if [ -n "$BASELINE" ]; then
  if [ "$FORMAT" = "text" ]; then
    cp /tmp/gitleaks-report-$$.json "$BASELINE" 2>/dev/null || true
  else
    cp "$REPORT_FILE" "$BASELINE" 2>/dev/null || true
  fi
  echo -e "${BLUE}📋 Baseline created at $BASELINE${NC}"
  echo "Use --use-baseline $BASELINE on future scans to only see new secrets."
fi

exit 1
