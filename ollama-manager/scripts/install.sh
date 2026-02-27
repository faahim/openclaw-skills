#!/bin/bash
# Ollama Manager — Install Script
# Installs Ollama on Linux or macOS

set -e

echo "🦙 Ollama Manager — Installer"
echo "=============================="

# Detect OS
OS=$(uname -s)
ARCH=$(uname -m)

echo "Detected: $OS ($ARCH)"

# Check if already installed
if command -v ollama &>/dev/null; then
    CURRENT_VER=$(ollama --version 2>/dev/null || echo "unknown")
    echo "✅ Ollama already installed: $CURRENT_VER"
    echo ""
    read -p "Reinstall/upgrade? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping install. Run 'bash scripts/run.sh status' to check service."
        exit 0
    fi
fi

# Install based on OS
case "$OS" in
    Linux)
        echo "📦 Installing Ollama for Linux..."
        curl -fsSL https://ollama.com/install.sh | sh
        
        # Verify service
        if command -v systemctl &>/dev/null; then
            echo ""
            echo "🔧 Checking systemd service..."
            if systemctl is-active --quiet ollama 2>/dev/null; then
                echo "✅ Ollama service is running"
            else
                echo "Starting Ollama service..."
                sudo systemctl enable ollama 2>/dev/null || true
                sudo systemctl start ollama 2>/dev/null || true
                sleep 2
                if systemctl is-active --quiet ollama 2>/dev/null; then
                    echo "✅ Ollama service started"
                else
                    echo "⚠️  Could not start via systemd. Starting manually..."
                    nohup ollama serve &>/dev/null &
                    sleep 2
                fi
            fi
        else
            echo "No systemd detected. Starting Ollama in background..."
            nohup ollama serve &>/dev/null &
            sleep 2
        fi
        ;;
    Darwin)
        echo "📦 Installing Ollama for macOS..."
        if command -v brew &>/dev/null; then
            brew install ollama
        else
            echo "Downloading Ollama installer..."
            curl -fsSL https://ollama.com/install.sh | sh
        fi
        
        echo "Starting Ollama..."
        nohup ollama serve &>/dev/null &
        sleep 2
        ;;
    *)
        echo "❌ Unsupported OS: $OS"
        echo "Ollama supports Linux and macOS."
        echo "For Windows, download from https://ollama.com/download"
        exit 1
        ;;
esac

# Verify installation
echo ""
echo "🔍 Verifying installation..."

if ! command -v ollama &>/dev/null; then
    echo "❌ Ollama binary not found in PATH"
    exit 1
fi

VER=$(ollama --version 2>/dev/null || echo "unknown")
echo "✅ Ollama installed: $VER"

# Check API
echo ""
echo "🔍 Checking API..."
if curl -sf http://localhost:11434/api/tags &>/dev/null; then
    echo "✅ Ollama API responding at http://localhost:11434"
else
    echo "⚠️  API not responding yet. It may need a moment to start."
    echo "   Try: curl http://localhost:11434/api/tags"
fi

# Check GPU
echo ""
echo "🔍 Checking GPU..."
if command -v nvidia-smi &>/dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)
    echo "✅ NVIDIA GPU detected: $GPU_NAME ($GPU_MEM)"
elif [[ "$OS" == "Darwin" ]] && [[ "$ARCH" == "arm64" ]]; then
    echo "✅ Apple Silicon detected — Metal acceleration available"
else
    echo "ℹ️  No GPU detected — Ollama will use CPU (slower)"
fi

echo ""
echo "=============================="
echo "🎉 Installation complete!"
echo ""
echo "Next steps:"
echo "  bash scripts/run.sh pull llama3.2       # Download a model"
echo "  bash scripts/run.sh prompt llama3.2 'Hi' # Run a prompt"
echo "  bash scripts/run.sh status               # Check status"
