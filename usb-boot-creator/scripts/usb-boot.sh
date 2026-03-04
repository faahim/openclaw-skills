#!/bin/bash
# USB Boot Creator — Create bootable USB drives with dd or Ventoy
# Requires: bash 4+, curl, dd, lsblk, sha256sum
set -euo pipefail

VERSION="1.0.0"
ISO_DIR="${USB_BOOT_ISO_DIR:-$HOME/ISOs}"
NO_CONFIRM="${USB_BOOT_NO_CONFIRM:-false}"
VENTOY_VER="${VENTOY_VERSION:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}ℹ️  $*${NC}"; }
ok()    { echo -e "${GREEN}✅ $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $*${NC}"; }
err()   { echo -e "${RED}❌ $*${NC}" >&2; }

# ─── List removable USB drives ─────────────────────────────────
cmd_list_drives() {
  echo "USB Drives Detected:"
  local found=0
  while IFS= read -r line; do
    local name size model tran rm mountpoint
    name=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    model=$(echo "$line" | awk '{$1=$2=$3=$4=$5=""; print $0}' | xargs)
    tran=$(echo "$line" | awk '{print $3}')
    rm=$(echo "$line" | awk '{print $4}')
    mountpoint=$(echo "$line" | awk '{print $5}')

    # Only show USB removable drives (not partitions)
    if [[ "$tran" == "usb" ]] && [[ ! "$name" =~ [0-9]$ ]]; then
      found=1
      local mount_status="NOT mounted"
      # Check if any partition is mounted
      if lsblk -ln -o MOUNTPOINT "/dev/$name" 2>/dev/null | grep -q '/'; then
        mount_status="Mounted"
      fi
      printf "  /dev/%-6s — %s (%s) — %s\n" "$name" "${model:-Unknown}" "$size" "$mount_status"
    fi
  done < <(lsblk -dno NAME,SIZE,TRAN,RM,MOUNTPOINT 2>/dev/null)

  if [[ $found -eq 0 ]]; then
    echo "  (none found — plug in a USB drive)"
  fi
}

# ─── Verify ISO checksum ──────────────────────────────────────
cmd_verify() {
  local iso="" checksum="" checksum_url=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --iso) iso="$2"; shift 2;;
      --checksum) checksum="$2"; shift 2;;
      --checksum-url) checksum_url="$2"; shift 2;;
      *) err "Unknown option: $1"; exit 1;;
    esac
  done

  [[ -z "$iso" ]] && { err "Missing --iso"; exit 1; }
  [[ ! -f "$iso" ]] && { err "ISO not found: $iso"; exit 1; }

  if [[ -n "$checksum_url" ]]; then
    info "Fetching checksums from $checksum_url..."
    local basename_iso
    basename_iso=$(basename "$iso")
    checksum=$(curl -sfL "$checksum_url" | grep "$basename_iso" | awk '{print $1}')
    [[ -z "$checksum" ]] && { err "Could not find checksum for $basename_iso"; exit 1; }
  fi

  if [[ -z "$checksum" ]]; then
    err "No checksum provided. Use --checksum or --checksum-url"
    exit 1
  fi

  # Strip algorithm prefix if present (e.g., "sha256:abc123")
  local algo="sha256"
  if [[ "$checksum" == *:* ]]; then
    algo="${checksum%%:*}"
    checksum="${checksum#*:}"
  fi

  info "Verifying ${algo^^} checksum of $(basename "$iso")..."
  local actual
  case "$algo" in
    sha256) actual=$(sha256sum "$iso" | awk '{print $1}');;
    sha512) actual=$(sha512sum "$iso" | awk '{print $1}');;
    md5) actual=$(md5sum "$iso" | awk '{print $1}');;
    *) err "Unsupported algorithm: $algo"; exit 1;;
  esac

  if [[ "$actual" == "$checksum" ]]; then
    ok "Checksum verified: ${checksum:0:16}..."
    return 0
  else
    err "Checksum MISMATCH!"
    echo "  Expected: $checksum"
    echo "  Actual:   $actual"
    return 1
  fi
}

# ─── Download ISO ──────────────────────────────────────────────
cmd_download() {
  local url="" checksum="" output="$ISO_DIR"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --url) url="$2"; shift 2;;
      --checksum) checksum="$2"; shift 2;;
      --output) output="$2"; shift 2;;
      *) err "Unknown option: $1"; exit 1;;
    esac
  done

  [[ -z "$url" ]] && { err "Missing --url"; exit 1; }
  mkdir -p "$output"

  local filename
  filename=$(basename "$url")
  local filepath="$output/$filename"

  if [[ -f "$filepath" ]]; then
    warn "File already exists: $filepath"
    if [[ -n "$checksum" ]]; then
      if cmd_verify --iso "$filepath" --checksum "$checksum" 2>/dev/null; then
        info "Existing file is valid, skipping download."
        return 0
      fi
      warn "Existing file checksum mismatch, re-downloading..."
    fi
  fi

  info "Downloading $filename..."
  if command -v pv &>/dev/null; then
    curl -sfL "$url" | pv -s "$(curl -sI "$url" | grep -i content-length | awk '{print $2}' | tr -d '\r')" > "$filepath"
  else
    curl -fL --progress-bar "$url" -o "$filepath"
  fi

  ok "Downloaded to $filepath"

  if [[ -n "$checksum" ]]; then
    cmd_verify --iso "$filepath" --checksum "$checksum"
  fi
}

# ─── Safety checks for drive ──────────────────────────────────
validate_drive() {
  local drive="$1"

  # Must be a block device
  [[ ! -b "$drive" ]] && { err "$drive is not a block device"; exit 1; }

  # Must not be a partition
  [[ "$drive" =~ [0-9]$ ]] && { err "Specify the whole drive (e.g., /dev/sdb, not /dev/sdb1)"; exit 1; }

  # Must be removable USB
  local tran
  tran=$(lsblk -dno TRAN "$drive" 2>/dev/null || echo "")
  [[ "$tran" != "usb" ]] && { err "$drive does not appear to be a USB drive (transport: $tran)"; exit 1; }

  # Must not have mounted partitions (unless forced)
  if lsblk -lno MOUNTPOINT "$drive" 2>/dev/null | grep -q '/'; then
    err "$drive has mounted partitions. Unmount first: sudo umount ${drive}*"
    exit 1
  fi

  # Must not be the system drive
  local sys_drive
  sys_drive=$(findmnt -no SOURCE / | sed 's/[0-9]*$//' | sed 's/p[0-9]*$//')
  [[ "$drive" == "$sys_drive" ]] && { err "Refusing to flash system drive!"; exit 1; }
}

confirm_flash() {
  local drive="$1"
  local size model
  size=$(lsblk -dno SIZE "$drive" | xargs)
  model=$(lsblk -dno MODEL "$drive" | xargs)

  warn "All data on $drive (${model:-Unknown} ${size}) will be ERASED!"

  if [[ "$NO_CONFIRM" == "true" ]]; then
    warn "Skipping confirmation (USB_BOOT_NO_CONFIRM=true)"
    return 0
  fi

  read -rp "Type 'YES' to confirm: " response
  [[ "$response" == "YES" ]] || { info "Aborted."; exit 0; }
}

# ─── Flash ISO to drive ───────────────────────────────────────
cmd_flash() {
  local iso="" drive="" bs="4M" do_sync=true
  while [[ $# -gt 0 ]]; do
    case $1 in
      --iso) iso="$2"; shift 2;;
      --drive) drive="$2"; shift 2;;
      --bs) bs="$2"; shift 2;;
      --sync) do_sync=true; shift;;
      --no-sync) do_sync=false; shift;;
      *) err "Unknown option: $1"; exit 1;;
    esac
  done

  [[ -z "$iso" ]] && { err "Missing --iso"; exit 1; }
  [[ -z "$drive" ]] && { err "Missing --drive"; exit 1; }
  [[ ! -f "$iso" ]] && { err "ISO not found: $iso"; exit 1; }

  validate_drive "$drive"

  # Size check
  local iso_size drive_size
  iso_size=$(stat -c %s "$iso" 2>/dev/null || stat -f %z "$iso")
  drive_size=$(lsblk -bdno SIZE "$drive")
  if (( iso_size > drive_size )); then
    err "ISO ($(numfmt --to=iec "$iso_size")) is larger than drive ($(numfmt --to=iec "$drive_size"))!"
    exit 1
  fi

  confirm_flash "$drive"

  info "Flashing $(basename "$iso") to $drive..."

  local start_time
  start_time=$(date +%s)

  if command -v pv &>/dev/null; then
    pv "$iso" | dd of="$drive" bs="$bs" conv=fdatasync status=none 2>/dev/null
  else
    dd if="$iso" of="$drive" bs="$bs" conv=fdatasync status=progress
  fi

  if $do_sync; then
    info "Syncing..."
    sync
  fi

  local end_time elapsed
  end_time=$(date +%s)
  elapsed=$(( end_time - start_time ))

  ok "$drive is now bootable with $(basename "$iso") (${elapsed}s)"
}

# ─── Install Ventoy ───────────────────────────────────────────
cmd_ventoy_install() {
  local drive="" secure_boot=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --drive) drive="$2"; shift 2;;
      --secure-boot) secure_boot=true; shift;;
      *) err "Unknown option: $1"; exit 1;;
    esac
  done

  [[ -z "$drive" ]] && { err "Missing --drive"; exit 1; }
  validate_drive "$drive"
  confirm_flash "$drive"

  # Get latest Ventoy version
  if [[ -z "$VENTOY_VER" ]]; then
    info "Detecting latest Ventoy version..."
    VENTOY_VER=$(curl -sfL "https://api.github.com/repos/ventoy/Ventoy/releases/latest" | jq -r '.tag_name' | sed 's/^v//')
    [[ -z "$VENTOY_VER" || "$VENTOY_VER" == "null" ]] && { err "Could not detect Ventoy version. Set VENTOY_VERSION manually."; exit 1; }
  fi

  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64) arch="linux";;
    aarch64) arch="aarch64";;
    *) err "Unsupported architecture: $arch"; exit 1;;
  esac

  local url="https://github.com/ventoy/Ventoy/releases/download/v${VENTOY_VER}/ventoy-${VENTOY_VER}-${arch}.tar.gz"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" EXIT

  info "Downloading Ventoy v${VENTOY_VER}..."
  curl -fL --progress-bar "$url" -o "$tmpdir/ventoy.tar.gz"

  info "Extracting..."
  tar xzf "$tmpdir/ventoy.tar.gz" -C "$tmpdir"

  local ventoy_dir="$tmpdir/ventoy-${VENTOY_VER}"
  [[ ! -d "$ventoy_dir" ]] && { err "Extraction failed"; exit 1; }

  info "Installing Ventoy to $drive..."
  local sb_flag=""
  $secure_boot && sb_flag="-s"

  # Ventoy2Disk.sh -i = install, -I = force install
  "$ventoy_dir/Ventoy2Disk.sh" -i $sb_flag "$drive"

  ok "Ventoy v${VENTOY_VER} installed on $drive"
  info "Copy ISO files to the Ventoy partition to make them bootable."
}

# ─── Add ISOs to Ventoy drive ─────────────────────────────────
cmd_ventoy_add() {
  local drive="" isos=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --drive) drive="$2"; shift 2;;
      --iso) isos+=("$2"); shift 2;;
      *) err "Unknown option: $1"; exit 1;;
    esac
  done

  [[ -z "$drive" ]] && { err "Missing --drive"; exit 1; }
  [[ ${#isos[@]} -eq 0 ]] && { err "No ISOs specified. Use --iso <path>"; exit 1; }

  # Find the Ventoy data partition (first partition)
  local part="${drive}1"
  [[ ! -b "$part" ]] && { err "Ventoy partition $part not found. Is Ventoy installed?"; exit 1; }

  local mnt
  mnt=$(mktemp -d)
  trap "umount '$mnt' 2>/dev/null; rmdir '$mnt'" EXIT

  info "Mounting Ventoy partition..."
  mount "$part" "$mnt"

  local total=${#isos[@]}
  local i=0
  for iso in "${isos[@]}"; do
    i=$((i + 1))
    [[ ! -f "$iso" ]] && { warn "[$i/$total] Not found: $iso — skipping"; continue; }
    local basename_iso
    basename_iso=$(basename "$iso")
    local size
    size=$(du -h "$iso" | awk '{print $1}')
    printf "  [%d/%d] %s (%s) " "$i" "$total" "$basename_iso" "$size"
    cp "$iso" "$mnt/"
    echo "✅"
  done

  sync
  ok "$total ISO(s) added. USB is ready for multi-boot."
}

# ─── Backup drive ─────────────────────────────────────────────
cmd_backup() {
  local drive="" output=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --drive) drive="$2"; shift 2;;
      --output) output="$2"; shift 2;;
      *) err "Unknown option: $1"; exit 1;;
    esac
  done

  [[ -z "$drive" ]] && { err "Missing --drive"; exit 1; }
  [[ -z "$output" ]] && output="$HOME/usb-backup-$(date +%Y%m%d).img.gz"

  validate_drive "$drive"

  info "Backing up $drive to $output..."
  if command -v pv &>/dev/null; then
    local size
    size=$(lsblk -bdno SIZE "$drive")
    dd if="$drive" bs=4M status=none | pv -s "$size" | gzip > "$output"
  else
    dd if="$drive" bs=4M status=progress | gzip > "$output"
  fi

  ok "Backup saved to $output ($(du -h "$output" | awk '{print $1}'))"
}

# ─── List popular ISOs ─────────────────────────────────────────
cmd_list_isos() {
  echo "Popular Linux ISOs:"
  echo "  ubuntu-24.04     — https://releases.ubuntu.com/24.04/"
  echo "  fedora-40        — https://download.fedoraproject.org/pub/fedora/linux/releases/40/"
  echo "  debian-12        — https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/"
  echo "  archlinux        — https://archlinux.org/download/"
  echo "  linuxmint-22     — https://linuxmint.com/download.php"
  echo "  nixos-24.05      — https://nixos.org/download/"
  echo "  popos-22.04      — https://pop.system76.com/"
  echo ""
  echo "Rescue/Utility ISOs:"
  echo "  clonezilla       — https://clonezilla.org/downloads/"
  echo "  gparted-live     — https://gparted.org/download.php"
  echo "  systemrescue     — https://www.system-rescue.org/Download/"
  echo "  memtest86+       — https://www.memtest.org/"
  echo "  tails            — https://tails.net/install/"
}

# ─── Usage ─────────────────────────────────────────────────────
usage() {
  echo "USB Boot Creator v${VERSION}"
  echo ""
  echo "Usage: bash usb-boot.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  list-drives       List connected USB drives"
  echo "  list-isos         Show popular ISO download URLs"
  echo "  download          Download an ISO (with optional checksum)"
  echo "  verify            Verify ISO checksum"
  echo "  flash             Flash ISO to USB drive (dd)"
  echo "  ventoy-install    Install Ventoy on USB drive (multi-boot)"
  echo "  ventoy-add        Add ISO(s) to Ventoy USB drive"
  echo "  backup            Backup USB drive to compressed image"
  echo ""
  echo "Examples:"
  echo "  bash usb-boot.sh list-drives"
  echo "  sudo bash usb-boot.sh flash --iso ubuntu.iso --drive /dev/sdb"
  echo "  sudo bash usb-boot.sh ventoy-install --drive /dev/sdb"
  echo "  bash usb-boot.sh ventoy-add --drive /dev/sdb --iso ubuntu.iso --iso fedora.iso"
}

# ─── Main ──────────────────────────────────────────────────────
[[ $# -eq 0 ]] && { usage; exit 0; }

CMD="$1"; shift
case "$CMD" in
  list-drives)    cmd_list_drives "$@";;
  list-isos)      cmd_list_isos "$@";;
  download)       cmd_download "$@";;
  verify)         cmd_verify "$@";;
  flash)          cmd_flash "$@";;
  ventoy-install) cmd_ventoy_install "$@";;
  ventoy-add)     cmd_ventoy_add "$@";;
  backup)         cmd_backup "$@";;
  auto)           
    err "Auto mode requires manual ISO URL mapping. Use 'download' then 'flash' separately."
    exit 1
    ;;
  -h|--help|help) usage;;
  *) err "Unknown command: $CMD"; usage; exit 1;;
esac
