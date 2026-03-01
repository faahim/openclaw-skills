#!/bin/bash
# Radicale Calendar & Contacts Server — Installer
set -e

RADICALE_CONFIG_DIR="${RADICALE_CONFIG_DIR:-$HOME/.config/radicale}"
RADICALE_DATA_DIR="${RADICALE_DATA_DIR:-$HOME/.local/share/radicale/collections}"
RADICALE_PORT="${RADICALE_PORT:-5232}"
RADICALE_HOST="${RADICALE_HOST:-0.0.0.0}"
SETUP_SYSTEMD=false
RESTART_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --systemd) SETUP_SYSTEMD=true; shift ;;
    --restart) RESTART_ONLY=true; shift ;;
    --port) RADICALE_PORT="$2"; shift 2 ;;
    --host) RADICALE_HOST="$2"; shift 2 ;;
    --data-dir) RADICALE_DATA_DIR="$2"; shift 2 ;;
    --help)
      echo "Usage: bash install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --systemd     Set up as systemd user service"
      echo "  --restart     Restart existing server"
      echo "  --port PORT   Server port (default: 5232)"
      echo "  --host HOST   Bind address (default: 0.0.0.0)"
      echo "  --data-dir    Storage directory"
      echo "  --help        Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Restart mode
if $RESTART_ONLY; then
  echo "🔄 Restarting Radicale..."
  if systemctl --user is-active radicale &>/dev/null; then
    systemctl --user restart radicale
    echo "✅ Restarted via systemd"
  else
    pkill -f "python.*radicale" 2>/dev/null || true
    sleep 1
    python3 -m radicale --config "$RADICALE_CONFIG_DIR/config" &
    echo "✅ Restarted (PID $!)"
  fi
  exit 0
fi

echo "📦 Installing Radicale Calendar & Contacts Server..."
echo ""

# Step 1: Install Python dependencies
echo "→ Installing Radicale and bcrypt..."
pip3 install --user --quiet radicale[bcrypt] 2>/dev/null || pip3 install --user radicale bcrypt

# Verify install
if ! python3 -m radicale --version &>/dev/null; then
  echo "❌ Radicale installation failed. Check Python/pip setup."
  exit 1
fi

RADICALE_VERSION=$(python3 -m radicale --version 2>&1 | head -1)
echo "✅ Installed Radicale $RADICALE_VERSION"

# Step 2: Create config directory
echo "→ Creating configuration..."
mkdir -p "$RADICALE_CONFIG_DIR"
mkdir -p "$RADICALE_DATA_DIR"

# Step 3: Generate config (only if not exists)
if [ ! -f "$RADICALE_CONFIG_DIR/config" ]; then
  cat > "$RADICALE_CONFIG_DIR/config" <<EOF
[server]
hosts = ${RADICALE_HOST}:${RADICALE_PORT}

[auth]
type = htpasswd
htpasswd_filename = ${RADICALE_CONFIG_DIR}/users
htpasswd_encryption = bcrypt

[storage]
filesystem_folder = ${RADICALE_DATA_DIR}

[web]
type = internal

[logging]
level = warning
mask_passwords = True
EOF
  echo "✅ Config created at $RADICALE_CONFIG_DIR/config"
else
  echo "⏭️  Config already exists, skipping"
fi

# Step 4: Create empty users file if not exists
if [ ! -f "$RADICALE_CONFIG_DIR/users" ]; then
  touch "$RADICALE_CONFIG_DIR/users"
  chmod 600 "$RADICALE_CONFIG_DIR/users"
  echo "✅ Users file created (empty — add users with manage-users.sh)"
fi

# Step 5: Set up systemd service if requested
if $SETUP_SYSTEMD; then
  echo "→ Setting up systemd user service..."
  SYSTEMD_DIR="$HOME/.config/systemd/user"
  mkdir -p "$SYSTEMD_DIR"

  # Find radicale module path
  RADICALE_PATH=$(python3 -c "import radicale; print(radicale.__file__)" 2>/dev/null | xargs dirname)
  PYTHON_PATH=$(which python3)

  cat > "$SYSTEMD_DIR/radicale.service" <<EOF
[Unit]
Description=Radicale CalDAV/CardDAV Server
After=network.target

[Service]
Type=simple
ExecStart=${PYTHON_PATH} -m radicale --config ${RADICALE_CONFIG_DIR}/config
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable radicale
  systemctl --user start radicale

  echo "✅ Systemd service installed and started"
  echo "   Manage with: systemctl --user {status|restart|stop} radicale"
else
  # Start directly
  echo "→ Starting Radicale..."
  pkill -f "python.*radicale" 2>/dev/null || true
  sleep 1
  nohup python3 -m radicale --config "$RADICALE_CONFIG_DIR/config" > /tmp/radicale.log 2>&1 &
  RADICALE_PID=$!
  sleep 2

  # Verify it's running
  if kill -0 $RADICALE_PID 2>/dev/null; then
    echo "✅ Radicale running (PID $RADICALE_PID)"
  else
    echo "❌ Failed to start. Check /tmp/radicale.log"
    cat /tmp/radicale.log
    exit 1
  fi
fi

echo ""
echo "════════════════════════════════════════════"
echo "  🗓️  Radicale is ready!"
echo "════════════════════════════════════════════"
echo ""
echo "  Web UI:   http://${RADICALE_HOST}:${RADICALE_PORT}"
echo "  Config:   $RADICALE_CONFIG_DIR/config"
echo "  Storage:  $RADICALE_DATA_DIR"
echo ""
echo "  Next steps:"
echo "  1. Create a user:  bash scripts/manage-users.sh add myuser mypassword"
echo "  2. Open the web UI and log in"
echo "  3. Connect your phone/laptop calendar app"
echo ""
