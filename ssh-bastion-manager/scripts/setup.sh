#!/usr/bin/env bash
set -euo pipefail

SSH_PORT=22
ADMIN_USER=""
ALLOW_CIDR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-port) SSH_PORT="$2"; shift 2;;
    --admin-user) ADMIN_USER="$2"; shift 2;;
    --allow-cidr) ALLOW_CIDR="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

if [[ -z "$ADMIN_USER" ]]; then
  echo "--admin-user is required" >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

SSHD=/etc/ssh/sshd_config
cp "$SSHD" "${SSHD}.bak.$(date +%s)"

set_conf() {
  local key="$1" val="$2"
  if grep -Eq "^#?\s*${key}\s+" "$SSHD"; then
    sed -i -E "s|^#?\s*${key}\s+.*|${key} ${val}|" "$SSHD"
  else
    echo "${key} ${val}" >> "$SSHD"
  fi
}

set_conf Port "$SSH_PORT"
set_conf PermitRootLogin no
set_conf PasswordAuthentication no
set_conf PubkeyAuthentication yes
set_conf ChallengeResponseAuthentication no
set_conf UsePAM yes
set_conf AllowUsers "$ADMIN_USER"

sshd -t
systemctl restart ssh || systemctl restart sshd

ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT"/tcp
if [[ -n "$ALLOW_CIDR" ]]; then
  ufw allow from "$ALLOW_CIDR" to any port "$SSH_PORT" proto tcp
fi

cat > /etc/fail2ban/jail.d/sshd.local <<JAIL
[sshd]
enabled = true
port = $SSH_PORT
maxretry = 5
findtime = 10m
bantime = 1h
JAIL

systemctl enable fail2ban
systemctl restart fail2ban

echo "Bastion hardened on SSH port $SSH_PORT"
