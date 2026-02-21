#!/bin/bash
# Log Analyzer Configuration
# Copy this file to config.sh and edit as needed

# Telegram alerts
export TELEGRAM_BOT_TOKEN=""
export TELEGRAM_CHAT_ID=""

# Webhook alerts (Slack, Discord, etc.)
export ALERT_WEBHOOK_URL=""

# Default error/warning patterns
export LOG_ERROR_PATTERN="ERROR|error|FATAL|fatal|CRITICAL|CRIT|PANIC|panic|EMERGENCY|EMERG|Failed|failed"
export LOG_WARN_PATTERN="WARN|warn|WARNING|warning"

# Monitor defaults
export LOG_MONITOR_THRESHOLD=10      # errors per interval to trigger alert
export LOG_MONITOR_INTERVAL=300      # check interval in seconds
export LOG_MONITOR_COOLDOWN=1800     # min seconds between alerts
