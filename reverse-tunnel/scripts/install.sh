#!/bin/bash
# Install tunnel backends for reverse-tunnel skill
set -euo pipefail

BACKEND="${1:-}"

usage() {
  echo "Usage: bash scripts/install.sh <backend>"
  echo ""
  echo "Backends:"
  echo "  cloudflared   - Cloudflare Tunnel (production-grade, free)"
  echo "  bore          - Lightweight Rust tunnel (self-hostable)"
  echo "  localtunnel   - Node.js zero-config tunnel"
  echo "  all           - Install all backends"
  exit 1
}

install_cloudflared() {
  if command -v cloudflared &>/dev/null; then
    echo "✅ cloudflared already installed: $(cloudflared --version 2>&1 | head -1)"
    return 0
  fi

  echo "📦 Installing cloudflared..."
  ARCH=$(uname -m)
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')

  case "$ARCH" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l|armhf) ARCH="arm" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
  esac

  case "$OS" in
    linux)
      URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}"
      if [ -w /usr/local/bin ]; then
        curl -sL "$URL" -o /usr/local/bin/cloudflared
        chmod +x /usr/local/bin/cloudflared
      else
        curl -sL "$URL" -o "$HOME/.local/bin/cloudflared"
        mkdir -p "$HOME/.local/bin"
        chmod +x "$HOME/.local/bin/cloudflared"
        echo "⚠️  Installed to ~/.local/bin/cloudflared — ensure it's in PATH"
      fi
      ;;
    darwin)
      if command -v brew &>/dev/null; then
        brew install cloudflared
      else
        echo "❌ Install Homebrew first: https://brew.sh"
        exit 1
      fi
      ;;
    *)
      echo "❌ Unsupported OS: $OS"
      exit 1
      ;;
  esac

  echo "✅ cloudflared installed: $(cloudflared --version 2>&1 | head -1)"
}

install_bore() {
  if command -v bore &>/dev/null; then
    echo "✅ bore already installed: $(bore --version 2>&1)"
    return 0
  fi

  echo "📦 Installing bore..."
  ARCH=$(uname -m)
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')

  case "$ARCH" in
    x86_64|amd64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *) echo "❌ Unsupported architecture: $ARCH. Try: cargo install bore-cli"; exit 1 ;;
  esac

  if command -v cargo &>/dev/null; then
    cargo install bore-cli
  else
    # Try pre-built binary
    case "$OS" in
      linux)
        URL="https://github.com/ekzhang/bore/releases/latest/download/bore-v0.5.2-${ARCH}-unknown-linux-musl.tar.gz"
        ;;
      darwin)
        URL="https://github.com/ekzhang/bore/releases/latest/download/bore-v0.5.2-${ARCH}-apple-darwin.tar.gz"
        ;;
      *)
        echo "❌ Unsupported OS. Try: cargo install bore-cli"
        exit 1
        ;;
    esac

    TMPDIR=$(mktemp -d)
    curl -sL "$URL" -o "$TMPDIR/bore.tar.gz" 2>/dev/null || {
      echo "⚠️  Pre-built binary not found. Installing via cargo..."
      if ! command -v cargo &>/dev/null; then
        echo "❌ Neither pre-built binary nor cargo available."
        echo "   Install Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        echo "   Then: cargo install bore-cli"
        exit 1
      fi
      cargo install bore-cli
      return 0
    }
    tar -xzf "$TMPDIR/bore.tar.gz" -C "$TMPDIR"
    if [ -w /usr/local/bin ]; then
      mv "$TMPDIR/bore" /usr/local/bin/bore
    else
      mkdir -p "$HOME/.local/bin"
      mv "$TMPDIR/bore" "$HOME/.local/bin/bore"
      echo "⚠️  Installed to ~/.local/bin/bore — ensure it's in PATH"
    fi
    chmod +x "$(command -v bore || echo "$HOME/.local/bin/bore")"
    rm -rf "$TMPDIR"
  fi

  echo "✅ bore installed"
}

install_localtunnel() {
  if command -v lt &>/dev/null; then
    echo "✅ localtunnel already installed"
    return 0
  fi

  echo "📦 Installing localtunnel..."
  if command -v npm &>/dev/null; then
    npm install -g localtunnel
  elif command -v npx &>/dev/null; then
    echo "✅ localtunnel available via npx (no global install needed)"
    echo "   Usage: npx localtunnel --port 3000"
    return 0
  else
    echo "❌ Node.js/npm required. Install: https://nodejs.org"
    exit 1
  fi

  echo "✅ localtunnel installed"
}

case "$BACKEND" in
  cloudflared) install_cloudflared ;;
  bore) install_bore ;;
  localtunnel|lt) install_localtunnel ;;
  all)
    install_cloudflared
    install_bore
    install_localtunnel
    ;;
  *) usage ;;
esac
