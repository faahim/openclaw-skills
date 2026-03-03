#!/usr/bin/env python3
"""Music Metadata Manager — Core metadata engine using mutagen + eyeD3."""

import sys
import os
import csv
import re
import argparse
import subprocess
import shutil
from pathlib import Path
from collections import defaultdict

EXTENSIONS = os.environ.get("MUSIC_EXTENSIONS", "mp3,flac,ogg,m4a,wma,aac").split(",")

# Try mutagen first (handles all formats), fall back to eyeD3 for MP3
try:
    import mutagen
    from mutagen.easyid3 import EasyID3
    from mutagen.mp3 import MP3
    from mutagen.flac import FLAC
    from mutagen.oggvorbis import OggVorbis
    from mutagen.mp4 import MP4
    from mutagen.id3 import ID3, APIC, ID3NoHeaderError
    HAS_MUTAGEN = True
except ImportError:
    HAS_MUTAGEN = False

def is_audio(path):
    return any(str(path).lower().endswith(f".{e.strip()}") for e in EXTENSIONS)

def find_audio(target):
    p = Path(target)
    if p.is_file() and is_audio(p):
        return [p]
    elif p.is_dir():
        files = []
        for ext in EXTENSIONS:
            files.extend(p.rglob(f"*.{ext.strip()}"))
            files.extend(p.rglob(f"*.{ext.strip().upper()}"))
        return sorted(set(files))
    return []

def get_meta(filepath):
    """Extract metadata dict from audio file."""
    fp = str(filepath)
    meta = {"file": fp, "title": "", "artist": "", "album": "", "year": "", "track": "", "genre": "", "disc": "", "duration": "", "bitrate": "", "has_cover": False}

    if not HAS_MUTAGEN:
        # Fallback: use ffprobe
        return _ffprobe_meta(fp, meta)

    try:
        audio = mutagen.File(fp, easy=True)
        if audio is None:
            return _ffprobe_meta(fp, meta)

        meta["title"] = _first(audio.get("title", []))
        meta["artist"] = _first(audio.get("artist", []))
        meta["album"] = _first(audio.get("album", []))
        meta["year"] = _first(audio.get("date", [])) or _first(audio.get("year", []))
        meta["genre"] = _first(audio.get("genre", []))
        raw_track = _first(audio.get("tracknumber", []))
        meta["track"] = raw_track
        meta["disc"] = _first(audio.get("discnumber", []))

        if audio.info:
            secs = int(audio.info.length)
            meta["duration"] = f"{secs // 60}:{secs % 60:02d}"
            br = getattr(audio.info, "bitrate", 0)
            if br:
                meta["bitrate"] = f"{br // 1000} kbps"

        # Check cover art
        try:
            raw = mutagen.File(fp)
            if isinstance(raw, MP3):
                meta["has_cover"] = any(k.startswith("APIC") for k in (raw.tags or {}).keys())
            elif isinstance(raw, FLAC):
                meta["has_cover"] = len(raw.pictures) > 0
            elif isinstance(raw, MP4):
                meta["has_cover"] = bool(raw.tags and raw.tags.get("covr"))
        except:
            pass

    except Exception as e:
        return _ffprobe_meta(fp, meta)

    return meta

def _first(lst):
    return str(lst[0]).strip() if lst else ""

def _ffprobe_meta(fp, meta):
    """Fallback metadata via ffprobe."""
    try:
        out = subprocess.check_output(
            ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", fp],
            stderr=subprocess.DEVNULL, text=True
        )
        import json
        data = json.loads(out).get("format", {})
        tags = {k.lower(): v for k, v in data.get("tags", {}).items()}
        meta["title"] = tags.get("title", "")
        meta["artist"] = tags.get("artist", "")
        meta["album"] = tags.get("album", "")
        meta["year"] = tags.get("date", "") or tags.get("year", "")
        meta["genre"] = tags.get("genre", "")
        meta["track"] = tags.get("track", "") or tags.get("tracknumber", "")
        dur = float(data.get("duration", 0))
        if dur:
            meta["duration"] = f"{int(dur) // 60}:{int(dur) % 60:02d}"
        br = int(data.get("bit_rate", 0))
        if br:
            meta["bitrate"] = f"{br // 1000} kbps"
    except:
        pass
    return meta

# ============ COMMANDS ============

def cmd_info(args):
    filepath = args.target
    meta = get_meta(filepath)
    print(f"File:     {os.path.basename(meta['file'])}")
    print(f"Title:    {meta['title'] or '(none)'}")
    print(f"Artist:   {meta['artist'] or '(none)'}")
    print(f"Album:    {meta['album'] or '(none)'}")
    print(f"Year:     {meta['year'] or '(none)'}")
    print(f"Track:    {meta['track'] or '(none)'}")
    print(f"Genre:    {meta['genre'] or '(none)'}")
    print(f"Duration: {meta['duration'] or '(unknown)'}")
    print(f"Bitrate:  {meta['bitrate'] or '(unknown)'}")
    cover = "embedded" if meta['has_cover'] else "none"
    print(f"Cover:    {cover}")

def cmd_tag(args):
    files = find_audio(args.target)
    if not files:
        print(f"No audio files found in: {args.target}")
        return

    if not HAS_MUTAGEN:
        print("Error: mutagen is required for tagging. Run: pip3 install mutagen")
        sys.exit(1)

    count = 0
    for fp in files:
        try:
            audio = mutagen.File(str(fp), easy=True)
            if audio is None:
                continue
            if audio.tags is None:
                audio.add_tags()

            if args.title: audio["title"] = args.title
            if args.artist: audio["artist"] = args.artist
            if args.album: audio["album"] = args.album
            if args.year: audio["date"] = args.year
            if args.genre: audio["genre"] = args.genre
            if args.track: audio["tracknumber"] = args.track

            audio.save()
            count += 1
            print(f"✅ Tagged: {fp.name}")
        except Exception as e:
            print(f"❌ Error tagging {fp.name}: {e}")

    print(f"\nProcessed: {count} files")

def cmd_art(args):
    files = find_audio(args.target)
    if not files:
        print(f"No audio files found: {args.target}")
        return

    if args.set_art:
        art_path = args.set_art
        if not os.path.isfile(art_path):
            print(f"Error: Art file not found: {art_path}")
            sys.exit(1)
        with open(art_path, "rb") as f:
            art_data = f.read()
        mime = "image/jpeg" if art_path.lower().endswith((".jpg", ".jpeg")) else "image/png"

        for fp in files:
            try:
                raw = mutagen.File(str(fp))
                if isinstance(raw, MP3):
                    if raw.tags is None:
                        raw.add_tags()
                    raw.tags.delall("APIC")
                    raw.tags.add(APIC(encoding=3, mime=mime, type=3, desc="Cover", data=art_data))
                    raw.save()
                elif isinstance(raw, FLAC):
                    from mutagen.flac import Picture
                    pic = Picture()
                    pic.data = art_data
                    pic.mime = mime
                    pic.type = 3
                    raw.clear_pictures()
                    raw.add_picture(pic)
                    raw.save()
                elif isinstance(raw, MP4):
                    from mutagen.mp4 import MP4Cover
                    fmt = MP4Cover.FORMAT_JPEG if "jpeg" in mime else MP4Cover.FORMAT_PNG
                    raw.tags["covr"] = [MP4Cover(art_data, imageformat=fmt)]
                    raw.save()
                print(f"✅ Art embedded: {fp.name}")
            except Exception as e:
                print(f"❌ Error: {fp.name}: {e}")

    elif args.extract:
        fp = files[0]
        try:
            raw = mutagen.File(str(fp))
            data = None
            if isinstance(raw, MP3) and raw.tags:
                for k, v in raw.tags.items():
                    if k.startswith("APIC"):
                        data = v.data
                        break
            elif isinstance(raw, FLAC) and raw.pictures:
                data = raw.pictures[0].data
            elif isinstance(raw, MP4) and raw.tags and raw.tags.get("covr"):
                data = bytes(raw.tags["covr"][0])
            if data:
                with open(args.extract, "wb") as f:
                    f.write(data)
                print(f"✅ Art extracted to: {args.extract}")
            else:
                print("No embedded art found.")
        except Exception as e:
            print(f"❌ Error: {e}")

    elif args.remove:
        for fp in files:
            try:
                raw = mutagen.File(str(fp))
                if isinstance(raw, MP3) and raw.tags:
                    raw.tags.delall("APIC")
                    raw.save()
                elif isinstance(raw, FLAC):
                    raw.clear_pictures()
                    raw.save()
                elif isinstance(raw, MP4) and raw.tags:
                    raw.tags.pop("covr", None)
                    raw.save()
                print(f"✅ Art removed: {fp.name}")
            except Exception as e:
                print(f"❌ Error: {fp.name}: {e}")

def cmd_rename(args):
    files = find_audio(args.target)
    if not files:
        print(f"No audio files found in: {args.target}")
        return

    pattern = args.pattern or os.environ.get("MUSIC_RENAME_PATTERN", "{artist} - {title}")
    dry_run = args.dry_run
    create_dirs = args.create_dirs
    count = 0
    errors = 0

    for fp in files:
        meta = get_meta(fp)
        try:
            track_num = ""
            raw_track = meta["track"]
            if raw_track:
                track_num = raw_track.split("/")[0].strip()

            # Build new name
            new_name = pattern
            new_name = new_name.replace("{artist}", _safe(meta["artist"]) or "Unknown Artist")
            new_name = new_name.replace("{title}", _safe(meta["title"]) or fp.stem)
            new_name = new_name.replace("{album}", _safe(meta["album"]) or "Unknown Album")
            new_name = new_name.replace("{year}", _safe(meta["year"]) or "0000")
            new_name = new_name.replace("{genre}", _safe(meta["genre"]) or "Unknown")
            new_name = new_name.replace("{disc}", _safe(meta["disc"]).split("/")[0] or "1")

            # Handle track with padding
            if "{track:02d}" in new_name:
                try:
                    new_name = new_name.replace("{track:02d}", f"{int(track_num):02d}")
                except:
                    new_name = new_name.replace("{track:02d}", track_num or "00")
            else:
                new_name = new_name.replace("{track}", track_num or "00")

            new_name = new_name + fp.suffix
            new_path = fp.parent / new_name

            if create_dirs:
                new_path = Path(args.target) / new_name
                new_path.parent.mkdir(parents=True, exist_ok=True)

            if fp == new_path:
                continue

            if dry_run:
                print(f"  [DRY] {fp.name} → {new_name}")
            else:
                shutil.move(str(fp), str(new_path))
                print(f"  Renamed: {fp.name} → {new_name}")
            count += 1
        except Exception as e:
            print(f"  ❌ Error: {fp.name}: {e}")
            errors += 1

    action = "Would rename" if dry_run else "Renamed"
    print(f"\n{action}: {count} files, {errors} errors")

def _safe(s):
    """Make string safe for filenames."""
    if not s:
        return ""
    # Remove/replace characters illegal in filenames
    s = re.sub(r'[<>:"/\\|?*]', '_', s)
    s = s.strip('. ')
    return s

def cmd_export(args):
    files = find_audio(args.target)
    if not files:
        print(f"No audio files found in: {args.target}")
        return

    output = args.output or "tags.csv"
    fields = ["file", "title", "artist", "album", "year", "track", "genre", "duration", "bitrate"]

    with open(output, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for fp in files:
            meta = get_meta(fp)
            meta["file"] = fp.name
            writer.writerow(meta)

    print(f"✅ Exported {len(files)} files to {output}")

def cmd_scan(args):
    files = find_audio(args.target)
    if not files:
        print(f"No audio files found in: {args.target}")
        return

    required = ["title", "artist", "album"]
    complete = 0
    incomplete = 0

    for fp in files:
        meta = get_meta(fp)
        missing = [f for f in required if not meta.get(f)]
        if missing:
            print(f"⚠️  {fp.name} — missing: {', '.join(missing)}")
            incomplete += 1
        else:
            complete += 1

    total = complete + incomplete
    print(f"\n✅ {complete}/{total} files have complete tags")
    if incomplete:
        print(f"❌ {incomplete} files need attention")

def cmd_strip(args):
    files = find_audio(args.target)
    if not files:
        print(f"No audio files found: {args.target}")
        return

    if len(files) > 1 and not args.confirm:
        print(f"This will strip tags from {len(files)} files. Use --confirm to proceed.")
        return

    for fp in files:
        try:
            raw = mutagen.File(str(fp))
            if raw and raw.tags:
                raw.delete()
                raw.save()
            print(f"✅ Stripped: {fp.name}")
        except Exception as e:
            print(f"❌ Error: {fp.name}: {e}")

def cmd_autotag(args):
    files = find_audio(args.target)
    if not files:
        print(f"No audio files found: {args.target}")
        return

    if not HAS_MUTAGEN:
        print("Error: mutagen is required. Run: pip3 install mutagen")
        sys.exit(1)

    pattern = args.from_filename
    if not pattern:
        print("Error: --from-filename <pattern> is required")
        sys.exit(1)

    # Convert pattern to regex
    regex = pattern
    field_map = {}
    for i, field in enumerate(re.findall(r'\{(\w+)\}', pattern)):
        field_map[i] = field
        regex = regex.replace(f"{{{field}}}", f"(.+?)", 1)
    regex = f"^{regex}$"

    count = 0
    for fp in files:
        stem = fp.stem
        m = re.match(regex, stem)
        if not m:
            print(f"⚠️  No match: {fp.name}")
            continue

        try:
            audio = mutagen.File(str(fp), easy=True)
            if audio is None:
                continue
            if audio.tags is None:
                audio.add_tags()

            for i, field in field_map.items():
                val = m.group(i + 1).strip()
                if field == "artist": audio["artist"] = val
                elif field == "title": audio["title"] = val
                elif field == "album": audio["album"] = val
                elif field == "year": audio["date"] = val
                elif field == "track": audio["tracknumber"] = val
                elif field == "genre": audio["genre"] = val

            audio.save()
            count += 1
            print(f"✅ Auto-tagged: {fp.name}")
        except Exception as e:
            print(f"❌ Error: {fp.name}: {e}")

    print(f"\nAuto-tagged: {count} files")

def cmd_dupes(args):
    files = find_audio(args.target)
    if not files:
        print(f"No audio files found: {args.target}")
        return

    # Group by (artist, title)
    groups = defaultdict(list)
    for fp in files:
        meta = get_meta(fp)
        key = (meta["artist"].lower().strip(), meta["title"].lower().strip())
        if key[0] and key[1]:
            groups[key].append((fp, meta))

    dupe_count = 0
    for (artist, title), items in groups.items():
        if len(items) > 1:
            dupe_count += 1
            print(f"\nDuplicate: {items[0][1]['artist']} - {items[0][1]['title']}")
            for fp, meta in items:
                print(f"  → {fp} ({meta['bitrate'] or 'unknown bitrate'})")

    if dupe_count:
        print(f"\n🔍 Found {dupe_count} duplicate track(s)")
    else:
        print("✅ No duplicates found")


# ============ MAIN ============

def main():
    parser = argparse.ArgumentParser(description="Music Metadata Manager")
    sub = parser.add_subparsers(dest="command")

    # info
    p_info = sub.add_parser("info")
    p_info.add_argument("target")

    # tag
    p_tag = sub.add_parser("tag")
    p_tag.add_argument("target")
    p_tag.add_argument("--title", default="")
    p_tag.add_argument("--artist", default="")
    p_tag.add_argument("--album", default="")
    p_tag.add_argument("--year", default="")
    p_tag.add_argument("--genre", default="")
    p_tag.add_argument("--track", default="")

    # art
    p_art = sub.add_parser("art")
    p_art.add_argument("target")
    p_art.add_argument("--set", dest="set_art", default="")
    p_art.add_argument("--extract", default="")
    p_art.add_argument("--remove", action="store_true")

    # rename
    p_rename = sub.add_parser("rename")
    p_rename.add_argument("target")
    p_rename.add_argument("--pattern", default="")
    p_rename.add_argument("--dry-run", action="store_true")
    p_rename.add_argument("--create-dirs", action="store_true")

    # export
    p_export = sub.add_parser("export")
    p_export.add_argument("target")
    p_export.add_argument("--output", default="tags.csv")

    # scan
    p_scan = sub.add_parser("scan")
    p_scan.add_argument("target")

    # strip
    p_strip = sub.add_parser("strip")
    p_strip.add_argument("target")
    p_strip.add_argument("--confirm", action="store_true")

    # autotag
    p_auto = sub.add_parser("autotag")
    p_auto.add_argument("target")
    p_auto.add_argument("--from-filename", default="")

    # dupes
    p_dupes = sub.add_parser("dupes")
    p_dupes.add_argument("target")

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)

    cmds = {
        "info": cmd_info, "tag": cmd_tag, "art": cmd_art,
        "rename": cmd_rename, "export": cmd_export, "scan": cmd_scan,
        "strip": cmd_strip, "autotag": cmd_autotag, "dupes": cmd_dupes,
    }
    cmds[args.command](args)

if __name__ == "__main__":
    main()
