#!/bin/bash
# Install asciinema and optional tools
set -e

echo "🎬 Installing Asciinema Terminal Recorder..."

# Detect OS and install
install_asciinema() {
  if command -v asciinema &>/dev/null; then
    echo "✅ asciinema already installed ($(asciinema --version))"
    return 0
  fi

  if command -v apt-get &>/dev/null; then
    echo "📦 Installing via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq asciinema
  elif command -v brew &>/dev/null; then
    echo "📦 Installing via Homebrew..."
    brew install asciinema
  elif command -v dnf &>/dev/null; then
    echo "📦 Installing via dnf..."
    sudo dnf install -y asciinema
  elif command -v pacman &>/dev/null; then
    echo "📦 Installing via pacman..."
    sudo pacman -S --noconfirm asciinema
  elif command -v pip3 &>/dev/null; then
    echo "📦 Installing via pip..."
    pip3 install asciinema
  else
    echo "❌ No supported package manager found."
    echo "   Install manually: https://docs.asciinema.org/manual/cli/installation/"
    exit 1
  fi

  echo "✅ asciinema installed ($(asciinema --version))"
}

# Create default config
setup_config() {
  local config_dir="$HOME/.config/asciinema"
  local config_file="$config_dir/config"

  if [ -f "$config_file" ]; then
    echo "✅ Config already exists at $config_file"
    return 0
  fi

  mkdir -p "$config_dir"
  cat > "$config_file" << 'EOF'
[record]
idle_time_limit = 2

[play]
speed = 1.0

[api]
url = https://asciinema.org
EOF

  echo "✅ Config created at $config_file"
}

# Create recordings directory
setup_dirs() {
  local rec_dir="$HOME/.local/share/asciinema/recordings"
  mkdir -p "$rec_dir"
  echo "✅ Recordings directory: $rec_dir"
}

# Install optional GIF converter
install_agg() {
  if command -v agg &>/dev/null; then
    echo "✅ agg (GIF converter) already installed"
    return 0
  fi

  echo "ℹ️  Optional: agg (GIF converter) not installed."
  echo "   Install from: https://github.com/asciinema/agg/releases"
  echo "   Or: cargo install agg"
}

# Main
install_asciinema
setup_config
setup_dirs
install_agg

echo ""
echo "🎬 Asciinema Terminal Recorder is ready!"
echo "   Record:  bash scripts/run.sh record --title 'My Demo'"
echo "   Play:    bash scripts/run.sh play recording.cast"
echo "   Upload:  bash scripts/run.sh upload recording.cast"
