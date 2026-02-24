#!/bin/bash
# Install Semgrep static analysis tool
set -e

echo "🔧 Installing Semgrep Code Scanner..."

# Method 1: Check if already installed
if command -v semgrep &>/dev/null; then
  VERSION=$(semgrep --version 2>/dev/null || echo "unknown")
  echo "✅ Semgrep already installed (version: $VERSION)"
  exit 0
fi

# Method 2: Try pipx (cleanest)
if command -v pipx &>/dev/null; then
  echo "📦 Installing via pipx..."
  pipx install semgrep && echo "✅ Installed via pipx" && exit 0
fi

# Method 3: Try pip
if command -v pip3 &>/dev/null; then
  echo "📦 Installing via pip3..."
  pip3 install --user semgrep 2>/dev/null && echo "✅ Installed via pip3" && exit 0
  pip3 install --user --break-system-packages semgrep 2>/dev/null && echo "✅ Installed via pip3" && exit 0
fi

# Method 4: Try Homebrew
if command -v brew &>/dev/null; then
  echo "📦 Installing via Homebrew..."
  brew install semgrep && echo "✅ Installed via Homebrew" && exit 0
fi

# Method 5: Docker fallback
if command -v docker &>/dev/null; then
  echo "📦 Setting up Docker-based semgrep..."
  docker pull returntocorp/semgrep:latest
  
  # Create wrapper script
  WRAPPER="$HOME/.local/bin/semgrep"
  mkdir -p "$HOME/.local/bin"
  cat > "$WRAPPER" <<'WRAPPER_EOF'
#!/bin/bash
docker run --rm -v "$(pwd):/src" returntocorp/semgrep:latest "$@"
WRAPPER_EOF
  chmod +x "$WRAPPER"
  echo "✅ Installed Docker wrapper at $WRAPPER"
  echo "   Make sure $HOME/.local/bin is in your PATH"
  exit 0
fi

echo "❌ Could not install semgrep. Options:"
echo "   1. pip3 install semgrep"
echo "   2. brew install semgrep"
echo "   3. docker pull returntocorp/semgrep"
echo "   4. pipx install semgrep"
exit 1
