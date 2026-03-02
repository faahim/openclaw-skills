#!/bin/bash
# Nmap Scanner — Install Script
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
err()   { echo -e "${RED}[ERR]${NC} $*"; }

has() { command -v "$1" &>/dev/null; }

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then echo "macos"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian|pop|linuxmint) echo "debian" ;;
            fedora|rhel|centos|rocky|alma) echo "fedora" ;;
            arch|manjaro) echo "arch" ;;
            alpine) echo "alpine" ;;
            *) echo "unknown" ;;
        esac
    else echo "unknown"; fi
}

OS=$(detect_os)

install_nmap() {
    if has nmap; then
        ok "nmap already installed ($(nmap --version | head -1))"
        return 0
    fi

    info "Installing nmap on $OS..."
    case "$OS" in
        debian)  sudo apt-get update -qq && sudo apt-get install -y nmap ;;
        fedora)  sudo dnf install -y nmap ;;
        arch)    sudo pacman -S --noconfirm nmap ;;
        alpine)  sudo apk add nmap nmap-scripts ;;
        macos)   brew install nmap ;;
        *)       err "Unknown OS. Install nmap manually: https://nmap.org/download"; exit 1 ;;
    esac
    ok "nmap installed"
}

install_extras() {
    # xsltproc for HTML reports
    if ! has xsltproc; then
        info "Installing xsltproc (for HTML reports)..."
        case "$OS" in
            debian)  sudo apt-get install -y xsltproc 2>/dev/null || true ;;
            fedora)  sudo dnf install -y libxslt 2>/dev/null || true ;;
            arch)    sudo pacman -S --noconfirm libxslt 2>/dev/null || true ;;
            macos)   true ;; # Built-in on macOS
        esac
    fi

    # jq for JSON processing
    if ! has jq; then
        info "Installing jq..."
        case "$OS" in
            debian)  sudo apt-get install -y jq 2>/dev/null || true ;;
            fedora)  sudo dnf install -y jq 2>/dev/null || true ;;
            arch)    sudo pacman -S --noconfirm jq 2>/dev/null || true ;;
            alpine)  sudo apk add jq 2>/dev/null || true ;;
            macos)   brew install jq 2>/dev/null || true ;;
        esac
    fi
}

# Create data directories
setup_dirs() {
    mkdir -p "$HOME/.nmap-scanner/reports"
    mkdir -p "$HOME/.nmap-scanner/baselines"
    ok "Created ~/.nmap-scanner/ directories"
}

install_nmap
install_extras
setup_dirs

echo ""
ok "Nmap Scanner ready! Run: bash scripts/scan.sh discover"
