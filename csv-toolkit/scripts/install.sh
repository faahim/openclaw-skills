#!/bin/bash
# CSV Toolkit — Install Dependencies
# Installs Miller (mlr), csvkit, and xsv

set -e

echo "🔧 CSV Toolkit — Installing dependencies..."
echo ""

# Detect OS
OS=""
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS="$ID"
elif [ "$(uname)" = "Darwin" ]; then
  OS="macos"
fi

echo "Detected OS: $OS"
echo ""

install_miller() {
  echo "📦 Installing Miller (mlr)..."
  case "$OS" in
    ubuntu|debian|pop)
      sudo apt-get update -qq
      sudo apt-get install -y -qq miller 2>/dev/null || {
        echo "  Miller not in apt — installing from GitHub release..."
        ARCH=$(dpkg --print-architecture)
        MLR_VERSION=$(curl -s https://api.github.com/repos/johnkerl/miller/releases/latest | grep tag_name | cut -d '"' -f4)
        curl -sL "https://github.com/johnkerl/miller/releases/download/${MLR_VERSION}/miller-${MLR_VERSION}-linux-${ARCH}.tar.gz" | tar xz
        sudo mv miller-*/mlr /usr/local/bin/
        rm -rf miller-*/
      }
      ;;
    fedora|rhel|centos|rocky|alma)
      sudo dnf install -y miller 2>/dev/null || sudo yum install -y miller
      ;;
    arch|manjaro)
      sudo pacman -S --noconfirm miller
      ;;
    macos)
      brew install miller
      ;;
    *)
      echo "  Unknown OS — trying GitHub release..."
      ARCH=$(uname -m)
      [ "$ARCH" = "x86_64" ] && ARCH="amd64"
      [ "$ARCH" = "aarch64" ] && ARCH="arm64"
      MLR_VERSION=$(curl -s https://api.github.com/repos/johnkerl/miller/releases/latest | grep tag_name | cut -d '"' -f4)
      curl -sL "https://github.com/johnkerl/miller/releases/download/${MLR_VERSION}/miller-${MLR_VERSION}-linux-${ARCH}.tar.gz" | tar xz
      sudo mv miller-*/mlr /usr/local/bin/
      rm -rf miller-*/
      ;;
  esac
  echo "  ✅ Miller installed: $(mlr --version 2>/dev/null || echo 'check PATH')"
}

install_csvkit() {
  echo "📦 Installing csvkit..."
  if command -v pip3 &>/dev/null; then
    pip3 install --quiet csvkit
  elif command -v pip &>/dev/null; then
    pip install --quiet csvkit
  else
    echo "  ⚠️  Python pip not found. Install Python 3 + pip first."
    echo "     sudo apt-get install python3-pip  # Debian/Ubuntu"
    echo "     brew install python3               # macOS"
    return 1
  fi
  echo "  ✅ csvkit installed: $(csvstat --version 2>/dev/null || echo 'check PATH')"
}

install_xsv() {
  echo "📦 Installing xsv..."
  case "$OS" in
    macos)
      brew install xsv
      ;;
    *)
      if command -v cargo &>/dev/null; then
        cargo install xsv
      else
        # Download prebuilt binary
        ARCH=$(uname -m)
        [ "$ARCH" = "aarch64" ] && ARCH="arm64"
        XSV_URL="https://github.com/BurntSushi/xsv/releases/latest/download/xsv-0.13.0-${ARCH}-unknown-linux-musl.tar.gz"
        if curl -sfL "$XSV_URL" | tar xz 2>/dev/null; then
          sudo mv xsv /usr/local/bin/
        else
          # Fallback: try x86_64
          curl -sL "https://github.com/BurntSushi/xsv/releases/download/0.13.0/xsv-0.13.0-x86_64-unknown-linux-musl.tar.gz" | tar xz
          sudo mv xsv /usr/local/bin/
        fi
      fi
      ;;
  esac
  echo "  ✅ xsv installed: $(xsv --version 2>/dev/null || echo 'check PATH')"
}

# Install each tool (skip if already present)
echo "--- Miller ---"
if command -v mlr &>/dev/null; then
  echo "  ✅ Already installed: $(mlr --version)"
else
  install_miller
fi

echo ""
echo "--- csvkit ---"
if command -v csvstat &>/dev/null; then
  echo "  ✅ Already installed: $(csvstat --version 2>&1 | head -1)"
else
  install_csvkit
fi

echo ""
echo "--- xsv ---"
if command -v xsv &>/dev/null; then
  echo "  ✅ Already installed: $(xsv --version 2>&1 | head -1)"
else
  install_xsv
fi

echo ""
echo "🎉 CSV Toolkit ready! Try:"
echo "   mlr --icsv --opprint head -n 5 yourfile.csv"
echo "   xsv headers yourfile.csv"
echo "   csvstat yourfile.csv"
