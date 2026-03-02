#!/usr/bin/env python3
"""Music Metadata Tagger — Python backend using mutagen."""

import argparse
import os
import re
import shutil
import sys
from pathlib import Path

try:
    import mutagen
    from mutagen.easyid3 import EasyID3
    from mutagen.mp3 import MP3
    from mutagen.flac import FLAC, Picture
    from mutagen.oggvorbis import OggVorbis
    from mutagen.mp4 import MP4
    from mutagen.id3 import ID3, APIC, ID3NoHeaderError
except ImportError:
    print("❌ mutagen not installed. Run: pip3 install --user mutagen")
    sys.exit(1)

MUSIC_EXTS = {'.mp3', '.flac', '.ogg', '.m4a', '.aac', '.wav', '.aiff', '.wma', '.opus'}

def find_music_files(path):
    """Find all music files in path (file or directory)."""
    p = Path(path)
    if p.is_file() and p.suffix.lower() in MUSIC_EXTS:
        return [p]
    elif p.is_dir():
        files = []
        for f in sorted(p.rglob('*')):
            if f.is_file() and f.suffix.lower() in MUSIC_EXTS:
                files.append(f)
        return files
    return []

def get_easy_tags(filepath):
    """Get tags as a simple dict."""
    try:
        audio = mutagen.File(filepath, easy=True)
        if audio is None:
            return {}
        tags = {}
        field_map = {
            'artist': 'artist', 'album': 'album', 'title': 'title',
            'tracknumber': 'track', 'date': 'year', 'genre': 'genre',
            'albumartist': 'albumartist', 'discnumber': 'disc',
            'composer': 'composer', 'comment': 'comment'
        }
        for key, name in field_map.items():
            val = audio.get(key)
            if val:
                tags[name] = val[0] if isinstance(val, list) else str(val)
        # Duration and bitrate
        raw = mutagen.File(filepath)
        if raw and raw.info:
            secs = int(raw.info.length)
            tags['duration'] = f"{secs // 60}:{secs % 60:02d}"
            if hasattr(raw.info, 'bitrate') and raw.info.bitrate:
                tags['bitrate'] = f"{raw.info.bitrate // 1000} kbps"
        return tags
    except Exception as e:
        return {'error': str(e)}

def has_album_art(filepath):
    """Check if file has embedded album art."""
    try:
        p = Path(filepath)
        if p.suffix.lower() == '.mp3':
            try:
                tags = ID3(str(filepath))
                return any(isinstance(f, APIC) for f in tags.values())
            except ID3NoHeaderError:
                return False
        elif p.suffix.lower() == '.flac':
            f = FLAC(str(filepath))
            return len(f.pictures) > 0
        elif p.suffix.lower() in ('.m4a', '.aac'):
            f = MP4(str(filepath))
            return 'covr' in f.tags if f.tags else False
    except:
        pass
    return False

def cmd_info(args):
    """Show info for a single file."""
    filepath = args.path
    if not os.path.isfile(filepath):
        print(f"❌ Not a file: {filepath}")
        return 1
    tags = get_easy_tags(filepath)
    if 'error' in tags:
        print(f"❌ Error reading {filepath}: {tags['error']}")
        return 1
    raw = mutagen.File(filepath)
    fmt = type(raw).__name__ if raw else "Unknown"
    print(f"File: {os.path.basename(filepath)}")
    print(f"Format: {fmt}")
    if 'duration' in tags:
        print(f"Duration: {tags['duration']}")
    if 'bitrate' in tags:
        print(f"Bitrate: {tags['bitrate']}")
    for field in ['artist', 'album', 'title', 'track', 'year', 'genre', 'albumartist', 'disc', 'composer', 'comment']:
        if field in tags:
            print(f"{field.title()}: {tags[field]}")
    art = has_album_art(filepath)
    print(f"Album Art: {'Yes' if art else 'No'}")
    return 0

def cmd_scan(args):
    """Scan directory and list all tags."""
    files = find_music_files(args.path)
    if not files:
        print(f"No music files found in {args.path}")
        return 1
    # Header
    print(f"{'File':<40} | {'Artist':<25} | {'Album':<30} | {'Title':<30} | {'Track':<5} | {'Year':<4}")
    print("-" * 140)
    for f in files:
        tags = get_easy_tags(f)
        name = f.name[:38]
        print(f"{name:<40} | {tags.get('artist',''):<25} | {tags.get('album',''):<30} | {tags.get('title',''):<30} | {tags.get('track',''):<5} | {tags.get('year',''):<4}")
    print(f"\n{len(files)} files scanned.")
    return 0

def cmd_tag(args):
    """Write tags to file(s)."""
    files = find_music_files(args.path)
    if not files:
        print(f"No music files found in {args.path}")
        return 1

    tag_map = {}
    if args.artist: tag_map['artist'] = [args.artist]
    if args.album: tag_map['album'] = [args.album]
    if args.title: tag_map['title'] = [args.title]
    if args.track: tag_map['tracknumber'] = [str(args.track)]
    if args.year: tag_map['date'] = [str(args.year)]
    if args.genre: tag_map['genre'] = [args.genre]
    if args.albumartist: tag_map['albumartist'] = [args.albumartist]
    if args.disc: tag_map['discnumber'] = [str(args.disc)]
    if args.composer: tag_map['composer'] = [args.composer]
    if args.comment: tag_map['comment'] = [args.comment]

    if not tag_map:
        print("No tags specified. Use --artist, --album, --title, etc.")
        return 1

    count = 0
    for f in files:
        try:
            audio = mutagen.File(f, easy=True)
            if audio is None:
                continue
            if audio.tags is None:
                audio.add_tags()
            for key, val in tag_map.items():
                audio[key] = val
            audio.save()
            count += 1
            print(f"✅ Tagged: {f.name}")
        except Exception as e:
            print(f"❌ Failed: {f.name} — {e}")
    print(f"\n{count}/{len(files)} files tagged.")
    return 0

def cmd_rename(args):
    """Rename files based on tags."""
    files = find_music_files(args.path)
    if not files:
        print(f"No music files found in {args.path}")
        return 1

    pattern = args.pattern or "{track:02d} - {title}"
    count = 0
    for f in files:
        tags = get_easy_tags(f)
        try:
            # Build template vars
            tvars = {
                'artist': tags.get('artist', 'Unknown Artist'),
                'album': tags.get('album', 'Unknown Album'),
                'title': tags.get('title', f.stem),
                'year': tags.get('year', ''),
                'genre': tags.get('genre', ''),
                'disc': tags.get('disc', '1'),
            }
            # Handle track number formatting
            track_raw = tags.get('track', '0')
            track_num = int(re.split(r'[/\\]', str(track_raw))[0]) if track_raw else 0
            tvars['track'] = track_num

            new_name = pattern.format(**tvars)
            # Sanitize filename
            new_name = re.sub(r'[<>:"/\\|?*]', '_', new_name)
            new_path = f.parent / f"{new_name}{f.suffix}"

            if new_path == f:
                continue
            if new_path.exists():
                print(f"⚠️  Skipped (exists): {new_path.name}")
                continue

            f.rename(new_path)
            count += 1
            print(f"✅ {f.name} → {new_path.name}")
        except Exception as e:
            print(f"❌ Failed: {f.name} — {e}")

    print(f"\n{count}/{len(files)} files renamed.")
    return 0

def cmd_organize(args):
    """Organize files into folder structure."""
    files = find_music_files(args.path)
    if not files:
        print(f"No music files found in {args.path}")
        return 1

    dest = Path(args.dest or './sorted')
    structure = args.structure or "{artist}/{album}"
    count = 0

    for f in files:
        tags = get_easy_tags(f)
        try:
            tvars = {
                'artist': tags.get('artist', 'Unknown Artist'),
                'album': tags.get('album', 'Unknown Album'),
                'year': tags.get('year', ''),
                'genre': tags.get('genre', ''),
            }
            folder = structure.format(**tvars)
            folder = re.sub(r'[<>:"|?*]', '_', folder)
            target_dir = dest / folder
            target_dir.mkdir(parents=True, exist_ok=True)
            target_file = target_dir / f.name
            if target_file.exists():
                print(f"⚠️  Skipped (exists): {target_file}")
                continue
            shutil.move(str(f), str(target_file))
            count += 1
            print(f"✅ {f.name} → {folder}/")
        except Exception as e:
            print(f"❌ Failed: {f.name} — {e}")

    print(f"\n{count}/{len(files)} files organized.")
    return 0

def cmd_art_extract(args):
    """Extract embedded album art."""
    files = find_music_files(args.path)
    if not files:
        print(f"No music files found in {args.path}")
        return 1

    output_dir = args.output_dir or '.'
    os.makedirs(output_dir, exist_ok=True)
    count = 0

    for f in files:
        try:
            ext = f.suffix.lower()
            art_data = None
            art_ext = 'jpg'

            if ext == '.mp3':
                try:
                    tags = ID3(str(f))
                except ID3NoHeaderError:
                    continue
                for key, val in tags.items():
                    if isinstance(val, APIC):
                        art_data = val.data
                        if 'png' in val.mime:
                            art_ext = 'png'
                        break
            elif ext == '.flac':
                audio = FLAC(str(f))
                if audio.pictures:
                    art_data = audio.pictures[0].data
                    if 'png' in audio.pictures[0].mime:
                        art_ext = 'png'
            elif ext in ('.m4a', '.aac'):
                audio = MP4(str(f))
                if audio.tags and 'covr' in audio.tags:
                    art_data = bytes(audio.tags['covr'][0])

            if art_data:
                if args.output and len(files) == 1:
                    out_path = args.output
                else:
                    out_path = os.path.join(output_dir, f"{f.stem}_cover.{art_ext}")
                with open(out_path, 'wb') as of:
                    of.write(art_data)
                count += 1
                size_kb = len(art_data) / 1024
                print(f"✅ Extracted: {out_path} ({size_kb:.1f} KB)")
        except Exception as e:
            print(f"❌ Failed: {f.name} — {e}")

    print(f"\n{count} cover(s) extracted.")
    return 0

def cmd_art_embed(args):
    """Embed album art into file(s)."""
    if not args.image:
        print("❌ Specify --image <file>")
        return 1
    if not os.path.isfile(args.image):
        print(f"❌ Image not found: {args.image}")
        return 1

    files = find_music_files(args.path)
    if not files:
        print(f"No music files found in {args.path}")
        return 1

    with open(args.image, 'rb') as img:
        art_data = img.read()

    mime = 'image/jpeg'
    if args.image.lower().endswith('.png'):
        mime = 'image/png'

    count = 0
    for f in files:
        try:
            ext = f.suffix.lower()
            if ext == '.mp3':
                try:
                    tags = ID3(str(f))
                except ID3NoHeaderError:
                    from mutagen.id3 import ID3
                    tags = ID3()
                # Remove existing art
                tags.delall('APIC')
                tags.add(APIC(encoding=3, mime=mime, type=3, desc='Cover', data=art_data))
                tags.save(str(f))
            elif ext == '.flac':
                audio = FLAC(str(f))
                audio.clear_pictures()
                pic = Picture()
                pic.type = 3
                pic.mime = mime
                pic.desc = 'Cover'
                pic.data = art_data
                audio.add_picture(pic)
                audio.save()
            elif ext in ('.m4a', '.aac'):
                from mutagen.mp4 import MP4Cover
                audio = MP4(str(f))
                fmt = MP4Cover.FORMAT_JPEG if 'jpeg' in mime else MP4Cover.FORMAT_PNG
                audio.tags['covr'] = [MP4Cover(art_data, imageformat=fmt)]
                audio.save()
            else:
                print(f"⚠️  Art embedding not supported for {ext}: {f.name}")
                continue
            count += 1
            print(f"✅ Embedded art: {f.name}")
        except Exception as e:
            print(f"❌ Failed: {f.name} — {e}")

    print(f"\n{count}/{len(files)} files updated.")
    return 0

def cmd_strip(args):
    """Remove all tags from file(s)."""
    files = find_music_files(args.path)
    if not files:
        print(f"No music files found in {args.path}")
        return 1

    count = 0
    for f in files:
        try:
            audio = mutagen.File(f)
            if audio is not None and audio.tags is not None:
                audio.delete()
                audio.save()
                count += 1
                print(f"✅ Stripped: {f.name}")
        except Exception as e:
            print(f"❌ Failed: {f.name} — {e}")

    print(f"\n{count}/{len(files)} files stripped.")
    return 0

def cmd_auto_tag(args):
    """Parse tags from filenames."""
    if not args.from_pattern:
        print("❌ Specify --from-pattern, e.g. '{track} - {artist} - {title}'")
        return 1

    files = find_music_files(args.path)
    if not files:
        print(f"No music files found in {args.path}")
        return 1

    # Convert pattern to regex
    pattern = args.from_pattern
    field_names = re.findall(r'\{(\w+)\}', pattern)
    regex = pattern
    for field in field_names:
        regex = regex.replace(f'{{{field}}}', f'(?P<{field}>.+?)')
    regex = f'^{regex}$'

    field_to_tag = {
        'artist': 'artist', 'album': 'album', 'title': 'title',
        'track': 'tracknumber', 'year': 'date', 'genre': 'genre',
    }

    count = 0
    for f in files:
        stem = f.stem
        m = re.match(regex, stem)
        if not m:
            print(f"⚠️  No match: {f.name}")
            continue
        try:
            audio = mutagen.File(f, easy=True)
            if audio is None:
                continue
            if audio.tags is None:
                audio.add_tags()
            for field in field_names:
                val = m.group(field).strip()
                tag_key = field_to_tag.get(field, field)
                audio[tag_key] = [val]
            audio.save()
            count += 1
            matched = {fn: m.group(fn).strip() for fn in field_names}
            print(f"✅ {f.name} → {matched}")
        except Exception as e:
            print(f"❌ Failed: {f.name} — {e}")

    print(f"\n{count}/{len(files)} files auto-tagged.")
    return 0

def main():
    parser = argparse.ArgumentParser(description='Music Metadata Tagger')
    parser.add_argument('command', choices=['info', 'scan', 'tag', 'rename', 'organize', 'art-extract', 'art-embed', 'strip', 'auto-tag'])
    parser.add_argument('path', help='File or directory path')

    # Tag fields
    parser.add_argument('--artist', default=None)
    parser.add_argument('--album', default=None)
    parser.add_argument('--title', default=None)
    parser.add_argument('--track', default=None)
    parser.add_argument('--year', default=None)
    parser.add_argument('--genre', default=None)
    parser.add_argument('--albumartist', default=None)
    parser.add_argument('--disc', default=None)
    parser.add_argument('--composer', default=None)
    parser.add_argument('--comment', default=None)

    # Rename
    parser.add_argument('--pattern', default=None)

    # Organize
    parser.add_argument('--dest', default=None)
    parser.add_argument('--structure', default=None)

    # Art
    parser.add_argument('--image', default=None)
    parser.add_argument('--output', default=None)
    parser.add_argument('--output-dir', default=None)

    # Auto-tag
    parser.add_argument('--from-pattern', default=None)

    # Compat
    parser.add_argument('--id3v2', action='store_true')

    args = parser.parse_args()

    commands = {
        'info': cmd_info,
        'scan': cmd_scan,
        'tag': cmd_tag,
        'rename': cmd_rename,
        'organize': cmd_organize,
        'art-extract': cmd_art_extract,
        'art-embed': cmd_art_embed,
        'strip': cmd_strip,
        'auto-tag': cmd_auto_tag,
    }

    return commands[args.command](args)

if __name__ == '__main__':
    sys.exit(main() or 0)
