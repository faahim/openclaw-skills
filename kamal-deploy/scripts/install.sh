#!/bin/bash
# Kamal Deploy Manager — Installation Script
# Installs Ruby (if needed), Kamal gem, and verifies Docker availability

set -e

echo "=== Kamal Deploy Manager — Installer ==="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail()    { echo -e "${RED}❌ $1${NC}"; }

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    if command -v apt-get &>/dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
    elif command -v yum &>/dev/null; then
        PKG_MANAGER="yum"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
    PKG_MANAGER="brew"
fi

echo "Detected OS: $OS (package manager: ${PKG_MANAGER:-none})"
echo ""

# Step 1: Check/Install Ruby
echo "--- Step 1: Ruby ---"
if command -v ruby &>/dev/null; then
    RUBY_VERSION=$(ruby -v | awk '{print $2}')
    success "Ruby $RUBY_VERSION found"
else
    warn "Ruby not found. Installing..."
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq ruby ruby-dev build-essential
    elif [[ "$PKG_MANAGER" == "dnf" || "$PKG_MANAGER" == "yum" ]]; then
        sudo $PKG_MANAGER install -y ruby ruby-devel gcc make
    elif [[ "$PKG_MANAGER" == "brew" ]]; then
        brew install ruby
    else
        fail "Cannot install Ruby automatically. Install manually: https://www.ruby-lang.org/en/downloads/"
        exit 1
    fi
    success "Ruby installed: $(ruby -v)"
fi
echo ""

# Step 2: Install Kamal
echo "--- Step 2: Kamal ---"
if command -v kamal &>/dev/null; then
    KAMAL_VERSION=$(kamal version 2>/dev/null || echo "unknown")
    success "Kamal already installed: $KAMAL_VERSION"
    
    echo "Checking for updates..."
    gem update kamal --no-document 2>/dev/null && success "Kamal updated" || warn "Update check failed (non-critical)"
else
    echo "Installing Kamal..."
    gem install kamal --no-document
    
    if command -v kamal &>/dev/null; then
        success "Kamal installed: $(kamal version)"
    else
        # Try with --user-install
        warn "System gem install failed, trying user install..."
        gem install kamal --no-document --user-install
        
        # Add gem bin to PATH
        GEM_BIN=$(ruby -e 'puts Gem.user_dir')/bin
        export PATH="$GEM_BIN:$PATH"
        
        if command -v kamal &>/dev/null; then
            success "Kamal installed (user): $(kamal version)"
            warn "Add to your shell profile: export PATH=\"$GEM_BIN:\$PATH\""
        else
            fail "Kamal installation failed"
            exit 1
        fi
    fi
fi
echo ""

# Step 3: Check Docker
echo "--- Step 3: Docker ---"
if command -v docker &>/dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    success "Docker $DOCKER_VERSION found"
    
    # Check if Docker daemon is running
    if docker info &>/dev/null; then
        success "Docker daemon is running"
    else
        warn "Docker is installed but daemon is not running"
        echo "   Start with: sudo systemctl start docker"
    fi
else
    warn "Docker not found locally (needed for building images)"
    echo "   Install: https://docs.docker.com/get-docker/"
    echo "   Note: Docker only needs to be on your LOCAL machine for builds."
    echo "   Kamal will install Docker on remote servers automatically."
fi
echo ""

# Step 4: Check SSH
echo "--- Step 4: SSH ---"
if command -v ssh &>/dev/null; then
    success "SSH client found"
    
    # Check for SSH keys
    if [ -f "$HOME/.ssh/id_rsa" ] || [ -f "$HOME/.ssh/id_ed25519" ]; then
        success "SSH keys found"
    else
        warn "No SSH keys found in ~/.ssh/"
        echo "   Generate with: ssh-keygen -t ed25519"
    fi
else
    fail "SSH client not found. Install openssh-client."
fi
echo ""

# Step 5: Check ssh-agent
echo "--- Step 5: SSH Agent ---"
if [ -n "$SSH_AUTH_SOCK" ]; then
    KEY_COUNT=$(ssh-add -l 2>/dev/null | grep -v "no identities" | wc -l)
    if [ "$KEY_COUNT" -gt 0 ]; then
        success "SSH agent running with $KEY_COUNT key(s)"
    else
        warn "SSH agent running but no keys loaded"
        echo "   Add key: ssh-add ~/.ssh/id_ed25519"
    fi
else
    warn "SSH agent not running"
    echo "   Start with: eval \$(ssh-agent -s) && ssh-add"
fi
echo ""

# Summary
echo "=== Installation Summary ==="
echo ""

ALL_GOOD=true

command -v ruby &>/dev/null   && success "Ruby:  $(ruby -v | awk '{print $2}')" || { fail "Ruby:  NOT INSTALLED"; ALL_GOOD=false; }
command -v kamal &>/dev/null  && success "Kamal: $(kamal version 2>/dev/null)" || { fail "Kamal: NOT INSTALLED"; ALL_GOOD=false; }
command -v docker &>/dev/null && success "Docker: $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')" || { warn "Docker: NOT INSTALLED (optional locally)"; }
command -v ssh &>/dev/null    && success "SSH:   Available" || { fail "SSH:   NOT INSTALLED"; ALL_GOOD=false; }

echo ""

if $ALL_GOOD; then
    success "Kamal is ready! Initialize a project with:"
    echo ""
    echo "   cd /path/to/your/app"
    echo "   kamal init"
    echo "   # Edit config/deploy.yml"
    echo "   kamal setup"
    echo ""
else
    fail "Some dependencies are missing. Install them and re-run this script."
fi
