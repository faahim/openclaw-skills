#!/bin/bash
# Modern CLI Toolkit — Verify Installation
set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TOTAL=0
FOUND=0

check() {
  local name=$1
  local cmd=$2
  local desc=$3
  ((TOTAL++)) || true
  
  if command -v "$cmd" &>/dev/null; then
    local ver=$($cmd --version 2>/dev/null | head -1 || echo "installed")
    echo -e "${GREEN}✅ $name ($desc) — $ver${NC}"
    ((FOUND++)) || true
  else
    echo -e "${RED}❌ $name ($desc) — not installed${NC}"
  fi
}

echo ""
echo "Modern CLI Toolkit — Installation Status"
echo "========================================="
echo ""

check "eza"      "eza"    "ls replacement"
check "bat"      "bat"    "cat replacement"
check "fd"       "fd"     "find replacement"
check "ripgrep"  "rg"     "grep replacement"
check "delta"    "delta"  "diff replacement"
check "dust"     "dust"   "du replacement"
check "duf"      "duf"    "df replacement"
check "procs"    "procs"  "ps replacement"
check "bottom"   "btm"    "top replacement"
check "zoxide"   "zoxide" "cd replacement"
check "sd"       "sd"     "sed replacement"
check "tokei"    "tokei"  "code line counter"

echo ""
echo "========================================="
echo "$FOUND / $TOTAL tools installed"
echo "========================================="
