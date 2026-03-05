#!/bin/bash
# Install Task (go-task) - modern task runner
set -euo pipefail

INSTALL_DIR="${TASK_INSTALL_DIR:-/usr/local/bin}"
USE_LOCAL="${TASK_LOCAL_INSTALL:-false}"

# Detect OS and architecture
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7*|armhf)  ARCH="arm" ;;
  i386|i686)     ARCH="386" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux|darwin) ;;
  mingw*|msys*|cygwin*) OS="windows" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

# Check if already installed
if command -v task &>/dev/null; then
  CURRENT=$(task --version 2>/dev/null || echo "unknown")
  echo "ℹ️  Task already installed: $CURRENT"
  read -r -p "Reinstall/upgrade? [y/N] " REPLY
  [[ "$REPLY" =~ ^[Yy]$ ]] || { echo "Keeping current version."; exit 0; }
fi

# Use local install if no write access to /usr/local/bin
if [[ "$USE_LOCAL" == "true" ]] || ! touch "$INSTALL_DIR/.task_test" 2>/dev/null; then
  INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"
  echo "📁 Installing to $INSTALL_DIR (add to PATH if needed)"
else
  rm -f "$INSTALL_DIR/.task_test"
fi

# Get latest version
echo "🔍 Fetching latest Task release..."
LATEST=$(curl -fsSL "https://api.github.com/repos/go-task/task/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')

if [[ -z "$LATEST" ]]; then
  echo "❌ Could not determine latest version. Check network."
  exit 1
fi

echo "📦 Downloading Task v${LATEST} for ${OS}/${ARCH}..."

EXT="tar.gz"
[[ "$OS" == "windows" ]] && EXT="zip"

URL="https://github.com/go-task/task/releases/download/v${LATEST}/task_${OS}_${ARCH}.${EXT}"
TMP=$(mktemp -d)

curl -fsSL "$URL" -o "$TMP/task.${EXT}"

# Extract
cd "$TMP"
if [[ "$EXT" == "tar.gz" ]]; then
  tar xzf "task.${EXT}"
else
  unzip -q "task.${EXT}"
fi

# Install binary
mv task "$INSTALL_DIR/task"
chmod +x "$INSTALL_DIR/task"

# Install completions if possible
if [[ -d /etc/bash_completion.d ]] && [[ -w /etc/bash_completion.d ]]; then
  [[ -f completion/bash/task.bash ]] && cp completion/bash/task.bash /etc/bash_completion.d/task
fi

# Cleanup
rm -rf "$TMP"

# Verify
INSTALLED=$("$INSTALL_DIR/task" --version 2>/dev/null || echo "failed")
echo ""
echo "✅ Task v${LATEST} installed at ${INSTALL_DIR}/task"
echo "   Version: ${INSTALLED}"

# Check PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  echo ""
  echo "⚠️  ${INSTALL_DIR} is not in your PATH. Add it:"
  echo "   echo 'export PATH=\"${INSTALL_DIR}:\$PATH\"' >> ~/.bashrc"
  echo "   source ~/.bashrc"
fi
