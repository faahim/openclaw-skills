#!/bin/bash
# Transmission Torrent Manager — Install & Service Management
set -e

ACTION="${1:-install}"
CONFIG_DIR="${TRANSMISSION_CONFIG_DIR:-$HOME/.config/transmission-daemon}"
DOWNLOAD_DIR="${TRANSMISSION_DOWNLOAD_DIR:-$HOME/Downloads/torrents}"
INCOMPLETE_DIR="$DOWNLOAD_DIR/incomplete"
COMPLETED_DIR="$DOWNLOAD_DIR/completed"

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  elif [ "$(uname)" = "Darwin" ]; then
    echo "macos"
  else
    echo "unknown"
  fi
}

install_transmission() {
  local os
  os=$(detect_os)

  echo "📦 Installing Transmission daemon..."

  case "$os" in
    ubuntu|debian|pop|linuxmint|raspbian)
      sudo apt-get update -qq
      sudo apt-get install -y -qq transmission-daemon transmission-cli jq
      # Stop the auto-started service so we can configure
      sudo systemctl stop transmission-daemon 2>/dev/null || true
      sudo systemctl disable transmission-daemon 2>/dev/null || true
      ;;
    fedora|rhel|centos|rocky|alma)
      sudo dnf install -y transmission-daemon transmission-cli jq
      sudo systemctl stop transmission-daemon 2>/dev/null || true
      sudo systemctl disable transmission-daemon 2>/dev/null || true
      ;;
    arch|manjaro|endeavouros)
      sudo pacman -Sy --noconfirm transmission-cli jq
      ;;
    alpine)
      sudo apk add transmission-daemon transmission-cli jq
      ;;
    macos)
      if command -v brew &>/dev/null; then
        brew install transmission-cli jq
      else
        echo "❌ Homebrew required. Install from https://brew.sh"
        exit 1
      fi
      ;;
    *)
      echo "❌ Unsupported OS: $os"
      echo "   Install transmission-daemon and transmission-cli manually."
      exit 1
      ;;
  esac

  echo "✅ Transmission installed."
}

configure_transmission() {
  echo "⚙️  Configuring Transmission..."

  # Create directories
  mkdir -p "$CONFIG_DIR"
  mkdir -p "$DOWNLOAD_DIR"
  mkdir -p "$INCOMPLETE_DIR"
  mkdir -p "$COMPLETED_DIR"

  # Generate initial settings
  cat > "$CONFIG_DIR/settings.json" << EOF
{
  "alt-speed-down": 1000,
  "alt-speed-enabled": false,
  "alt-speed-time-begin": 540,
  "alt-speed-time-day": 127,
  "alt-speed-time-enabled": false,
  "alt-speed-time-end": 1020,
  "alt-speed-up": 500,
  "blocklist-enabled": true,
  "blocklist-url": "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz",
  "dht-enabled": true,
  "download-dir": "$COMPLETED_DIR",
  "download-queue-enabled": true,
  "download-queue-size": 5,
  "encryption": 1,
  "idle-seeding-limit": 30,
  "idle-seeding-limit-enabled": true,
  "incomplete-dir": "$INCOMPLETE_DIR",
  "incomplete-dir-enabled": true,
  "peer-limit-global": 200,
  "peer-limit-per-torrent": 50,
  "peer-port": 51413,
  "pex-enabled": true,
  "ratio-limit": 2.0,
  "ratio-limit-enabled": true,
  "rename-partial-files": true,
  "rpc-authentication-required": false,
  "rpc-bind-address": "127.0.0.1",
  "rpc-enabled": true,
  "rpc-host-whitelist": "127.0.0.1,localhost",
  "rpc-host-whitelist-enabled": true,
  "rpc-port": 9091,
  "rpc-url": "/transmission/",
  "rpc-whitelist": "127.0.0.1,::1",
  "rpc-whitelist-enabled": true,
  "seed-queue-enabled": true,
  "seed-queue-size": 10,
  "speed-limit-down": 10000,
  "speed-limit-down-enabled": false,
  "speed-limit-up": 5000,
  "speed-limit-up-enabled": false,
  "start-added-torrents": true,
  "umask": 18
}
EOF

  echo "✅ Configuration saved to $CONFIG_DIR/settings.json"
  echo "   Download dir:   $COMPLETED_DIR"
  echo "   Incomplete dir: $INCOMPLETE_DIR"
}

start_daemon() {
  if pgrep -x transmission-da &>/dev/null; then
    echo "⚡ Transmission daemon already running."
    return 0
  fi

  echo "🚀 Starting Transmission daemon..."
  transmission-daemon \
    --config-dir "$CONFIG_DIR" \
    --download-dir "$COMPLETED_DIR" \
    --incomplete-dir "$INCOMPLETE_DIR" \
    --logfile "$CONFIG_DIR/transmission.log" \
    --log-level info

  # Wait for RPC to be ready
  local retries=10
  while [ $retries -gt 0 ]; do
    if curl -s "http://127.0.0.1:9091/transmission/rpc" >/dev/null 2>&1; then
      echo "✅ Daemon started (RPC on port 9091)."
      return 0
    fi
    sleep 1
    retries=$((retries - 1))
  done

  echo "✅ Daemon started (RPC may take a moment to respond)."
}

stop_daemon() {
  echo "🛑 Stopping Transmission daemon..."
  if pgrep -x transmission-da &>/dev/null; then
    pkill -x transmission-da
    sleep 2
    echo "✅ Daemon stopped."
  else
    echo "ℹ️  Daemon was not running."
  fi
}

case "$ACTION" in
  install)
    install_transmission
    configure_transmission
    start_daemon
    echo ""
    echo "🎉 Transmission Torrent Manager ready!"
    echo "   Run: bash scripts/run.sh status"
    ;;
  start)
    start_daemon
    ;;
  stop)
    stop_daemon
    ;;
  restart)
    stop_daemon
    sleep 1
    start_daemon
    ;;
  status)
    if pgrep -x transmission-da &>/dev/null; then
      echo "✅ Transmission daemon is running (PID: $(pgrep -x transmission-da))"
      echo "   RPC: http://127.0.0.1:9091"
      echo "   Config: $CONFIG_DIR"
    else
      echo "❌ Transmission daemon is not running."
      echo "   Start with: bash scripts/install.sh start"
    fi
    ;;
  *)
    echo "Usage: bash scripts/install.sh [install|start|stop|restart|status]"
    exit 1
    ;;
esac
