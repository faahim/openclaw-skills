#!/bin/bash
# Coolify Installer — wraps the official install script with pre-checks
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✅]${NC} $*"; }
warn() { echo -e "${YELLOW}[⚠️]${NC} $*"; }
err()  { echo -e "${RED}[❌]${NC} $*"; exit 1; }

echo "╔══════════════════════════════════════╗"
echo "║     Coolify Manager — Installer      ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Pre-flight checks
echo "Running pre-flight checks..."

# 1. Root/sudo check
if [ "$EUID" -ne 0 ]; then
  err "Must run as root (sudo bash scripts/install.sh)"
fi

# 2. OS check
if [ -f /etc/os-release ]; then
  . /etc/os-release
  log "OS: $PRETTY_NAME"
else
  warn "Could not detect OS"
fi

# 3. Architecture check
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
  err "Unsupported architecture: $ARCH (need x86_64 or aarch64)"
fi
log "Architecture: $ARCH"

# 4. Memory check
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -lt 1800 ]; then
  err "Insufficient memory: ${TOTAL_MEM}MB (need 2GB+)"
fi
log "Memory: ${TOTAL_MEM}MB"

# 5. Disk check
AVAIL_DISK=$(df -BG / | awk 'NR==2{print $4}' | tr -d 'G')
if [ "$AVAIL_DISK" -lt 10 ]; then
  warn "Low disk space: ${AVAIL_DISK}GB available (recommend 20GB+)"
else
  log "Disk: ${AVAIL_DISK}GB available"
fi

# 6. Port check
for PORT in 8000 80 443; do
  if ss -tlnp | grep -q ":${PORT} "; then
    warn "Port $PORT is already in use — Coolify may conflict"
  fi
done

echo ""
echo "All pre-flight checks passed. Installing Coolify..."
echo ""

# Run official Coolify installer
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash

echo ""
log "Coolify installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Open http://$(hostname -I | awk '{print $1}'):8000 in your browser"
echo "  2. Create your admin account"
echo "  3. Go to Settings → API Tokens → Create Token"
echo "  4. Set environment variables:"
echo "     export COOLIFY_URL=\"http://localhost:8000\""
echo "     export COOLIFY_TOKEN=\"your-token-here\""
echo "  5. Run: bash scripts/manage.sh status"
