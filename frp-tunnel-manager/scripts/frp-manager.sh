#!/usr/bin/env bash
set -euo pipefail
CFG_DIR="$HOME/.config/frp"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$CFG_DIR"

usage(){ echo "Usage: $0 <init-server|init-client|install-systemd-server|install-systemd-client|status|restart|validate> [args]"; }

init_server(){
  local bind_port=7000 token=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bind-port) bind_port="$2"; shift 2;;
      --token) token="$2"; shift 2;;
      *) echo "Unknown arg: $1"; exit 1;;
    esac
  done
  [[ -n "$token" ]] || { echo "--token required"; exit 1; }
  cat > "$CFG_DIR/frps.toml" <<TOML
bindPort = ${bind_port}
auth.method = "token"
auth.token = "${token}"
TOML
  echo "Wrote $CFG_DIR/frps.toml"
}

init_client(){
  local server_addr="" server_port=7000 token="" local_ip="127.0.0.1" local_port="" remote_port=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --server-addr) server_addr="$2"; shift 2;;
      --server-port) server_port="$2"; shift 2;;
      --token) token="$2"; shift 2;;
      --local-ip) local_ip="$2"; shift 2;;
      --local-port) local_port="$2"; shift 2;;
      --remote-port) remote_port="$2"; shift 2;;
      *) echo "Unknown arg: $1"; exit 1;;
    esac
  done
  [[ -n "$server_addr" && -n "$token" && -n "$local_port" && -n "$remote_port" ]] || { echo "Missing required args"; exit 1; }
  cat > "$CFG_DIR/frpc.toml" <<TOML
serverAddr = "${server_addr}"
serverPort = ${server_port}
auth.method = "token"
auth.token = "${token}"

[[proxies]]
name = "tcp-${remote_port}"
type = "tcp"
localIP = "${local_ip}"
localPort = ${local_port}
remotePort = ${remote_port}
TOML
  echo "Wrote $CFG_DIR/frpc.toml"
}

install_systemd_server(){
  sudo tee /etc/systemd/system/frps.service >/dev/null <<UNIT
[Unit]
Description=FRP Server
After=network.target
[Service]
Type=simple
ExecStart=${BIN_DIR}/frps -c ${CFG_DIR}/frps.toml
Restart=on-failure
User=${USER}
[Install]
WantedBy=multi-user.target
UNIT
  sudo systemctl daemon-reload
  echo "Installed frps.service"
}

install_systemd_client(){
  sudo tee /etc/systemd/system/frpc.service >/dev/null <<UNIT
[Unit]
Description=FRP Client
After=network.target
[Service]
Type=simple
ExecStart=${BIN_DIR}/frpc -c ${CFG_DIR}/frpc.toml
Restart=on-failure
User=${USER}
[Install]
WantedBy=multi-user.target
UNIT
  sudo systemctl daemon-reload
  echo "Installed frpc.service"
}

status(){ systemctl status frps frpc --no-pager || true; }
restart(){ sudo systemctl restart frps frpc; }
validate(){
  [[ -x "$BIN_DIR/frps" && -x "$BIN_DIR/frpc" ]] || { echo "frp binaries missing"; exit 1; }
  [[ -f "$CFG_DIR/frps.toml" ]] && "$BIN_DIR/frps" -c "$CFG_DIR/frps.toml" -v >/dev/null || true
  [[ -f "$CFG_DIR/frpc.toml" ]] && "$BIN_DIR/frpc" -c "$CFG_DIR/frpc.toml" -v >/dev/null || true
  echo "Validation complete"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  init-server) init_server "$@" ;;
  init-client) init_client "$@" ;;
  install-systemd-server) install_systemd_server ;;
  install-systemd-client) install_systemd_client ;;
  status) status ;;
  restart) restart ;;
  validate) validate ;;
  *) usage; exit 1 ;;
esac
