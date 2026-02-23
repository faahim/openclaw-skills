#!/bin/bash
# Data Pipeline Tool — Installer
# Installs Miller (mlr), csvkit, and jq

set -e

CHECK_ONLY=false
if [[ "$1" == "--check" ]]; then
  CHECK_ONLY=true
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }

check_tool() {
  local name=$1
  local cmd=$2
  local version_flag=${3:---version}
  
  if command -v "$cmd" &>/dev/null; then
    local ver=$($cmd $version_flag 2>&1 | head -1)
    ok "$name installed: $ver"
    return 0
  else
    fail "$name not found"
    return 1
  fi
}

echo "🔍 Checking data pipeline dependencies..."
echo ""

MISSING=0

check_tool "Miller (mlr)" "mlr" "--version" || ((MISSING++))
check_tool "csvkit" "csvstat" "--version" || ((MISSING++))
check_tool "jq" "jq" "--version" || ((MISSING++))
check_tool "Python 3" "python3" "--version" || ((MISSING++))

echo ""

if [[ $MISSING -eq 0 ]]; then
  ok "All dependencies installed!"
  exit 0
fi

if [[ "$CHECK_ONLY" == "true" ]]; then
  warn "$MISSING tool(s) missing. Run without --check to install."
  exit 1
fi

echo "📦 Installing missing dependencies..."
echo ""

# Detect OS
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  OS=$ID
elif [[ "$(uname)" == "Darwin" ]]; then
  OS="macos"
else
  OS="unknown"
fi

install_miller() {
  if command -v mlr &>/dev/null; then return 0; fi
  
  echo "Installing Miller..."
  case $OS in
    ubuntu|debian|pop)
      sudo apt-get update -qq && sudo apt-get install -y -qq miller 2>/dev/null || {
        # Fallback: download binary
        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
          MLR_ARCH="amd64"
        elif [[ "$ARCH" == "aarch64" ]]; then
          MLR_ARCH="arm64"
        else
          fail "Unsupported architecture: $ARCH"
          return 1
        fi
        MLR_URL="https://github.com/johnkerl/miller/releases/latest/download/mlr-linux-${MLR_ARCH}"
        sudo curl -sL "$MLR_URL" -o /usr/local/bin/mlr && sudo chmod +x /usr/local/bin/mlr
      }
      ;;
    fedora|centos|rhel)
      sudo dnf install -y miller 2>/dev/null || sudo yum install -y miller
      ;;
    arch|manjaro)
      sudo pacman -S --noconfirm miller
      ;;
    macos)
      brew install miller
      ;;
    *)
      ARCH=$(uname -m)
      [[ "$ARCH" == "x86_64" ]] && MLR_ARCH="amd64" || MLR_ARCH="arm64"
      sudo curl -sL "https://github.com/johnkerl/miller/releases/latest/download/mlr-linux-${MLR_ARCH}" -o /usr/local/bin/mlr
      sudo chmod +x /usr/local/bin/mlr
      ;;
  esac
  ok "Miller installed"
}

install_csvkit() {
  if command -v csvstat &>/dev/null; then return 0; fi
  
  echo "Installing csvkit..."
  pip3 install --quiet csvkit 2>/dev/null || pip install --quiet csvkit
  ok "csvkit installed"
}

install_jq() {
  if command -v jq &>/dev/null; then return 0; fi
  
  echo "Installing jq..."
  case $OS in
    ubuntu|debian|pop) sudo apt-get update -qq && sudo apt-get install -y -qq jq ;;
    fedora|centos|rhel) sudo dnf install -y jq 2>/dev/null || sudo yum install -y jq ;;
    arch|manjaro) sudo pacman -S --noconfirm jq ;;
    macos) brew install jq ;;
    *) sudo apt-get install -y jq 2>/dev/null || sudo yum install -y jq ;;
  esac
  ok "jq installed"
}

install_miller
install_csvkit
install_jq

echo ""
echo "🔍 Final verification..."
echo ""
check_tool "Miller (mlr)" "mlr" "--version"
check_tool "csvkit" "csvstat" "--version"
check_tool "jq" "jq" "--version"

echo ""
ok "Data Pipeline Tool ready! Try: mlr --csv head -n 5 your_data.csv"
