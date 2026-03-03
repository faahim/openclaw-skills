#!/bin/bash
# Mailpit Runner — start, stop, manage Mailpit instances
set -e

SMTP_PORT=1025
UI_PORT=8025
PID_FILE="/tmp/mailpit.pid"
LOG_FILE="/tmp/mailpit.log"
DB_FILE="/tmp/mailpit.db"
ACTION="${1:-help}"
shift 2>/dev/null || true

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --smtp) SMTP_PORT="$2"; shift 2 ;;
    --ui) UI_PORT="$2"; shift 2 ;;
    --db) DB_FILE="$2"; shift 2 ;;
    --relay-host) RELAY_HOST="$2"; shift 2 ;;
    --relay-port) RELAY_PORT="$2"; shift 2 ;;
    --relay-user) RELAY_USER="$2"; shift 2 ;;
    --relay-pass) RELAY_PASS="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

find_mailpit() {
  if command -v mailpit &>/dev/null; then
    echo "mailpit"
  elif [ -f "$HOME/.local/bin/mailpit" ]; then
    echo "$HOME/.local/bin/mailpit"
  else
    echo ""
  fi
}

build_args() {
  local args="--smtp 0.0.0.0:${SMTP_PORT} --listen 0.0.0.0:${UI_PORT} --database ${DB_FILE}"
  if [ -n "$RELAY_HOST" ]; then
    args="$args --smtp-relay-host $RELAY_HOST"
    [ -n "$RELAY_PORT" ] && args="$args --smtp-relay-port $RELAY_PORT"
    [ -n "$RELAY_USER" ] && args="$args --smtp-relay-username $RELAY_USER"
    [ -n "$RELAY_PASS" ] && args="$args --smtp-relay-password $RELAY_PASS"
  fi
  echo "$args"
}

is_running() {
  if [ -f "$PID_FILE" ]; then
    local pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    rm -f "$PID_FILE"
  fi
  return 1
}

case $ACTION in
  start)
    MAILPIT=$(find_mailpit)
    if [ -z "$MAILPIT" ]; then
      echo "❌ Mailpit not found. Run: bash scripts/install.sh"
      exit 1
    fi

    if is_running; then
      echo "⚠️  Mailpit already running (PID: $(cat $PID_FILE))"
      echo "   SMTP: localhost:${SMTP_PORT}"
      echo "   Web:  http://localhost:${UI_PORT}"
      exit 0
    fi

    echo "🚀 Starting Mailpit..."
    ARGS=$(build_args)
    $MAILPIT $ARGS &
    echo $! > "$PID_FILE"
    sleep 1

    if is_running; then
      echo "✅ Mailpit running"
      echo "   SMTP: localhost:${SMTP_PORT}"
      echo "   Web:  http://localhost:${UI_PORT}"
      echo "   PID:  $(cat $PID_FILE)"
    else
      echo "❌ Mailpit failed to start. Check logs:"
      echo "   $LOG_FILE"
      exit 1
    fi
    ;;

  daemon)
    MAILPIT=$(find_mailpit)
    if [ -z "$MAILPIT" ]; then
      echo "❌ Mailpit not found. Run: bash scripts/install.sh"
      exit 1
    fi

    # Try systemd first
    if command -v systemctl &>/dev/null && [ "$(id -u)" = "0" ] || command -v sudo &>/dev/null; then
      MAILPIT_PATH=$(which mailpit 2>/dev/null || echo "$HOME/.local/bin/mailpit")
      cat > /tmp/mailpit.service <<EOF
[Unit]
Description=Mailpit Email Testing Server
After=network.target

[Service]
Type=simple
ExecStart=${MAILPIT_PATH} --smtp 0.0.0.0:${SMTP_PORT} --listen 0.0.0.0:${UI_PORT} --database ${DB_FILE}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
      sudo mv /tmp/mailpit.service /etc/systemd/system/mailpit.service
      sudo systemctl daemon-reload
      sudo systemctl enable mailpit
      sudo systemctl start mailpit
      echo "✅ Mailpit daemon started (systemd)"
      echo "   SMTP: localhost:${SMTP_PORT}"
      echo "   Web:  http://localhost:${UI_PORT}"
      echo "   Manage: sudo systemctl {status|stop|restart} mailpit"
    else
      # Fallback to nohup
      ARGS=$(build_args)
      nohup $MAILPIT $ARGS > "$LOG_FILE" 2>&1 &
      echo $! > "$PID_FILE"
      echo "✅ Mailpit daemon started (nohup)"
      echo "   SMTP: localhost:${SMTP_PORT}"
      echo "   Web:  http://localhost:${UI_PORT}"
      echo "   Logs: $LOG_FILE"
    fi
    ;;

  stop)
    if systemctl is-active mailpit &>/dev/null 2>&1; then
      sudo systemctl stop mailpit
      echo "✅ Mailpit stopped (systemd)"
    elif is_running; then
      kill $(cat "$PID_FILE")
      rm -f "$PID_FILE"
      echo "✅ Mailpit stopped"
    else
      echo "ℹ️  Mailpit is not running"
    fi
    ;;

  status)
    if systemctl is-active mailpit &>/dev/null 2>&1; then
      echo "✅ Mailpit running (systemd)"
      systemctl status mailpit --no-pager | head -5
    elif is_running; then
      echo "✅ Mailpit running (PID: $(cat $PID_FILE))"
      echo "   SMTP: localhost:${SMTP_PORT}"
      echo "   Web:  http://localhost:${UI_PORT}"
    else
      echo "❌ Mailpit is not running"
    fi
    ;;

  logs)
    if [ -f "$LOG_FILE" ]; then
      tail -50 "$LOG_FILE"
    else
      echo "No log file found at $LOG_FILE"
      # Try journalctl
      journalctl -u mailpit --no-pager -n 50 2>/dev/null || true
    fi
    ;;

  test)
    echo "📧 Sending test email to localhost:${SMTP_PORT}..."

    # Use built-in tools to send a test email
    if command -v python3 &>/dev/null; then
      python3 -c "
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

msg = MIMEMultipart('alternative')
msg['Subject'] = '🎉 Mailpit Test Email'
msg['From'] = 'test@example.com'
msg['To'] = 'dev@example.com'

text = 'Hello! This is a test email captured by Mailpit.'
html = '<html><body><h1>🎉 It works!</h1><p>This email was captured by <strong>Mailpit</strong>.</p><p>Your local SMTP server is configured correctly.</p></body></html>'

msg.attach(MIMEText(text, 'plain'))
msg.attach(MIMEText(html, 'html'))

with smtplib.SMTP('127.0.0.1', ${SMTP_PORT}) as server:
    server.sendmail('test@example.com', 'dev@example.com', msg.as_string())
print('✅ Test email sent! Check http://localhost:${UI_PORT}')
"
    elif command -v curl &>/dev/null; then
      # Use curl with SMTP
      curl --url "smtp://localhost:${SMTP_PORT}" \
        --mail-from "test@example.com" \
        --mail-rcpt "dev@example.com" \
        -T - <<EOF
From: Test <test@example.com>
To: Dev <dev@example.com>
Subject: Mailpit Test Email
Content-Type: text/plain

Hello! This is a test email captured by Mailpit.
EOF
      echo "✅ Test email sent! Check http://localhost:${UI_PORT}"
    else
      echo "❌ Need python3 or curl to send test email"
      exit 1
    fi
    ;;

  help|*)
    echo "Mailpit Email Testing Server"
    echo ""
    echo "Usage: bash scripts/run.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start    Start Mailpit (foreground-ish, with PID tracking)"
    echo "  daemon   Start as persistent background service"
    echo "  stop     Stop Mailpit"
    echo "  status   Check if Mailpit is running"
    echo "  logs     View recent logs"
    echo "  test     Send a test email"
    echo "  help     Show this help"
    echo ""
    echo "Options:"
    echo "  --smtp <port>       SMTP port (default: 1025)"
    echo "  --ui <port>         Web UI port (default: 8025)"
    echo "  --db <path>         Database file path"
    echo "  --relay-host <host> SMTP relay host (forward emails)"
    echo "  --relay-port <port> SMTP relay port"
    echo "  --relay-user <user> SMTP relay username"
    echo "  --relay-pass <pass> SMTP relay password"
    ;;
esac
