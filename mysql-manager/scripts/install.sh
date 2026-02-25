#!/bin/bash
# MySQL/MariaDB Installation Script
set -euo pipefail

FLAVOR="${1:-mariadb}"  # mariadb or mysql

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
err() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1" >&2; exit 1; }

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  else
    err "Unsupported OS"
  fi
}

install_mariadb() {
  local os=$(detect_os)
  log "Installing MariaDB on $os..."

  case "$os" in
    ubuntu|debian)
      sudo apt-get update -qq
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client
      ;;
    centos|rhel|rocky|alma|fedora)
      sudo dnf install -y mariadb-server mariadb
      sudo systemctl enable mariadb
      ;;
    arch|manjaro)
      sudo pacman -S --noconfirm mariadb
      sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
      ;;
    alpine)
      sudo apk add mariadb mariadb-client mariadb-openrc
      sudo /etc/init.d/mariadb setup
      ;;
    *)
      err "Unsupported OS: $os. Install MariaDB manually."
      ;;
  esac

  sudo systemctl start mariadb 2>/dev/null || sudo service mariadb start 2>/dev/null || true
  log "✅ MariaDB installed and running"
}

install_mysql() {
  local os=$(detect_os)
  log "Installing MySQL on $os..."

  case "$os" in
    ubuntu|debian)
      sudo apt-get update -qq
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server mysql-client
      ;;
    centos|rhel|rocky|alma|fedora)
      sudo dnf install -y mysql-server mysql
      sudo systemctl enable mysqld
      ;;
    arch|manjaro)
      # MySQL not in official repos on Arch, suggest MariaDB
      err "MySQL not available on Arch. Use: bash install.sh mariadb"
      ;;
    *)
      err "Unsupported OS: $os. Install MySQL manually."
      ;;
  esac

  sudo systemctl start mysql 2>/dev/null || sudo systemctl start mysqld 2>/dev/null || true
  log "✅ MySQL installed and running"
}

setup_root_auth() {
  log "Setting up root authentication..."

  # Generate random root password
  ROOT_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)

  # Try to set root password (might already have one)
  if sudo mysql -e "SELECT 1" 2>/dev/null; then
    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASS}';" 2>/dev/null || \
    sudo mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${ROOT_PASS}');" 2>/dev/null || true
  fi

  # Write credentials file
  cat > ~/.my.cnf << EOF
[client]
user=root
password=${ROOT_PASS}
EOF
  chmod 600 ~/.my.cnf

  log "✅ Root credentials saved to ~/.my.cnf"
  log "🔑 Root password: ${ROOT_PASS}"
  log "⚠️  Save this password! It won't be shown again."
}

verify_installation() {
  log "Verifying installation..."

  if mysql -e "SELECT VERSION();" 2>/dev/null | head -2; then
    log "✅ MySQL/MariaDB is working"
  elif sudo mysql -e "SELECT VERSION();" 2>/dev/null | head -2; then
    log "✅ MySQL/MariaDB is working (via sudo)"
    setup_root_auth
  else
    err "Installation verification failed"
  fi
}

# Main
case "$FLAVOR" in
  mariadb) install_mariadb ;;
  mysql)   install_mysql ;;
  *)       err "Usage: bash install.sh [mariadb|mysql]" ;;
esac

verify_installation

log "🎉 Installation complete. Run: bash scripts/manage.sh secure"
