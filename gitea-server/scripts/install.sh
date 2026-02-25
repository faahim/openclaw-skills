#!/bin/bash
# Gitea Server Installer
# Installs Gitea binary, creates system user, sets up systemd service

set -euo pipefail

# Defaults
DB_TYPE="sqlite3"
DB_HOST="localhost"
DB_NAME="gitea"
DB_USER="gitea"
DB_PASS=""
GITEA_PORT="${GITEA_PORT:-3000}"
GITEA_DOMAIN="${GITEA_DOMAIN:-localhost}"
GITEA_VERSION="latest"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[GITEA]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --db) DB_TYPE="$2"; shift 2 ;;
    --db-host) DB_HOST="$2"; shift 2 ;;
    --db-name) DB_NAME="$2"; shift 2 ;;
    --db-user) DB_USER="$2"; shift 2 ;;
    --db-pass) DB_PASS="$2"; shift 2 ;;
    --port) GITEA_PORT="$2"; shift 2 ;;
    --domain) GITEA_DOMAIN="$2"; shift 2 ;;
    --version) GITEA_VERSION="$2"; shift 2 ;;
    --help) echo "Usage: install.sh [--db sqlite|postgres|mysql] [--port 3000] [--domain git.example.com] [--version latest]"; exit 0 ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
done

# Check root
if [[ $EUID -ne 0 ]]; then
  error "This script must be run as root (use sudo)"
  exit 1
fi

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
  x86_64) GITEA_ARCH="linux-amd64" ;;
  aarch64|arm64) GITEA_ARCH="linux-arm64" ;;
  armv7l) GITEA_ARCH="linux-armv6" ;;
  *) error "Unsupported architecture: $ARCH"; exit 1 ;;
esac

log "Installing Gitea for $GITEA_ARCH..."

# Step 1: Install dependencies
log "Installing dependencies..."
if command -v apt-get &>/dev/null; then
  apt-get update -qq
  apt-get install -y -qq curl git sqlite3 2>/dev/null
elif command -v dnf &>/dev/null; then
  dnf install -y -q curl git sqlite 2>/dev/null
elif command -v yum &>/dev/null; then
  yum install -y -q curl git sqlite 2>/dev/null
else
  warn "Could not detect package manager. Ensure curl, git, sqlite3 are installed."
fi

# Step 2: Download Gitea binary
if [[ "$GITEA_VERSION" == "latest" ]]; then
  log "Fetching latest version..."
  GITEA_VERSION=$(curl -sL https://dl.gitea.com/gitea/version.json | grep -oP '"latest":\s*\{"version":\s*"v?\K[^"]+' || echo "")
  if [[ -z "$GITEA_VERSION" ]]; then
    # Fallback: get from GitHub API
    GITEA_VERSION=$(curl -sL https://api.github.com/repos/go-gitea/gitea/releases/latest | grep -oP '"tag_name":\s*"v?\K[^"]+' || echo "1.22.6")
  fi
fi

DOWNLOAD_URL="https://dl.gitea.com/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-${GITEA_ARCH}"
log "Downloading Gitea v${GITEA_VERSION}..."
curl -sL -o /usr/local/bin/gitea "$DOWNLOAD_URL"
chmod +x /usr/local/bin/gitea

# Verify
if ! /usr/local/bin/gitea --version &>/dev/null; then
  error "Downloaded binary is not executable or corrupt"
  exit 1
fi
log "Gitea $(/usr/local/bin/gitea --version) installed"

# Step 3: Create system user
if ! id -u git &>/dev/null 2>&1; then
  log "Creating 'git' system user..."
  adduser --system --shell /bin/bash --gecos 'Git Version Control' \
    --group --disabled-password --home /home/git git 2>/dev/null || \
  useradd -r -m -s /bin/bash -d /home/git git 2>/dev/null
fi

# Step 4: Create directory structure
log "Setting up directories..."
mkdir -p /var/lib/gitea/{custom,data,log,repositories}
mkdir -p /etc/gitea
chown -R git:git /var/lib/gitea
chown root:git /etc/gitea
chmod 770 /etc/gitea

# Step 5: Create config
log "Generating configuration..."
cat > /etc/gitea/app.ini << EOCONFIG
APP_NAME = Gitea: Git with a cup of tea
RUN_USER = git
RUN_MODE = prod
WORK_PATH = /var/lib/gitea

[server]
DOMAIN           = ${GITEA_DOMAIN}
HTTP_PORT        = ${GITEA_PORT}
ROOT_URL         = http://${GITEA_DOMAIN}:${GITEA_PORT}/
DISABLE_SSH      = false
SSH_DOMAIN       = ${GITEA_DOMAIN}
SSH_PORT         = 22
LFS_START_SERVER = true
OFFLINE_MODE     = false

[database]
DB_TYPE  = ${DB_TYPE}
$(if [[ "$DB_TYPE" == "sqlite3" ]]; then
  echo "PATH     = /var/lib/gitea/data/gitea.db"
else
  echo "HOST     = ${DB_HOST}:$([ "$DB_TYPE" = "postgres" ] && echo 5432 || echo 3306)"
  echo "NAME     = ${DB_NAME}"
  echo "USER     = ${DB_USER}"
  echo "PASSWD   = ${DB_PASS}"
fi)

[repository]
ROOT = /var/lib/gitea/repositories

[service]
REGISTER_EMAIL_CONFIRM = false
ENABLE_NOTIFY_MAIL     = false
DISABLE_REGISTRATION   = false
ALLOW_ONLY_EXTERNAL_REGISTRATION = false
ENABLE_CAPTCHA         = false
REQUIRE_SIGNIN_VIEW    = false
DEFAULT_KEEP_EMAIL_PRIVATE = false

[mailer]
ENABLED = false

[picture]
DISABLE_GRAVATAR        = false
ENABLE_FEDERATED_AVATAR = true

[session]
PROVIDER = file

[log]
MODE      = console
LEVEL     = info
ROOT_PATH = /var/lib/gitea/log
EOCONFIG

chown root:git /etc/gitea/app.ini
chmod 640 /etc/gitea/app.ini

# Step 6: Create systemd service
log "Creating systemd service..."
cat > /etc/systemd/system/gitea.service << 'EOSERVICE'
[Unit]
Description=Gitea (Git with a cup of tea)
After=syslog.target
After=network.target

[Service]
RestartSec=2s
Type=simple
User=git
Group=git
WorkingDirectory=/var/lib/gitea/
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea

[Install]
WantedBy=multi-user.target
EOSERVICE

# Step 7: Start service
log "Starting Gitea..."
systemctl daemon-reload
systemctl enable gitea
systemctl start gitea

# Wait for startup
sleep 3
if systemctl is-active --quiet gitea; then
  log "✅ Gitea is running on http://${GITEA_DOMAIN}:${GITEA_PORT}"
  log ""
  log "Next steps:"
  log "  1. Open http://${GITEA_DOMAIN}:${GITEA_PORT} in your browser"
  log "  2. Create an admin account: bash scripts/manage.sh create-admin --username admin --password 'yourpassword' --email admin@example.com"
  log "  3. Set DISABLE_REGISTRATION=true in /etc/gitea/app.ini after creating your admin"
else
  error "Gitea failed to start. Check: sudo journalctl -u gitea -f"
  exit 1
fi
