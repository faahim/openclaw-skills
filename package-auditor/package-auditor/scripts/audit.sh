#!/bin/bash
# Package Auditor — Scan installed packages for vulnerabilities, orphans, and updates
# Supports: apt (Debian/Ubuntu), dnf (RHEL/Fedora), brew (macOS)

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT_MIN_SEVERITY="${AUDIT_MIN_SEVERITY:-low}"
AUDIT_FORMAT="${AUDIT_FORMAT:-text}"
AUDIT_LOG_DIR="${AUDIT_LOG_DIR:-$SCRIPT_DIR/../logs}"
AUDIT_IGNORE="${AUDIT_IGNORE:-}"
IGNORE_FILE="${SCRIPT_DIR}/../config/ignore.txt"

# Parse arguments
MODE="full"
OUTPUT_FORMAT="$AUDIT_FORMAT"
STRICT=false
CLEAN=false
DRY_RUN=false
DIFF_FILE=""
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --vulns) MODE="vulns"; shift ;;
    --orphans) MODE="orphans"; shift ;;
    --outdated) MODE="outdated"; shift ;;
    --json) JSON_OUTPUT=true; OUTPUT_FORMAT="json"; shift ;;
    --format) OUTPUT_FORMAT="$2"; shift 2 ;;
    --strict) STRICT=true; shift ;;
    --clean) CLEAN=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --fix) MODE="fix"; shift ;;
    --diff) DIFF_FILE="$2"; shift 2 ;;
    --version) echo "package-auditor v$VERSION"; exit 0 ;;
    --help|-h) 
      echo "Usage: audit.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --vulns       Scan for vulnerabilities only"
      echo "  --orphans     Find orphaned packages only"
      echo "  --outdated    Check for updates only"
      echo "  --json        Output as JSON"
      echo "  --format FMT  Output format: text, json, markdown, csv"
      echo "  --strict      Exit code 1 if critical CVEs found"
      echo "  --clean       Auto-remove orphaned packages (with confirmation)"
      echo "  --dry-run     Preview actions without executing"
      echo "  --fix         Generate fix commands"
      echo "  --diff FILE   Compare with previous audit JSON"
      echo "  --version     Show version"
      echo "  --help        Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Detect package manager
detect_pm() {
  if command -v apt &>/dev/null; then
    echo "apt"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v brew &>/dev/null; then
    echo "brew"
  else
    echo "unknown"
  fi
}

PM=$(detect_pm)

# Load ignore patterns
load_ignores() {
  local patterns=()
  if [[ -n "$AUDIT_IGNORE" ]]; then
    IFS=',' read -ra patterns <<< "$AUDIT_IGNORE"
  fi
  if [[ -f "$IGNORE_FILE" ]]; then
    while IFS= read -r line; do
      [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
      patterns+=("$line")
    done < "$IGNORE_FILE"
  fi
  printf '%s\n' "${patterns[@]}" 2>/dev/null || true
}

IGNORE_PATTERNS=$(load_ignores)

is_ignored() {
  local pkg="$1"
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    if [[ "$pkg" == $pattern ]]; then
      return 0
    fi
  done <<< "$IGNORE_PATTERNS"
  return 1
}

# Count installed packages
count_packages() {
  case $PM in
    apt) dpkg --get-selections | grep -c 'install$' 2>/dev/null || echo 0 ;;
    dnf) rpm -qa 2>/dev/null | wc -l ;;
    brew) brew list --formula 2>/dev/null | wc -l ;;
    *) echo 0 ;;
  esac
}

# Vulnerability scan
scan_vulns() {
  local vulns_critical=0 vulns_high=0 vulns_medium=0 vulns_low=0
  local vuln_details=""

  case $PM in
    apt)
      if ! command -v debsecan &>/dev/null; then
        echo "⚠️  debsecan not installed. Run: sudo apt-get install -y debsecan"
        return 1
      fi
      
      local raw
      raw=$(debsecan --format detail 2>/dev/null || true)
      
      if [[ -z "$raw" ]]; then
        echo "✅ No known vulnerabilities found"
        return 0
      fi

      while IFS= read -r line; do
        local pkg cve severity
        # debsecan output: CVE-XXXX-YYYY package-name severity
        if [[ "$line" =~ ^(CVE-[0-9]+-[0-9]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(.*) ]]; then
          cve="${BASH_REMATCH[1]}"
          pkg="${BASH_REMATCH[2]}"
          severity="${BASH_REMATCH[3]}"
          
          is_ignored "$pkg" && continue
          
          case "$severity" in
            *urgently*|*high*) ((vulns_critical++)); vuln_details+="    CRITICAL: $pkg → $cve ($severity)\n" ;;
            *medium*) ((vulns_high++)); vuln_details+="    HIGH: $pkg → $cve ($severity)\n" ;;
            *low*|*unimportant*) ((vulns_low++)); vuln_details+="    LOW: $pkg → $cve ($severity)\n" ;;
            *) ((vulns_medium++)); vuln_details+="    MEDIUM: $pkg → $cve ($severity)\n" ;;
          esac
        fi
      done <<< "$(debsecan 2>/dev/null || true)"
      ;;
    dnf)
      local advisory_output
      advisory_output=$(dnf updateinfo list --security 2>/dev/null || true)
      if [[ -n "$advisory_output" ]]; then
        vulns_critical=$(echo "$advisory_output" | grep -ci "critical" || true)
        vulns_high=$(echo "$advisory_output" | grep -ci "important" || true)
        vulns_medium=$(echo "$advisory_output" | grep -ci "moderate" || true)
        vulns_low=$(echo "$advisory_output" | grep -ci "low" || true)
        vuln_details="$advisory_output"
      fi
      ;;
    brew)
      echo "ℹ️  Homebrew doesn't track CVEs directly. Run 'brew audit' for formula issues."
      return 0
      ;;
  esac

  local total=$((vulns_critical + vulns_high + vulns_medium + vulns_low))
  
  if [[ "$JSON_OUTPUT" == true ]]; then
    echo "{\"total\": $total, \"critical\": $vulns_critical, \"high\": $vulns_high, \"medium\": $vulns_medium, \"low\": $vulns_low}"
  else
    echo "🔴 VULNERABILITIES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Total: $total"
    echo "  Critical: $vulns_critical"
    echo "  High: $vulns_high"
    echo "  Medium: $vulns_medium"
    echo "  Low: $vulns_low"
    if [[ -n "$vuln_details" ]]; then
      echo ""
      echo -e "$vuln_details" | head -20
      if [[ $(echo -e "$vuln_details" | wc -l) -gt 20 ]]; then
        echo "    ... and more. Run with --json for full list."
      fi
    fi
  fi
  
  if [[ "$STRICT" == true && $vulns_critical -gt 0 ]]; then
    return 1
  fi
}

# Orphaned packages
scan_orphans() {
  case $PM in
    apt)
      local orphans
      orphans=$(apt list --installed 2>/dev/null | grep -i "automatic" | awk -F/ '{print $1}' || true)
      
      # Better: use deborphan if available, otherwise apt autoremove --dry-run
      local autoremove_list
      autoremove_list=$(apt-get autoremove --dry-run 2>/dev/null | grep "^Remv " | awk '{print $2}' || true)
      
      local count=0
      local total_size=0
      local details=""
      
      while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        is_ignored "$pkg" && continue
        ((count++))
        local size
        size=$(dpkg-query -W -f='${Installed-Size}' "$pkg" 2>/dev/null || echo 0)
        total_size=$((total_size + size))
        details+="    - $pkg ($((size / 1024)) MB)\n"
      done <<< "$autoremove_list"
      
      if [[ "$JSON_OUTPUT" == true ]]; then
        echo "{\"count\": $count, \"total_size_kb\": $total_size}"
      else
        echo "🗑️  ORPHANED PACKAGES"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "  $count orphaned packages found ($((total_size / 1024)) MB total)"
        if [[ -n "$details" ]]; then
          echo -e "$details" | head -10
        fi
        echo "  Run: sudo apt autoremove --purge"
      fi
      
      if [[ "$CLEAN" == true && $count -gt 0 ]]; then
        if [[ "$DRY_RUN" == true ]]; then
          echo ""
          echo "  [DRY RUN] Would remove $count packages"
        else
          echo ""
          read -p "  Remove $count orphaned packages? [y/N] " confirm
          if [[ "$confirm" =~ ^[Yy]$ ]]; then
            sudo apt-get autoremove --purge -y
            echo "  ✅ Removed $count orphaned packages"
          fi
        fi
      fi
      ;;
    dnf)
      local orphans
      orphans=$(dnf autoremove --assumeno 2>/dev/null | grep "Remove" | head -1 || echo "0 packages")
      echo "🗑️  ORPHANED PACKAGES"
      echo "━━━━━━━━━━━━━━━━━━━━"
      echo "  $orphans"
      echo "  Run: sudo dnf autoremove"
      ;;
    brew)
      local orphans
      orphans=$(brew autoremove --dry-run 2>/dev/null || echo "No orphaned formulae")
      echo "🗑️  ORPHANED PACKAGES"
      echo "━━━━━━━━━━━━━━━━━━━━"
      echo "  $orphans"
      echo "  Run: brew autoremove"
      ;;
  esac
}

# Outdated packages
scan_outdated() {
  case $PM in
    apt)
      local updates
      updates=$(apt list --upgradable 2>/dev/null | grep -v "Listing" || true)
      local count
      count=$(echo "$updates" | grep -c . 2>/dev/null || echo 0)
      
      local security_count=0
      if command -v apt-get &>/dev/null; then
        security_count=$(apt-get upgrade -s 2>/dev/null | grep -c "^Inst.*security" || true)
        security_count=${security_count:-0}
        [[ "$security_count" =~ ^[0-9]+$ ]] || security_count=0
      fi
      count=${count:-0}
      [[ "$count" =~ ^[0-9]+$ ]] || count=0
      
      local regular_count=$((count - security_count))
      [[ $regular_count -lt 0 ]] && regular_count=0
      
      if [[ "$JSON_OUTPUT" == true ]]; then
        echo "{\"total\": $count, \"security\": $security_count, \"regular\": $regular_count}"
      else
        echo "📥 AVAILABLE UPDATES"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "  $count packages have updates available"
        echo "    - Security updates: $security_count"
        echo "    - Regular updates: $regular_count"
        if [[ $count -gt 0 ]]; then
          echo ""
          echo "$updates" | head -10 | sed 's/^/    /'
          if [[ $count -gt 10 ]]; then
            echo "    ... and $((count - 10)) more"
          fi
        fi
        echo "  Run: sudo apt upgrade"
      fi
      ;;
    dnf)
      local count
      count=$(dnf check-update 2>/dev/null | grep -c . || echo 0)
      echo "📥 AVAILABLE UPDATES"
      echo "━━━━━━━━━━━━━━━━━━━━"
      echo "  $count packages have updates available"
      echo "  Run: sudo dnf update"
      ;;
    brew)
      local outdated
      outdated=$(brew outdated 2>/dev/null || true)
      local count
      count=$(echo "$outdated" | grep -c . 2>/dev/null || echo 0)
      echo "📥 AVAILABLE UPDATES"
      echo "━━━━━━━━━━━━━━━━━━━━"
      echo "  $count formulae are outdated"
      if [[ -n "$outdated" ]]; then
        echo "$outdated" | head -10 | sed 's/^/    /'
      fi
      echo "  Run: brew upgrade"
      ;;
  esac
}

# Risk score calculation
calc_risk() {
  local vulns_crit=${1:-0} vulns_high=${2:-0} vulns_med=${3:-0} orphans=${4:-0} outdated=${5:-0}
  local score=0
  
  # Critical CVEs: +3 each (max 10)
  score=$((score + (vulns_crit * 3 > 10 ? 10 : vulns_crit * 3)))
  # High CVEs: +1.5 each (max 5)
  score=$((score + (vulns_high > 3 ? 5 : vulns_high * 2)))
  # Medium CVEs: +0.5 each (max 2)  
  score=$((score + (vulns_med > 4 ? 2 : vulns_med / 2)))
  # Outdated with security fixes: +1
  [[ $outdated -gt 0 ]] && score=$((score + 1))
  
  # Cap at 10
  [[ $score -gt 10 ]] && score=10
  
  echo $score
}

# Generate fix commands
generate_fixes() {
  echo "🔧 RECOMMENDED FIXES"
  echo "━━━━━━━━━━━━━━━━━━━━"
  
  case $PM in
    apt)
      echo "  1. Fix critical vulnerabilities:"
      echo "     sudo apt-get update && sudo apt-get upgrade -y"
      echo ""
      echo "  2. Remove orphaned packages:"
      echo "     sudo apt-get autoremove --purge -y"
      echo ""
      echo "  3. Clean package cache:"
      echo "     sudo apt-get clean && sudo apt-get autoclean"
      echo ""
      echo "  4. Check for held-back packages:"
      echo "     apt-mark showhold"
      ;;
    dnf)
      echo "  1. Apply security updates:"
      echo "     sudo dnf update --security -y"
      echo ""
      echo "  2. Remove orphaned packages:"
      echo "     sudo dnf autoremove -y"
      echo ""
      echo "  3. Clean cache:"
      echo "     sudo dnf clean all"
      ;;
    brew)
      echo "  1. Update formulae:"
      echo "     brew update && brew upgrade"
      echo ""
      echo "  2. Remove orphaned dependencies:"
      echo "     brew autoremove"
      echo ""
      echo "  3. Clean cache:"
      echo "     brew cleanup -s"
      ;;
  esac
}

# Main execution
mkdir -p "$AUDIT_LOG_DIR" 2>/dev/null || true

TOTAL_PKGS=$(count_packages)
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

if [[ "$JSON_OUTPUT" != true ]]; then
  echo "╔══════════════════════════════════════════╗"
  echo "║         SYSTEM PACKAGE AUDIT             ║"
  echo "║         $TIMESTAMP          ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "📦 Package manager: $PM"
  echo "📦 Total installed packages: $TOTAL_PKGS"
  echo ""
fi

case $MODE in
  full)
    scan_vulns || true
    echo ""
    scan_orphans
    echo ""
    scan_outdated
    echo ""
    echo "📊 SUMMARY"
    echo "━━━━━━━━━━"
    echo "  Package manager: $PM"
    echo "  Packages scanned: $TOTAL_PKGS"
    echo "  Audit time: $TIMESTAMP"
    ;;
  vulns)
    scan_vulns
    ;;
  orphans)
    scan_orphans
    ;;
  outdated)
    scan_outdated
    ;;
  fix)
    scan_vulns || true
    echo ""
    scan_orphans
    echo ""
    scan_outdated
    echo ""
    generate_fixes
    ;;
esac

# Log the audit
if [[ -d "$AUDIT_LOG_DIR" ]]; then
  echo "$TIMESTAMP | $PM | $TOTAL_PKGS packages | mode=$MODE" >> "$AUDIT_LOG_DIR/audit.log" 2>/dev/null || true
fi
