#!/bin/bash
# Initialize a DNSControl project for a domain
set -euo pipefail

PROVIDER=""
DOMAIN=""
IMPORT_EXISTING=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --provider)  PROVIDER="$2"; shift 2 ;;
        --domain)    DOMAIN="$2";   shift 2 ;;
        --import)    IMPORT_EXISTING=true; shift ;;
        -h|--help)
            echo "Usage: bash scripts/init.sh --provider <provider> --domain <domain> [--import]"
            echo ""
            echo "Providers: cloudflare, route53, gcloud, digitalocean, hetzner, vultr, linode, gandi, ovh, bind"
            echo ""
            echo "Options:"
            echo "  --import    Import existing DNS records from provider"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ -z "$PROVIDER" ] || [ -z "$DOMAIN" ]; then
    echo "❌ Both --provider and --domain are required"
    echo "Usage: bash scripts/init.sh --provider cloudflare --domain example.com"
    exit 1
fi

# Map provider to DNSControl type
declare -A PROVIDER_MAP=(
    [cloudflare]="CLOUDFLAREAPI"
    [route53]="ROUTE53"
    [gcloud]="GCLOUD"
    [digitalocean]="DIGITALOCEAN"
    [hetzner]="HETZNER"
    [vultr]="VULTR"
    [linode]="LINODE"
    [gandi]="GANDI_V5"
    [ovh]="OVH"
    [bind]="BIND"
)

PROVIDER_TYPE="${PROVIDER_MAP[$PROVIDER]:-}"
if [ -z "$PROVIDER_TYPE" ]; then
    echo "❌ Unknown provider: $PROVIDER"
    echo "Supported: ${!PROVIDER_MAP[*]}"
    exit 1
fi

echo "🔧 Initializing DNSControl for ${DOMAIN} (${PROVIDER})..."

# Create creds.json if it doesn't exist
if [ ! -f creds.json ]; then
    cat > creds.json <<CREDS
{
    "${PROVIDER}": {
        "TYPE": "${PROVIDER_TYPE}",
        "apitoken": "YOUR_API_TOKEN_HERE"
    }
}
CREDS
    echo "📝 Created creds.json — edit with your API credentials"
else
    echo "📝 creds.json already exists — add ${PROVIDER} credentials if needed"
fi

# Create .gitignore
if [ ! -f .gitignore ]; then
    echo "creds.json" > .gitignore
    echo "📝 Created .gitignore (creds.json excluded)"
fi

# Create dnsconfig.js
if [ ! -f dnsconfig.js ]; then
    cat > dnsconfig.js <<CONFIG
// DNSControl configuration for ${DOMAIN}
// Docs: https://docs.dnscontrol.org/

var DSP_${PROVIDER^^} = NewDnsProvider("${PROVIDER}");

D("${DOMAIN}", REG_NONE, DnsProvider(DSP_${PROVIDER^^}),
    // === A Records ===
    // A("@", "YOUR_SERVER_IP"),

    // === CNAME Records ===
    // CNAME("www", "@"),

    // === MX Records ===
    // MX("@", 10, "mail.${DOMAIN}."),

    // === TXT Records ===
    // TXT("@", "v=spf1 include:_spf.google.com ~all"),

    // === Other Records ===
    // AAAA("@", "2001:db8::1"),
    // CAA("@", "issue", "letsencrypt.org"),

END);
CONFIG
    echo "📝 Created dnsconfig.js — add your DNS records"
else
    echo "📝 dnsconfig.js already exists"
fi

# Import existing records if requested
if [ "$IMPORT_EXISTING" = true ]; then
    echo ""
    echo "📥 Importing existing DNS records from ${PROVIDER}..."
    echo "⚠️  Make sure creds.json has valid credentials first!"
    echo ""
    
    if dnscontrol get-zones --format js "${PROVIDER}" - "${DOMAIN}" 2>/dev/null; then
        echo ""
        echo "✅ Records imported! Copy the output above into dnsconfig.js"
    else
        echo "❌ Import failed. Check your credentials in creds.json"
    fi
fi

echo ""
echo "✅ Project initialized!"
echo ""
echo "Next steps:"
echo "  1. Edit creds.json with your ${PROVIDER} API credentials"
echo "  2. Edit dnsconfig.js with your DNS records"
echo "  3. Run: dnscontrol check     (validate config)"
echo "  4. Run: dnscontrol preview   (see pending changes)"
echo "  5. Run: dnscontrol push      (apply changes)"
