#!/bin/bash
# License Scanner — Main scanning script
# Scans Node.js, Python, and Rust projects for license compliance
set -euo pipefail

# --- Defaults ---
DIR="."
FORMAT="terminal"
OUTPUT=""
POLICY="permissive"
POLICY_FILE=""
TYPE="auto"
STRICT=false
PRODUCTION_ONLY=false
DEEP=false
RECURSIVE=false
SBOM=false
DIFF_FILE=""
SUGGEST=false

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Parse Args ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --dir) DIR="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --policy) POLICY="$2"; shift 2 ;;
    --policy-file) POLICY_FILE="$2"; shift 2 ;;
    --type) TYPE="$2"; shift 2 ;;
    --strict) STRICT=true; shift ;;
    --production-only) PRODUCTION_ONLY=true; shift ;;
    --deep) DEEP=true; shift ;;
    --recursive) RECURSIVE=true; shift ;;
    --sbom) SBOM=true; shift ;;
    --diff) DIFF_FILE="$2"; shift 2 ;;
    --suggest) SUGGEST=true; shift ;;
    -h|--help) echo "Usage: scan.sh --dir <path> [--policy commercial|permissive|copyleft] [--format terminal|json|csv|markdown] [--output file] [--strict] [--sbom]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Resolve directory
DIR=$(realpath "$DIR" 2>/dev/null || echo "$DIR")
if [[ ! -d "$DIR" ]]; then
  echo -e "${RED}❌ Directory not found: $DIR${NC}"
  exit 1
fi

# --- Policy Definitions ---
declare -A POLICY_DENY
declare -A POLICY_REVIEW

load_policy() {
  local pf="${POLICY_FILE:-$DIR/.license-policy.json}"
  if [[ -f "$pf" ]]; then
    POLICY="custom"
    # Load from file
    return
  fi
  
  case "$POLICY" in
    commercial)
      POLICY_DENY=([GPL-2.0]=1 [GPL-3.0]=1 [AGPL-3.0]=1 [GPL-2.0-only]=1 [GPL-3.0-only]=1 [AGPL-3.0-only]=1 [GPL-2.0-or-later]=1 [GPL-3.0-or-later]=1)
      POLICY_REVIEW=([LGPL-2.1]=1 [LGPL-3.0]=1 [MPL-2.0]=1 [LGPL-2.1-only]=1 [LGPL-3.0-only]=1 [LGPL-2.1-or-later]=1 [LGPL-3.0-or-later]=1 [EUPL-1.2]=1)
      ;;
    permissive)
      POLICY_DENY=([AGPL-3.0]=1 [AGPL-3.0-only]=1)
      POLICY_REVIEW=([GPL-2.0]=1 [GPL-3.0]=1 [GPL-2.0-only]=1 [GPL-3.0-only]=1)
      ;;
    copyleft)
      POLICY_DENY=()
      POLICY_REVIEW=()
      ;;
  esac
}

# --- Detect Project Type ---
detect_type() {
  local dir="$1"
  if [[ -f "$dir/package.json" ]]; then
    echo "node"
  elif [[ -f "$dir/requirements.txt" ]] || [[ -f "$dir/pyproject.toml" ]] || [[ -f "$dir/setup.py" ]] || [[ -f "$dir/Pipfile" ]]; then
    echo "python"
  elif [[ -f "$dir/Cargo.toml" ]]; then
    echo "rust"
  else
    echo "unknown"
  fi
}

# --- Scan Node.js ---
scan_node() {
  local dir="$1"
  local tmpfile=$(mktemp)
  
  echo -e "${BLUE}📦 Scanning Node.js project (package.json found)...${NC}" >&2
  
  local extra_args=""
  if [[ "$PRODUCTION_ONLY" == true ]]; then
    extra_args="--production"
  fi
  
  # Use license-checker
  if command -v license-checker &>/dev/null; then
    (cd "$dir" && license-checker --json $extra_args 2>/dev/null) > "$tmpfile" || {
      # Fallback: try npx
      (cd "$dir" && npx --yes license-checker --json $extra_args 2>/dev/null) > "$tmpfile"
    }
  else
    (cd "$dir" && npx --yes license-checker --json $extra_args 2>/dev/null) > "$tmpfile"
  fi
  
  # Parse results
  if [[ ! -s "$tmpfile" ]]; then
    echo -e "${RED}❌ No results from license-checker. Is node_modules installed?${NC}" >&2
    echo "   Run: cd $dir && npm install" >&2
    rm -f "$tmpfile"
    return 1
  fi
  
  # Convert to our standard format
  jq -r 'to_entries | map({
    name: (.key | ltrimstr("@") | split("@") | .[0:-1] | join("@") | if (input_line_number == 0) then . else . end | if (.key | startswith("@")) then ("@" + .) else . end),
    version: (.key | split("@") | .[-1]),
    license: (if .value.licenses then (if (.value.licenses | type) == "array" then .value.licenses[0] else .value.licenses end) else "UNKNOWN" end),
    repository: (.value.repository // ""),
    publisher: (.value.publisher // "")
  })' "$tmpfile" 2>/dev/null || jq 'to_entries | map({
    name: (.key | sub("@[^@]*$"; "")),
    version: (.key | split("@") | .[-1]),
    license: (if .value.licenses then (if (.value.licenses | type) == "array" then .value.licenses[0] else .value.licenses end) else "UNKNOWN" end),
    repository: (.value.repository // ""),
    publisher: (.value.publisher // "")
  })' "$tmpfile" 2>/dev/null || {
    echo -e "${YELLOW}⚠️  Failed to parse license-checker output${NC}" >&2
    rm -f "$tmpfile"
    return 1
  }
  
  rm -f "$tmpfile"
}

# --- Scan Python ---
scan_python() {
  local dir="$1"
  
  echo -e "${BLUE}📦 Scanning Python project...${NC}" >&2
  
  if ! python3 -m pip show pip-licenses &>/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  pip-licenses not installed. Run: pip3 install pip-licenses${NC}" >&2
    return 1
  fi
  
  # If virtualenv, activate it
  local venv_activate=""
  for vpath in "$dir/venv" "$dir/.venv" "$dir/env"; do
    if [[ -f "$vpath/bin/activate" ]]; then
      venv_activate="$vpath/bin/activate"
      break
    fi
  done
  
  local result
  if [[ -n "$venv_activate" ]]; then
    result=$(source "$venv_activate" && pip-licenses --format=json 2>/dev/null)
  else
    result=$(cd "$dir" && python3 -m piplicenses --format=json 2>/dev/null || pip-licenses --format=json 2>/dev/null)
  fi
  
  echo "$result" | jq '[.[] | {
    name: .Name,
    version: .Version,
    license: .License,
    repository: "",
    publisher: ""
  }]' 2>/dev/null || echo "[]"
}

# --- Scan Rust ---
scan_rust() {
  local dir="$1"
  
  echo -e "${BLUE}📦 Scanning Rust project (Cargo.toml found)...${NC}" >&2
  
  if ! command -v cargo-license &>/dev/null; then
    echo -e "${YELLOW}⚠️  cargo-license not installed. Run: cargo install cargo-license${NC}" >&2
    return 1
  fi
  
  (cd "$dir" && cargo license --json 2>/dev/null) | jq '[.[] | {
    name: .name,
    version: .version,
    license: .license,
    repository: (.repository // ""),
    publisher: (.authors // "" | if type == "array" then .[0] // "" else . end)
  }]' 2>/dev/null || echo "[]"
}

# --- Analyze Results ---
analyze() {
  local results="$1"
  local total=$(echo "$results" | jq 'length')
  local violations=()
  local reviews=()
  local unknowns=()
  
  # Count by license
  local summary=$(echo "$results" | jq -r '[.[].license] | group_by(.) | map({license: .[0], count: length}) | sort_by(-.count)')
  
  # Classify
  while IFS= read -r line; do
    local name=$(echo "$line" | jq -r '.name')
    local version=$(echo "$line" | jq -r '.version')
    local license=$(echo "$line" | jq -r '.license')
    
    # Normalize license
    local norm_license=$(echo "$license" | sed 's/ *$//;s/^ *//' | tr -d '()')
    
    if [[ "$norm_license" == "UNKNOWN" ]] || [[ "$norm_license" == "" ]] || [[ "$norm_license" == "null" ]]; then
      unknowns+=("$name@$version")
    elif [[ -n "${POLICY_DENY[$norm_license]+x}" ]]; then
      violations+=("$norm_license|$name@$version")
    elif [[ -n "${POLICY_REVIEW[$norm_license]+x}" ]]; then
      reviews+=("$norm_license|$name@$version")
    fi
  done < <(echo "$results" | jq -c '.[]')
  
  # --- Terminal Output ---
  if [[ "$FORMAT" == "terminal" ]]; then
    echo ""
    echo -e "${GREEN}✅ $total dependencies scanned${NC}"
    echo ""
    echo "LICENSE SUMMARY:"
    echo "$summary" | jq -r '.[] | "  \(.license)\t│ \(.count)"' | column -t -s $'\t'
    echo ""
    echo -e "POLICY: ${BLUE}$POLICY${NC}"
    
    if [[ ${#violations[@]} -gt 0 ]]; then
      echo ""
      echo -e "${RED}❌ VIOLATIONS FOUND: ${#violations[@]} packages${NC}"
      for v in "${violations[@]}"; do
        IFS='|' read -r lic pkg <<< "$v"
        echo -e "  ${RED}$lic${NC}\t│ $pkg"
      done
    fi
    
    if [[ ${#reviews[@]} -gt 0 ]]; then
      echo ""
      echo -e "${YELLOW}⚠️  REVIEW NEEDED: ${#reviews[@]} packages${NC}"
      for r in "${reviews[@]}"; do
        IFS='|' read -r lic pkg <<< "$r"
        echo -e "  ${YELLOW}$lic${NC}\t│ $pkg"
      done
    fi
    
    if [[ ${#unknowns[@]} -gt 0 ]]; then
      echo ""
      echo -e "${YELLOW}🔍 UNKNOWN LICENSE: ${#unknowns[@]} packages${NC}"
      for u in "${unknowns[@]}"; do
        echo "  $u"
      done
    fi
    
    if [[ ${#violations[@]} -eq 0 ]] && [[ ${#unknowns[@]} -eq 0 ]]; then
      echo ""
      echo -e "${GREEN}✅ No license violations found!${NC}"
    fi
  fi
  
  # --- JSON Output ---
  if [[ "$FORMAT" == "json" ]] || [[ -n "$OUTPUT" && "$FORMAT" == "json" ]]; then
    local json_out=$(jq -n \
      --argjson results "$results" \
      --argjson summary "$summary" \
      --arg policy "$POLICY" \
      --arg scanned_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg total "$total" \
      --arg violation_count "${#violations[@]}" \
      '{
        scanned_at: $scanned_at,
        total_dependencies: ($total | tonumber),
        policy: $policy,
        violations: ($violation_count | tonumber),
        summary: $summary,
        dependencies: $results
      }')
    
    if [[ -n "$OUTPUT" ]]; then
      echo "$json_out" > "$OUTPUT"
      echo -e "${GREEN}📄 Report saved to $OUTPUT${NC}"
    else
      echo "$json_out"
    fi
  fi
  
  # --- CSV Output ---
  if [[ "$FORMAT" == "csv" ]]; then
    local csv_out="name,version,license,status"
    while IFS= read -r line; do
      local name=$(echo "$line" | jq -r '.name')
      local version=$(echo "$line" | jq -r '.version')
      local license=$(echo "$line" | jq -r '.license')
      local status="ok"
      
      local norm=$(echo "$license" | sed 's/ *$//;s/^ *//')
      if [[ -n "${POLICY_DENY[$norm]+x}" ]]; then status="violation"
      elif [[ -n "${POLICY_REVIEW[$norm]+x}" ]]; then status="review"
      elif [[ "$norm" == "UNKNOWN" ]] || [[ "$norm" == "" ]]; then status="unknown"
      fi
      
      csv_out="$csv_out\n$name,$version,$license,$status"
    done < <(echo "$results" | jq -c '.[]')
    
    if [[ -n "$OUTPUT" ]]; then
      echo -e "$csv_out" > "$OUTPUT"
      echo -e "${GREEN}📄 CSV saved to $OUTPUT${NC}"
    else
      echo -e "$csv_out"
    fi
  fi
  
  # --- Markdown Output ---
  if [[ "$FORMAT" == "markdown" ]]; then
    local md="# License Compliance Report\n\n"
    md+="**Scanned:** $(date -u +%Y-%m-%d)\n"
    md+="**Policy:** $POLICY\n"
    md+="**Total dependencies:** $total\n\n"
    md+="## Summary\n\n| License | Count |\n|---------|-------|\n"
    md+=$(echo "$summary" | jq -r '.[] | "| \(.license) | \(.count) |"')
    md+="\n\n"
    
    if [[ ${#violations[@]} -gt 0 ]]; then
      md+="## ❌ Violations\n\n| License | Package |\n|---------|--------|\n"
      for v in "${violations[@]}"; do
        IFS='|' read -r lic pkg <<< "$v"
        md+="| $lic | $pkg |\n"
      done
      md+="\n"
    fi
    
    if [[ -n "$OUTPUT" ]]; then
      echo -e "$md" > "$OUTPUT"
      echo -e "${GREEN}📄 Markdown saved to $OUTPUT${NC}"
    else
      echo -e "$md"
    fi
  fi
  
  # --- SBOM Output ---
  if [[ "$SBOM" == true ]]; then
    local sbom_out=$(echo "$results" | jq '{
      bomFormat: "CycloneDX",
      specVersion: "1.4",
      serialNumber: ("urn:uuid:" + (now | tostring)),
      version: 1,
      metadata: {
        timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
        tools: [{ vendor: "license-scanner", name: "license-scanner", version: "1.0.0" }]
      },
      components: [.[] | {
        type: "library",
        name: .name,
        version: .version,
        licenses: [{ license: { id: .license } }],
        purl: ("pkg:npm/" + .name + "@" + .version)
      }]
    }')
    
    local sbom_file="${OUTPUT:-sbom.json}"
    echo "$sbom_out" > "$sbom_file"
    echo -e "${GREEN}📄 SBOM saved to $sbom_file${NC}"
  fi
  
  # --- Exit Code ---
  if [[ "$STRICT" == true ]]; then
    if [[ ${#violations[@]} -gt 0 ]]; then
      exit 1
    fi
  fi
}

# --- Main ---
load_policy

if [[ "$TYPE" == "auto" ]]; then
  TYPE=$(detect_type "$DIR")
fi

case "$TYPE" in
  node)
    RESULTS=$(scan_node "$DIR")
    ;;
  python)
    RESULTS=$(scan_python "$DIR")
    ;;
  rust)
    RESULTS=$(scan_rust "$DIR")
    ;;
  unknown)
    echo -e "${RED}❌ Could not detect project type in $DIR${NC}"
    echo "   Supported: Node.js (package.json), Python (requirements.txt), Rust (Cargo.toml)"
    echo "   Use --type node|python|rust to specify manually"
    exit 1
    ;;
esac

if [[ -n "$RESULTS" ]] && [[ "$RESULTS" != "[]" ]]; then
  analyze "$RESULTS"
else
  echo -e "${YELLOW}⚠️  No dependencies found or scan failed${NC}"
  exit 1
fi
