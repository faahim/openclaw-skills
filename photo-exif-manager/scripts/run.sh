#!/bin/bash
# Photo EXIF Manager — View, strip, and batch-edit EXIF metadata
set -euo pipefail

BACKUP="${EXIF_BACKUP:-true}"
EXTENSIONS="${EXIF_EXTENSIONS:-jpg,jpeg,png,tiff,tif,heic,raw,cr2,nef,arw,dng,orf,rw2}"

# Build find pattern from extensions
build_find_pattern() {
  local dir="$1"
  local args=(-type f \()
  local first=true
  IFS=',' read -ra exts <<< "$EXTENSIONS"
  for ext in "${exts[@]}"; do
    if $first; then first=false; else args+=(-o); fi
    args+=(-iname "*.${ext}")
  done
  args+=(\))
  find "$dir" "${args[@]}" 2>/dev/null | sort
}

# Backup original if enabled
maybe_backup() {
  local file="$1"
  if [[ "$BACKUP" == "true" && ! -f "${file}.original" ]]; then
    cp "$file" "${file}.original"
  fi
}

cmd_view() {
  local file="$1"
  if [[ ! -f "$file" ]]; then echo "❌ File not found: $file"; exit 1; fi

  echo "━━━ EXIF: $(basename "$file") ━━━"

  local camera lens date exposure fstop iso res gps filesize
  camera=$(exiftool -s3 -Model "$file" 2>/dev/null || echo "Unknown")
  lens=$(exiftool -s3 -LensModel "$file" 2>/dev/null || echo "Unknown")
  date=$(exiftool -s3 -DateTimeOriginal "$file" 2>/dev/null || echo "Unknown")
  exposure=$(exiftool -s3 -ExposureTime "$file" 2>/dev/null || echo "—")
  fstop=$(exiftool -s3 -FNumber "$file" 2>/dev/null || echo "—")
  iso=$(exiftool -s3 -ISO "$file" 2>/dev/null || echo "—")
  res=$(exiftool -s3 -ImageSize "$file" 2>/dev/null || echo "Unknown")
  filesize=$(exiftool -s3 -FileSize "$file" 2>/dev/null || echo "Unknown")

  # GPS
  local gps_lat gps_lon
  gps_lat=$(exiftool -s3 -n -GPSLatitude "$file" 2>/dev/null || echo "")
  gps_lon=$(exiftool -s3 -n -GPSLongitude "$file" 2>/dev/null || echo "")

  printf "Camera:      %s\n" "$camera"
  printf "Lens:        %s\n" "$lens"
  printf "Date:        %s\n" "$date"
  printf "Exposure:    %s  f/%s  ISO %s\n" "$exposure" "$fstop" "$iso"
  printf "Resolution:  %s\n" "$res"
  if [[ -n "$gps_lat" && -n "$gps_lon" && "$gps_lat" != "0" ]]; then
    printf "GPS:         %s, %s\n" "$gps_lat" "$gps_lon"
    printf "Map:         https://www.google.com/maps?q=%s,%s\n" "$gps_lat" "$gps_lon"
  else
    printf "GPS:         None\n"
  fi
  printf "File Size:   %s\n" "$filesize"
}

cmd_strip_gps() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then echo "❌ Directory not found: $dir"; exit 1; fi

  local count=0 stripped=0
  while IFS= read -r file; do
    count=$((count + 1))
    local has_gps
    has_gps=$(exiftool -s3 -n -GPSLatitude "$file" 2>/dev/null || echo "")
    if [[ -n "$has_gps" && "$has_gps" != "0" ]]; then
      maybe_backup "$file"
      exiftool -overwrite_original -gps:all= "$file" >/dev/null 2>&1
      stripped=$((stripped + 1))
      echo "[$count] ✅ Stripped GPS: $(basename "$file")"
    else
      echo "[$count] ⏭️  No GPS: $(basename "$file")"
    fi
  done < <(build_find_pattern "$dir")

  echo "━━━ Done: $count files processed, $stripped had GPS data removed ━━━"
}

cmd_rename_by_date() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then echo "❌ Directory not found: $dir"; exit 1; fi

  local count=0
  while IFS= read -r file; do
    local date_str
    date_str=$(exiftool -s3 -d "%Y-%m-%d_%H%M%S" -DateTimeOriginal "$file" 2>/dev/null || echo "")
    if [[ -z "$date_str" ]]; then
      echo "⏭️  No date: $(basename "$file")"
      continue
    fi
    local ext="${file##*.}"
    local newname="${date_str}.${ext,,}"
    local newpath="$(dirname "$file")/$newname"

    # Handle duplicates
    local suffix=1
    while [[ -f "$newpath" && "$newpath" != "$file" ]]; do
      newname="${date_str}_${suffix}.${ext,,}"
      newpath="$(dirname "$file")/$newname"
      suffix=$((suffix + 1))
    done

    if [[ "$newpath" != "$file" ]]; then
      mv "$file" "$newpath"
      count=$((count + 1))
      echo "$(basename "$file") → $newname"
    fi
  done < <(build_find_pattern "$dir")

  echo "━━━ Renamed $count files ━━━"
}

cmd_export_csv() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then echo "❌ Directory not found: $dir"; exit 1; fi

  echo "filename,camera,lens,date,exposure,fstop,iso,gps_lat,gps_lon,filesize"
  while IFS= read -r file; do
    local fname camera lens date exposure fstop iso gps_lat gps_lon filesize
    fname=$(basename "$file")
    camera=$(exiftool -s3 -Model "$file" 2>/dev/null | tr ',' ';' || echo "")
    lens=$(exiftool -s3 -LensModel "$file" 2>/dev/null | tr ',' ';' || echo "")
    date=$(exiftool -s3 -DateTimeOriginal "$file" 2>/dev/null || echo "")
    exposure=$(exiftool -s3 -ExposureTime "$file" 2>/dev/null || echo "")
    fstop=$(exiftool -s3 -FNumber "$file" 2>/dev/null || echo "")
    iso=$(exiftool -s3 -ISO "$file" 2>/dev/null || echo "")
    gps_lat=$(exiftool -s3 -n -GPSLatitude "$file" 2>/dev/null || echo "")
    gps_lon=$(exiftool -s3 -n -GPSLongitude "$file" 2>/dev/null || echo "")
    filesize=$(exiftool -s3 -FileSize "$file" 2>/dev/null | tr ',' ';' || echo "")
    echo "$fname,$camera,$lens,$date,$exposure,$fstop,$iso,$gps_lat,$gps_lon,$filesize"
  done < <(build_find_pattern "$dir")
}

cmd_set_field() {
  local dir="$1" field="$2" value="$3"
  if [[ ! -d "$dir" ]]; then echo "❌ Directory not found: $dir"; exit 1; fi

  local count=0
  while IFS= read -r file; do
    count=$((count + 1))
    maybe_backup "$file"
    exiftool -overwrite_original "-${field}=${value}" "$file" >/dev/null 2>&1
    echo "[$count] ✅ Set $field on $(basename "$file")"
  done < <(build_find_pattern "$dir")

  echo "━━━ Updated $field on $count files ━━━"
}

cmd_strip_all() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then echo "❌ Directory not found: $dir"; exit 1; fi

  local count=0 total_saved=0
  while IFS= read -r file; do
    count=$((count + 1))
    local before after saved
    before=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
    maybe_backup "$file"
    exiftool -overwrite_original -all= "$file" >/dev/null 2>&1
    after=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
    saved=$(( (before - after) ))
    total_saved=$((total_saved + saved))
    local saved_kb=$((saved / 1024))
    echo "[$count] ✅ Stripped all metadata: $(basename "$file") (saved ${saved_kb} KB)"
  done < <(build_find_pattern "$dir")

  local total_mb
  total_mb=$(echo "scale=1; $total_saved / 1048576" | bc 2>/dev/null || echo "?")
  echo "━━━ Total space saved: ${total_mb} MB ━━━"
}

cmd_find_by() {
  local dir="$1" field="$2"
  if [[ ! -d "$dir" ]]; then echo "❌ Directory not found: $dir"; exit 1; fi

  if [[ "$field" == "camera" ]]; then
    local query="$3"
    echo "📷 Photos taken with: $query"
    echo "━━━"
    while IFS= read -r file; do
      local camera
      camera=$(exiftool -s3 -Model "$file" 2>/dev/null || echo "")
      if [[ "$camera" == *"$query"* ]]; then
        echo "  $(basename "$file") — $camera"
      fi
    done < <(build_find_pattern "$dir")
  elif [[ "$field" == "date" ]]; then
    local start_date="$3" end_date="${4:-$3}"
    echo "📅 Photos from $start_date to $end_date"
    echo "━━━"
    while IFS= read -r file; do
      local date_str
      date_str=$(exiftool -s3 -d "%Y-%m-%d" -DateTimeOriginal "$file" 2>/dev/null || echo "")
      if [[ -n "$date_str" && ! "$date_str" < "$start_date" && ! "$date_str" > "$end_date" ]]; then
        echo "  $(basename "$file") — $date_str"
      fi
    done < <(build_find_pattern "$dir")
  else
    echo "❌ Unknown field: $field (use 'camera' or 'date')"
    exit 1
  fi
}

cmd_gps_link() {
  local file="$1"
  if [[ ! -f "$file" ]]; then echo "❌ File not found: $file"; exit 1; fi

  local gps_lat gps_lon
  gps_lat=$(exiftool -s3 -n -GPSLatitude "$file" 2>/dev/null || echo "")
  gps_lon=$(exiftool -s3 -n -GPSLongitude "$file" 2>/dev/null || echo "")

  if [[ -n "$gps_lat" && -n "$gps_lon" && "$gps_lat" != "0" ]]; then
    echo "📍 GPS: ${gps_lat}, ${gps_lon}"
    echo "🗺️  https://www.google.com/maps?q=${gps_lat},${gps_lon}"
  else
    echo "❌ No GPS data in $(basename "$file")"
  fi
}

# ── Main ──
usage() {
  echo "Photo EXIF Manager"
  echo ""
  echo "Usage: bash run.sh <command> [args]"
  echo ""
  echo "Commands:"
  echo "  view <file>                  View EXIF data for a single photo"
  echo "  strip-gps <dir>             Remove GPS data from all photos in directory"
  echo "  rename-by-date <dir>        Rename photos to YYYY-MM-DD_HHMMSS format"
  echo "  export-csv <dir>            Export EXIF data to CSV"
  echo "  set-field <dir> <field> <v> Set a metadata field on all photos"
  echo "  strip-all <dir>             Remove ALL metadata from photos"
  echo "  find-by <dir> camera <name> Find photos by camera model"
  echo "  find-by <dir> date <from> [to]  Find photos by date range"
  echo "  gps-link <file>             Get Google Maps link for photo GPS"
}

if [[ $# -lt 1 ]]; then usage; exit 1; fi

COMMAND="$1"; shift

case "$COMMAND" in
  view)         cmd_view "$@" ;;
  strip-gps)    cmd_strip_gps "$@" ;;
  rename-by-date) cmd_rename_by_date "$@" ;;
  export-csv)   cmd_export_csv "$@" ;;
  set-field)    cmd_set_field "$@" ;;
  strip-all)    cmd_strip_all "$@" ;;
  find-by)      cmd_find_by "$@" ;;
  gps-link)     cmd_gps_link "$@" ;;
  *)            echo "❌ Unknown command: $COMMAND"; usage; exit 1 ;;
esac
