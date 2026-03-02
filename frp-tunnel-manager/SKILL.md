---
name: frp-tunnel-manager
description: Install and manage FRP (Fast Reverse Proxy) server/client tunnels with secure defaults and systemd automation.
categories: [dev-tools, automation]
dependencies: [bash, curl, tar, systemctl]
---

# FRP Tunnel Manager

Install, configure, and operate FRP reverse tunnels (frps + frpc) on Linux.

## Quick Start

### 1) Install FRP
```bash
bash scripts/install.sh
```

### 2) Generate server config (frps)
```bash
bash scripts/frp-manager.sh init-server \
  --bind-port 7000 \
  --token "change-me-strong-token"
```

### 3) Generate client config (frpc)
```bash
bash scripts/frp-manager.sh init-client \
  --server-addr "YOUR_SERVER_IP" \
  --server-port 7000 \
  --token "change-me-strong-token" \
  --local-ip 127.0.0.1 \
  --local-port 3000 \
  --remote-port 13000
```

### 4) Manage services
```bash
sudo bash scripts/frp-manager.sh install-systemd-server
sudo bash scripts/frp-manager.sh install-systemd-client
sudo systemctl enable --now frps
sudo systemctl enable --now frpc
```

## Common Workflows

### Check status
```bash
bash scripts/frp-manager.sh status
```

### Restart both services
```bash
sudo bash scripts/frp-manager.sh restart
```

### Validate configs
```bash
bash scripts/frp-manager.sh validate
```

## Files
- Server config: `~/.config/frp/frps.toml`
- Client config: `~/.config/frp/frpc.toml`
- Binaries: `~/.local/bin/frps`, `~/.local/bin/frpc`

## Troubleshooting
- Ensure server port is reachable: `nc -vz <server> 7000`
- Check logs: `journalctl -u frps -u frpc -n 100 --no-pager`
- If token mismatch, regenerate both configs with same `--token`
