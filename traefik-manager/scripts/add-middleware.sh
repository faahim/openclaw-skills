#!/bin/bash
# Add middleware configuration to Traefik via file provider

set -euo pipefail

TRAEFIK_DIR="/opt/traefik"
MW_NAME=""
MW_TYPE=""
USERS=""
AVERAGE=""
BURST=""
STS=false
FRAME_DENY=false
CONTENT_TYPE_NOSNIFF=false

usage() {
  cat <<EOF
Usage: $0 --name <name> --type <type> [options]

Middleware types:
  basicauth     Basic authentication
  ratelimit     Rate limiting
  headers       Security headers
  stripprefix   Strip URL prefix
  redirectregex Regex-based redirect

Options (basicauth):
  --users <htpasswd>    htpasswd formatted user:password

Options (ratelimit):
  --average <n>         Average requests per second
  --burst <n>           Maximum burst size

Options (headers):
  --sts                 Add Strict-Transport-Security
  --frame-deny          Add X-Frame-Options: DENY
  --content-type-nosniff Add X-Content-Type-Options: nosniff

Options (stripprefix):
  --prefixes <p1,p2>    Comma-separated prefixes to strip

Options (redirectregex):
  --regex <pattern>     Regex pattern
  --replacement <repl>  Replacement string
EOF
  exit 0
}

PREFIXES=""
REGEX=""
REPLACEMENT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) MW_NAME="$2"; shift 2 ;;
    --type) MW_TYPE="$2"; shift 2 ;;
    --users) USERS="$2"; shift 2 ;;
    --average) AVERAGE="$2"; shift 2 ;;
    --burst) BURST="$2"; shift 2 ;;
    --sts) STS=true; shift ;;
    --frame-deny) FRAME_DENY=true; shift ;;
    --content-type-nosniff) CONTENT_TYPE_NOSNIFF=true; shift ;;
    --prefixes) PREFIXES="$2"; shift 2 ;;
    --regex) REGEX="$2"; shift 2 ;;
    --replacement) REPLACEMENT="$2"; shift 2 ;;
    --dir) TRAEFIK_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [[ -z "$MW_NAME" || -z "$MW_TYPE" ]]; then
  echo "❌ --name and --type required"; exit 1
fi

CONFIG_FILE="${TRAEFIK_DIR}/config/middleware-${MW_NAME}.yml"

case "$MW_TYPE" in
  basicauth)
    cat > "$CONFIG_FILE" <<EOF
http:
  middlewares:
    ${MW_NAME}:
      basicAuth:
        users:
          - "${USERS}"
EOF
    ;;
  ratelimit)
    cat > "$CONFIG_FILE" <<EOF
http:
  middlewares:
    ${MW_NAME}:
      rateLimit:
        average: ${AVERAGE:-100}
        burst: ${BURST:-50}
EOF
    ;;
  headers)
    HEADERS_YAML="      customResponseHeaders: {}"
    EXTRAS=""
    $STS && EXTRAS="${EXTRAS}
        stsSeconds: 31536000
        stsIncludeSubdomains: true"
    $FRAME_DENY && EXTRAS="${EXTRAS}
        frameDeny: true"
    $CONTENT_TYPE_NOSNIFF && EXTRAS="${EXTRAS}
        contentTypeNosniff: true"
    cat > "$CONFIG_FILE" <<EOF
http:
  middlewares:
    ${MW_NAME}:
      headers:${EXTRAS}
EOF
    ;;
  stripprefix)
    IFS=',' read -ra PFX <<< "$PREFIXES"
    PFX_YAML=""
    for p in "${PFX[@]}"; do
      PFX_YAML="${PFX_YAML}
          - \"${p}\""
    done
    cat > "$CONFIG_FILE" <<EOF
http:
  middlewares:
    ${MW_NAME}:
      stripPrefix:
        prefixes:${PFX_YAML}
EOF
    ;;
  redirectregex)
    cat > "$CONFIG_FILE" <<EOF
http:
  middlewares:
    ${MW_NAME}:
      redirectRegex:
        regex: "${REGEX}"
        replacement: "${REPLACEMENT}"
        permanent: true
EOF
    ;;
  *)
    echo "❌ Unknown middleware type: $MW_TYPE"; exit 1 ;;
esac

echo "✅ Middleware '${MW_NAME}' (${MW_TYPE}) added"
echo "   Config: ${CONFIG_FILE}"
echo ""
echo "Apply to a router by adding this label to your container:"
echo "   traefik.http.routers.<name>.middlewares=${MW_NAME}"
