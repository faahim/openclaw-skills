#!/bin/bash
# Install load testing tools (hey preferred, ab fallback)
set -e

echo "🔧 Installing HTTP load testing tools..."

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

install_hey() {
  echo "Installing hey..."
  
  if command -v go &>/dev/null; then
    go install github.com/rakyll/hey@latest
    echo "✅ hey installed via go"
    return 0
  fi
  
  # Try binary download
  case "$OS" in
    Linux)
      case "$ARCH" in
        x86_64|amd64)
          HEY_URL="https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64"
          ;;
        aarch64|arm64)
          HEY_URL="https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_arm64"
          ;;
        *)
          echo "⚠️ Unsupported architecture: $ARCH"
          return 1
          ;;
      esac
      ;;
    Darwin)
      case "$ARCH" in
        x86_64|amd64)
          HEY_URL="https://hey-release.s3.us-east-2.amazonaws.com/hey_darwin_amd64"
          ;;
        arm64)
          HEY_URL="https://hey-release.s3.us-east-2.amazonaws.com/hey_darwin_arm64"
          ;;
        *)
          echo "⚠️ Unsupported architecture: $ARCH"
          return 1
          ;;
      esac
      ;;
    *)
      echo "⚠️ Unsupported OS: $OS"
      return 1
      ;;
  esac
  
  if [ -n "$HEY_URL" ]; then
    DEST="/usr/local/bin/hey"
    if [ -w "/usr/local/bin" ]; then
      curl -sL "$HEY_URL" -o "$DEST"
      chmod +x "$DEST"
    else
      sudo curl -sL "$HEY_URL" -o "$DEST"
      sudo chmod +x "$DEST"
    fi
    echo "✅ hey installed to $DEST"
    return 0
  fi
  
  return 1
}

install_ab() {
  echo "Installing Apache Bench (ab)..."
  
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq apache2-utils
  elif command -v yum &>/dev/null; then
    sudo yum install -y httpd-tools
  elif command -v brew &>/dev/null; then
    brew install httpd
  elif command -v apk &>/dev/null; then
    sudo apk add apache2-utils
  else
    echo "⚠️ Cannot install ab — unknown package manager"
    return 1
  fi
  
  echo "✅ ab (Apache Bench) installed"
  return 0
}

# Check what's already installed
if command -v hey &>/dev/null; then
  echo "✅ hey already installed: $(hey --version 2>&1 | head -1 || echo 'available')"
  exit 0
fi

if command -v ab &>/dev/null; then
  echo "✅ ab already installed: $(ab -V 2>&1 | head -1)"
  exit 0
fi

if command -v wrk &>/dev/null; then
  echo "✅ wrk already installed: $(wrk --version 2>&1 | head -1)"
  exit 0
fi

# Install in preference order
echo "No load testing tools found. Installing..."

if install_hey; then
  exit 0
fi

echo "hey install failed, trying ab..."
if install_ab; then
  exit 0
fi

echo "❌ Could not install any load testing tool."
echo "Manual install options:"
echo "  hey: go install github.com/rakyll/hey@latest"
echo "  ab:  apt install apache2-utils"
echo "  wrk: apt install wrk"
exit 1
