#!/bin/bash
# Install Apprise notification router
set -e

echo "📦 Installing Apprise..."

# Check Python
if ! command -v python3 &>/dev/null; then
  echo "❌ Python 3 is required. Install it first."
  exit 1
fi

# Install apprise
pip3 install --user apprise 2>/dev/null || python3 -m pip install --user apprise

# Verify
if command -v apprise &>/dev/null; then
  echo "✅ Apprise installed: $(apprise --version 2>&1 | head -1)"
else
  # Try adding user bin to PATH
  export PATH="$HOME/.local/bin:$PATH"
  if command -v apprise &>/dev/null; then
    echo "✅ Apprise installed (add \$HOME/.local/bin to PATH)"
    echo "   Run: echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
  else
    echo "❌ Installation failed. Try: python3 -m pip install apprise"
    exit 1
  fi
fi

# Create default config if not exists
CONFIG="$HOME/.apprise.yml"
if [ ! -f "$CONFIG" ]; then
  cat > "$CONFIG" << 'YAML'
# Apprise Notification Config
# Docs: https://github.com/caronc/apprise/wiki
urls:
  # Uncomment and configure your services:

  # Telegram
  # - tgram://BOT_TOKEN/CHAT_ID:
  #     tag: personal

  # Slack (webhook)
  # - slack://TOKEN_A/TOKEN_B/TOKEN_C/#channel:
  #     tag: team

  # Discord (webhook)
  # - discord://WEBHOOK_ID/WEBHOOK_TOKEN:
  #     tag: team

  # Email
  # - mailto://user:app-pass@smtp.gmail.com?to=recipient@example.com:
  #     tag: email

  # ntfy (free, no signup)
  # - ntfy://ntfy.sh/your-topic:
  #     tag: alerts
YAML
  echo "📝 Config template created at $CONFIG"
  echo "   Edit it to add your notification services."
else
  echo "📝 Config already exists at $CONFIG"
fi

echo ""
echo "🚀 Quick test:"
echo "   apprise -t 'Test' -b 'Hello from Apprise' 'json://httpbin.org/post'"
