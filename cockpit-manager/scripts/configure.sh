#!/bin/bash
# Cockpit Web Console — Configuration Manager

set -euo pipefail

CONF_FILE="/etc/cockpit/cockpit.conf"

show_config() {
  echo "Current Cockpit Configuration"
  echo "═════════════════════════════"
  if [ -f "$CONF_FILE" ]; then
    cat "$CONF_FILE"
  else
    echo "(No custom config — using defaults)"
    echo "Port: 9090, IdleTimeout: 15 min"
  fi
  echo ""
  
  # Show socket override if exists
  if [ -f /etc/systemd/system/cockpit.socket.d/listen.conf ]; then
    echo "Socket Override:"
    cat /etc/systemd/system/cockpit.socket.d/listen.conf
  fi
}

ensure_config() {
  sudo mkdir -p /etc/cockpit
  if [ ! -f "$CONF_FILE" ]; then
    sudo tee "$CONF_FILE" > /dev/null <<'EOF'
[WebService]
LoginTitle = Cockpit

[Session]
IdleTimeout = 15
EOF
  fi
}

set_ini_value() {
  local section=$1 key=$2 value=$3
  ensure_config
  
  if grep -q "^\[${section}\]" "$CONF_FILE" 2>/dev/null; then
    if grep -q "^${key}" "$CONF_FILE" 2>/dev/null; then
      sudo sed -i "s|^${key}.*|${key} = ${value}|" "$CONF_FILE"
    else
      sudo sed -i "/^\[${section}\]/a ${key} = ${value}" "$CONF_FILE"
    fi
  else
    echo -e "\n[${section}]\n${key} = ${value}" | sudo tee -a "$CONF_FILE" > /dev/null
  fi
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --show)
      show_config
      exit 0
      ;;

    --port)
      PORT=$2; shift 2
      echo "🔧 Setting port to $PORT..."
      sudo mkdir -p /etc/systemd/system/cockpit.socket.d
      sudo tee /etc/systemd/system/cockpit.socket.d/listen.conf > /dev/null <<EOF
[Socket]
ListenStream=
ListenStream=${PORT}
EOF
      sudo systemctl daemon-reload
      sudo systemctl restart cockpit.socket
      echo "✅ Cockpit now listening on port $PORT"
      
      # Update firewall
      if command -v ufw &>/dev/null; then
        sudo ufw allow "${PORT}/tcp" 2>/dev/null || true
      elif command -v firewall-cmd &>/dev/null; then
        sudo firewall-cmd --add-port="${PORT}/tcp" --permanent 2>/dev/null && sudo firewall-cmd --reload || true
      fi
      ;;

    --idle-timeout)
      TIMEOUT=$2; shift 2
      set_ini_value "Session" "IdleTimeout" "$TIMEOUT"
      echo "✅ Idle timeout set to ${TIMEOUT} minutes"
      ;;

    --allow-from)
      ALLOWED=$2; shift 2
      set_ini_value "WebService" "AllowUnencrypted" "false"
      set_ini_value "WebService" "Origins" "https://${ALLOWED}"
      echo "✅ Access restricted to: $ALLOWED"
      echo "⚠️  Note: Use firewall rules (ufw/iptables) for IP-level restrictions"
      ;;

    --banner)
      BANNER_TEXT=$2; shift 2
      echo "$BANNER_TEXT" | sudo tee /etc/cockpit/issue.cockpit > /dev/null
      set_ini_value "Session" "Banner" "/etc/cockpit/issue.cockpit"
      echo "✅ Login banner set"
      ;;

    --ssl-cert)
      CERT=$2; shift 2
      KEY=""
      if [[ "${1:-}" == "--ssl-key" ]]; then
        KEY=$2; shift 2
      fi
      
      sudo mkdir -p /etc/cockpit/ws-certs.d
      if [ -n "$KEY" ]; then
        sudo cat "$CERT" "$KEY" | sudo tee /etc/cockpit/ws-certs.d/custom.cert > /dev/null
      else
        sudo cp "$CERT" /etc/cockpit/ws-certs.d/custom.cert
      fi
      sudo systemctl restart cockpit
      echo "✅ SSL certificate installed"
      ;;

    --generate-ssl)
      DOMAIN=${2:-$(hostname -f)}; shift 2 2>/dev/null || shift
      echo "🔐 Generating self-signed cert for $DOMAIN..."
      sudo mkdir -p /etc/cockpit/ws-certs.d
      sudo openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout /tmp/cockpit.key \
        -out /tmp/cockpit.crt \
        -subj "/CN=${DOMAIN}" 2>/dev/null
      sudo cat /tmp/cockpit.crt /tmp/cockpit.key | sudo tee /etc/cockpit/ws-certs.d/custom.cert > /dev/null
      rm -f /tmp/cockpit.key /tmp/cockpit.crt
      sudo systemctl restart cockpit
      echo "✅ Self-signed cert generated for $DOMAIN (valid 365 days)"
      ;;

    --enable-autostart)
      shift
      sudo systemctl enable cockpit.socket
      echo "✅ Cockpit auto-start enabled"
      ;;

    --proxy-config)
      PROXY_TYPE=${2:-nginx}; shift 2
      case "$PROXY_TYPE" in
        nginx)
          cat <<'NGINX'
# Nginx reverse proxy config for Cockpit
# Save to /etc/nginx/sites-available/cockpit
server {
    listen 443 ssl http2;
    server_name cockpit.example.com;

    ssl_certificate /etc/letsencrypt/live/cockpit.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cockpit.example.com/privkey.pem;

    location / {
        proxy_pass https://127.0.0.1:9090;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support (required for terminal)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_read_timeout 1800s;
        proxy_send_timeout 1800s;
    }
}
NGINX
          ;;
        *)
          echo "❌ Unsupported proxy type: $PROXY_TYPE (supported: nginx)"
          exit 1
          ;;
      esac
      ;;

    --backup)
      DEST=${2:-cockpit-backup.tar.gz}; shift 2
      echo "📦 Backing up Cockpit config..."
      sudo tar -czf "$DEST" /etc/cockpit/ /etc/systemd/system/cockpit.socket.d/ 2>/dev/null || \
        sudo tar -czf "$DEST" /etc/cockpit/ 2>/dev/null
      echo "✅ Backup saved to $DEST"
      ;;

    --restore)
      SRC=$2; shift 2
      echo "📦 Restoring Cockpit config from $SRC..."
      sudo tar -xzf "$SRC" -C /
      sudo systemctl daemon-reload
      sudo systemctl restart cockpit.socket
      echo "✅ Config restored and Cockpit restarted"
      ;;

    --help|-h)
      echo "Usage: configure.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --show                   Show current configuration"
      echo "  --port PORT              Set listening port (default: 9090)"
      echo "  --idle-timeout MINS      Set session idle timeout"
      echo "  --allow-from CIDR        Restrict access to network range"
      echo "  --banner TEXT            Set login banner message"
      echo "  --ssl-cert FILE [--ssl-key FILE]  Install SSL certificate"
      echo "  --generate-ssl [DOMAIN]  Generate self-signed certificate"
      echo "  --enable-autostart       Enable start on boot"
      echo "  --proxy-config nginx     Generate reverse proxy config"
      echo "  --backup FILE            Backup all configs"
      echo "  --restore FILE           Restore configs from backup"
      exit 0
      ;;

    *)
      echo "Unknown option: $1 (use --help)"
      exit 1
      ;;
  esac
done
