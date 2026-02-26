#!/bin/bash
# MongoDB Installation Script
# Supports Ubuntu/Debian and RHEL/CentOS/Amazon Linux

set -euo pipefail

VERSION="8.0"
ENABLE_AUTH=false
DBPATH=""

usage() {
  echo "Usage: $0 [--version VERSION] [--auth] [--dbpath PATH]"
  echo ""
  echo "Options:"
  echo "  --version   MongoDB version (default: 8.0)"
  echo "  --auth      Enable authentication after install"
  echo "  --dbpath    Custom data directory"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --version) VERSION="$2"; shift 2 ;;
    --auth) ENABLE_AUTH=true; shift ;;
    --dbpath) DBPATH="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
  else
    echo "❌ Cannot detect OS. Supported: Ubuntu, Debian, CentOS, RHEL, Amazon Linux"
    exit 1
  fi
}

install_ubuntu_debian() {
  echo "📦 Installing MongoDB $VERSION on $OS $OS_VERSION..."

  # Import GPG key
  curl -fsSL "https://www.mongodb.org/static/pgp/server-${VERSION}.asc" | \
    sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-${VERSION}.gpg 2>/dev/null || true

  # Add repository
  if [[ "$OS" == "ubuntu" ]]; then
    CODENAME=$(lsb_release -cs)
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-${VERSION}.gpg ] https://repo.mongodb.org/apt/ubuntu ${CODENAME}/mongodb-org/${VERSION} multiverse" | \
      sudo tee /etc/apt/sources.list.d/mongodb-org-${VERSION}.list
  else
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-${VERSION}.gpg ] https://repo.mongodb.org/apt/debian $(lsb_release -cs)/mongodb-org/${VERSION} main" | \
      sudo tee /etc/apt/sources.list.d/mongodb-org-${VERSION}.list
  fi

  sudo apt-get update -qq
  sudo apt-get install -y mongodb-org mongodb-org-tools mongodb-org-shell

  echo "✅ MongoDB $VERSION installed"
}

install_rhel() {
  echo "📦 Installing MongoDB $VERSION on $OS $OS_VERSION..."

  cat <<EOF | sudo tee /etc/yum.repos.d/mongodb-org-${VERSION}.repo
[mongodb-org-${VERSION}]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/${VERSION}/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-${VERSION}.asc
EOF

  sudo yum install -y mongodb-org mongodb-org-tools mongodb-org-shell

  echo "✅ MongoDB $VERSION installed"
}

configure() {
  # Custom data directory
  if [[ -n "$DBPATH" ]]; then
    echo "📁 Setting data directory to $DBPATH..."
    sudo mkdir -p "$DBPATH"
    sudo chown mongod:mongod "$DBPATH"
    sudo sed -i "s|dbPath:.*|dbPath: $DBPATH|" /etc/mongod.conf
  fi

  # Enable authentication
  if [[ "$ENABLE_AUTH" == true ]]; then
    echo "🔐 Enabling authentication..."
    if ! grep -q "authorization: enabled" /etc/mongod.conf; then
      sudo sed -i '/^security:/a\  authorization: enabled' /etc/mongod.conf 2>/dev/null || \
        echo -e "\nsecurity:\n  authorization: enabled" | sudo tee -a /etc/mongod.conf
    fi
  fi

  # Bind to localhost by default (secure)
  sudo sed -i 's/bindIp:.*/bindIp: 127.0.0.1/' /etc/mongod.conf
}

start_service() {
  echo "🚀 Starting MongoDB..."
  sudo systemctl daemon-reload
  sudo systemctl enable mongod
  sudo systemctl start mongod

  # Wait for startup
  for i in {1..10}; do
    if mongosh --quiet --eval "db.runCommand({ping:1})" &>/dev/null; then
      echo "✅ MongoDB is running!"
      mongosh --quiet --eval "db.version()" | xargs -I{} echo "   Version: {}"
      mongosh --quiet --eval "db.serverStatus().host" | xargs -I{} echo "   Host: {}"
      return 0
    fi
    sleep 1
  done

  echo "⚠️ MongoDB started but not yet responding. Check: sudo systemctl status mongod"
}

# Main
detect_os

case $OS in
  ubuntu|debian) install_ubuntu_debian ;;
  centos|rhel|amzn|fedora) install_rhel ;;
  *)
    echo "❌ Unsupported OS: $OS"
    echo "   Supported: Ubuntu, Debian, CentOS, RHEL, Amazon Linux, Fedora"
    exit 1
    ;;
esac

configure
start_service

echo ""
echo "📋 Next steps:"
echo "   1. Create admin user: bash scripts/manage.sh create-user --db admin --user admin --role root --pass YOUR_PASSWORD"
echo "   2. Check status: bash scripts/monitor.sh status"
echo "   3. Connect: mongosh"
