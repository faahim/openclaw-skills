#!/bin/bash
# Audio Normalizer — Normalize, convert, trim, and batch process audio files
# Requires: ffmpeg 4.0+, bash 4.0+, bc

set -euo pipefail

VERSION="1.0.0"
TARGET_LUFS="${AUDIO_NORM_TARGET:--16}"
TRUE_PEAK="${AUDIO_NORM_TRUE_PEAK:--1.5}"
SILENCE_DB="${AUDIO_NORM_SILENCE_DB:--50}"
PARALLEL="${AUDIO_NORM_PARALLEL:-4}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "[audio-normalizer] $*"; }
err() { echo -e "${RED}[audio-normalizer] ERROR: $*${NC}" >&2; }
ok()  { echo -e "${GREEN}[audio-normalizer] ✅ $*${NC}"; }
warn() { echo -e "${YELLOW}[audio-normalizer] ⚠️  $*${NC}"; }

# Check dependencies
check_deps() {
    if ! command -v ffmpeg &>/dev/null; then
        err "ffmpeg not found. Install: sudo apt install ffmpeg (or brew install ffmpeg)"
        exit 1
    fi
    if ! command -v bc &>/dev/null; then
        err "bc not found. Install: sudo apt install bc"
        exit 1
    fi
}

# Measure loudness using ffmpeg loudnorm filter (two-pass)
measure_loudness() {
    local input="$1"
    ffmpeg -i "$input" -af loudnorm=print_format=json -f null - 2>&1 | \
        grep -A 20 '"input_i"' | head -20
}

# Get integrated loudness value
get_lufs() {
    local input="$1"
    ffmpeg -i "$input" -af loudnorm=print_format=json -f null - 2>&1 | \
        grep '"input_i"' | grep -oE '[-0-9.]+'
}

# Get true peak
get_true_peak() {
    local input="$1"
    ffmpeg -i "$input" -af loudnorm=print_format=json -f null - 2>&1 | \
        grep '"input_tp"' | grep -oE '[-0-9.]+'
}

# Analyze audio file
cmd_analyze() {
    local input=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --input) input="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    [[ -z "$input" ]] && { err "Usage: run.sh analyze --input <file>"; exit 1; }
    [[ ! -f "$input" ]] && { err "File not found: $input"; exit 1; }

    log "File: $input"

    # Get file info
    local duration format sample_rate channels
    duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$input" 2>/dev/null)
    format=$(ffprobe -v quiet -show_entries format=format_long_name -of csv=p=0 "$input" 2>/dev/null)
    sample_rate=$(ffprobe -v quiet -show_entries stream=sample_rate -of csv=p=0 "$input" 2>/dev/null | head -1)
    channels=$(ffprobe -v quiet -show_entries stream=channels -of csv=p=0 "$input" 2>/dev/null | head -1)

    # Format duration
    if [[ -n "$duration" ]]; then
        local mins secs
        mins=$(echo "$duration / 60" | bc)
        secs=$(echo "$duration - ($mins * 60)" | bc | xargs printf "%.0f")
        log "Duration: ${mins}:$(printf '%02d' $secs)"
    fi

    [[ -n "$format" ]] && log "Format: $format"
    [[ -n "$sample_rate" ]] && log "Sample rate: ${sample_rate} Hz"

    case "$channels" in
        1) log "Channels: 1 (mono)" ;;
        2) log "Channels: 2 (stereo)" ;;
        *) log "Channels: $channels" ;;
    esac

    # Loudness analysis
    log "Analyzing loudness (this may take a moment)..."
    local loudnorm_out
    loudnorm_out=$(ffmpeg -i "$input" -af loudnorm=print_format=json -f null - 2>&1)

    local lufs tp lr
    lufs=$(echo "$loudnorm_out" | grep '"input_i"' | grep -oE '[-0-9.]+' || echo "N/A")
    tp=$(echo "$loudnorm_out" | grep '"input_tp"' | grep -oE '[-0-9.]+' || echo "N/A")
    lr=$(echo "$loudnorm_out" | grep '"input_lra"' | grep -oE '[-0-9.]+' || echo "N/A")

    log "Integrated loudness: ${lufs} LUFS"
    log "True peak: ${tp} dBTP"
    log "Loudness range: ${lr} LU"
}

# Normalize audio loudness
cmd_normalize() {
    local input="" output="" target="$TARGET_LUFS" tp="$TRUE_PEAK"
    while [[ $# -gt 0 ]]; do
        case $1 in
            --input) input="$2"; shift 2 ;;
            --output) output="$2"; shift 2 ;;
            --target) target="$2"; shift 2 ;;
            --true-peak) tp="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    [[ -z "$input" || -z "$output" ]] && { err "Usage: run.sh normalize --input <file> --output <file> [--target -16] [--true-peak -1.5]"; exit 1; }
    [[ ! -f "$input" ]] && { err "File not found: $input"; exit 1; }

    log "Analyzing: $input"
    local input_lufs
    input_lufs=$(get_lufs "$input")
    log "Input loudness: ${input_lufs} LUFS"
    log "Target loudness: ${target} LUFS"

    # Two-pass loudnorm for best quality
    log "Normalizing (two-pass)..."

    # First pass: measure
    local loudnorm_output
    loudnorm_output=$(ffmpeg -i "$input" -af "loudnorm=I=${target}:TP=${tp}:LRA=11:print_format=json" -f null - 2>&1)

    local measured_i measured_tp measured_lra measured_thresh
    measured_i=$(echo "$loudnorm_output" | grep '"input_i"' | grep -oE '[-0-9.]+')
    measured_tp=$(echo "$loudnorm_output" | grep '"input_tp"' | grep -oE '[-0-9.]+')
    measured_lra=$(echo "$loudnorm_output" | grep '"input_lra"' | grep -oE '[-0-9.]+')
    measured_thresh=$(echo "$loudnorm_output" | grep '"input_thresh"' | grep -oE '[-0-9.]+')

    # Second pass: apply
    ffmpeg -y -i "$input" \
        -af "loudnorm=I=${target}:TP=${tp}:LRA=11:measured_I=${measured_i}:measured_TP=${measured_tp}:measured_LRA=${measured_lra}:measured_thresh=${measured_thresh}:linear=true" \
        "$output" 2>/dev/null

    local gain
    gain=$(echo "${target} - ${input_lufs}" | bc 2>/dev/null || echo "?")
    log "Gain applied: ${gain} dB"
    ok "Output: $output (${target} LUFS)"
}

# Convert audio format
cmd_convert() {
    local input="" output="" bitrate="" quality=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --input) input="$2"; shift 2 ;;
            --output) output="$2"; shift 2 ;;
            --bitrate) bitrate="$2"; shift 2 ;;
            --quality) quality="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    [[ -z "$input" || -z "$output" ]] && { err "Usage: run.sh convert --input <file> --output <file> [--bitrate 320k] [--quality 8]"; exit 1; }
    [[ ! -f "$input" ]] && { err "File not found: $input"; exit 1; }

    local ext="${output##*.}"
    local args=(-y -i "$input")

    case "$ext" in
        mp3)
            if [[ -n "$bitrate" ]]; then
                args+=(-b:a "$bitrate")
            else
                args+=(-b:a "192k")
            fi
            ;;
        ogg)
            if [[ -n "$quality" ]]; then
                args+=(-q:a "$quality")
            else
                args+=(-q:a "6")
            fi
            ;;
        opus)
            if [[ -n "$bitrate" ]]; then
                args+=(-b:a "$bitrate")
            else
                args+=(-b:a "128k")
            fi
            ;;
        aac|m4a)
            if [[ -n "$bitrate" ]]; then
                args+=(-b:a "$bitrate")
            else
                args+=(-b:a "192k")
            fi
            ;;
        flac)
            args+=(-c:a flac)
            ;;
        wav)
            args+=(-c:a pcm_s16le)
            ;;
    esac

    args+=("$output")

    log "Converting: $input → $output"
    ffmpeg "${args[@]}" 2>/dev/null

    local in_size out_size
    in_size=$(du -h "$input" | cut -f1)
    out_size=$(du -h "$output" | cut -f1)
    ok "$input ($in_size) → $output ($out_size)"
}

# Trim silence from start/end
cmd_trim() {
    local input="" output="" threshold="$SILENCE_DB" duration="0.5"
    while [[ $# -gt 0 ]]; do
        case $1 in
            --input) input="$2"; shift 2 ;;
            --output) output="$2"; shift 2 ;;
            --threshold) threshold="$2"; shift 2 ;;
            --duration) duration="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    [[ -z "$input" || -z "$output" ]] && { err "Usage: run.sh trim --input <file> --output <file> [--threshold -50] [--duration 0.5]"; exit 1; }
    [[ ! -f "$input" ]] && { err "File not found: $input"; exit 1; }

    log "Trimming silence: $input (threshold: ${threshold}dB, min duration: ${duration}s)"

    # Use silenceremove filter to trim start and end silence
    ffmpeg -y -i "$input" \
        -af "silenceremove=start_periods=1:start_duration=${duration}:start_threshold=${threshold}dB:detection=peak,areverse,silenceremove=start_periods=1:start_duration=${duration}:start_threshold=${threshold}dB:detection=peak,areverse" \
        "$output" 2>/dev/null

    local in_dur out_dur
    in_dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$input" 2>/dev/null)
    out_dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$output" 2>/dev/null)
    local trimmed
    trimmed=$(echo "$in_dur - $out_dur" | bc 2>/dev/null || echo "?")
    ok "Trimmed ${trimmed}s of silence → $output"
}

# Full pipeline: trim + normalize + convert
cmd_pipeline() {
    local input="" output="" do_normalize=false do_trim=false
    local target="$TARGET_LUFS" tp="$TRUE_PEAK" threshold="$SILENCE_DB"
    local format="" bitrate="" quality=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --input) input="$2"; shift 2 ;;
            --output) output="$2"; shift 2 ;;
            --normalize) do_normalize=true; shift ;;
            --trim) do_trim=true; shift ;;
            --target) target="$2"; shift 2 ;;
            --true-peak) tp="$2"; shift 2 ;;
            --threshold) threshold="$2"; shift 2 ;;
            --format) format="$2"; shift 2 ;;
            --bitrate) bitrate="$2"; shift 2 ;;
            --quality) quality="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    [[ -z "$input" || -z "$output" ]] && { err "Usage: run.sh pipeline --input <file> --output <file> [--normalize] [--trim] [--format mp3] [--bitrate 192k]"; exit 1; }
    [[ ! -f "$input" ]] && { err "File not found: $input"; exit 1; }

    local current="$input"
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf $tmpdir" EXIT

    # Step 1: Trim
    if $do_trim; then
        local trimmed="$tmpdir/trimmed.wav"
        cmd_trim --input "$current" --output "$trimmed" --threshold "$threshold"
        current="$trimmed"
    fi

    # Step 2: Normalize
    if $do_normalize; then
        local normalized="$tmpdir/normalized.wav"
        cmd_normalize --input "$current" --output "$normalized" --target "$target" --true-peak "$tp"
        current="$normalized"
    fi

    # Step 3: Convert (or copy)
    if [[ "$current" != "$output" ]]; then
        local args=(--input "$current" --output "$output")
        [[ -n "$bitrate" ]] && args+=(--bitrate "$bitrate")
        [[ -n "$quality" ]] && args+=(--quality "$quality")
        cmd_convert "${args[@]}"
    fi

    ok "Pipeline complete: $output"
}

# Batch process directory
cmd_batch() {
    local input_dir="" output_dir="" parallel="$PARALLEL"
    local extra_args=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            --input) input_dir="$2"; shift 2 ;;
            --output) output_dir="$2"; shift 2 ;;
            --parallel) parallel="$2"; shift 2 ;;
            *) extra_args+=("$1"); shift ;;
        esac
    done

    [[ -z "$input_dir" || -z "$output_dir" ]] && { err "Usage: run.sh batch --input <dir> --output <dir> [--parallel 4] [pipeline options]"; exit 1; }
    [[ ! -d "$input_dir" ]] && { err "Directory not found: $input_dir"; exit 1; }

    mkdir -p "$output_dir"

    # Find audio files
    local files=()
    while IFS= read -r -d '' f; do
        files+=("$f")
    done < <(find "$input_dir" -maxdepth 1 -type f \( -iname "*.wav" -o -iname "*.mp3" -o -iname "*.flac" -o -iname "*.ogg" -o -iname "*.aac" -o -iname "*.m4a" -o -iname "*.opus" \) -print0 | sort -z)

    local total=${#files[@]}
    [[ $total -eq 0 ]] && { warn "No audio files found in $input_dir"; exit 0; }

    log "Processing $total files (parallel: $parallel)..."

    local count=0 running=0
    for f in "${files[@]}"; do
        local base="${f##*/}"
        local name="${base%.*}"

        # Determine output extension
        local out_ext="wav"
        for arg in "${extra_args[@]}"; do
            if [[ "$prev" == "--format" ]]; then
                out_ext="$arg"
            fi
            prev="$arg"
        done
        # Also check for format in extra_args
        for i in "${!extra_args[@]}"; do
            if [[ "${extra_args[$i]}" == "--format" ]] && [[ -n "${extra_args[$((i+1))]:-}" ]]; then
                out_ext="${extra_args[$((i+1))]}"
            fi
        done

        local out_file="$output_dir/${name}.${out_ext}"

        (
            cmd_pipeline --input "$f" --output "$out_file" "${extra_args[@]}"
        ) &

        ((running++))
        if [[ $running -ge $parallel ]]; then
            wait -n 2>/dev/null || wait
            ((running--))
        fi
        ((count++))
    done

    wait
    ok "Done: $count/$total files processed → $output_dir"
}

# Usage
usage() {
    cat <<EOF
Audio Normalizer v${VERSION}

Usage: run.sh <command> [options]

Commands:
  analyze     Analyze audio loudness (no changes)
  normalize   Normalize loudness to target LUFS
  convert     Convert between audio formats
  trim        Trim silence from start/end
  pipeline    Full pipeline: trim + normalize + convert
  batch       Batch process a directory

Examples:
  run.sh analyze --input file.wav
  run.sh normalize --input file.wav --output norm.wav --target -16
  run.sh convert --input file.wav --output file.mp3 --bitrate 320k
  run.sh trim --input file.wav --output trimmed.wav --threshold -50
  run.sh pipeline --input raw.wav --output final.mp3 --normalize --trim --format mp3 --bitrate 192k
  run.sh batch --input ./raw/ --output ./processed/ --normalize --trim --format mp3 --bitrate 320k

Environment:
  AUDIO_NORM_TARGET     Target loudness (default: -16 LUFS)
  AUDIO_NORM_TRUE_PEAK  True peak limit (default: -1.5 dBTP)
  AUDIO_NORM_SILENCE_DB Silence threshold (default: -50 dB)
  AUDIO_NORM_PARALLEL   Batch parallelism (default: 4)
EOF
}

# Main
check_deps

case "${1:-}" in
    analyze)   shift; cmd_analyze "$@" ;;
    normalize) shift; cmd_normalize "$@" ;;
    convert)   shift; cmd_convert "$@" ;;
    trim)      shift; cmd_trim "$@" ;;
    pipeline)  shift; cmd_pipeline "$@" ;;
    batch)     shift; cmd_batch "$@" ;;
    --version) echo "audio-normalizer v${VERSION}" ;;
    *)         usage ;;
esac
