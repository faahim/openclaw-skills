#!/bin/bash
# Data Processor — Install Dependencies
set -e

echo "📦 Installing Data Processor dependencies..."

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
else
    echo "⚠️  Unsupported OS: $OSTYPE"
    echo "Install manually: python3, pip3, csvkit, miller, jq"
    exit 1
fi

# Check Python3
if ! command -v python3 &>/dev/null; then
    echo "❌ python3 not found."
    if [[ "$OS" == "linux" ]]; then
        echo "   Install: sudo apt-get install python3 python3-pip"
    else
        echo "   Install: brew install python3"
    fi
    exit 1
fi

# Install csvkit
if ! command -v csvcut &>/dev/null; then
    echo "📥 Installing csvkit..."
    pip3 install --user csvkit 2>/dev/null || pip3 install csvkit
    echo "   ✅ csvkit installed"
else
    echo "   ✅ csvkit already installed ($(csvcut --version 2>&1 | head -1))"
fi

# Install miller
if ! command -v mlr &>/dev/null; then
    echo "📥 Installing miller..."
    if [[ "$OS" == "linux" ]]; then
        if command -v apt-get &>/dev/null; then
            sudo apt-get install -y miller 2>/dev/null || {
                # Fallback: download binary
                ARCH=$(uname -m)
                if [[ "$ARCH" == "x86_64" ]]; then
                    MLR_ARCH="amd64"
                elif [[ "$ARCH" == "aarch64" ]]; then
                    MLR_ARCH="arm64"
                else
                    echo "⚠️  Unknown arch: $ARCH. Install miller manually."
                    MLR_ARCH=""
                fi
                if [[ -n "$MLR_ARCH" ]]; then
                    MLR_URL="https://github.com/johnkerl/miller/releases/latest/download/mlr-linux-${MLR_ARCH}"
                    curl -sL -o /tmp/mlr "$MLR_URL"
                    chmod +x /tmp/mlr
                    sudo mv /tmp/mlr /usr/local/bin/mlr 2>/dev/null || mv /tmp/mlr ~/.local/bin/mlr
                fi
            }
        fi
    else
        brew install miller 2>/dev/null || echo "⚠️  Install miller: brew install miller"
    fi
    if command -v mlr &>/dev/null; then
        echo "   ✅ miller installed ($(mlr --version 2>&1))"
    fi
else
    echo "   ✅ miller already installed ($(mlr --version 2>&1))"
fi

# Install jq
if ! command -v jq &>/dev/null; then
    echo "📥 Installing jq..."
    if [[ "$OS" == "linux" ]]; then
        sudo apt-get install -y jq 2>/dev/null || {
            curl -sL -o /tmp/jq https://github.com/jqlang/jq/releases/latest/download/jq-linux-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
            chmod +x /tmp/jq
            sudo mv /tmp/jq /usr/local/bin/jq 2>/dev/null || mv /tmp/jq ~/.local/bin/jq
        }
    else
        brew install jq 2>/dev/null || echo "⚠️  Install jq: brew install jq"
    fi
    echo "   ✅ jq installed"
else
    echo "   ✅ jq already installed ($(jq --version 2>&1))"
fi

echo ""
echo "✅ Data Processor ready!"
echo ""
echo "Quick test:"
echo '  echo "name,age\nAlice,30\nBob,25" | mlr --icsv --ojson cat'
