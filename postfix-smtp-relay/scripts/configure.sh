#!/bin/bash
# Postfix SMTP Relay — Configuration Script
# Configures Postfix to relay outbound email through an SMTP provider

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}✅${NC} $1"; }
warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
error() { echo -e "${RED}❌${NC} $1"; exit 1; }

# Defaults
HOST=""
PORT="587"
USER=""
PASS=""
FROM=""
PROVIDER=""
RATE_LIMIT=""
REWRITE_FROM=""
DESTINATION=""
TEST_ONLY=false

# Provider presets
declare -A PROVIDERS
PROVIDERS[gmail]="smtp.gmail.com:587"
PROVIDERS[sendgrid]="smtp.sendgrid.net:587"
PROVIDERS[mailgun]="smtp.mailgun.org:587"
PROVIDERS[ses]="email-smtp.us-east-1.amazonaws.com:587"
PROVIDERS[outlook]="smtp.office365.com:587"
PROVIDERS[zoho]="smtp.zoho.com:587"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Provider preset:"
    echo "  --provider <name>    gmail|sendgrid|mailgun|ses|outlook|zoho"
    echo ""
    echo "Custom SMTP:"
    echo "  --host <hostname>    SMTP server hostname"
    echo "  --port <port>        SMTP port (default: 587)"
    echo ""
    echo "Authentication:"
    echo "  --user <username>    SMTP username"
    echo "  --password <pass>    SMTP password/API key"
    echo ""
    echo "Optional:"
    echo "  --from <address>     Default sender address"
    echo "  --rewrite-from <addr> Rewrite all From addresses"
    echo "  --rate-limit <n>     Max messages per minute"
    echo "  --destination <dom>  Apply config to specific destination domain only"
    echo "  --test               Test connection without saving"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --provider) PROVIDER="$2"; shift 2 ;;
        --host) HOST="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --user) USER="$2"; shift 2 ;;
        --password) PASS="$2"; shift 2 ;;
        --from) FROM="$2"; shift 2 ;;
        --rewrite-from) REWRITE_FROM="$2"; shift 2 ;;
        --rate-limit) RATE_LIMIT="$2"; shift 2 ;;
        --destination) DESTINATION="$2"; shift 2 ;;
        --test) TEST_ONLY=true; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Resolve provider preset
if [[ -n "$PROVIDER" ]]; then
    if [[ -z "${PROVIDERS[$PROVIDER]+x}" ]]; then
        error "Unknown provider: $PROVIDER. Options: ${!PROVIDERS[*]}"
    fi
    IFS=':' read -r HOST PORT <<< "${PROVIDERS[$PROVIDER]}"
    info "Using $PROVIDER preset: $HOST:$PORT"
fi

# Use env vars as fallback
HOST="${HOST:-${SMTP_HOST:-}}"
PORT="${PORT:-${SMTP_PORT:-587}}"
USER="${USER:-${SMTP_USER:-}}"
PASS="${PASS:-${SMTP_PASS:-}}"
FROM="${FROM:-${SMTP_FROM:-}}"

# Validate
[[ -z "$HOST" ]] && error "Missing --host or --provider"
[[ -z "$USER" ]] && error "Missing --user"
[[ -z "$PASS" ]] && error "Missing --password"

# Check root/sudo
if [[ $EUID -ne 0 ]]; then
    if command -v sudo &>/dev/null; then
        SUDO="sudo"
    else
        error "This script must be run as root or with sudo"
    fi
else
    SUDO=""
fi

# Test connection if requested
if [[ "$TEST_ONLY" == true ]]; then
    echo -e "${CYAN}🔍 Testing connection to $HOST:$PORT...${NC}"
    if timeout 10 bash -c "echo | openssl s_client -connect $HOST:$PORT -starttls smtp -quiet 2>/dev/null" | grep -q "Verify return code: 0"; then
        info "TLS connection to $HOST:$PORT successful"
    else
        warn "Could not verify TLS — connection may still work"
    fi
    exit 0
fi

echo "📧 Configuring Postfix SMTP Relay"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Relay: $HOST:$PORT"
echo "  User:  $USER"
echo ""

# Backup existing config
BACKUP="/etc/postfix/main.cf.bak.$(date +%Y%m%d%H%M%S)"
$SUDO cp /etc/postfix/main.cf "$BACKUP" 2>/dev/null || true
info "Backed up config to $BACKUP"

# Create SASL password file
SASL_FILE="/etc/postfix/sasl_passwd"
if [[ -n "$DESTINATION" ]]; then
    # Per-destination relay
    echo "[$HOST]:$PORT $USER:$PASS" | $SUDO tee -a "$SASL_FILE" > /dev/null
else
    echo "[$HOST]:$PORT $USER:$PASS" | $SUDO tee "$SASL_FILE" > /dev/null
fi
$SUDO chmod 600 "$SASL_FILE"
$SUDO postmap "$SASL_FILE"
info "SASL credentials configured"

# Configure main.cf
MAIN_CF="/etc/postfix/main.cf"

# Remove old relay settings (idempotent)
$SUDO sed -i '/^relayhost\s*=/d' "$MAIN_CF"
$SUDO sed -i '/^smtp_sasl_/d' "$MAIN_CF"
$SUDO sed -i '/^smtp_tls_/d' "$MAIN_CF"
$SUDO sed -i '/^smtp_destination_rate_delay/d' "$MAIN_CF"
$SUDO sed -i '/^sender_canonical_maps/d' "$MAIN_CF"
$SUDO sed -i '/^# SMTP Relay Config/d' "$MAIN_CF"

# Append relay configuration
cat <<EOF | $SUDO tee -a "$MAIN_CF" > /dev/null

# SMTP Relay Config (postfix-smtp-relay skill)
relayhost = [$HOST]:$PORT
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
EOF

info "Postfix relay configured → [$HOST]:$PORT"

# Optional: sender address rewriting
if [[ -n "$REWRITE_FROM" ]]; then
    CANONICAL="/etc/postfix/sender_canonical"
    echo "/.+/ $REWRITE_FROM" | $SUDO tee "$CANONICAL" > /dev/null
    $SUDO postmap regexp:"$CANONICAL"
    echo "sender_canonical_maps = regexp:/etc/postfix/sender_canonical" | $SUDO tee -a "$MAIN_CF" > /dev/null
    info "From address rewriting → $REWRITE_FROM"
fi

# Optional: rate limiting
if [[ -n "$RATE_LIMIT" ]]; then
    DELAY=$((60 / RATE_LIMIT))
    echo "smtp_destination_rate_delay = ${DELAY}s" | $SUDO tee -a "$MAIN_CF" > /dev/null
    info "Rate limited to ~$RATE_LIMIT msgs/min (${DELAY}s delay)"
fi

# Reload postfix
$SUDO systemctl reload postfix 2>/dev/null || $SUDO postfix reload 2>/dev/null
info "Postfix reloaded"

echo ""
echo "🎉 Done! Send a test email:"
echo "   bash scripts/send-test.sh you@example.com"
