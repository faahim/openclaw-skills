#!/usr/bin/env bash
# Security Headers Checker v1.0
# Audits HTTP security headers, produces grades and fix recommendations.

set -euo pipefail

VERSION="1.0.0"
TIMEOUT=10
FOLLOW_REDIRECTS=false
OUTPUT_FORMAT="text"
FIX_SERVER=""
GRADE_ONLY=false
USER_AGENT="SecurityHeadersChecker/${VERSION}"
INSECURE=false
ONLY_HEADERS=""
URLS=()

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
  cat <<EOF
Security Headers Checker v${VERSION}

Usage: $(basename "$0") [OPTIONS] URL [URL...]

Options:
  --json              Output JSON format
  --grade-only        Output only the letter grade
  --fix <server>      Generate fix config (nginx|apache|cloudflare)
  --follow            Follow HTTP redirects
  --timeout <secs>    Request timeout (default: 10)
  --user-agent <ua>   Custom User-Agent string
  --insecure          Skip SSL verification
  --only <headers>    Check only specific headers (comma-separated: csp,hsts,xfo,xcto,rp,pp,coop,xxp)
  --help              Show this help
  --version           Show version

Examples:
  $(basename "$0") https://example.com
  $(basename "$0") --json https://example.com
  $(basename "$0") --fix nginx https://example.com
  $(basename "$0") https://site1.com https://site2.com
EOF
  exit 0
}

# ── Parse Arguments ──
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) OUTPUT_FORMAT="json"; shift ;;
    --grade-only) GRADE_ONLY=true; shift ;;
    --fix) FIX_SERVER="$2"; shift 2 ;;
    --follow) FOLLOW_REDIRECTS=true; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --user-agent) USER_AGENT="$2"; shift 2 ;;
    --insecure) INSECURE=true; shift ;;
    --only) ONLY_HEADERS="$2"; shift 2 ;;
    --help) usage ;;
    --version) echo "v${VERSION}"; exit 0 ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *) URLS+=("$1"); shift ;;
  esac
done

if [[ ${#URLS[@]} -eq 0 ]]; then
  echo "Error: No URL provided. Use --help for usage."
  exit 1
fi

# ── Header definitions ──
# name|short|max_score|description
HEADER_DEFS=(
  "content-security-policy|csp|25|Controls which resources the browser can load. #1 defense against XSS."
  "strict-transport-security|hsts|15|Forces HTTPS connections, prevents protocol downgrade attacks."
  "permissions-policy|pp|15|Restricts browser API access (camera, mic, geolocation)."
  "x-content-type-options|xcto|10|Prevents MIME type sniffing attacks."
  "x-frame-options|xfo|10|Prevents clickjacking by controlling iframe embedding."
  "referrer-policy|rp|10|Controls how much referrer info is sent with requests."
  "cross-origin-opener-policy|coop|10|Isolates browsing context from cross-origin windows."
  "x-xss-protection|xxp|5|Legacy XSS filter. Should be '0' or absent (CSP replaces it)."
)

# ── Fetch headers ──
fetch_headers() {
  local url="$1"
  local curl_opts=(-s -D- -o /dev/null --max-time "$TIMEOUT" -A "$USER_AGENT")
  
  [[ "$FOLLOW_REDIRECTS" == true ]] && curl_opts+=(-L)
  [[ "$INSECURE" == true ]] && curl_opts+=(-k)
  
  curl "${curl_opts[@]}" "$url" 2>/dev/null || echo "FETCH_ERROR"
}

# ── Score a single header ──
score_header() {
  local header_name="$1"
  local header_value="$2"
  local max_score="$3"
  
  if [[ -z "$header_value" ]]; then
    echo "0"
    return
  fi
  
  case "$header_name" in
    content-security-policy)
      # Has CSP at all = good. Check for default-src or script-src for full marks.
      if echo "$header_value" | grep -qi "default-src\|script-src"; then
        echo "$max_score"
      else
        echo "$((max_score * 3 / 4))"
      fi
      ;;
    strict-transport-security)
      local max_age
      max_age=$(echo "$header_value" | grep -oi 'max-age=[0-9]*' | head -1 | cut -d= -f2)
      if [[ -n "$max_age" && "$max_age" -ge 31536000 ]]; then
        echo "$max_score"
      elif [[ -n "$max_age" && "$max_age" -ge 2592000 ]]; then
        echo "$((max_score * 3 / 4))"
      else
        echo "$((max_score / 2))"
      fi
      ;;
    x-content-type-options)
      if echo "$header_value" | grep -qi "nosniff"; then
        echo "$max_score"
      else
        echo "$((max_score / 2))"
      fi
      ;;
    x-frame-options)
      if echo "$header_value" | grep -qi "DENY\|SAMEORIGIN"; then
        echo "$max_score"
      else
        echo "$((max_score / 2))"
      fi
      ;;
    referrer-policy)
      case "$(echo "$header_value" | tr '[:upper:]' '[:lower:]' | xargs)" in
        no-referrer|strict-origin-when-cross-origin|strict-origin|same-origin)
          echo "$max_score" ;;
        no-referrer-when-downgrade|origin-when-cross-origin)
          echo "$((max_score / 2))" ;;
        *)
          echo "$((max_score / 4))" ;;
      esac
      ;;
    permissions-policy)
      echo "$max_score"
      ;;
    cross-origin-opener-policy)
      if echo "$header_value" | grep -qi "same-origin"; then
        echo "$max_score"
      else
        echo "$((max_score * 3 / 4))"
      fi
      ;;
    x-xss-protection)
      # "0" is correct (disable legacy filter). "1" is acceptable but risky.
      if [[ "$(echo "$header_value" | xargs)" == "0" ]]; then
        echo "$max_score"
      else
        echo "$((max_score / 2))"
      fi
      ;;
    *)
      echo "$max_score"
      ;;
  esac
}

# ── Letter grade ──
letter_grade() {
  local score=$1
  if [[ $score -ge 95 ]]; then echo "A+"
  elif [[ $score -ge 85 ]]; then echo "A"
  elif [[ $score -ge 70 ]]; then echo "B"
  elif [[ $score -ge 55 ]]; then echo "C"
  elif [[ $score -ge 40 ]]; then echo "D"
  else echo "F"
  fi
}

# ── Get recommendation ──
get_recommendation() {
  local header_name="$1"
  case "$header_name" in
    content-security-policy)
      echo "Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' https:; connect-src 'self' https:; frame-ancestors 'none'" ;;
    strict-transport-security)
      echo "Strict-Transport-Security: max-age=63072000; includeSubDomains; preload" ;;
    permissions-policy)
      echo "Permissions-Policy: camera=(), microphone=(), geolocation=(), interest-cohort=()" ;;
    x-content-type-options)
      echo "X-Content-Type-Options: nosniff" ;;
    x-frame-options)
      echo "X-Frame-Options: DENY" ;;
    referrer-policy)
      echo "Referrer-Policy: strict-origin-when-cross-origin" ;;
    cross-origin-opener-policy)
      echo "Cross-Origin-Opener-Policy: same-origin" ;;
    x-xss-protection)
      echo "X-XSS-Protection: 0" ;;
  esac
}

# ── Generate fix config ──
generate_fix() {
  local server="$1"
  shift
  local missing_headers=("$@")
  
  echo ""
  case "$server" in
    nginx)
      echo "# Add to your Nginx server block:"
      for h in "${missing_headers[@]}"; do
        local rec
        rec=$(get_recommendation "$h")
        local hname hval
        hname=$(echo "$rec" | cut -d: -f1)
        hval=$(echo "$rec" | cut -d: -f2- | xargs)
        echo "add_header ${hname} \"${hval}\" always;"
      done
      ;;
    apache)
      echo "# Add to your Apache .htaccess or VirtualHost:"
      for h in "${missing_headers[@]}"; do
        local rec
        rec=$(get_recommendation "$h")
        local hname hval
        hname=$(echo "$rec" | cut -d: -f1)
        hval=$(echo "$rec" | cut -d: -f2- | xargs)
        echo "Header always set ${hname} \"${hval}\""
      done
      ;;
    cloudflare)
      echo "# Add as Cloudflare Transform Rules (HTTP Response Header Modification):"
      for h in "${missing_headers[@]}"; do
        local rec
        rec=$(get_recommendation "$h")
        local hname hval
        hname=$(echo "$rec" | cut -d: -f1)
        hval=$(echo "$rec" | cut -d: -f2- | xargs)
        echo "Set static: ${hname} = ${hval}"
      done
      ;;
    *)
      echo "Unknown server type: $server (use nginx, apache, or cloudflare)"
      return 1
      ;;
  esac
  echo ""
}

# ── Check if header should be processed ──
should_check() {
  local short="$1"
  [[ -z "$ONLY_HEADERS" ]] && return 0
  echo ",$ONLY_HEADERS," | grep -q ",$short," && return 0
  return 1
}

# ── Main scan function ──
scan_url() {
  local url="$1"
  local raw_headers
  raw_headers=$(fetch_headers "$url")
  
  if [[ "$raw_headers" == "FETCH_ERROR" ]]; then
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
      echo "{\"url\":\"$url\",\"error\":\"Failed to fetch URL\",\"grade\":\"F\",\"score\":0}"
    else
      echo -e "${RED}Error: Failed to fetch $url${NC}"
    fi
    return 1
  fi
  
  local total_score=0
  local total_max=0
  local missing=()
  local warnings=()
  local recommendations=()
  local json_headers=""
  local text_output=""
  
  for def in "${HEADER_DEFS[@]}"; do
    IFS='|' read -r hname hshort hmax hdesc <<< "$def"
    
    should_check "$hshort" || continue
    
    total_max=$((total_max + hmax))
    
    # Extract header value (case-insensitive)
    local hval
    hval=$(echo "$raw_headers" | grep -i "^${hname}:" | head -1 | sed "s/^[^:]*: //" | tr -d '\r' || true)
    
    local hscore
    hscore=$(score_header "$hname" "$hval" "$hmax")
    total_score=$((total_score + hscore))
    
    local present="true"
    if [[ -z "$hval" ]]; then
      present="false"
      missing+=("$hname")
      recommendations+=("$(get_recommendation "$hname")")
    elif [[ "$hscore" -lt "$hmax" ]]; then
      warnings+=("$hname")
    fi
    
    # Build JSON fragment
    local escaped_val
    escaped_val=$(echo "$hval" | sed 's/"/\\"/g')
    [[ -n "$json_headers" ]] && json_headers+=","
    json_headers+="\"${hname}\":{\"present\":${present},\"value\":$([ -n "$hval" ] && echo "\"${escaped_val}\"" || echo "null"),\"score\":${hscore},\"max\":${hmax}}"
    
    # Build text output
    if [[ -z "$hval" ]]; then
      text_output+="$(printf "${RED}❌ %-35s MISSING${NC}\n" "${hname}:")"
      text_output+=$'\n'
      text_output+="   → ${hdesc}"$'\n'
      text_output+="   → Recommended: $(get_recommendation "$hname")"$'\n'
    elif [[ "$hscore" -lt "$hmax" ]]; then
      text_output+="$(printf "${YELLOW}⚠️  %-35s %s${NC}\n" "${hname}:" "$hval")"
      text_output+=$'\n'
      text_output+="   → Partial score (${hscore}/${hmax}). ${hdesc}"$'\n'
    else
      text_output+="$(printf "${GREEN}✅ %-35s %s${NC}\n" "${hname}:" "$hval")"
      text_output+=$'\n'
      text_output+="   → Good. ${hdesc}"$'\n'
    fi
    text_output+=$'\n'
  done
  
  # Calculate percentage and grade
  local pct=0
  [[ $total_max -gt 0 ]] && pct=$((total_score * 100 / total_max))
  local grade
  grade=$(letter_grade "$pct")
  
  # ── Output ──
  if [[ "$GRADE_ONLY" == true ]]; then
    echo "$grade"
    return
  fi
  
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    local missing_json="[]"
    local warn_json="[]"
    local rec_json="[]"
    
    if [[ ${#missing[@]} -gt 0 ]]; then
      missing_json=$(printf ',"%s"' "${missing[@]}")
      missing_json="[${missing_json:1}]"
    fi
    if [[ ${#warnings[@]} -gt 0 ]]; then
      warn_json=$(printf ',"%s"' "${warnings[@]}")
      warn_json="[${warn_json:1}]"
    fi
    if [[ ${#recommendations[@]} -gt 0 ]]; then
      rec_json=$(printf ',"%s"' "${recommendations[@]}")
      rec_json="[${rec_json:1}]"
    fi
    
    cat <<EOF
{
  "url": "$url",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "grade": "$grade",
  "score": $pct,
  "raw_score": $total_score,
  "max_score": $total_max,
  "headers": {${json_headers}},
  "missing": ${missing_json},
  "warnings": ${warn_json},
  "recommendations": ${rec_json}
}
EOF
    return
  fi
  
  # Text output
  local present_count=$((${#HEADER_DEFS[@]} - ${#missing[@]}))
  [[ -n "$ONLY_HEADERS" ]] && present_count=$(($(echo "$ONLY_HEADERS" | tr ',' '\n' | wc -l) - ${#missing[@]}))
  
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
  printf "${BOLD}║  Security Headers Report: %-27s ║${NC}\n" "$url"
  printf "${BOLD}║  Grade: %-2s (%d/100)%*s║${NC}\n" "$grade" "$pct" $((36 - ${#grade} - ${#pct})) ""
  echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "$text_output"
  echo -e "${CYAN}Summary: ${present_count} present | ${#missing[@]} missing | ${#warnings[@]} warnings${NC}"
  
  # Generate fix if requested
  if [[ -n "$FIX_SERVER" && ${#missing[@]} -gt 0 ]]; then
    generate_fix "$FIX_SERVER" "${missing[@]}"
  fi
}

# ── Run ──
for url in "${URLS[@]}"; do
  scan_url "$url"
  [[ ${#URLS[@]} -gt 1 ]] && echo "---"
done
