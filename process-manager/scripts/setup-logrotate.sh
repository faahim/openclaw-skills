#!/bin/bash
# Install and configure PM2 log rotation
set -e

if ! command -v pm2 &>/dev/null; then
  echo "❌ PM2 not installed. Run: bash scripts/install.sh"
  exit 1
fi

echo "📦 Installing pm2-logrotate..."
pm2 install pm2-logrotate

echo "⚙️ Configuring log rotation..."
# Rotate when file reaches 10MB
pm2 set pm2-logrotate:max_size 10M
# Keep 30 days of logs
pm2 set pm2-logrotate:retain 30
# Compress old logs
pm2 set pm2-logrotate:compress true
# Rotate at midnight
pm2 set pm2-logrotate:rotateInterval '0 0 * * *'
# Use date format in filenames
pm2 set pm2-logrotate:dateFormat YYYY-MM-DD_HH-mm-ss

echo ""
echo "✅ Log rotation configured:"
echo "   Max size: 10MB per file"
echo "   Retention: 30 days"
echo "   Compression: enabled"
echo "   Schedule: daily at midnight"
echo ""
echo "View settings: pm2 conf pm2-logrotate"
