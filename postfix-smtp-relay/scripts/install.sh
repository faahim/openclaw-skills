#!/bin/bash
# Postfix SMTP Relay — Install Script
# Installs postfix, SASL modules, and mail utilities non-interactively

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}✅${NC} $1"; }
warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
error() { echo -e "${RED}❌${NC} $1"; exit 1; }

# Check root/sudo
if [[ $EUID -ne 0 ]]; then
    if command -v sudo &>/dev/null; then
        SUDO="sudo"
    else
        error "This script must be run as root or with sudo"
    fi
else
    SUDO=""
fi

echo "📧 Installing Postfix SMTP Relay..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Detect package manager
if command -v apt-get &>/dev/null; then
    PKG_MGR="apt"
elif command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
elif command -v yum &>/dev/null; then
    PKG_MGR="yum"
else
    error "Unsupported package manager. Need apt, dnf, or yum."
fi

# Pre-configure postfix to avoid interactive prompts
if [[ "$PKG_MGR" == "apt" ]]; then
    echo "postfix postfix/mailname string $(hostname -f 2>/dev/null || hostname)" | $SUDO debconf-set-selections
    echo "postfix postfix/main_mailer_type string 'Satellite system'" | $SUDO debconf-set-selections
    
    $SUDO apt-get update -qq
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq postfix libsasl2-modules mailutils ca-certificates 2>/dev/null
    info "Installed: postfix, libsasl2-modules, mailutils"
    
elif [[ "$PKG_MGR" == "dnf" ]] || [[ "$PKG_MGR" == "yum" ]]; then
    $SUDO $PKG_MGR install -y -q postfix cyrus-sasl-plain cyrus-sasl-md5 mailx ca-certificates 2>/dev/null
    info "Installed: postfix, cyrus-sasl, mailx"
fi

# Enable and start postfix
$SUDO systemctl enable postfix 2>/dev/null || true
$SUDO systemctl start postfix 2>/dev/null || true

# Verify installation
if command -v postfix &>/dev/null; then
    POSTFIX_VER=$(postconf -d mail_version 2>/dev/null | awk '{print $3}')
    info "Postfix ${POSTFIX_VER} installed and running"
else
    error "Postfix installation failed"
fi

echo ""
echo "Next: Run 'bash scripts/configure.sh --provider gmail --user ... --password ...' to set up relay"
