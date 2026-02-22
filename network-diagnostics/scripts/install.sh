#!/bin/bash
# Network Diagnostics Toolkit — Dependency Installer
set -e

echo "=== Network Diagnostics Toolkit — Installing Dependencies ==="
echo ""

# Detect package manager
if command -v apt-get &>/dev/null; then
    PKG_MGR="apt"
    INSTALL="sudo apt-get install -y"
    UPDATE="sudo apt-get update -qq"
elif command -v yum &>/dev/null; then
    PKG_MGR="yum"
    INSTALL="sudo yum install -y"
    UPDATE=""
elif command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
    INSTALL="sudo dnf install -y"
    UPDATE=""
elif command -v brew &>/dev/null; then
    PKG_MGR="brew"
    INSTALL="brew install"
    UPDATE="brew update"
elif command -v pacman &>/dev/null; then
    PKG_MGR="pacman"
    INSTALL="sudo pacman -S --noconfirm"
    UPDATE="sudo pacman -Sy"
else
    echo "❌ No supported package manager found (apt, yum, dnf, brew, pacman)"
    echo "   Install manually: nmap, dig, mtr, curl, openssl, whois, netcat, traceroute"
    exit 1
fi

echo "Detected package manager: $PKG_MGR"

# Update package list
if [ -n "$UPDATE" ]; then
    echo "Updating package list..."
    $UPDATE 2>/dev/null
fi

# Package mapping per manager
declare -A PACKAGES
if [ "$PKG_MGR" = "apt" ]; then
    PACKAGES=(
        [nmap]="nmap"
        [dig]="dnsutils"
        [mtr]="mtr-tiny"
        [curl]="curl"
        [openssl]="openssl"
        [whois]="whois"
        [nc]="netcat-openbsd"
        [traceroute]="traceroute"
        [ss]="iproute2"
        [jq]="jq"
    )
elif [ "$PKG_MGR" = "yum" ] || [ "$PKG_MGR" = "dnf" ]; then
    PACKAGES=(
        [nmap]="nmap"
        [dig]="bind-utils"
        [mtr]="mtr"
        [curl]="curl"
        [openssl]="openssl"
        [whois]="whois"
        [nc]="nmap-ncat"
        [traceroute]="traceroute"
        [ss]="iproute"
        [jq]="jq"
    )
elif [ "$PKG_MGR" = "brew" ]; then
    PACKAGES=(
        [nmap]="nmap"
        [dig]="bind"
        [mtr]="mtr"
        [curl]="curl"
        [openssl]="openssl"
        [whois]="whois"
        [nc]="netcat"
        [traceroute]="traceroute"
        [jq]="jq"
    )
elif [ "$PKG_MGR" = "pacman" ]; then
    PACKAGES=(
        [nmap]="nmap"
        [dig]="bind"
        [mtr]="mtr"
        [curl]="curl"
        [openssl]="openssl"
        [whois]="whois"
        [nc]="gnu-netcat"
        [traceroute]="traceroute"
        [jq]="jq"
    )
fi

INSTALLED=0
SKIPPED=0

for cmd in nmap dig mtr curl openssl whois nc traceroute ss jq; do
    pkg="${PACKAGES[$cmd]}"
    [ -z "$pkg" ] && continue
    
    if command -v "$cmd" &>/dev/null; then
        echo "  ✅ $cmd — already installed"
        ((SKIPPED++))
    else
        echo "  📦 Installing $pkg ($cmd)..."
        $INSTALL "$pkg" 2>/dev/null || echo "  ⚠️  Failed to install $pkg — install manually"
        ((INSTALLED++))
    fi
done

echo ""
echo "=== Installation Complete ==="
echo "Installed: $INSTALLED | Already present: $SKIPPED"
echo ""
echo "Test with: bash scripts/netdiag.sh myip"
