#!/bin/bash
# Install Piper TTS and a default English voice model
set -euo pipefail

PIPER_HOME="${PIPER_HOME:-$HOME/.local/share/piper}"
PIPER_VERSION="2023.11.14-2"
DEFAULT_VOICE="en_US-lessac-medium"

# Detect architecture
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

case "$ARCH" in
  x86_64|amd64) ARCH_TAG="amd64" ;;
  aarch64|arm64) ARCH_TAG="arm64" ;;
  armv7l) ARCH_TAG="armv7" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux) OS_TAG="linux" ;;
  darwin) OS_TAG="macos"; ARCH_TAG="x64" ;;
  *) echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

echo "🔧 Installing Piper TTS..."
echo "   Architecture: $ARCH ($ARCH_TAG)"
echo "   OS: $OS ($OS_TAG)"
echo "   Install directory: $PIPER_HOME"
echo ""

# Create install directory
mkdir -p "$PIPER_HOME/voices"

# Download Piper binary
PIPER_URL="https://github.com/rhasspy/piper/releases/download/${PIPER_VERSION}/piper_${OS_TAG}_${ARCH_TAG}.tar.gz"
PIPER_TAR="$PIPER_HOME/piper.tar.gz"

if [ -f "$PIPER_HOME/piper" ]; then
  echo "✅ Piper binary already installed"
else
  echo "⬇️  Downloading Piper from $PIPER_URL..."
  curl -fSL "$PIPER_URL" -o "$PIPER_TAR"
  echo "📦 Extracting..."
  tar -xzf "$PIPER_TAR" -C "$PIPER_HOME" --strip-components=1
  rm -f "$PIPER_TAR"
  chmod +x "$PIPER_HOME/piper"
  echo "✅ Piper binary installed"
fi

# Download default voice model
VOICE_DIR="$PIPER_HOME/voices/$DEFAULT_VOICE"
if [ -d "$VOICE_DIR" ] && [ -f "$VOICE_DIR/$DEFAULT_VOICE.onnx" ]; then
  echo "✅ Default voice ($DEFAULT_VOICE) already installed"
else
  echo "⬇️  Downloading default voice: $DEFAULT_VOICE..."
  mkdir -p "$VOICE_DIR"
  
  MODEL_URL="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx"
  CONFIG_URL="https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json"
  
  curl -fSL "$MODEL_URL" -o "$VOICE_DIR/$DEFAULT_VOICE.onnx"
  curl -fSL "$CONFIG_URL" -o "$VOICE_DIR/$DEFAULT_VOICE.onnx.json"
  echo "✅ Voice model installed: $DEFAULT_VOICE"
fi

# Add to PATH if not already there
SHELL_RC=""
if [ -f "$HOME/.bashrc" ]; then
  SHELL_RC="$HOME/.bashrc"
elif [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
fi

if [ -n "$SHELL_RC" ] && ! grep -q "PIPER_HOME" "$SHELL_RC" 2>/dev/null; then
  echo "" >> "$SHELL_RC"
  echo "# Piper TTS" >> "$SHELL_RC"
  echo "export PIPER_HOME=\"$PIPER_HOME\"" >> "$SHELL_RC"
  echo "export PATH=\"\$PIPER_HOME:\$PATH\"" >> "$SHELL_RC"
  echo "📝 Added PIPER_HOME to $SHELL_RC"
fi

echo ""
echo "════════════════════════════════════════"
echo "✅ Piper TTS installed successfully!"
echo ""
echo "   Binary:  $PIPER_HOME/piper"
echo "   Voice:   $DEFAULT_VOICE"
echo "   Voices:  $PIPER_HOME/voices/"
echo ""
echo "   Quick test:"
echo "   echo 'Hello world!' | $PIPER_HOME/piper --model $VOICE_DIR/$DEFAULT_VOICE.onnx --output_file test.wav"
echo "════════════════════════════════════════"
