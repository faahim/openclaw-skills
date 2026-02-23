#!/bin/bash
# Install dependencies for Speedtest Monitor
set -e

echo "Installing Speedtest Monitor dependencies..."

# speedtest-cli
if command -v speedtest-cli &>/dev/null; then
  echo "✅ speedtest-cli already installed ($(speedtest-cli --version 2>&1 | head -1))"
else
  echo "Installing speedtest-cli..."
  if command -v pip3 &>/dev/null; then
    pip3 install speedtest-cli
  elif command -v pip &>/dev/null; then
    pip install speedtest-cli
  elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y speedtest-cli
  elif command -v brew &>/dev/null; then
    brew install speedtest-cli
  else
    echo "❌ Cannot install speedtest-cli. Install manually: pip3 install speedtest-cli"
    exit 1
  fi
  echo "✅ speedtest-cli installed"
fi

# jq
if command -v jq &>/dev/null; then
  echo "✅ jq already installed"
else
  echo "Installing jq..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y jq
  elif command -v brew &>/dev/null; then
    brew install jq
  else
    echo "❌ Please install jq manually"
  fi
fi

# bc
if command -v bc &>/dev/null; then
  echo "✅ bc already installed"
else
  echo "Installing bc..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y bc
  fi
fi

echo ""
echo "✅ All dependencies installed. Run: bash scripts/run.sh --once"
