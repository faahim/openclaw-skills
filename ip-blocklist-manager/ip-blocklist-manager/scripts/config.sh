#!/bin/bash
# IP Blocklist Manager — Configuration
# Copy to /etc/ip-blocklist/config.sh and edit

# Threat intelligence feeds
# Format: "name|url|format"
# Formats: ip (one IP per line), cidr (CIDR notation), dshield (DShield block format)
FEEDS=(
  "spamhaus-drop|https://www.spamhaus.org/drop/drop.txt|cidr"
  "spamhaus-edrop|https://www.spamhaus.org/drop/edrop.txt|cidr"
  "blocklist-de|https://lists.blocklist.de/lists/all.txt|ip"
  "emerging-threats|https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt|ip"
  "dshield-top20|https://feeds.dshield.org/block.txt|dshield"
  "firehol-level1|https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset|cidr"
)

# ipset configuration
IPSET_NAME="blocklist"
IPSET_MAXELEM=200000
IPSET_HASHSIZE=16384

# Firewall backend: "iptables" or "nftables"
FIREWALL_BACKEND="iptables"

# Firewall chain name
CHAIN_NAME="BLOCKLIST"

# Logging
LOG_BLOCKED=true
LOG_PREFIX="[BLOCKED] "

# Whitelist
WHITELIST_FILE="/etc/ip-blocklist/whitelist.txt"

# Cron schedule
CRON_SCHEDULE="0 */6 * * *"

# Directories
DATA_DIR="/var/lib/ip-blocklist"
LOG_DIR="/var/log/ip-blocklist"

# Telegram notifications (optional)
NOTIFY_ON_UPDATE=false
# TELEGRAM_BOT_TOKEN="your-bot-token"
# TELEGRAM_CHAT_ID="your-chat-id"
