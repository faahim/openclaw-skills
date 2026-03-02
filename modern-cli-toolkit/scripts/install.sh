#!/bin/bash
# Modern CLI Toolkit — Install Script
# Installs modern replacements for core Unix commands
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# All available tools
ALL_TOOLS="eza bat fd-find ripgrep git-delta dust duf procs bottom zoxide sd-find tokei"

# Parse arguments
ONLY=""
SKIP=""
UPDATE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --only) ONLY="$2"; shift 2 ;;
    --skip) SKIP="$2"; shift 2 ;;
    --update) UPDATE=true; shift ;;
    --help|-h)
      echo "Usage: install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --only eza,bat,fd    Install only specified tools"
      echo "  --skip procs,btm     Skip specified tools"
      echo "  --update             Update existing tools to latest"
      echo "  --help               Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Detect OS and package manager
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
  elif [[ "$(uname)" == "Darwin" ]]; then
    OS="macos"
  else
    OS="unknown"
  fi
  
  if command -v brew &>/dev/null; then
    PKG="brew"
  elif command -v apt-get &>/dev/null; then
    PKG="apt"
  elif command -v dnf &>/dev/null; then
    PKG="dnf"
  elif command -v pacman &>/dev/null; then
    PKG="pacman"
  elif command -v cargo &>/dev/null; then
    PKG="cargo"
  else
    echo -e "${RED}No supported package manager found. Install brew or cargo.${NC}"
    exit 1
  fi
  
  echo -e "${BLUE}Detected: OS=$OS, Package Manager=$PKG${NC}"
}

# Check if tool should be installed
should_install() {
  local tool=$1
  
  if [[ -n "$ONLY" ]]; then
    echo "$ONLY" | tr ',' '\n' | grep -q "^${tool}$" && return 0 || return 1
  fi
  
  if [[ -n "$SKIP" ]]; then
    echo "$SKIP" | tr ',' '\n' | grep -q "^${tool}$" && return 1 || return 0
  fi
  
  return 0
}

# Check if already installed
is_installed() {
  command -v "$1" &>/dev/null
}

# Install counter
INSTALLED=0
SKIPPED=0
FAILED=0

install_tool() {
  local name=$1
  local cmd=$2
  local brew_pkg=$3
  local apt_pkg=${4:-""}
  local cargo_pkg=${5:-""}
  
  if ! should_install "$cmd" && ! should_install "$name"; then
    return
  fi
  
  if is_installed "$cmd" && ! $UPDATE; then
    echo -e "${YELLOW}⏭  $name ($cmd) already installed — use --update to upgrade${NC}"
    ((SKIPPED++)) || true
    return
  fi
  
  echo -e "${BLUE}📦 Installing $name...${NC}"
  
  case $PKG in
    brew)
      if brew install "$brew_pkg" 2>/dev/null; then
        echo -e "${GREEN}✅ $name installed${NC}"
        ((INSTALLED++)) || true
      else
        echo -e "${RED}❌ Failed to install $name${NC}"
        ((FAILED++)) || true
      fi
      ;;
    apt)
      if [[ -n "$apt_pkg" ]]; then
        if sudo apt-get install -y "$apt_pkg" 2>/dev/null; then
          echo -e "${GREEN}✅ $name installed${NC}"
          ((INSTALLED++)) || true
        elif [[ -n "$cargo_pkg" ]] && command -v cargo &>/dev/null; then
          echo -e "${YELLOW}apt failed, trying cargo...${NC}"
          cargo install "$cargo_pkg" 2>/dev/null && echo -e "${GREEN}✅ $name installed via cargo${NC}" && ((INSTALLED++)) || { echo -e "${RED}❌ Failed${NC}"; ((FAILED++)); }
        else
          echo -e "${RED}❌ Failed to install $name${NC}"
          ((FAILED++)) || true
        fi
      elif [[ -n "$cargo_pkg" ]] && command -v cargo &>/dev/null; then
        cargo install "$cargo_pkg" 2>/dev/null && echo -e "${GREEN}✅ $name installed via cargo${NC}" && ((INSTALLED++)) || { echo -e "${RED}❌ Failed${NC}"; ((FAILED++)); }
      fi
      ;;
    cargo)
      if [[ -n "$cargo_pkg" ]]; then
        cargo install "$cargo_pkg" 2>/dev/null && echo -e "${GREEN}✅ $name installed via cargo${NC}" && ((INSTALLED++)) || { echo -e "${RED}❌ Failed${NC}"; ((FAILED++)); }
      fi
      ;;
    *)
      echo -e "${YELLOW}⚠️  Manual install needed for $name on $PKG${NC}"
      ((SKIPPED++)) || true
      ;;
  esac
}

echo ""
echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Modern CLI Toolkit — Installer    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
echo ""

detect_os

# Update package index
if [[ "$PKG" == "apt" ]]; then
  echo -e "${BLUE}Updating package index...${NC}"
  sudo apt-get update -qq 2>/dev/null || true
fi

echo ""

#              Display Name    Command   Brew Package     APT Package         Cargo Package
install_tool  "eza"           "eza"     "eza"            "eza"               "eza"
install_tool  "bat"           "bat"     "bat"            "bat"               "bat"
install_tool  "fd"            "fd"      "fd"             "fd-find"           "fd-find"
install_tool  "ripgrep"       "rg"      "ripgrep"        "ripgrep"           "ripgrep"
install_tool  "delta"         "delta"   "git-delta"      ""                  "git-delta"
install_tool  "dust"          "dust"    "dust"           ""                  "du-dust"
install_tool  "duf"           "duf"     "duf"            "duf"               ""
install_tool  "procs"         "procs"   "procs"          ""                  "procs"
install_tool  "bottom"        "btm"     "bottom"         ""                  "bottom"
install_tool  "zoxide"        "zoxide"  "zoxide"         "zoxide"            "zoxide"
install_tool  "sd"            "sd"      "sd"             ""                  "sd"
install_tool  "tokei"         "tokei"   "tokei"          ""                  "tokei"

echo ""
echo -e "${GREEN}════════════════════════════════${NC}"
echo -e "${GREEN}  Installed: $INSTALLED${NC}"
echo -e "${YELLOW}  Skipped:   $SKIPPED${NC}"
if [[ $FAILED -gt 0 ]]; then
  echo -e "${RED}  Failed:    $FAILED${NC}"
fi
echo -e "${GREEN}════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Next step: Run 'bash scripts/configure.sh' to set up aliases${NC}"
