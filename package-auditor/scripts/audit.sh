#!/bin/bash
# Package Auditor — Unified package manager security & freshness scanner
# Scans: apt, brew, npm, pip, cargo
# Output: text (default), json

set -euo pipefail

# ─── Defaults ───
OUTPUT_FORMAT="text"
SECURITY_ONLY=false
FIX_SCRIPT=false
ONLY_MANAGER=""
PROJECT_DIR=""
TIMEOUT=120
FAIL_ON=""
ALERT_TYPE=""
IGNORE_FILE="$(dirname "$0")/../.audit-ignore"
AUDIT_IGNORE="${AUDIT_IGNORE:-}"
AUDIT_MIN_SEVERITY="${AUDIT_MIN_SEVERITY:-low}"

# ─── Colors ───
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Parse args ───
while [[ $# -gt 0 ]]; do
  case $1 in
    --output) OUTPUT_FORMAT="$2"; shift 2 ;;
    --security-only) SECURITY_ONLY=true; shift ;;
    --fix-script) FIX_SCRIPT=true; shift ;;
    --only) ONLY_MANAGER="$2"; shift 2 ;;
    --project) PROJECT_DIR="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --fail-on) FAIL_ON="$2"; shift ;;
    --alert) ALERT_TYPE="$2"; shift 2 ;;
    -h|--help) echo "Usage: audit.sh [--output text|json] [--security-only] [--fix-script] [--only apt|brew|npm|pip|cargo] [--project DIR] [--timeout SECS] [--fail-on low|medium|high|critical] [--alert telegram]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Ignore list ───
IGNORE_PATTERNS=()
if [[ -f "$IGNORE_FILE" ]]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    IGNORE_PATTERNS+=("$line")
  done < "$IGNORE_FILE"
fi
IFS=',' read -ra EXTRA_IGNORE <<< "$AUDIT_IGNORE"
IGNORE_PATTERNS+=("${EXTRA_IGNORE[@]}")

should_ignore() {
  local pkg="$1"
  for pattern in "${IGNORE_PATTERNS[@]}"; do
    [[ -z "$pattern" ]] && continue
    if [[ "$pkg" == $pattern ]]; then
      return 0
    fi
  done
  return 1
}

# ─── JSON accumulator ───
JSON_RESULTS='{}'
TOTAL_OUTDATED=0
TOTAL_VULNERABLE=0
MANAGERS_SCANNED=0
FIX_COMMANDS=()

# ─── Manager: APT ───
audit_apt() {
  if ! command -v apt &>/dev/null && ! command -v apt-get &>/dev/null; then
    return
  fi
  MANAGERS_SCANNED=$((MANAGERS_SCANNED + 1))

  local installed outdated security_updates
  installed=$(dpkg -l 2>/dev/null | grep -c '^ii' || echo 0)

  # Get outdated
  timeout "$TIMEOUT" apt list --upgradable 2>/dev/null | tail -n +2 > /tmp/apt-outdated.tmp || true
  outdated=$(wc -l < /tmp/apt-outdated.tmp)

  # Check security updates
  security_updates=0
  local sec_pkgs=""
  if command -v apt-get &>/dev/null; then
    # Check for security pocket updates
    grep -i security /tmp/apt-outdated.tmp > /tmp/apt-security.tmp 2>/dev/null || true
    security_updates=$(wc -l < /tmp/apt-security.tmp)
    sec_pkgs=$(cat /tmp/apt-security.tmp 2>/dev/null || true)
  fi

  TOTAL_OUTDATED=$((TOTAL_OUTDATED + outdated))
  TOTAL_VULNERABLE=$((TOTAL_VULNERABLE + security_updates))

  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    local pkgs_json="[]"
    if [[ $outdated -gt 0 ]]; then
      pkgs_json=$(cat /tmp/apt-outdated.tmp | while IFS= read -r line; do
        local name=$(echo "$line" | cut -d'/' -f1)
        should_ignore "$name" && continue
        local new_ver=$(echo "$line" | awk '{print $2}')
        local cur_ver=$(echo "$line" | grep -oP 'upgradable from: \K[^\]]+' || echo "unknown")
        local is_sec="false"
        echo "$sec_pkgs" | grep -q "$name" && is_sec="true"
        printf '{"name":"%s","current":"%s","available":"%s","security":%s}' "$name" "$cur_ver" "$new_ver" "$is_sec"
      done | jq -s '.' 2>/dev/null || echo "[]")
    fi
    JSON_RESULTS=$(echo "$JSON_RESULTS" | jq --argjson pkgs "$pkgs_json" --arg inst "$installed" --arg out "$outdated" --arg sec "$security_updates" \
      '.apt = {"installed": ($inst|tonumber), "outdated": ($out|tonumber), "security_updates": ($sec|tonumber), "packages": $pkgs}')
  else
    echo -e "\n${BLUE}📦 APT (Debian/Ubuntu)${NC}"
    echo "  Installed: $installed packages"
    echo "  Outdated:  $outdated packages"
    echo "  Security:  $security_updates packages with pending security updates"
    if [[ $security_updates -gt 0 ]]; then
      echo "$sec_pkgs" | head -10 | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local name=$(echo "$line" | cut -d'/' -f1)
        echo -e "  ├── ${RED}$name${NC}"
      done
    fi
    if [[ "$SECURITY_ONLY" == "false" && $outdated -gt 0 ]]; then
      cat /tmp/apt-outdated.tmp | head -5 | while IFS= read -r line; do
        local name=$(echo "$line" | cut -d'/' -f1)
        should_ignore "$name" && continue
        echo "  ├── $name"
      done
      [[ $outdated -gt 5 ]] && echo "  └── ... and $((outdated - 5)) more"
    fi
  fi

  if [[ "$FIX_SCRIPT" == "true" && $outdated -gt 0 ]]; then
    FIX_COMMANDS+=("# APT updates")
    FIX_COMMANDS+=("sudo apt-get update && sudo apt-get upgrade -y")
  fi

  rm -f /tmp/apt-outdated.tmp /tmp/apt-security.tmp
}

# ─── Manager: BREW ───
audit_brew() {
  if ! command -v brew &>/dev/null; then
    return
  fi
  MANAGERS_SCANNED=$((MANAGERS_SCANNED + 1))

  local installed outdated
  installed=$(brew list --formula 2>/dev/null | wc -l)

  timeout "$TIMEOUT" brew outdated --json=v2 2>/dev/null > /tmp/brew-outdated.json || echo '{"formulae":[]}' > /tmp/brew-outdated.json
  outdated=$(jq '.formulae | length' /tmp/brew-outdated.json 2>/dev/null || echo 0)

  TOTAL_OUTDATED=$((TOTAL_OUTDATED + outdated))

  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    local pkgs_json
    pkgs_json=$(jq '[.formulae[] | {name: .name, current: .installed_versions[0], available: .current_version}]' /tmp/brew-outdated.json 2>/dev/null || echo "[]")
    JSON_RESULTS=$(echo "$JSON_RESULTS" | jq --argjson pkgs "$pkgs_json" --arg inst "$installed" --arg out "$outdated" \
      '.brew = {"installed": ($inst|tonumber), "outdated": ($out|tonumber), "packages": $pkgs}')
  else
    echo -e "\n${BLUE}🍺 HOMEBREW${NC}"
    echo "  Installed: $installed packages"
    echo "  Outdated:  $outdated packages"
    if [[ $outdated -gt 0 ]]; then
      jq -r '.formulae[:5][] | "  ├── \(.name)  \(.installed_versions[0]) → \(.current_version)"' /tmp/brew-outdated.json 2>/dev/null || true
      [[ $outdated -gt 5 ]] && echo "  └── ... and $((outdated - 5)) more"
    fi
  fi

  if [[ "$FIX_SCRIPT" == "true" && $outdated -gt 0 ]]; then
    FIX_COMMANDS+=("# Homebrew updates")
    FIX_COMMANDS+=("brew upgrade")
  fi

  rm -f /tmp/brew-outdated.json
}

# ─── Manager: NPM ───
audit_npm() {
  if ! command -v npm &>/dev/null; then
    return
  fi
  MANAGERS_SCANNED=$((MANAGERS_SCANNED + 1))

  local installed=0 outdated=0 vulnerable=0

  # Global packages
  installed=$(npm list -g --depth=0 2>/dev/null | grep -c '├\|└' || echo 0)

  timeout "$TIMEOUT" npm outdated -g --json 2>/dev/null > /tmp/npm-outdated.json || echo '{}' > /tmp/npm-outdated.json
  outdated=$(jq 'keys | length' /tmp/npm-outdated.json 2>/dev/null || echo 0)

  # Vulnerability check
  if [[ -n "$PROJECT_DIR" && -f "$PROJECT_DIR/package.json" ]]; then
    timeout "$TIMEOUT" npm audit --json --prefix "$PROJECT_DIR" 2>/dev/null > /tmp/npm-audit.json || echo '{}' > /tmp/npm-audit.json
    vulnerable=$(jq '.metadata.vulnerabilities // {} | to_entries | map(.value) | add // 0' /tmp/npm-audit.json 2>/dev/null || echo 0)
  fi

  TOTAL_OUTDATED=$((TOTAL_OUTDATED + outdated))
  TOTAL_VULNERABLE=$((TOTAL_VULNERABLE + vulnerable))

  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    local pkgs_json
    pkgs_json=$(jq '[to_entries[] | {name: .key, current: .value.current, available: .value.latest}]' /tmp/npm-outdated.json 2>/dev/null || echo "[]")
    JSON_RESULTS=$(echo "$JSON_RESULTS" | jq --argjson pkgs "$pkgs_json" --arg inst "$installed" --arg out "$outdated" --arg vuln "$vulnerable" \
      '.npm = {"installed": ($inst|tonumber), "outdated": ($out|tonumber), "vulnerable": ($vuln|tonumber), "packages": $pkgs}')
  else
    echo -e "\n${BLUE}📦 NPM (Global)${NC}"
    echo "  Installed: $installed packages"
    echo "  Outdated:  $outdated packages"
    [[ $vulnerable -gt 0 ]] && echo -e "  ${RED}Vulnerable: $vulnerable packages${NC}"
    if [[ $outdated -gt 0 ]]; then
      jq -r 'to_entries[:5][] | "  ├── \(.key)  \(.value.current) → \(.value.latest)"' /tmp/npm-outdated.json 2>/dev/null || true
      [[ $outdated -gt 5 ]] && echo "  └── ... and $((outdated - 5)) more"
    fi
  fi

  if [[ "$FIX_SCRIPT" == "true" && $outdated -gt 0 ]]; then
    FIX_COMMANDS+=("# NPM global updates")
    FIX_COMMANDS+=("npm update -g")
  fi

  rm -f /tmp/npm-outdated.json /tmp/npm-audit.json
}

# ─── Manager: PIP ───
audit_pip() {
  local pip_cmd=""
  if command -v pip3 &>/dev/null; then
    pip_cmd="pip3"
  elif command -v pip &>/dev/null; then
    pip_cmd="pip"
  else
    return
  fi
  MANAGERS_SCANNED=$((MANAGERS_SCANNED + 1))

  local installed outdated
  installed=$($pip_cmd list 2>/dev/null | tail -n +3 | wc -l)

  timeout "$TIMEOUT" $pip_cmd list --outdated --format=json 2>/dev/null > /tmp/pip-outdated.json || echo '[]' > /tmp/pip-outdated.json
  outdated=$(jq 'length' /tmp/pip-outdated.json 2>/dev/null || echo 0)

  TOTAL_OUTDATED=$((TOTAL_OUTDATED + outdated))

  # Check for pip-audit (vulnerability scanner)
  local vulnerable=0
  if command -v pip-audit &>/dev/null; then
    timeout "$TIMEOUT" pip-audit --format=json 2>/dev/null > /tmp/pip-audit.json || echo '[]' > /tmp/pip-audit.json
    vulnerable=$(jq 'length' /tmp/pip-audit.json 2>/dev/null || echo 0)
    TOTAL_VULNERABLE=$((TOTAL_VULNERABLE + vulnerable))
    rm -f /tmp/pip-audit.json
  fi

  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    local pkgs_json
    pkgs_json=$(jq '[.[] | {name: .name, current: .version, available: .latest_version}]' /tmp/pip-outdated.json 2>/dev/null || echo "[]")
    JSON_RESULTS=$(echo "$JSON_RESULTS" | jq --argjson pkgs "$pkgs_json" --arg inst "$installed" --arg out "$outdated" --arg vuln "$vulnerable" \
      '.pip = {"installed": ($inst|tonumber), "outdated": ($out|tonumber), "vulnerable": ($vuln|tonumber), "packages": $pkgs}')
  else
    echo -e "\n${BLUE}🐍 PIP${NC}"
    echo "  Installed: $installed packages"
    echo "  Outdated:  $outdated packages"
    [[ $vulnerable -gt 0 ]] && echo -e "  ${RED}Vulnerable: $vulnerable packages${NC}"
    if [[ "$SECURITY_ONLY" == "false" && $outdated -gt 0 ]]; then
      jq -r '.[:5][] | "  ├── \(.name)  \(.version) → \(.latest_version)"' /tmp/pip-outdated.json 2>/dev/null || true
      [[ $outdated -gt 5 ]] && echo "  └── ... and $((outdated - 5)) more"
    fi
  fi

  if [[ "$FIX_SCRIPT" == "true" && $outdated -gt 0 ]]; then
    FIX_COMMANDS+=("# PIP updates")
    local update_list
    update_list=$(jq -r '.[].name' /tmp/pip-outdated.json 2>/dev/null | tr '\n' ' ')
    FIX_COMMANDS+=("$pip_cmd install --upgrade $update_list")
  fi

  rm -f /tmp/pip-outdated.json
}

# ─── Manager: CARGO ───
audit_cargo() {
  if ! command -v cargo &>/dev/null; then
    return
  fi
  MANAGERS_SCANNED=$((MANAGERS_SCANNED + 1))

  local installed outdated=0
  installed=$(cargo install --list 2>/dev/null | grep -c ':$' || echo 0)

  # cargo-outdated check
  if command -v cargo-outdated &>/dev/null || cargo install --list 2>/dev/null | grep -q 'cargo-outdated'; then
    timeout "$TIMEOUT" cargo outdated --root-deps-only 2>/dev/null > /tmp/cargo-outdated.txt || true
    outdated=$(tail -n +3 /tmp/cargo-outdated.txt 2>/dev/null | grep -v '^$' | wc -l || echo 0)
  fi

  # cargo-audit check
  local vulnerable=0
  if command -v cargo-audit &>/dev/null; then
    timeout "$TIMEOUT" cargo audit --json 2>/dev/null > /tmp/cargo-audit.json || true
    vulnerable=$(jq '.vulnerabilities.count // 0' /tmp/cargo-audit.json 2>/dev/null || echo 0)
    TOTAL_VULNERABLE=$((TOTAL_VULNERABLE + vulnerable))
    rm -f /tmp/cargo-audit.json
  fi

  TOTAL_OUTDATED=$((TOTAL_OUTDATED + outdated))

  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    JSON_RESULTS=$(echo "$JSON_RESULTS" | jq --arg inst "$installed" --arg out "$outdated" --arg vuln "$vulnerable" \
      '.cargo = {"installed": ($inst|tonumber), "outdated": ($out|tonumber), "vulnerable": ($vuln|tonumber)}')
  else
    echo -e "\n${BLUE}🦀 CARGO${NC}"
    echo "  Installed: $installed packages"
    echo "  Outdated:  $outdated packages"
    [[ $vulnerable -gt 0 ]] && echo -e "  ${RED}Vulnerable: $vulnerable packages${NC}"
  fi

  rm -f /tmp/cargo-outdated.txt
}

# ─── Main ───

if [[ "$OUTPUT_FORMAT" == "text" && "$FIX_SCRIPT" == "false" ]]; then
  echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║           PACKAGE AUDIT REPORT                   ║${NC}"
  echo -e "${BOLD}║           $(date -u '+%Y-%m-%d %H:%M') UTC                   ║${NC}"
  echo -e "${BOLD}╠══════════════════════════════════════════════════╣${NC}"
fi

# Run selected or all managers
if [[ -n "$ONLY_MANAGER" ]]; then
  "audit_$ONLY_MANAGER"
else
  audit_apt
  audit_brew
  audit_npm
  audit_pip
  audit_cargo
fi

# ─── Summary ───
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  JSON_RESULTS=$(echo "$JSON_RESULTS" | jq \
    --arg total_out "$TOTAL_OUTDATED" \
    --arg total_vuln "$TOTAL_VULNERABLE" \
    --arg managers "$MANAGERS_SCANNED" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '. + {summary: {total_outdated: ($total_out|tonumber), total_vulnerable: ($total_vuln|tonumber), managers_scanned: ($managers|tonumber), timestamp: $ts}}')
  echo "$JSON_RESULTS" | jq .
elif [[ "$FIX_SCRIPT" == "true" ]]; then
  echo "#!/bin/bash"
  echo "# Auto-generated fix script — $(date -u '+%Y-%m-%d %H:%M UTC')"
  echo "# Review before running!"
  echo "set -e"
  echo ""
  for cmd in "${FIX_COMMANDS[@]}"; do
    echo "$cmd"
  done
else
  echo ""
  echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
  if [[ $TOTAL_VULNERABLE -gt 0 ]]; then
    echo -e "${RED}SUMMARY: $TOTAL_OUTDATED outdated | $TOTAL_VULNERABLE vulnerable | $MANAGERS_SCANNED managers scanned${NC}"
  else
    echo -e "${GREEN}SUMMARY: $TOTAL_OUTDATED outdated | $TOTAL_VULNERABLE vulnerable | $MANAGERS_SCANNED managers scanned${NC}"
  fi
  echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
fi

# ─── Telegram alert (only if vulnerabilities found) ───
if [[ "$ALERT_TYPE" == "telegram" && $TOTAL_VULNERABLE -gt 0 ]]; then
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    MSG="🚨 Package Audit Alert%0A%0A$TOTAL_OUTDATED outdated | $TOTAL_VULNERABLE vulnerable%0AManagers scanned: $MANAGERS_SCANNED%0ATime: $(date -u '+%Y-%m-%d %H:%M UTC')"
    curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage?chat_id=${TELEGRAM_CHAT_ID}&text=${MSG}" > /dev/null 2>&1 || true
  fi
fi

# ─── Exit code for CI/CD ───
if [[ -n "$FAIL_ON" ]]; then
  if [[ $TOTAL_VULNERABLE -gt 0 ]]; then
    exit 1
  fi
fi

exit 0
