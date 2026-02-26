#!/bin/bash
# Gracefully stop Minecraft server
set -euo pipefail

MC_DIR="${MC_DIR:-$HOME/minecraft-server}"
MC_SCREEN="${MC_SCREEN:-minecraft}"

if ! screen -list | grep -q "\.$MC_SCREEN\b"; then
  echo "⚠️  Server not running"
  exit 0
fi

echo "📢 Warning players..."
screen -S "$MC_SCREEN" -X stuff "say Server shutting down in 10 seconds...\n"
sleep 5
screen -S "$MC_SCREEN" -X stuff "say Server shutting down in 5 seconds...\n"
sleep 5

echo "💾 Saving world..."
screen -S "$MC_SCREEN" -X stuff "save-all\n"
sleep 3

echo "🛑 Stopping server..."
screen -S "$MC_SCREEN" -X stuff "stop\n"

# Wait for server to stop (max 30s)
for i in $(seq 1 30); do
  if ! screen -list | grep -q "\.$MC_SCREEN\b"; then
    echo "✅ Server stopped"
    exit 0
  fi
  sleep 1
done

echo "⚠️  Server didn't stop cleanly. Force killing..."
screen -S "$MC_SCREEN" -X quit
echo "✅ Server force-stopped"
