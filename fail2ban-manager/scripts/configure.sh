#!/bin/bash
# Configure Fail2ban jails
set -e

JAIL=""
MAXRETRY=5
BANTIME=3600
FINDTIME=600
LOGPATH=""
FILTER_REGEX=""
ACTION="iptables-multiport"
ALERT=""
CONFIG=""

usage() {
    echo "Usage: $0 --jail <name> [options]"
    echo ""
    echo "Options:"
    echo "  --jail <name>         Jail name (sshd, nginx-http-auth, custom, etc.)"
    echo "  --maxretry <n>        Max failures before ban (default: 5)"
    echo "  --bantime <seconds>   Ban duration in seconds, -1 for permanent (default: 3600)"
    echo "  --findtime <seconds>  Window to count failures (default: 600)"
    echo "  --logpath <path>      Log file to monitor (for custom jails)"
    echo "  --filter-regex <re>   Regex filter with <HOST> placeholder (for custom jails)"
    echo "  --action <action>     Ban action: iptables-multiport, cloudflare (default: iptables-multiport)"
    echo "  --alert <type>        Alert type: telegram"
    echo "  --config <yaml>       Apply config from YAML file"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --jail) JAIL="$2"; shift 2 ;;
        --maxretry) MAXRETRY="$2"; shift 2 ;;
        --bantime) BANTIME="$2"; shift 2 ;;
        --findtime) FINDTIME="$2"; shift 2 ;;
        --logpath) LOGPATH="$2"; shift 2 ;;
        --filter-regex) FILTER_REGEX="$2"; shift 2 ;;
        --action) ACTION="$2"; shift 2 ;;
        --alert) ALERT="$2"; shift 2 ;;
        --config) CONFIG="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Setup Telegram action if requested
setup_telegram_action() {
    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        echo "❌ Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID environment variables"
        exit 1
    fi

    # Create Telegram action script
    sudo tee /etc/fail2ban/action.d/telegram.conf > /dev/null << 'ACTIONEOF'
[Definition]
actionstart =
actionstop =
actioncheck =
actionban = /etc/fail2ban/scripts/telegram-notify.sh ban <name> <ip> <failures>
actionunban = /etc/fail2ban/scripts/telegram-notify.sh unban <name> <ip>
ACTIONEOF

    sudo mkdir -p /etc/fail2ban/scripts

    sudo tee /etc/fail2ban/scripts/telegram-notify.sh > /dev/null << SCRIPTEOF
#!/bin/bash
ACTION=\$1
JAIL=\$2
IP=\$3
FAILURES=\$4

BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
CHAT_ID="$TELEGRAM_CHAT_ID"

# Try GeoIP lookup
COUNTRY=""
if command -v geoiplookup &>/dev/null; then
    COUNTRY=\$(geoiplookup "\$IP" 2>/dev/null | head -1 | cut -d: -f2 | xargs)
fi

TIMESTAMP=\$(date -u '+%Y-%m-%d %H:%M:%S UTC')

if [ "\$ACTION" = "ban" ]; then
    EMOJI="🚨"
    MSG="\$EMOJI *Fail2ban Alert*
Jail: \$JAIL
Action: BAN
IP: \`\$IP\`
Failures: \$FAILURES
\${COUNTRY:+Country: \$COUNTRY
}Time: \$TIMESTAMP"
else
    EMOJI="✅"
    MSG="\$EMOJI *Fail2ban Alert*
Jail: \$JAIL
Action: UNBAN
IP: \`\$IP\`
Time: \$TIMESTAMP"
fi

curl -s -X POST "https://api.telegram.org/bot\$BOT_TOKEN/sendMessage" \
    -d "chat_id=\$CHAT_ID" \
    -d "text=\$MSG" \
    -d "parse_mode=Markdown" > /dev/null 2>&1
SCRIPTEOF

    sudo chmod +x /etc/fail2ban/scripts/telegram-notify.sh
    echo "✅ Telegram alert action configured"
}

# Setup Cloudflare action if requested
setup_cloudflare_action() {
    if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$CLOUDFLARE_ZONE_ID" ]; then
        echo "❌ Set CLOUDFLARE_API_TOKEN and CLOUDFLARE_ZONE_ID environment variables"
        exit 1
    fi

    sudo tee /etc/fail2ban/action.d/cloudflare-ban.conf > /dev/null << CFEOF
[Definition]
actionstart =
actionstop =
actioncheck =
actionban = curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/firewall/access_rules/rules" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"mode":"block","configuration":{"target":"ip","value":"<ip>"},"notes":"Banned by fail2ban jail <name>"}'
actionunban = RULE_ID=\$(curl -s "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/firewall/access_rules/rules?configuration.value=<ip>" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result[0].id') && \
    curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/firewall/access_rules/rules/\$RULE_ID" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
CFEOF

    echo "✅ Cloudflare ban action configured"
}

# Configure a jail
configure_jail() {
    local jail=$1
    local jail_config=""

    # Determine action string
    local action_str="$ACTION"
    if [ "$ALERT" = "telegram" ]; then
        setup_telegram_action
        action_str="${ACTION}\n              telegram"
    fi
    if [ "$ACTION" = "cloudflare" ]; then
        setup_cloudflare_action
        action_str="cloudflare-ban"
    fi

    # Build jail config
    jail_config="[$jail]
enabled = true
maxretry = $MAXRETRY
bantime = $BANTIME
findtime = $FINDTIME"

    if [ -n "$LOGPATH" ]; then
        jail_config="$jail_config
logpath = $LOGPATH"
    fi

    if [ -n "$FILTER_REGEX" ]; then
        # Create custom filter
        local filter_name="f2b-custom-$jail"
        sudo tee "/etc/fail2ban/filter.d/${filter_name}.conf" > /dev/null << FILTEREOF
[Definition]
failregex = $FILTER_REGEX
ignoreregex =
FILTEREOF
        jail_config="$jail_config
filter = $filter_name"
        echo "📄 Created custom filter: $filter_name"
    fi

    if [ "$ACTION" != "iptables-multiport" ] || [ "$ALERT" = "telegram" ]; then
        jail_config="$jail_config
action = $(echo -e "$action_str")"
    fi

    # Write to jail.local
    local jail_file="/etc/fail2ban/jail.local"

    # Remove existing jail section if present
    if sudo grep -q "^\[$jail\]" "$jail_file" 2>/dev/null; then
        # Use python to remove the section
        sudo python3 -c "
import re
with open('$jail_file', 'r') as f:
    content = f.read()
# Remove the jail section
pattern = r'\[$jail\][^\[]*'
content = re.sub(pattern, '', content)
with open('$jail_file', 'w') as f:
    f.write(content.strip() + '\n\n')
"
    fi

    # Append new config
    echo "" | sudo tee -a "$jail_file" > /dev/null
    echo "$jail_config" | sudo tee -a "$jail_file" > /dev/null

    echo ""
    echo "✅ Jail [$jail] configured:"
    echo "   Max retries: $MAXRETRY"
    echo "   Ban time: ${BANTIME}s$([ "$BANTIME" = "-1" ] && echo ' (permanent)' || echo " ($(($BANTIME/60)) minutes)")"
    echo "   Find time: ${FINDTIME}s ($(($FINDTIME/60)) minutes)"
    [ -n "$LOGPATH" ] && echo "   Log path: $LOGPATH"
    [ -n "$ALERT" ] && echo "   Alert: $ALERT"
    echo "   Action: $action_str"
}

# Main
if [ -z "$JAIL" ] && [ -z "$CONFIG" ]; then
    usage
fi

if [ -n "$CONFIG" ]; then
    echo "📄 Applying config from: $CONFIG"
    # Parse YAML config (basic parser)
    if ! command -v python3 &>/dev/null; then
        echo "❌ python3 required for YAML config parsing"
        exit 1
    fi

    python3 << PYEOF
import yaml, subprocess, os

with open("$CONFIG") as f:
    cfg = yaml.safe_load(f)

# Apply global settings
g = cfg.get('global', {})
if g.get('ignoreip'):
    ips = ' '.join(g['ignoreip'])
    subprocess.run(['sudo', 'fail2ban-client', 'set', 'default', 'ignoreip', ips], check=False)

# Configure jails
for jail_name, jail_cfg in cfg.get('jails', {}).items():
    if not jail_cfg.get('enabled', True):
        continue
    cmd = ['bash', '$0', '--jail', jail_name]
    cmd += ['--maxretry', str(jail_cfg.get('maxretry', g.get('maxretry', 5)))]
    cmd += ['--bantime', str(jail_cfg.get('bantime', g.get('bantime', 3600)))]
    cmd += ['--findtime', str(jail_cfg.get('findtime', g.get('findtime', 600)))]
    if 'logpath' in jail_cfg:
        cmd += ['--logpath', jail_cfg['logpath']]
    if 'filter_regex' in jail_cfg:
        cmd += ['--filter-regex', jail_cfg['filter_regex']]
    subprocess.run(cmd, check=True)

# Configure alerts
alerts = cfg.get('alerts', {})
if 'telegram' in alerts:
    t = alerts['telegram']
    os.environ['TELEGRAM_BOT_TOKEN'] = str(t.get('bot_token', os.environ.get('TELEGRAM_BOT_TOKEN', '')))
    os.environ['TELEGRAM_CHAT_ID'] = str(t.get('chat_id', os.environ.get('TELEGRAM_CHAT_ID', '')))
PYEOF
    echo "✅ Config applied"
else
    configure_jail "$JAIL"
fi

# Reload fail2ban
sudo fail2ban-client reload
echo "✅ Fail2ban reloaded"
