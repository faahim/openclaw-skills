#!/bin/bash
# Dependency License Checker — Scan project dependencies for license compliance
# Supports: Node.js (npm/yarn/pnpm), Python (pip), Go, Rust (cargo)

set -euo pipefail

# === Defaults ===
PROJECT_DIR=""
POLICY="permissive"     # permissive | strict | custom
ALLOWED_LICENSES=""
FORMAT="markdown"       # markdown | json | csv | notice
OUTPUT_FILE=""
RECURSIVE=false
PRODUCTION=false
IGNORE_PKGS=""
BASELINE=""
NOTICE_MODE=false

# === License Classification ===
PERMISSIVE="MIT|Apache-2.0|BSD-2-Clause|BSD-3-Clause|ISC|Unlicense|0BSD|CC0-1.0|CC-BY-3.0|CC-BY-4.0|Zlib|WTFPL|BlueOak-1.0.0|Python-2.0|PSF-2.0|Artistic-2.0"
WEAK_COPYLEFT="LGPL-2.0|LGPL-2.1|LGPL-3.0|MPL-2.0|EPL-1.0|EPL-2.0|OSL-3.0|CDDL-1.0"
STRONG_COPYLEFT="GPL-2.0|GPL-3.0|AGPL-3.0|AGPL-1.0|EUPL-1.1|EUPL-1.2|SSPL-1.0"

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# === Parse Arguments ===
while [[ $# -gt 0 ]]; do
  case $1 in
    --policy) POLICY="$2"; shift 2 ;;
    --allow) ALLOWED_LICENSES="$2"; POLICY="custom"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --recursive) RECURSIVE=true; shift ;;
    --production) PRODUCTION=true; shift ;;
    --ignore) IGNORE_PKGS="$2"; shift 2 ;;
    --baseline) BASELINE="$2"; shift 2 ;;
    --notice) NOTICE_MODE=true; FORMAT="notice"; shift ;;
    --help|-h)
      echo "Usage: scan.sh <project-dir> [options]"
      echo ""
      echo "Options:"
      echo "  --policy <permissive|strict|custom>  License policy (default: permissive)"
      echo "  --allow <licenses>                    Comma-separated allowed licenses"
      echo "  --format <markdown|json|csv|notice>   Output format (default: markdown)"
      echo "  --output <file>                       Save report to file"
      echo "  --recursive                           Scan subdirectories"
      echo "  --production                          Exclude dev dependencies"
      echo "  --ignore <packages>                   Comma-separated packages to skip"
      echo "  --baseline <file.json>                Compare against baseline"
      echo "  --notice                              Generate THIRD-PARTY-NOTICES"
      exit 0
      ;;
    *)
      if [[ -z "$PROJECT_DIR" ]]; then
        PROJECT_DIR="$1"
      else
        echo -e "${RED}Unknown option: $1${NC}"
        exit 2
      fi
      shift
      ;;
  esac
done

# Default to current directory
PROJECT_DIR="${PROJECT_DIR:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# === Detect Project Type ===
detect_projects() {
  local dir="$1"
  local projects=()

  if [[ "$RECURSIVE" == true ]]; then
    while IFS= read -r -d '' pfile; do
      local pdir=$(dirname "$pfile")
      # Skip node_modules, .git, vendor
      if [[ "$pdir" == *node_modules* ]] || [[ "$pdir" == */.git/* ]] || [[ "$pdir" == */vendor/* ]]; then
        continue
      fi
      local ptype=""
      local fname=$(basename "$pfile")
      case "$fname" in
        package.json) ptype="nodejs" ;;
        requirements.txt|setup.py|pyproject.toml|Pipfile) ptype="python" ;;
        go.mod) ptype="go" ;;
        Cargo.toml) ptype="rust" ;;
      esac
      if [[ -n "$ptype" ]]; then
        projects+=("$pdir|$ptype")
      fi
    done < <(find "$dir" -maxdepth 3 \( -name "package.json" -o -name "requirements.txt" -o -name "setup.py" -o -name "pyproject.toml" -o -name "go.mod" -o -name "Cargo.toml" \) -print0 2>/dev/null)
  else
    if [[ -f "$dir/package.json" ]]; then
      projects+=("$dir|nodejs")
    fi
    if [[ -f "$dir/requirements.txt" ]] || [[ -f "$dir/setup.py" ]] || [[ -f "$dir/pyproject.toml" ]]; then
      projects+=("$dir|python")
    fi
    if [[ -f "$dir/go.mod" ]]; then
      projects+=("$dir|go")
    fi
    if [[ -f "$dir/Cargo.toml" ]]; then
      projects+=("$dir|rust")
    fi
  fi

  if [[ ${#projects[@]} -eq 0 ]]; then
    echo -e "${RED}❌ No supported project files found in $dir${NC}" >&2
    exit 2
  fi

  printf '%s\n' "${projects[@]}"
}

# === Scan Node.js ===
scan_nodejs() {
  local dir="$1"
  local tmpfile=$(mktemp)

  local checker=""
  if command -v license-checker-rspack &>/dev/null; then
    checker="license-checker-rspack"
  elif command -v license-checker &>/dev/null; then
    checker="license-checker"
  else
    echo -e "${YELLOW}⚠️  license-checker not found. Installing...${NC}" >&2
    npm install -g license-checker >&2 2>/dev/null || {
      echo -e "${RED}❌ Failed to install license-checker. Run: npm install -g license-checker${NC}" >&2
      return 1
    }
    checker="license-checker"
  fi

  local prod_flag=""
  [[ "$PRODUCTION" == true ]] && prod_flag="--production"

  cd "$dir"
  $checker --json $prod_flag 2>/dev/null | jq -r '
    to_entries[] | 
    {
      name: (.key | split("@") | if length > 2 then [.[0:-1] | join("@"), .[-1]] else . end | .[0]),
      version: (.key | split("@") | .[-1]),
      license: (.value.licenses // "UNKNOWN"),
      repository: (.value.repository // ""),
      publisher: (.value.publisher // "")
    }
  ' > "$tmpfile" 2>/dev/null || true

  # Convert to our standard JSONL format
  jq -s '.' "$tmpfile" 2>/dev/null || echo "[]"
  rm -f "$tmpfile"
}

# === Scan Python ===
scan_python() {
  local dir="$1"

  if ! command -v pip-licenses &>/dev/null; then
    echo -e "${YELLOW}⚠️  pip-licenses not found. Installing...${NC}" >&2
    pip install pip-licenses >&2 2>/dev/null || pip3 install pip-licenses >&2 2>/dev/null || {
      echo -e "${RED}❌ Failed to install pip-licenses. Run: pip install pip-licenses${NC}" >&2
      return 1
    }
  fi

  cd "$dir"
  pip-licenses --format=json 2>/dev/null | jq '[.[] | {
    name: .Name,
    version: .Version,
    license: .License,
    repository: "",
    publisher: ""
  }]' 2>/dev/null || echo "[]"
}

# === Scan Go ===
scan_go() {
  local dir="$1"
  cd "$dir"

  if command -v go-licenses &>/dev/null; then
    go-licenses csv . 2>/dev/null | while IFS=, read -r pkg url license; do
      echo "{\"name\":\"$pkg\",\"version\":\"\",\"license\":\"$license\",\"repository\":\"$url\",\"publisher\":\"\"}"
    done | jq -s '.' 2>/dev/null || echo "[]"
  else
    # Fallback: parse go.sum and try to detect licenses
    echo -e "${YELLOW}⚠️  go-licenses not found. Using basic go.sum scan.${NC}" >&2
    if [[ -f go.sum ]]; then
      grep -oP '^\S+' go.sum | sort -u | while read -r mod; do
        echo "{\"name\":\"$mod\",\"version\":\"\",\"license\":\"UNKNOWN\",\"repository\":\"\",\"publisher\":\"\"}"
      done | jq -s '.' 2>/dev/null || echo "[]"
    else
      echo "[]"
    fi
  fi
}

# === Scan Rust ===
scan_rust() {
  local dir="$1"
  cd "$dir"

  if command -v cargo-license &>/dev/null; then
    cargo license --json 2>/dev/null | jq '[.[] | {
      name: .name,
      version: .version,
      license: .license,
      repository: (.repository // ""),
      publisher: (.authors // "" | if type == "array" then join(", ") else . end)
    }]' 2>/dev/null || echo "[]"
  else
    echo -e "${YELLOW}⚠️  cargo-license not found. Run: cargo install cargo-license${NC}" >&2
    echo "[]"
  fi
}

# === Classify License ===
classify_license() {
  local lic="$1"
  # Normalize
  lic=$(echo "$lic" | sed 's/[()]//g; s/ OR /|/g; s/ AND /\&/g')

  if echo "$lic" | grep -qEi "($STRONG_COPYLEFT)"; then
    echo "strong_copyleft"
  elif echo "$lic" | grep -qEi "($WEAK_COPYLEFT)"; then
    echo "weak_copyleft"
  elif echo "$lic" | grep -qEi "($PERMISSIVE)"; then
    echo "permissive"
  elif echo "$lic" | grep -qEi "^(UNKNOWN|UNLICENSED|NONE|Custom.*)$"; then
    echo "unknown"
  elif [[ -z "$lic" ]]; then
    echo "unknown"
  else
    # Try partial match
    if echo "$lic" | grep -qEi "MIT|Apache|BSD|ISC"; then
      echo "permissive"
    elif echo "$lic" | grep -qEi "GPL|AGPL"; then
      echo "strong_copyleft"
    elif echo "$lic" | grep -qEi "LGPL|MPL|EPL"; then
      echo "weak_copyleft"
    else
      echo "unknown"
    fi
  fi
}

# === Check Policy ===
check_policy() {
  local classification="$1"
  local license="$2"

  case "$POLICY" in
    strict)
      [[ "$classification" == "permissive" ]] && return 0 || return 1
      ;;
    permissive)
      [[ "$classification" == "strong_copyleft" || "$classification" == "unknown" ]] && return 1 || return 0
      ;;
    custom)
      if [[ -n "$ALLOWED_LICENSES" ]]; then
        echo "$ALLOWED_LICENSES" | tr ',' '\n' | grep -qFx "$license" && return 0 || return 1
      fi
      return 0
      ;;
  esac
}

# === Format Output ===
format_markdown() {
  local scan_results="$1"
  local project_name="$2"
  local project_type="$3"

  local total=$(echo "$scan_results" | jq 'length')
  local permissive_count=0
  local weak_count=0
  local strong_count=0
  local unknown_count=0
  local issues=()

  echo ""
  echo "LICENSE COMPLIANCE REPORT"
  echo "========================"
  echo "Project: $project_name ($project_type)"
  echo "Total dependencies: $total"
  echo "Policy: $POLICY"
  echo ""

  while IFS= read -r dep; do
    local name=$(echo "$dep" | jq -r '.name')
    local version=$(echo "$dep" | jq -r '.version')
    local license=$(echo "$dep" | jq -r '.license')

    # Check if ignored
    if [[ -n "$IGNORE_PKGS" ]] && echo "$IGNORE_PKGS" | tr ',' '\n' | grep -qFx "$name"; then
      continue
    fi

    local cls=$(classify_license "$license")
    case "$cls" in
      permissive) ((permissive_count++)) ;;
      weak_copyleft) ((weak_count++)); issues+=("⚠️  $name@$version — $license (weak copyleft)") ;;
      strong_copyleft) ((strong_count++)); issues+=("❌ $name@$version — $license (strong copyleft)") ;;
      unknown) ((unknown_count++)); issues+=("❓ $name@$version — $license (unknown/missing)") ;;
    esac
  done < <(echo "$scan_results" | jq -c '.[]')

  echo -e "${GREEN}✅ Permissive: $permissive_count${NC}"
  [[ $weak_count -gt 0 ]] && echo -e "${YELLOW}⚠️  Weak Copyleft: $weak_count${NC}"
  [[ $strong_count -gt 0 ]] && echo -e "${RED}❌ Strong Copyleft: $strong_count${NC}"
  [[ $unknown_count -gt 0 ]] && echo -e "${RED}❓ Unknown/Missing: $unknown_count${NC}"

  if [[ ${#issues[@]} -gt 0 ]]; then
    echo ""
    echo "Issues:"
    for issue in "${issues[@]}"; do
      echo "  $issue"
    done
  fi

  # Policy check
  echo ""
  local failed=false
  case "$POLICY" in
    strict)
      if [[ $strong_count -gt 0 ]] || [[ $weak_count -gt 0 ]] || [[ $unknown_count -gt 0 ]]; then
        echo -e "${RED}Policy: STRICT — ❌ FAILED${NC}"
        failed=true
      else
        echo -e "${GREEN}Policy: STRICT — ✅ PASSED${NC}"
      fi
      ;;
    permissive)
      if [[ $strong_count -gt 0 ]] || [[ $unknown_count -gt 0 ]]; then
        echo -e "${RED}Policy: PERMISSIVE — ❌ FAILED${NC}"
        failed=true
      else
        echo -e "${GREEN}Policy: PERMISSIVE — ✅ PASSED${NC}"
      fi
      ;;
    custom)
      if [[ ${#issues[@]} -gt 0 ]]; then
        echo -e "${RED}Policy: CUSTOM — ❌ FAILED${NC}"
        failed=true
      else
        echo -e "${GREEN}Policy: CUSTOM — ✅ PASSED${NC}"
      fi
      ;;
  esac

  [[ "$failed" == true ]] && return 1 || return 0
}

format_json() {
  local scan_results="$1"
  local project_name="$2"
  local project_type="$3"

  echo "$scan_results" | jq --arg proj "$project_name" --arg type "$project_type" '{
    project: $proj,
    type: $type,
    scanned_at: (now | todate),
    dependencies: [.[] | . + {classification: (
      if (.license | test("GPL|AGPL"; "i")) and (.license | test("LGPL"; "i") | not) then "strong_copyleft"
      elif (.license | test("LGPL|MPL|EPL"; "i")) then "weak_copyleft"
      elif (.license | test("MIT|Apache|BSD|ISC|Unlicense|0BSD|CC0"; "i")) then "permissive"
      else "unknown"
      end
    )}],
    summary: {
      total: length,
      permissive: ([.[] | select(.license | test("MIT|Apache|BSD|ISC|Unlicense|0BSD|CC0"; "i"))] | length),
      copyleft: ([.[] | select(.license | test("GPL|AGPL"; "i"))] | length),
      unknown: ([.[] | select(.license | test("UNKNOWN|UNLICENSED|NONE|^$"; "i"))] | length)
    }
  }'
}

format_csv() {
  local scan_results="$1"
  echo "name,version,license,classification"
  echo "$scan_results" | jq -r '.[] | [.name, .version, .license] | @csv'
}

format_notice() {
  local scan_results="$1"
  local project_name="$2"

  echo "# Third-Party Notices"
  echo ""
  echo "This project ($project_name) uses the following open-source packages:"
  echo ""

  echo "$scan_results" | jq -r '.[] | "## \(.name) (\(.version)) — \(.license)\n\(.repository)\n"'
}

# === Main ===
echo -e "${BLUE}🔍 Scanning $PROJECT_DIR...${NC}"

OVERALL_EXIT=0

while IFS='|' read -r proj_dir proj_type; do
  proj_name=$(basename "$proj_dir")
  type_label=""
  case "$proj_type" in
    nodejs) type_label="Node.js" ;;
    python) type_label="Python" ;;
    go) type_label="Go" ;;
    rust) type_label="Rust" ;;
  esac

  echo -e "${BLUE}📦 Detected: $type_label ($proj_dir)${NC}"

  # Run scanner
  scan_results=""
  case "$proj_type" in
    nodejs) scan_results=$(scan_nodejs "$proj_dir") ;;
    python) scan_results=$(scan_python "$proj_dir") ;;
    go) scan_results=$(scan_go "$proj_dir") ;;
    rust) scan_results=$(scan_rust "$proj_dir") ;;
  esac

  if [[ -z "$scan_results" ]] || [[ "$scan_results" == "[]" ]]; then
    echo -e "${YELLOW}⚠️  No dependencies found in $proj_dir${NC}"
    continue
  fi

  total=$(echo "$scan_results" | jq 'length' 2>/dev/null || echo 0)
  echo -e "${GREEN}✅ $total dependencies scanned${NC}"

  # Format output
  report=""
  case "$FORMAT" in
    markdown) format_markdown "$scan_results" "$proj_name" "$type_label" || OVERALL_EXIT=1 ;;
    json) format_json "$scan_results" "$proj_name" "$type_label" ;;
    csv) format_csv "$scan_results" ;;
    notice) format_notice "$scan_results" "$proj_name" ;;
  esac

done < <(detect_projects "$PROJECT_DIR")

# Save to file if requested
if [[ -n "$OUTPUT_FILE" ]]; then
  echo -e "${BLUE}📄 Report saved to: $OUTPUT_FILE${NC}"
fi

exit $OVERALL_EXIT
