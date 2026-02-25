#!/bin/bash
# Show storage usage report for a remote
set -euo pipefail

REMOTE="${1:-}"

if [[ -z "$REMOTE" ]]; then
  echo "Usage: $(basename "$0") <remote:path>"
  echo "Example: $(basename "$0") s3:my-bucket"
  exit 1
fi

echo "📊 Storage Report: $REMOTE"
echo ""

# Get total size and count
SIZE_OUTPUT=$(rclone size "$REMOTE" 2>/dev/null)
TOTAL_COUNT=$(echo "$SIZE_OUTPUT" | grep "Total objects" | awk '{print $3}')
TOTAL_SIZE=$(echo "$SIZE_OUTPUT" | grep "Total size" | sed 's/Total size: //')

echo "├── Total files: ${TOTAL_COUNT:-0}"
echo "├── Total size: ${TOTAL_SIZE:-0}"

# Find largest files
echo "├── Largest files:"
rclone ls "$REMOTE" 2>/dev/null | sort -rn | head -5 | while read -r size path; do
  if [[ $size -ge 1073741824 ]]; then
    HR=$(awk "BEGIN {printf \"%.1f GiB\", $size/1073741824}")
  elif [[ $size -ge 1048576 ]]; then
    HR=$(awk "BEGIN {printf \"%.1f MiB\", $size/1048576}")
  elif [[ $size -ge 1024 ]]; then
    HR=$(awk "BEGIN {printf \"%.1f KiB\", $size/1024}")
  else
    HR="${size} B"
  fi
  echo "│   $path ($HR)"
done

# Group by extension
echo "└── By type:"
rclone ls "$REMOTE" 2>/dev/null | awk '{print $2}' | grep -oE '\.[^.]+$' | sort | uniq -c | sort -rn | head -10 | while read -r count ext; do
  echo "    ├── $ext: $count files"
done

echo ""
echo "Done."
