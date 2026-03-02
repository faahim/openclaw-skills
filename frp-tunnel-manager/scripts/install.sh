#!/usr/bin/env bash
set -euo pipefail
VER="${FRP_VERSION:-0.61.2}"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) PKG_ARCH="amd64" ;;
  aarch64|arm64) PKG_ARCH="arm64" ;;
  *) echo "Unsupported arch: $ARCH"; exit 1 ;;
esac
TMP=$(mktemp -d)
URL="https://github.com/fatedier/frp/releases/download/v${VER}/frp_${VER}_linux_${PKG_ARCH}.tar.gz"
echo "Downloading $URL"
curl -fsSL "$URL" -o "$TMP/frp.tgz"
tar -xzf "$TMP/frp.tgz" -C "$TMP"
DIR=$(find "$TMP" -maxdepth 1 -type d -name "frp_*_linux_*" | head -n1)
mkdir -p "$HOME/.local/bin"
install -m 0755 "$DIR/frps" "$HOME/.local/bin/frps"
install -m 0755 "$DIR/frpc" "$HOME/.local/bin/frpc"
mkdir -p "$HOME/.config/frp"
echo "Installed frps/frpc to $HOME/.local/bin"
