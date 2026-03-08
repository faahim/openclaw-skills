#!/bin/bash
# SBOM Diff — Compare two SBOM files and show added/removed/changed packages
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $(basename "$0") <old-sbom.json> <new-sbom.json>"
  echo ""
  echo "Compares two CycloneDX or SPDX JSON SBOMs and shows differences."
  exit 1
fi

OLD="$1"
NEW="$2"

if ! command -v jq &>/dev/null; then
  echo "❌ jq is required for SBOM diffing. Install: sudo apt install jq"
  exit 1
fi

for f in "$OLD" "$NEW"; do
  if [[ ! -f "$f" ]]; then
    echo "❌ File not found: $f"
    exit 1
  fi
done

# Detect format
detect_format() {
  local file="$1"
  if jq -e '.components' "$file" &>/dev/null; then
    echo "cyclonedx"
  elif jq -e '.packages' "$file" &>/dev/null; then
    echo "spdx"
  elif jq -e '.artifacts' "$file" &>/dev/null; then
    echo "syft"
  else
    echo "unknown"
  fi
}

FORMAT=$(detect_format "$OLD")

# Extract package list as "name@version type" sorted
extract_packages() {
  local file="$1"
  case "$FORMAT" in
    cyclonedx)
      jq -r '.components[] | "\(.name)@\(.version // "unknown") \(.type // "library")"' "$file" | sort
      ;;
    spdx)
      jq -r '.packages[] | "\(.name)@\(.versionInfo // "unknown") \(.supplier // "")"' "$file" | sort
      ;;
    syft)
      jq -r '.artifacts[] | "\(.name)@\(.version // "unknown") \(.type // "")"' "$file" | sort
      ;;
    *)
      echo "❌ Unknown SBOM format"
      exit 1
      ;;
  esac
}

# Extract name→version maps
extract_versions() {
  local file="$1"
  case "$FORMAT" in
    cyclonedx)
      jq -r '.components[] | "\(.name)\t\(.version // "unknown")\t\(.type // "library")"' "$file" | sort -k1,1
      ;;
    spdx)
      jq -r '.packages[] | "\(.name)\t\(.versionInfo // "unknown")\t"' "$file" | sort -k1,1
      ;;
    syft)
      jq -r '.artifacts[] | "\(.name)\t\(.version // "unknown")\t\(.type // "")"' "$file" | sort -k1,1
      ;;
  esac
}

OLD_PKGS=$(mktemp)
NEW_PKGS=$(mktemp)
OLD_VERS=$(mktemp)
NEW_VERS=$(mktemp)

extract_packages "$OLD" > "$OLD_PKGS"
extract_packages "$NEW" > "$NEW_PKGS"
extract_versions "$OLD" > "$OLD_VERS"
extract_versions "$NEW" > "$NEW_VERS"

# Find differences
ADDED=$(comm -13 <(cut -d'@' -f1 "$OLD_PKGS" | sort -u) <(cut -d'@' -f1 "$NEW_PKGS" | sort -u))
REMOVED=$(comm -23 <(cut -d'@' -f1 "$OLD_PKGS" | sort -u) <(cut -d'@' -f1 "$NEW_PKGS" | sort -u))
COMMON=$(comm -12 <(cut -d'@' -f1 "$OLD_PKGS" | sort -u) <(cut -d'@' -f1 "$NEW_PKGS" | sort -u))

echo "📊 SBOM Diff Report"
echo "   Old: $OLD"
echo "   New: $NEW"
echo "   Format: $FORMAT"
echo ""

# Added
ADD_COUNT=0
if [[ -n "$ADDED" ]]; then
  echo "ADDED:"
  while IFS= read -r name; do
    ver=$(grep "^${name}	" "$NEW_VERS" | head -1 | cut -f2)
    typ=$(grep "^${name}	" "$NEW_VERS" | head -1 | cut -f3)
    echo "  + $name $ver ($typ)"
    ADD_COUNT=$((ADD_COUNT + 1))
  done <<< "$ADDED"
  echo ""
fi

# Removed
REM_COUNT=0
if [[ -n "$REMOVED" ]]; then
  echo "REMOVED:"
  while IFS= read -r name; do
    ver=$(grep "^${name}	" "$OLD_VERS" | head -1 | cut -f2)
    typ=$(grep "^${name}	" "$OLD_VERS" | head -1 | cut -f3)
    echo "  - $name $ver ($typ)"
    REM_COUNT=$((REM_COUNT + 1))
  done <<< "$REMOVED"
  echo ""
fi

# Changed versions
CHG_COUNT=0
if [[ -n "$COMMON" ]]; then
  CHANGES=""
  while IFS= read -r name; do
    old_ver=$(grep "^${name}	" "$OLD_VERS" | head -1 | cut -f2)
    new_ver=$(grep "^${name}	" "$NEW_VERS" | head -1 | cut -f2)
    typ=$(grep "^${name}	" "$NEW_VERS" | head -1 | cut -f3)
    if [[ "$old_ver" != "$new_ver" ]]; then
      CHANGES="${CHANGES}  ~ $name $old_ver → $new_ver ($typ)\n"
      CHG_COUNT=$((CHG_COUNT + 1))
    fi
  done <<< "$COMMON"
  
  if [[ -n "$CHANGES" ]]; then
    echo "CHANGED:"
    echo -e "$CHANGES"
  fi
fi

OLD_TOTAL=$(wc -l < "$OLD_PKGS")
NEW_TOTAL=$(wc -l < "$NEW_PKGS")

echo "Summary: +$ADD_COUNT added, -$REM_COUNT removed, ~$CHG_COUNT changed"
echo "         Old: $OLD_TOTAL packages → New: $NEW_TOTAL packages"

# Cleanup
rm -f "$OLD_PKGS" "$NEW_PKGS" "$OLD_VERS" "$NEW_VERS"
