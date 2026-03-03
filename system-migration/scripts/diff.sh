#!/bin/bash
# System Migration Tool — Diff Script
# Compares current system against a migration bundle

set -euo pipefail

BUNDLE=""
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

while [[ $# -gt 0 ]]; do
  case $1 in
    --bundle|-b) BUNDLE="$2"; shift 2 ;;
    *) echo "Usage: bash $0 --bundle <path.tar.gz>"; exit 1 ;;
  esac
done

[[ -z "$BUNDLE" ]] && { echo "Usage: bash $0 --bundle <path.tar.gz>"; exit 1; }
[[ ! -f "$BUNDLE" ]] && { echo "Bundle not found: $BUNDLE"; exit 1; }

WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT
tar xzf "$BUNDLE" -C "$WORK_DIR"
MIG="$WORK_DIR/migration"

echo -e "${CYAN}[diff]${NC} Comparing current system to bundle..."
echo ""

# Packages
if [[ -f "$MIG/packages.txt" ]]; then
  PKG_FILE="$MIG/packages.txt"
  [[ -f "$MIG/packages-manual.txt" ]] && PKG_FILE="$MIG/packages-manual.txt"

  if command -v dpkg-query &>/dev/null; then
    CURRENT=$(dpkg-query -W -f='${binary:Package}\n' 2>/dev/null | sort)
  elif command -v rpm &>/dev/null; then
    CURRENT=$(rpm -qa --qf '%{NAME}\n' 2>/dev/null | sort)
  else
    CURRENT=""
  fi

  IN_BUNDLE=$(comm -23 <(sort "$PKG_FILE") <(echo "$CURRENT") 2>/dev/null)
  NOT_IN_BUNDLE=$(comm -13 <(sort "$PKG_FILE") <(echo "$CURRENT") 2>/dev/null)
  BUNDLE_COUNT=$(echo "$IN_BUNDLE" | grep -c . || echo 0)
  LOCAL_COUNT=$(echo "$NOT_IN_BUNDLE" | grep -c . || echo 0)

  echo -e "${CYAN}[diff] Packages:${NC}"
  [[ $BUNDLE_COUNT -gt 0 ]] && echo -e "  ${GREEN}+ $BUNDLE_COUNT packages in bundle but not installed${NC}"
  [[ $LOCAL_COUNT -gt 0 ]] && echo -e "  ${RED}- $LOCAL_COUNT packages installed but not in bundle${NC}"
  [[ $BUNDLE_COUNT -eq 0 && $LOCAL_COUNT -eq 0 ]] && echo "  ✅ Package lists match"
  echo ""
fi

# Services
if [[ -f "$MIG/services/enabled.txt" ]]; then
  CURRENT_SVC=$(systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend 2>/dev/null | awk '{print $1}' | sort)
  BUNDLE_SVC=$(sort "$MIG/services/enabled.txt")
  MISSING_SVC=$(comm -23 <(echo "$BUNDLE_SVC") <(echo "$CURRENT_SVC") 2>/dev/null)
  EXTRA_SVC=$(comm -13 <(echo "$BUNDLE_SVC") <(echo "$CURRENT_SVC") 2>/dev/null)
  MISS_COUNT=$(echo "$MISSING_SVC" | grep -c . || echo 0)
  EXTRA_COUNT=$(echo "$EXTRA_SVC" | grep -c . || echo 0)

  echo -e "${CYAN}[diff] Services:${NC}"
  [[ $MISS_COUNT -gt 0 ]] && echo -e "  ${GREEN}+ $MISS_COUNT services enabled in bundle but not here${NC}" && echo "$MISSING_SVC" | head -5 | sed 's/^/    /'
  [[ $EXTRA_COUNT -gt 0 ]] && echo -e "  ${RED}- $EXTRA_COUNT services enabled here but not in bundle${NC}" && echo "$EXTRA_SVC" | head -5 | sed 's/^/    /'
  [[ $MISS_COUNT -eq 0 && $EXTRA_COUNT -eq 0 ]] && echo "  ✅ Service states match"
  echo ""
fi

# Crontabs
if [[ -d "$MIG/crontabs" ]]; then
  echo -e "${CYAN}[diff] Crontabs:${NC}"
  for cron_file in "$MIG/crontabs"/user-*.cron; do
    [[ ! -f "$cron_file" ]] && continue
    USERNAME=$(basename "$cron_file" | sed 's/^user-//;s/\.cron$//')
    CURRENT_CRON=$(crontab -l -u "$USERNAME" 2>/dev/null || echo "")
    BUNDLE_CRON=$(cat "$cron_file")
    if [[ "$CURRENT_CRON" != "$BUNDLE_CRON" ]]; then
      if [[ -z "$CURRENT_CRON" ]]; then
        echo -e "  ${GREEN}+ crontab for $USERNAME (in bundle, not present)${NC}"
      else
        DIFF_LINES=$(diff <(echo "$CURRENT_CRON") <(echo "$BUNDLE_CRON") | grep -c '^[<>]' || echo 0)
        echo -e "  ${YELLOW}~ crontab for $USERNAME differs ($DIFF_LINES lines)${NC}"
      fi
    fi
  done
  echo ""
fi

# Sysctl
if [[ -f "$MIG/sysctl/sysctl.conf" ]]; then
  echo -e "${CYAN}[diff] Sysctl:${NC}"
  if [[ -f /etc/sysctl.conf ]]; then
    DIFF_COUNT=$(diff "$MIG/sysctl/sysctl.conf" /etc/sysctl.conf 2>/dev/null | grep -c '^[<>]' || echo 0)
    if [[ $DIFF_COUNT -gt 0 ]]; then
      echo -e "  ${YELLOW}~ $DIFF_COUNT lines differ in sysctl.conf${NC}"
    else
      echo "  ✅ sysctl.conf matches"
    fi
  else
    echo -e "  ${GREEN}+ sysctl.conf in bundle but not present${NC}"
  fi
  echo ""
fi

echo -e "${CYAN}[diff]${NC} Comparison complete."
