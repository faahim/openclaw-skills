#!/bin/bash
# SMTP Email Tester — Test connections, DNS records, send test emails
# Dependencies: openssl, dig, bash 4+

set -euo pipefail

VERSION="1.0.0"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults from env
HOST="${SMTP_HOST:-}"
PORT="${SMTP_PORT:-587}"
USER="${SMTP_USER:-}"
PASS="${SMTP_PASS:-}"
DOMAIN=""
DKIM_SELECTOR="google"
FROM=""
TO=""
SUBJECT="SMTP Test Email"
BODY="This is a test email sent by smtp-email-tester."
IP=""

usage() {
    cat <<EOF
SMTP Email Tester v${VERSION}

Usage: $0 <command> [options]

Commands:
  connect     Test SMTP connection and STARTTLS
  auth        Test SMTP authentication
  dns         Audit domain email DNS (MX, SPF, DKIM, DMARC)
  send        Send a test email
  tls         Check TLS certificate details
  blacklist   Check IP against spam blacklists

Options:
  --host HOST           SMTP server hostname
  --port PORT           SMTP port (default: 587)
  --user USER           SMTP username
  --pass PASS           SMTP password
  --domain DOMAIN       Domain to check DNS for
  --dkim-selector SEL   DKIM selector (default: google)
  --from EMAIL          Sender email
  --to EMAIL            Recipient email
  --subject TEXT        Email subject
  --body TEXT           Email body
  --ip IP               IP address for blacklist check

Environment variables: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS
EOF
    exit 1
}

log_ok()   { echo -e "  ${GREEN}✅${NC} $1"; }
log_fail() { echo -e "  ${RED}❌${NC} $1"; }
log_warn() { echo -e "  ${YELLOW}⚠️ ${NC} $1"; }
log_info() { echo -e "  ${BLUE}ℹ️ ${NC} $1"; }
log_hint() { echo -e "  💡 $1"; }

# Parse command
COMMAND="${1:-}"
[[ -z "$COMMAND" ]] && usage
shift

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        --host) HOST="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --user) USER="$2"; shift 2 ;;
        --pass) PASS="$2"; shift 2 ;;
        --domain) DOMAIN="$2"; shift 2 ;;
        --dkim-selector) DKIM_SELECTOR="$2"; shift 2 ;;
        --from) FROM="$2"; shift 2 ;;
        --to) TO="$2"; shift 2 ;;
        --subject) SUBJECT="$2"; shift 2 ;;
        --body) BODY="$2"; shift 2 ;;
        --ip) IP="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

##############################################
# CONNECT — Test SMTP connection
##############################################
cmd_connect() {
    [[ -z "$HOST" ]] && { echo "Error: --host required"; exit 1; }
    
    echo -e "\n${BLUE}[SMTP]${NC} Connecting to ${HOST}:${PORT}..."
    
    # Test basic TCP connection
    if ! timeout 10 bash -c "echo > /dev/tcp/${HOST}/${PORT}" 2>/dev/null; then
        log_fail "Connection failed — ${HOST}:${PORT} is unreachable"
        echo -e "\n${YELLOW}Troubleshooting:${NC}"
        echo "  - Check firewall rules"
        echo "  - Try ports: 25, 465, 587, 2525"
        echo "  - Verify hostname resolves: dig ${HOST}"
        return 1
    fi
    log_ok "TCP connection successful"
    
    # Get SMTP banner and test STARTTLS
    local tmpfile
    tmpfile=$(mktemp)
    
    if [[ "$PORT" == "465" ]]; then
        # Port 465 = implicit TLS
        echo "QUIT" | timeout 10 openssl s_client -connect "${HOST}:${PORT}" -quiet 2>/dev/null > "$tmpfile" || true
        local banner
        banner=$(head -1 "$tmpfile" | tr -d '\r')
        [[ -n "$banner" ]] && echo -e "${BLUE}[SMTP]${NC} Banner: ${banner}"
        log_ok "Implicit TLS (port 465)"
        
        # Get cert info
        _show_cert_info "$HOST" "$PORT" "465"
    else
        # Port 587/25 = STARTTLS
        (echo "EHLO test.local"; sleep 1; echo "STARTTLS"; sleep 1; echo "QUIT") | \
            timeout 10 openssl s_client -connect "${HOST}:${PORT}" -starttls smtp -quiet 2>/dev/null > "$tmpfile" || true
        
        # Get banner via plain connection
        local banner
        banner=$(echo "QUIT" | timeout 5 nc -w5 "${HOST}" "${PORT}" 2>/dev/null | head -1 | tr -d '\r') || true
        [[ -n "$banner" ]] && echo -e "${BLUE}[SMTP]${NC} Banner: ${banner}"
        
        # Check STARTTLS support
        local ehlo_response
        ehlo_response=$( (echo "EHLO test.local"; sleep 1; echo "QUIT") | timeout 5 nc -w5 "${HOST}" "${PORT}" 2>/dev/null) || true
        if echo "$ehlo_response" | grep -qi "STARTTLS"; then
            log_ok "STARTTLS: Supported"
            _show_cert_info "$HOST" "$PORT" "starttls"
        else
            log_warn "STARTTLS: Not advertised"
        fi
        
        # Check AUTH methods
        if echo "$ehlo_response" | grep -qi "AUTH"; then
            local auth_methods
            auth_methods=$(echo "$ehlo_response" | grep -i "AUTH" | head -1 | sed 's/.*AUTH //' | tr -d '\r')
            log_info "Auth methods: ${auth_methods}"
        fi
    fi
    
    rm -f "$tmpfile"
    echo ""
}

_show_cert_info() {
    local host=$1 port=$2 mode=$3
    local cert_info
    
    if [[ "$mode" == "465" ]]; then
        cert_info=$(echo | timeout 10 openssl s_client -connect "${host}:${port}" 2>/dev/null)
    else
        cert_info=$(echo | timeout 10 openssl s_client -connect "${host}:${port}" -starttls smtp 2>/dev/null)
    fi
    
    local tls_version
    tls_version=$(echo "$cert_info" | grep "Protocol" | awk '{print $NF}')
    [[ -n "$tls_version" ]] && echo -e "${BLUE}[SMTP]${NC} TLS Version: ${tls_version}"
    
    local cert_subject
    cert_subject=$(echo "$cert_info" | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//')
    [[ -n "$cert_subject" ]] && echo -e "${BLUE}[SMTP]${NC} Certificate: ${cert_subject}"
    
    local cert_expiry
    cert_expiry=$(echo "$cert_info" | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//')
    [[ -n "$cert_expiry" ]] && echo -e "${BLUE}[SMTP]${NC} Expires: ${cert_expiry}"
}

##############################################
# AUTH — Test SMTP authentication
##############################################
cmd_auth() {
    [[ -z "$HOST" ]] && { echo "Error: --host required"; exit 1; }
    [[ -z "$USER" ]] && { echo "Error: --user required"; exit 1; }
    [[ -z "$PASS" ]] && { echo "Error: --pass required"; exit 1; }
    
    echo -e "\n${BLUE}[SMTP]${NC} Testing authentication on ${HOST}:${PORT}..."
    
    local auth_b64
    auth_b64=$(echo -ne "\0${USER}\0${PASS}" | base64)
    
    local tmpfile
    tmpfile=$(mktemp)
    
    local smtp_commands
    smtp_commands="EHLO test.local
AUTH PLAIN ${auth_b64}
QUIT"
    
    if [[ "$PORT" == "465" ]]; then
        echo "$smtp_commands" | timeout 15 openssl s_client -connect "${HOST}:${PORT}" -quiet 2>/dev/null > "$tmpfile" || true
    else
        echo "$smtp_commands" | timeout 15 openssl s_client -connect "${HOST}:${PORT}" -starttls smtp -quiet 2>/dev/null > "$tmpfile" || true
    fi
    
    if grep -q "235" "$tmpfile" 2>/dev/null; then
        log_ok "Authentication successful for ${USER}"
    elif grep -q "535" "$tmpfile" 2>/dev/null; then
        log_fail "Authentication failed — invalid credentials"
        log_hint "For Gmail: use App Passwords (Security → 2FA → App Passwords)"
    elif grep -q "534" "$tmpfile" 2>/dev/null; then
        log_fail "Authentication failed — application-specific password required"
        log_hint "Enable 2FA and generate an App Password"
    else
        log_warn "Unexpected response — check output:"
        cat "$tmpfile" 2>/dev/null | tail -5
    fi
    
    rm -f "$tmpfile"
    echo ""
}

##############################################
# DNS — Audit domain email DNS records
##############################################
cmd_dns() {
    [[ -z "$DOMAIN" ]] && { echo "Error: --domain required"; exit 1; }
    
    if ! command -v dig &>/dev/null; then
        echo "Error: 'dig' not found. Install: apt install dnsutils / yum install bind-utils / brew install bind"
        exit 1
    fi
    
    echo -e "\n${BLUE}[DNS]${NC} Checking email records for ${DOMAIN}...\n"
    
    # MX Records
    echo -e "${BLUE}[MX Records]${NC}"
    local mx_records
    mx_records=$(dig +short MX "$DOMAIN" 2>/dev/null)
    if [[ -n "$mx_records" ]]; then
        while IFS= read -r mx; do
            log_ok "$mx"
        done <<< "$mx_records"
    else
        log_fail "No MX records found"
        log_hint "Without MX records, email cannot be delivered to ${DOMAIN}"
    fi
    
    echo ""
    
    # SPF Record
    echo -e "${BLUE}[SPF Record]${NC}"
    local spf_record
    spf_record=$(dig +short TXT "$DOMAIN" 2>/dev/null | grep -i "v=spf1" | tr -d '"')
    if [[ -n "$spf_record" ]]; then
        log_ok "$spf_record"
        
        # Check for common issues
        if echo "$spf_record" | grep -q "+all"; then
            log_warn "SPF uses +all — this allows ANY server to send as ${DOMAIN}"
            log_hint "Use ~all (softfail) or -all (hardfail) instead"
        elif echo "$spf_record" | grep -q "~all"; then
            log_info "SPF uses ~all (softfail) — emails from unauthorized servers may land in spam"
        elif echo "$spf_record" | grep -q "\-all"; then
            log_ok "SPF uses -all (hardfail) — strictest policy ✓"
        fi
    else
        log_fail "No SPF record found"
        log_hint "Add a TXT record: v=spf1 include:_spf.google.com ~all"
    fi
    
    echo ""
    
    # DKIM Record
    echo -e "${BLUE}[DKIM Record]${NC}"
    local dkim_record
    dkim_record=$(dig +short TXT "${DKIM_SELECTOR}._domainkey.${DOMAIN}" 2>/dev/null | tr -d '"')
    if [[ -n "$dkim_record" ]]; then
        log_ok "Found DKIM at ${DKIM_SELECTOR}._domainkey.${DOMAIN}"
        echo "    ${dkim_record:0:80}..."
    else
        log_warn "No DKIM record at ${DKIM_SELECTOR}._domainkey.${DOMAIN}"
        log_hint "Try other selectors: --dkim-selector default | selector1 | k1 | mail"
        
        # Try common selectors
        for sel in default selector1 selector2 k1 mail s1; do
            if [[ "$sel" == "$DKIM_SELECTOR" ]]; then continue; fi
            local try_dkim
            try_dkim=$(dig +short TXT "${sel}._domainkey.${DOMAIN}" 2>/dev/null | tr -d '"')
            if [[ -n "$try_dkim" ]]; then
                log_ok "Found DKIM at ${sel}._domainkey.${DOMAIN}"
                echo "    ${try_dkim:0:80}..."
                break
            fi
        done
    fi
    
    echo ""
    
    # DMARC Record
    echo -e "${BLUE}[DMARC Record]${NC}"
    local dmarc_record
    dmarc_record=$(dig +short TXT "_dmarc.${DOMAIN}" 2>/dev/null | tr -d '"')
    if [[ -n "$dmarc_record" ]]; then
        log_ok "$dmarc_record"
        
        # Parse policy
        local policy
        policy=$(echo "$dmarc_record" | grep -oP 'p=\w+' | head -1)
        case "$policy" in
            "p=none")
                log_warn "DMARC policy is 'none' — no enforcement, monitoring only"
                log_hint "Move to p=quarantine or p=reject when ready"
                ;;
            "p=quarantine")
                log_info "DMARC policy is 'quarantine' — suspicious emails go to spam"
                ;;
            "p=reject")
                log_ok "DMARC policy is 'reject' — unauthorized emails are blocked ✓"
                ;;
        esac
        
        # Check for reporting
        if echo "$dmarc_record" | grep -q "rua="; then
            log_ok "DMARC reporting (rua) configured"
        else
            log_hint "Add rua=mailto:dmarc@${DOMAIN} for aggregate reports"
        fi
    else
        log_fail "No DMARC record found"
        log_hint "Add TXT at _dmarc.${DOMAIN}: v=DMARC1; p=quarantine; rua=mailto:dmarc@${DOMAIN}"
    fi
    
    echo ""
    
    # Reverse DNS for MX hosts
    echo -e "${BLUE}[Reverse DNS]${NC}"
    if [[ -n "$mx_records" ]]; then
        while IFS= read -r mx; do
            local mx_host
            mx_host=$(echo "$mx" | awk '{print $2}' | sed 's/\.$//')
            local mx_ip
            mx_ip=$(dig +short A "$mx_host" 2>/dev/null | head -1)
            if [[ -n "$mx_ip" ]]; then
                local rdns
                rdns=$(dig +short -x "$mx_ip" 2>/dev/null | head -1 | sed 's/\.$//')
                if [[ -n "$rdns" ]]; then
                    log_ok "${mx_host} (${mx_ip}) → rDNS: ${rdns}"
                else
                    log_warn "${mx_host} (${mx_ip}) — No reverse DNS"
                fi
            fi
        done <<< "$mx_records"
    fi
    
    echo ""
}

##############################################
# SEND — Send a test email
##############################################
cmd_send() {
    [[ -z "$HOST" ]] && { echo "Error: --host required"; exit 1; }
    [[ -z "$USER" ]] && { echo "Error: --user required"; exit 1; }
    [[ -z "$PASS" ]] && { echo "Error: --pass required"; exit 1; }
    [[ -z "$FROM" ]] && { echo "Error: --from required"; exit 1; }
    [[ -z "$TO" ]] && { echo "Error: --to required"; exit 1; }
    
    echo -e "\n${BLUE}[SMTP]${NC} Sending test email via ${HOST}:${PORT}..."
    
    local auth_b64
    auth_b64=$(echo -ne "\0${USER}\0${PASS}" | base64)
    
    local date_header
    date_header=$(date -R 2>/dev/null || date "+%a, %d %b %Y %H:%M:%S %z")
    local msg_id
    msg_id="<$(date +%s).$(( RANDOM )).smtp-test@$(hostname)>"
    
    local smtp_commands
    smtp_commands="EHLO test.local
AUTH PLAIN ${auth_b64}
MAIL FROM:<${FROM}>
RCPT TO:<${TO}>
DATA
From: ${FROM}
To: ${TO}
Subject: ${SUBJECT}
Date: ${date_header}
Message-ID: ${msg_id}
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
X-Mailer: smtp-email-tester/${VERSION}

${BODY}
.
QUIT"
    
    local tmpfile
    tmpfile=$(mktemp)
    
    if [[ "$PORT" == "465" ]]; then
        echo "$smtp_commands" | timeout 30 openssl s_client -connect "${HOST}:${PORT}" -quiet 2>/dev/null > "$tmpfile" || true
    else
        echo "$smtp_commands" | timeout 30 openssl s_client -connect "${HOST}:${PORT}" -starttls smtp -quiet 2>/dev/null > "$tmpfile" || true
    fi
    
    if grep -q "250.*OK\|250.*Accepted\|250.*queued\|250 2" "$tmpfile" 2>/dev/null; then
        log_ok "Email sent successfully!"
        log_info "From: ${FROM}"
        log_info "To: ${TO}"
        log_info "Subject: ${SUBJECT}"
    else
        log_fail "Email send failed"
        echo -e "\n${YELLOW}Server response:${NC}"
        cat "$tmpfile" 2>/dev/null | tail -10
    fi
    
    rm -f "$tmpfile"
    echo ""
}

##############################################
# TLS — Check TLS certificate
##############################################
cmd_tls() {
    [[ -z "$HOST" ]] && { echo "Error: --host required"; exit 1; }
    
    echo -e "\n${BLUE}[TLS]${NC} Checking certificate for ${HOST}:${PORT}...\n"
    
    local cert_info
    if [[ "$PORT" == "465" ]]; then
        cert_info=$(echo | timeout 10 openssl s_client -connect "${HOST}:${PORT}" 2>/dev/null)
    else
        cert_info=$(echo | timeout 10 openssl s_client -connect "${HOST}:${PORT}" -starttls smtp 2>/dev/null)
    fi
    
    if [[ -z "$cert_info" ]]; then
        log_fail "Could not retrieve TLS certificate"
        return 1
    fi
    
    # Protocol version
    local protocol
    protocol=$(echo "$cert_info" | grep "Protocol" | awk '{print $NF}')
    echo -e "${BLUE}Protocol:${NC}    ${protocol:-Unknown}"
    
    # Cipher
    local cipher
    cipher=$(echo "$cert_info" | grep "Cipher" | head -1 | awk '{print $NF}')
    echo -e "${BLUE}Cipher:${NC}      ${cipher:-Unknown}"
    
    # Subject
    local subject
    subject=$(echo "$cert_info" | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//')
    echo -e "${BLUE}Subject:${NC}     ${subject:-Unknown}"
    
    # Issuer
    local issuer
    issuer=$(echo "$cert_info" | openssl x509 -noout -issuer 2>/dev/null | sed 's/issuer=//')
    echo -e "${BLUE}Issuer:${NC}      ${issuer:-Unknown}"
    
    # Validity
    local not_before not_after
    not_before=$(echo "$cert_info" | openssl x509 -noout -startdate 2>/dev/null | sed 's/notBefore=//')
    not_after=$(echo "$cert_info" | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//')
    echo -e "${BLUE}Valid from:${NC}  ${not_before:-Unknown}"
    echo -e "${BLUE}Valid until:${NC} ${not_after:-Unknown}"
    
    # Check if expired
    if [[ -n "$not_after" ]]; then
        local expiry_epoch now_epoch days_left
        expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$not_after" +%s 2>/dev/null || echo 0)
        now_epoch=$(date +%s)
        if [[ "$expiry_epoch" -gt 0 ]]; then
            days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
            echo ""
            if [[ "$days_left" -lt 0 ]]; then
                log_fail "Certificate EXPIRED ${days_left#-} days ago!"
            elif [[ "$days_left" -lt 30 ]]; then
                log_warn "Certificate expires in ${days_left} days"
            else
                log_ok "Certificate valid for ${days_left} days"
            fi
        fi
    fi
    
    # SANs
    local sans
    sans=$(echo "$cert_info" | openssl x509 -noout -ext subjectAltName 2>/dev/null | grep -v "Subject Alternative" | tr ',' '\n' | sed 's/DNS://g; s/^ *//')
    if [[ -n "$sans" ]]; then
        echo -e "\n${BLUE}Subject Alt Names:${NC}"
        echo "$sans" | head -10 | while read -r san; do
            echo "  - $san"
        done
    fi
    
    echo ""
}

##############################################
# BLACKLIST — Check IP against blacklists
##############################################
cmd_blacklist() {
    [[ -z "$IP" ]] && { echo "Error: --ip required"; exit 1; }
    
    if ! command -v dig &>/dev/null; then
        echo "Error: 'dig' not found."
        exit 1
    fi
    
    echo -e "\n${BLUE}[Blacklist]${NC} Checking ${IP} against spam blacklists...\n"
    
    # Reverse IP for DNSBL queries
    local reversed
    reversed=$(echo "$IP" | awk -F. '{print $4"."$3"."$2"."$1}')
    
    local blacklists=(
        "zen.spamhaus.org"
        "bl.spamcop.net"
        "dnsbl.sorbs.net"
        "b.barracudacentral.org"
        "cbl.abuseat.org"
        "dnsbl-1.uceprotect.net"
        "psbl.surriel.com"
        "db.wpbl.info"
        "ix.dnsbl.manitu.net"
        "spam.dnsbl.anonmails.de"
        "combined.abuse.ch"
        "dnsbl.dronebl.org"
    )
    
    local listed=0
    local total=${#blacklists[@]}
    
    for bl in "${blacklists[@]}"; do
        local result
        result=$(dig +short "${reversed}.${bl}" 2>/dev/null)
        if [[ -n "$result" && "$result" != "" ]]; then
            log_fail "${bl} — LISTED (${result})"
            ((listed++))
        else
            log_ok "${bl} — Not listed"
        fi
    done
    
    echo -e "\n${BLUE}[Result]${NC} Listed on ${listed}/${total} blacklists"
    if [[ "$listed" -gt 0 ]]; then
        log_warn "Being blacklisted affects email deliverability"
        log_hint "Contact each blacklist provider for delisting procedures"
    else
        log_ok "Clean — not on any checked blacklists"
    fi
    
    echo ""
}

##############################################
# Main dispatcher
##############################################
case "$COMMAND" in
    connect)    cmd_connect ;;
    auth)       cmd_auth ;;
    dns)        cmd_dns ;;
    send)       cmd_send ;;
    tls)        cmd_tls ;;
    blacklist)  cmd_blacklist ;;
    -h|--help)  usage ;;
    *)          echo "Unknown command: $COMMAND"; usage ;;
esac
