#!/bin/bash
# Redis Manager — Install Script
# Detects OS and installs Redis server + CLI

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}✅${NC} $1"; }
warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
err() { echo -e "${RED}❌${NC} $1" >&2; }

# Check if Redis is already installed
if command -v redis-server &>/dev/null; then
  CURRENT_VERSION=$(redis-server --version | grep -oP 'v=\K[0-9.]+')
  log "Redis already installed (v${CURRENT_VERSION})"
  echo ""
  read -p "Reinstall/upgrade? [y/N] " -n 1 -r
  echo
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi

# Detect OS
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
  elif [[ "$(uname)" == "Darwin" ]]; then
    OS="macos"
  else
    err "Unsupported OS"
    exit 1
  fi
}

detect_os

case "$OS" in
  ubuntu|debian|pop|linuxmint)
    log "Detected: $OS $VERSION"
    echo "Installing Redis via apt..."
    
    # Add Redis official repo for latest version
    if [[ ! -f /etc/apt/sources.list.d/redis.list ]]; then
      curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg 2>/dev/null
      echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list >/dev/null
    fi
    
    sudo apt-get update -qq
    sudo apt-get install -y redis-server redis-tools jq
    
    # Enable and start
    sudo systemctl enable redis-server
    sudo systemctl start redis-server
    ;;
    
  centos|rhel|fedora|rocky|alma)
    log "Detected: $OS $VERSION"
    echo "Installing Redis via dnf/yum..."
    
    if command -v dnf &>/dev/null; then
      sudo dnf install -y redis jq
    else
      sudo yum install -y epel-release
      sudo yum install -y redis jq
    fi
    
    sudo systemctl enable redis
    sudo systemctl start redis
    ;;
    
  macos)
    log "Detected: macOS"
    
    if ! command -v brew &>/dev/null; then
      err "Homebrew required. Install: https://brew.sh"
      exit 1
    fi
    
    brew install redis jq
    brew services start redis
    ;;
    
  arch|manjaro)
    log "Detected: $OS"
    sudo pacman -Sy --noconfirm redis jq
    sudo systemctl enable redis
    sudo systemctl start redis
    ;;
    
  alpine)
    log "Detected: Alpine Linux"
    sudo apk add redis jq
    sudo rc-update add redis
    sudo rc-service redis start
    ;;
    
  *)
    err "Unsupported OS: $OS"
    echo "Manual install: https://redis.io/docs/getting-started/installation/"
    exit 1
    ;;
esac

# Verify installation
echo ""
if redis-cli ping 2>/dev/null | grep -q PONG; then
  VERSION=$(redis-server --version | grep -oP 'v=\K[0-9.]+')
  log "Redis v${VERSION} installed and running!"
  log "Listening on port 6379"
  
  # Create config directory
  mkdir -p ~/.redis-manager
  log "Config directory: ~/.redis-manager"
else
  warn "Redis installed but may not be running. Check: systemctl status redis-server"
fi

# Install aws CLI if not present (for S3 backups)
if ! command -v aws &>/dev/null; then
  warn "AWS CLI not found — S3 backups won't work. Install: https://aws.amazon.com/cli/"
fi

echo ""
echo "Next steps:"
echo "  1. Check status:  bash scripts/redis-manager.sh status"
echo "  2. Harden:        bash scripts/redis-manager.sh harden --password \"\$(openssl rand -base64 32)\""
echo "  3. Monitor:       bash scripts/redis-manager.sh monitor --interval 30"
